---
name: debug-flux
description: Use when something in the cluster isn't reconciling — a Kustomization or HelmRelease is stuck, an app didn't deploy, a secret is missing, or "why is X not running / not updating"
---

# Debug a Flux Reconciliation

Work top-down. A leaf app almost never breaks on its own; it's usually blocked by the thing above it in the chain: `GitRepository` → `Kustomization` → `OCIRepository` → `HelmRelease` → workload, with `ExternalSecret` hanging off the side.

## Connect

`mise` sets `KUBECONFIG` for this repo, so a shell in the repo root is already pointed at the cluster:

```bash
KUBECONFIG=~/.kube/configs/config.homelab kubectl get nodes
```

Never print secret values. To inspect a Secret, list its keys: `kubectl get secret <n> -o json | jq '.data | keys'`.

## Step 1: Find the broken link

```bash
flux get kustomizations -A --status-selector ready=false
flux get helmreleases -A --status-selector ready=false
flux get sources all -A --status-selector ready=false
```

If a Kustomization is `Unknown` rather than `False`, it's waiting on `dependsOn` — chase the dependency, not the app. Only `dependsOn` a Kustomization that has `wait: true` or `healthChecks`; without either, the gate is meaningless and the dependent starts too early.

## Step 2: Read the actual message

```bash
flux -n <ns> get kustomization <name>
kubectl -n <ns> describe kustomization <name> | tail -30
kubectl -n <ns> describe helmrelease <name> | tail -40
```

Then force a retry rather than waiting for the interval:

```bash
flux -n flux-system reconcile source git flux-system     # pull latest commit first
flux -n <ns> reconcile kustomization <name> --with-source
flux -n <ns> reconcile helmrelease <name> --force
```

## Common causes, in rough order of frequency

**ExternalSecret not syncing.** The app's Secret never appears, so the pod sits in `CreateContainerConfigError`.

```bash
kubectl -n <ns> get externalsecret
kubectl -n <ns> describe externalsecret <name> | tail -20
kubectl -n external-secrets logs deploy/onepassword -c api --tail=50
```

Usually the 1Password item or field name is wrong. The store is `onepassword` and it is scoped to the **Kubernetes** vault only — an item in any other vault is invisible. A wrong *field* name is worse than a wrong item: templating renders an empty string with no error, so the Secret exists and looks fine while the app fails on a blank credential.

**Values the chart doesn't have.** A HelmRelease that installs but does nothing you asked for usually has a mistyped value key — Helm ignores unknown keys silently. Render it locally:

```bash
yq '.spec.values' kubernetes/apps/<ns>/<app>/app/helmrelease.yaml > /tmp/v.yaml
helm template <app> oci://<url> --version <tag> -n <ns> -f /tmp/v.yaml
```

**Drift detection reverting your fix.** `cluster-apps` patches `driftDetection.mode: enabled` onto every HelmRelease, so a `kubectl edit` on a managed resource is undone on the next reconcile. Change the manifest and merge it. (`rook-ceph-cluster`, `inzosoft-amd64` and `poetica-amd64` are patched back to `disabled` — check `kubernetes/flux/cluster/ks.yaml` before assuming.)

**The manifest isn't what Flux sees.** Flux renders from the last commit on `main`, not your working tree. Confirm what's actually deployed:

```bash
flux -n flux-system get source git flux-system   # which revision is live
kustomize build kubernetes/apps/<ns>/<app>/app   # what it renders to
```

`${APP}` and other `${...}` staying literal in that output is expected — `postBuild.substitute` runs server-side.

**Job or hook failing on a cold pod.** Anything whose first action is an off-cluster call can fail on a freshly scheduled pod before egress is ready. Check whether the pod is new and whether the failure is a DNS or connection error before treating it as a config bug.

**A new namespace directory not picked up.** It is autodetected — but only if it contains a `kustomization.yaml`. A directory with just manifests in it is silently ignored.

## Step 3: Workload level

Once Flux itself is green and the app is still wrong:

```bash
kubectl -n <ns> get pods -o wide
kubectl -n <ns> describe pod <pod> | tail -30
kubectl -n <ns> logs <pod> --previous --tail=100    # --previous for CrashLoopBackOff
kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -20
```

`CreateContainerConfigError` → a missing Secret/ConfigMap (go back to ExternalSecret). `CrashLoopBackOff` with an immediate exit → read `--previous` logs; a read-only root filesystem with no `/tmp` emptyDir and a wrong `runAsUser` are the two usual culprits. `Pending` → check PVC binding and node resources.

## Don't

- Don't `kubectl apply` or `edit` a fix into the cluster and call it done — drift detection reverts it and the repo stays wrong. Fix the manifest and open a PR.
- Don't delete a Kustomization to "force" it. `cluster-apps` sets `deletionPolicy: WaitForTermination` and pruning is on, so this can take real workloads with it.
- Don't read Secret values into the transcript.
