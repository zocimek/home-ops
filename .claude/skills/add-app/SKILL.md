---
name: add-app
description: Use when deploying a new application to the cluster — scaffolding a Flux Kustomization plus an app-template HelmRelease under kubernetes/apps/ ("add X to the cluster", "deploy X", "new app")
---

# Add a New Application

Scaffolds `kubernetes/apps/<namespace>/<app>/` with a Flux Kustomization (`ks.yaml`) and a HelmRelease. Everything below is drawn from this repo's current conventions — when a detail isn't covered, mirror a recent real app rather than inventing structure:

| Reference app | Shows |
|---|---|
| `kubernetes/apps/network/echo` | Minimal stateless app + route |
| `kubernetes/apps/default/gokapi` | volsync-backed persistence |
| `kubernetes/apps/default/reactive-resume` | ExternalSecret, postgres + dragonfly deps, OIDC, custom probes |
| `kubernetes/apps/observability/silence-operator` | Upstream (non-app-template) chart |
| `kubernetes/apps/renovate/renovate-operator` | Upstream chart with a CRD, plus a second Kustomization for the CRs |

## Step 1: Gather details

Ask (AskUserQuestion) for anything not already given:

1. **App name** and **namespace** — existing: `ls kubernetes/apps/`
2. **Image** repository + tag, or **upstream Helm chart** if it ships one
3. **Port**, and whether it gets a **route**: `envoy-internal` (LAN, default), `envoy-external` (public), or `envoy-privnote`. Hostnames are `<app>.pospiech.dev` (or `.prywatna-notatka.pl` for the privnote gateway)
4. **Persistence** — does it store state? (→ `components/volsync`)
5. **Secrets** — env vars from 1Password? Get the item name **and its exact field names**; never guess them, a wrong field renders an empty value with no error
6. **Database** — postgres (`components/postgres`) or dragonfly? Dragonfly logical DB numbers are tracked in the repo, pick an unused one
7. **Private registry** — images from `registry.pospiech.dev` need the `registry-creds` component on the namespace

## Step 2: Create the files

```
kubernetes/apps/<namespace>/<app>/
├── ks.yaml
└── app/
    ├── kustomization.yaml
    ├── ocirepository.yaml
    ├── helmrelease.yaml
    └── externalsecret.yaml      # only if secrets
```

### ks.yaml

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app <app>
spec:
  dependsOn:
    - name: onepassword          # only if the app has an ExternalSecret
      namespace: external-secrets
  interval: 30m
  path: "./kubernetes/apps/<namespace>/<app>/app"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: <namespace>
  wait: false
  retryInterval: 1m
  timeout: 5m
```

`metadata.namespace` is deliberately absent — the per-namespace `kustomization.yaml` injects it via its `namespace:` directive.

**Persistence** adds a component plus its substitutions (defaults live in `kubernetes/components/volsync/`):

```yaml
  components:
    - ../../../../components/volsync
  dependsOn:
    - name: volsync
      namespace: volsync-system
  postBuild:
    substitute:
      APP: *app
      VOLSYNC_CAPACITY: 5Gi        # default 5Gi
      VOLSYNC_PUID: "1000"         # default 3000 - match the image's uid
      VOLSYNC_PGID: "1000"         # default 3000
      # VOLSYNC_CLAIM: <app>-data          # default: <app>
      # VOLSYNC_STORAGECLASS: ceph-block   # default
      # VOLSYNC_SNAPSHOTCLASS: csi-ceph-blockpool
