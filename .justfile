#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod kube "kubernetes"

[private]
default:
    just -l

# Authentik does NOT generate these - terraform/authentik pushes whatever is in
# 1Password into the provider, so the pair is invented here and 1Password is the
# source of truth for both halves.
#
# `vault` accepts a comma-separated list, and every vault gets the SAME
# generated pair. That matters when the two consumers disagree: terraform reads
# the Kubernetes vault, but a cluster can only read the vault its
# ClusterSecretStore is scoped to - konflate needs
# `just gen-oauth konflate Kubernetes,Poetica.pl`. Copying a 128-character
# secret between vaults by hand risks a mismatch that surfaces only as
# invalid_client at login.
[doc('Generate an OIDC client id/secret pair into one or more 1Password items')]
gen-oauth app vault="Kubernetes" force="false":
    #!/usr/bin/env bash
    # A shebang recipe rather than the usual backslash continuations: enough
    # branching here that one continued line stops being reviewable.
    set -euo pipefail

    # Hints go in the message, not in *args: `log` passes args unquoted, so gum
    # word-splits a multi-word value into nonsense key=value pairs.
    if ! op account get >/dev/null 2>&1; then
        just log fatal 'Not signed in to 1Password - run: eval $(op signin)'
    fi

    # Matches authentik/lib/generators.py: client_id is generate_id(40) and
    # client_secret is generate_client_secret() -> generate_id(128), both drawn
    # from string.ascii_letters + string.digits. That is base62, NOT hex - a
    # hex value is valid but visibly unlike anything Authentik issues.
    # (generate_key() does include punctuation, but no OAuth2 field uses it.)
    gen_id() {
        local length="$1" out
        # cut rather than `head -c`: head closes the pipe early, which under
        # pipefail surfaces as a SIGPIPE failure from openssl.
        out="$(openssl rand -base64 "$(( length * 3 ))" | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c "1-${length}")"
        if [[ "${#out}" -ne "$length" ]]; then
            just log fatal "Generated a short value - openssl or tr misbehaved"
        fi
        printf '%s' "$out"
    }

    client_id="$(gen_id 40)"
    client_secret="$(gen_id 128)"

    # Both fields live in an "OIDC" SECTION, and that is load-bearing rather
    # than cosmetic: terraform-1password-item builds its `fields` map by
    # iterating item.section[].field[], so a field outside a section is
    # invisible to `module.onepassword_oauth[...].fields["OIDC_CLIENT_ID"]`.
    # External-secrets looks fields up by label and doesn't care either way.
    #
    # Both CONCEALED - the client id isn't quite a secret, but the module
    # wraps CONCEALED values in sensitive(), which keeps them out of plan
    # output.
    fields_json="$(jq -n --arg id "$client_id" --arg secret "$client_secret" '[
        {section: {id: "OIDC", label: "OIDC"}, type: "CONCEALED", label: "OIDC_CLIENT_ID", value: $id},
        {section: {id: "OIDC", label: "OIDC"}, type: "CONCEALED", label: "OIDC_CLIENT_SECRET", value: $secret}
    ]')"

    # One temp dir for every vault's merge file, cleaned up once.
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    IFS=',' read -ra vaults <<< "{{ vault }}"
    for v in "${vaults[@]}"; do
        v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
        [[ -n "$v" ]] || continue

        # Fetched once, never echoed - it carries every existing field value.
        item_json="$(op item get "{{ app }}" --vault "${v}" --format json 2>/dev/null || true)"

        if [[ -z "$item_json" ]]; then
            just log info "Creating item" "item" "{{ app }}" "vault" "${v}"
            # Piped, not assignment statements: `op item create --help` warns that
            # arguments land in shell history and are readable by other local
            # processes, and says to use a template for sensitive values.
            # SECURE_NOTE carries exactly one built-in field (notesPlain), so the
            # item is the OIDC section and nothing else. The other two candidates
            # are worse: PASSWORD refuses to validate without a value in its
            # built-in password field ("Password item requires ps value") - absent
            # and empty are both rejected, so it would need filler nothing reads -
            # and API_CREDENTIAL drags in seven unused fields (username,
            # credential, type, filename, valid from, expires, hostname).
            #
            # Category is cosmetic here: terraform-1password-item reads
            # item.section[].field[] and external-secrets resolves by label, so
            # neither looks at it. The existing OIDC items are PASSWORD with an
            # EMPTY password, which the UI allows and the CLI will not create - if
            # you want that shape, make the item in the app first and this recipe
            # will add the section without touching the category.
            jq -n --arg title "{{ app }}" --argjson fields "$fields_json" \
                '{title: $title, category: "SECURE_NOTE", sections: [{id: "OIDC", label: "OIDC"}], fields: $fields}' \
                | op item create --vault "${v}" - >/dev/null
        elif jq -e '.fields[]? | select(.label == "OIDC_CLIENT_ID")' <<<"$item_json" >/dev/null 2>&1 \
            && [[ "{{ force }}" != "true" ]]; then
            # Overwriting in place would leave Authentik and the cluster briefly
            # disagreeing, and every issued session invalid. Make that deliberate.
            just log fatal "OIDC fields already exist - pass force=true as the 3rd argument to rotate" \
                "item" "{{ app }}" "vault" "${v}"
        else
            just log info "Adding OIDC fields to existing item" "item" "{{ app }}" "vault" "${v}"
            # `op item edit` takes --template but not piped input, so this one has
            # to go through a file. Created 0600 and removed on any exit.
            tmp="$workdir/${v//\//_}.json"
            (umask 077; : > "$tmp")
            # Merge rather than replace: the template is the item's whole new
            # state, so anything dropped here (WEBHOOK_SECRET, App credentials)
            # would be deleted from the item.
            # Category is left as-is: an existing item may legitimately be a
            # Password or Login, and rewriting that is not this recipe's business.
            jq --argjson fields "$fields_json" '
                .sections = ((.sections // []) | if any(.label == "OIDC") then . else . + [{id: "OIDC", label: "OIDC"}] end)
                | .fields = ((.fields // []) | map(select(.label != "OIDC_CLIENT_ID" and .label != "OIDC_CLIENT_SECRET"))) + $fields
            ' <<<"$item_json" > "$tmp"
            op item edit "{{ app }}" --vault "${v}" --template "$tmp" >/dev/null
        fi
    done

    just log info "Wrote OIDC_CLIENT_ID and OIDC_CLIENT_SECRET" "item" "{{ app }}" "vaults" "{{ vault }}"
    just log info "Next: reference the item in terraform/authentik/applications.tf, then terraform apply"

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
