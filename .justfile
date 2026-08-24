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

    # Authentik's own generator uses a 40-character client id and a
    # 128-character secret. Matching those lengths keeps a generated provider
    # indistinguishable from one created in the UI.
    client_id="$(openssl rand -hex 20)"
    client_secret="$(openssl rand -hex 64)"

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
