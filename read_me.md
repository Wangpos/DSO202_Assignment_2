# DSO202 Assignment 2 — Task Tracker rebuilt with Unit II concepts

Assignment 1 deployed a three-tier Task Tracker (nginx frontend, Node.js API,
PostgreSQL) on a kind cluster using Unit I objects. Assignment 2 deploys the
**same application images** again, redesigned with the Unit II concepts:

| Unit II topic | Assignment 1 | Assignment 2 | Files |
| --- | --- | --- | --- |
| 2.1 StatefulSets | DB as a `Deployment` + hand-made PVC | DB as `StatefulSet db` with headless `db-svc`, `volumeClaimTemplates`, retention policy | `manifests/05-database-statefulset.yaml` |
| 2.2 Ingress | `frontend-svc` NodePort 30080, `/api` proxied inside the frontend's nginx | ingress-nginx controller + `Ingress` with TLS, host `tasktracker.local`, `/api` → backend, `/` → frontend; all Services ClusterIP | `manifests/08-ingress.yaml`, `scripts/make-tls.sh` |
| 2.3 RBAC | every Pod ran as `default` SA with a mounted token | one SA per tier, no token mounted; read-only `tasktracker-viewer` and least-privilege `tasktracker-deployer` Roles | `manifests/03-serviceaccounts.yaml`, `manifests/04-rbac.yaml`, `scripts/rbac-check.sh`, `scripts/token-demo.sh` |
| 2.4 Operators | — | a CRD with no controller (stored, nothing happens) vs. the CloudNativePG Operator running a 2-instance PostgreSQL cluster with automatic failover | `operator/` |

Assignment 1's original manifests are kept unchanged at the repository root
(`namespace.yaml`, `database/`, `backend/`, `frontend/`, …) as the baseline.
Assignment 2 lives in its own namespace, `dso202-assignment-02`.

## Repository layout

```
manifests/                  Assignment 2, applied in lexical order
  00-namespace.yaml         Namespace dso202-assignment-02
  01-quota-and-limits.yaml  ResourceQuota + LimitRange
  02-config.yaml            ConfigMap + Secret (lab credentials)
  03-serviceaccounts.yaml   db-sa, backend-sa, frontend-sa (no API token)
  04-rbac.yaml              viewer + deployer ServiceAccounts, Roles, RoleBindings
  05-database-statefulset.yaml  headless db-svc + StatefulSet db
  06-backend.yaml           Deployment backend (2) + ClusterIP backend-svc
  07-frontend.yaml          nginx ConfigMap + Deployment frontend (2) + ClusterIP frontend-svc
  08-ingress.yaml           Ingress tasktracker-ingress (TLS, path routing)
operator/
  01-crd-without-controller.yaml  CRD TaskTrackerDB + one CR (no controller)
  02-cnpg-cluster.yaml            CloudNativePG Cluster tasksdb-ha (2 instances, pinned to
                                  dso202-worker - see the file header for why)
scripts/
  make-tls.sh       self-signed cert -> Secret tasktracker-tls (key stays in tls/, git-ignored)
  rbac-check.sh     kubectl auth can-i matrix for every identity
  token-demo.sh     real requests with a short-lived ServiceAccount token
evidence/           raw command output (.txt) behind every screenshot
screenshot/         U2-xx terminal screenshots referenced by REPORT.md
REPORT.md           the assessed report
```

## Versions used

kind v0.32.0 · Kubernetes v1.36.1 (3 nodes) · kubectl v1.37.2 · Docker 29.9.2 ·
ingress-nginx controller-v1.15.1 · CloudNativePG 1.30.1 · images
`sarojsanyasi/dso202-{db,backend,frontend}:1.0` (same as Assignment 1).

## Rebuild from scratch

```bash
# 0. Cluster (Assignment 1 config) and context
kind create cluster --config kind-config.yaml        # skip if it already exists
kubectl config use-context kind-dso202

# 1. Ingress controller (2.2.2) - must run before an Ingress does anything
kubectl label node dso202-control-plane ingress-ready=true
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=600s

# 2. Application tiers, RBAC and StatefulSet
kubectl apply -f manifests/00-namespace.yaml
./scripts/make-tls.sh                                # Secret tasktracker-tls
kubectl apply -f manifests/
kubectl config set-context --current --namespace=dso202-assignment-02
kubectl rollout status statefulset/db
kubectl rollout status deployment/backend

# 3. Reach the app through the Ingress (kind does not publish 443 to the host)
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8443:443
curl -k --resolve tasktracker.local:8443:127.0.0.1 https://tasktracker.local:8443/api/status
#   browser: add "127.0.0.1 tasktracker.local" to /etc/hosts, open https://tasktracker.local:8443

# 4. RBAC checks
./scripts/rbac-check.sh
./scripts/token-demo.sh tasktracker-viewer

# 5. Operators
kubectl apply -f operator/01-crd-without-controller.yaml   # CRD, then wait ...
kubectl wait --for=condition=Established crd/tasktrackerdbs.dso202.cst.edu.bt
kubectl apply -f operator/01-crd-without-controller.yaml   # ... then the CR
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/releases/cnpg-1.30.1.yaml
kubectl rollout status -n cnpg-system deployment/cnpg-controller-manager
kubectl apply -f operator/02-cnpg-cluster.yaml
kubectl get cluster -n dso202-operator-lab -w
```

Verify the cluster still matches the repository: `kubectl diff -f manifests/`.

## Cleanup

```bash
kubectl delete -f operator/02-cnpg-cluster.yaml
kubectl delete -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/releases/cnpg-1.30.1.yaml
kubectl delete -f operator/01-crd-without-controller.yaml
kubectl delete -f manifests/
kubectl delete pvc data-db-0 -n dso202-assignment-02   # retained on purpose (whenDeleted: Retain)
kubectl delete namespace dso202-assignment-02
kubectl config set-context --current --namespace=default
```
