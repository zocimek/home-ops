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
# The vault has to be the one the CONSUMING cluster's ClusterSecretStore is
# scoped to: Kubernetes for the homelab, Poetica.pl for the poetica cluster
# (e.g. `just gen-oauth konflate Poetica.pl`).
[doc('Generate an OIDC client id/secret pair into a 1Password item')]
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

    # Fetched once, never echoed - it carries every existing field value.
    item_json="$(op item get "{{ app }}" --vault "{{ vault }}" --format json 2>/dev/null || true)"

    if [[ -z "$item_json" ]]; then
        just log info "Creating item" "item" "{{ app }}" "vault" "{{ vault }}"
        op item create --category "API Credential" --title "{{ app }}" --vault "{{ vault }}" \
            "OIDC_CLIENT_ID[text]=${client_id}" \
            "OIDC_CLIENT_SECRET[password]=${client_secret}" >/dev/null
    elif jq -e '.fields[]? | select(.label == "OIDC_CLIENT_ID")' <<<"$item_json" >/dev/null 2>&1 \
        && [[ "{{ force }}" != "true" ]]; then
        # Overwriting in place would leave Authentik and the cluster briefly
        # disagreeing, and every issued session invalid. Make that deliberate.
        just log fatal "OIDC fields already exist - pass force=true as the 3rd argument to rotate" \
            "item" "{{ app }}" "vault" "{{ vault }}"
    else
        just log info "Adding OIDC fields to existing item" "item" "{{ app }}" "vault" "{{ vault }}"
        op item edit "{{ app }}" --vault "{{ vault }}" \
            "OIDC_CLIENT_ID[text]=${client_id}" \
            "OIDC_CLIENT_SECRET[password]=${client_secret}" >/dev/null
    fi

    just log info "Wrote OIDC_CLIENT_ID and OIDC_CLIENT_SECRET" "item" "{{ app }}" "vault" "{{ vault }}"
    just log info "Next: reference the item in terraform/authentik/applications.tf, then terraform apply"

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