```

`APP` is required whenever any component is used. Getting `VOLSYNC_PUID`/`PGID` wrong leaves the mover unable to read the PVC — set them to the uid/gid the container actually runs as.

**Database** components (`../../../../components/postgres`, `../../../../components/dragonfly`) patch a `dependsOn` onto the HelmRelease themselves; postgres takes `USERNAME`, `DATABASES` and `POOL_MODE` substitutions.

### app/ocirepository.yaml

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: <app>
spec:
  interval: 15m
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: <version>
  url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

**Never write `<version>` from memory.** Read what the rest of the repo is on:

```bash
grep -h -A1 'app-template' kubernetes/apps/*/*/app/ocirepository.yaml | grep 'tag:' | sort | uniq -c | sort -rn | head -1
```

For an upstream chart, point `url` at its own OCI registry instead and look up the current release.

### app/helmrelease.yaml

```yaml
---
# yamllint disable-line rule:line-length
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app <app>
spec:
  interval: 30m
  chartRef:
    kind: OCIRepository
    name: <app>
  values:
    defaultPodOptions:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        fsGroupChangePolicy: OnRootMismatch
        seccompProfile:
          type: RuntimeDefault

    controllers:
      <app>:                       # literal name - the repo never uses *app as a key
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: <image-repo>
              tag: <image-tag>
            env:
              TZ: Europe/Warsaw
            probes:
              liveness:
                enabled: true
              readiness:
                enabled: true
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop: ["ALL"]
            resources:
              requests:
                cpu: 10m
              limits:
                memory: 256Mi

    service:
      app:
        controller: *app
        ports:
          http:
            port: <port>

    route:
      app:
        hostnames:
          - <app>.pospiech.dev
        parentRefs:
          - name: envoy-internal
            namespace: network
            sectionName: https
        rules:
          - backendRefs:
              - identifier: app
                port: <port>

    persistence:
      data:
        existingClaim: *app        # must match VOLSYNC_CLAIM if overridden
        globalMounts:
          - path: /data
      tmp:                         # required whenever readOnlyRootFilesystem is on
        type: emptyDir
        globalMounts:
          - path: /tmp
```

Drop the blocks that don't apply. `automountServiceAccountToken: false` matters — app-template v5 defaults it to `false` for wrapped controllers, and anything using `GetConfigOrDie` will CrashLoop before serving a probe if it needs the token.

Secrets are wired on the container:

```yaml
            envFrom:
              - secretRef:
                  name: <app>-secret
```

**Gatus:** don't add a `gatus.home-operations.com/endpoint` annotation just to be monitored — the sidecar runs with `--auto-httproute` and picks up every HTTPRoute. Annotate only to override the URL, conditions or group.

### app/externalsecret.yaml (only if secrets)

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: &secretName <app>-secret
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: *secretName
    template:
      engineVersion: v2
      data:
        SOME_ENV_VAR: "{{ .FIELD_NAME }}"
  dataFrom:
    - extract:
        key: <1password-item>
```

The store is `onepassword` (not `onepassword-connect`) and it is scoped to the **Kubernetes** vault only. `FIELD_NAME` must be the item's real field name from Step 1.

## Step 3: Register it

Add `./<app>/ks.yaml` to `kubernetes/apps/<namespace>/kustomization.yaml` under `resources`, alphabetically among the app entries (`namespace.yaml` stays first).

**New namespace?** Create the directory with a `namespace.yaml` (keep the literal `name: _`; kustomize rewrites it) and a `kustomization.yaml` carrying `namespace: <ns>` and the `../../components/alerts` component. Nothing registers the directory itself — Flux's `cluster-apps` Kustomization points at `./kubernetes/apps` with no kustomization.yaml, so kustomize autodetects any subdirectory that has one.

## Step 4: Verify

```bash
kustomize build kubernetes/apps/<namespace>/<app>/app   # ${APP} staying literal is expected
yamllint kubernetes/apps/<namespace>/<app>
```

For an upstream chart, also render it with the real values before committing — it catches a mistyped value key that kustomize never sees:

```bash
yq '.spec.values' kubernetes/apps/<ns>/<app>/app/helmrelease.yaml > /tmp/v.yaml
helm template <app> oci://<chart-url> --version <tag> -n <ns> -f /tmp/v.yaml | head -50
```

Show the user the files and get confirmation before committing. Commit style: `feat(<app>): deploy <App>`. Always open a PR; never push to `main`.

## Common mistakes

- **Copying a chart version or image tag from this file or from memory** — read the current one out of the repo and check upstream for the image.
- **Guessing 1Password field names** — a wrong name renders an empty string silently. Ask, or leave a `<FIXME>` and say so.
- **`readOnlyRootFilesystem: true` with no `/tmp` emptyDir** — anything that writes to `/tmp` crashes.
- **Forgetting `reloader.stakater.com/auto`** — secret and config changes then never restart the pod.
- **Wrong `VOLSYNC_PUID`/`PGID`** — the backup mover can't read the PVC.
- **Adding `metadata.namespace`** to a HelmRelease or Kustomization — the namespace comes from the parent kustomization.
- **Assuming a new namespace needs registering somewhere** — it doesn't; the directory is autodetected.
