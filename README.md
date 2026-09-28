# DSO202 Assignment 1

## Purpose

This repository deploys the provided three-tier Task Tracker application to the
`kind-dso202` Kubernetes cluster. All resources are isolated in the
`dso202-assignment-01` namespace.

## Architecture

The kind control-plane node hosts the Kubernetes API server, scheduler,
controller manager, and kubelet. The scheduler assigns one Pod for each tier
to the node. Deployments manage the frontend, backend, and database Pods and
their ReplicaSets. Services provide stable networking: `frontend-svc` is the
external NodePort, `backend-svc` is an internal ClusterIP, and `db-svc` is an
internal headless Service. The ConfigMap supplies non-sensitive configuration,
the Secret supplies database credentials, the PVC keeps PostgreSQL data across
Pod replacement, and the ResourceQuota and LimitRange govern namespace usage.

## Images and ports

| Tier     | Image                               | Internal port | Service          |
| -------- | ----------------------------------- | ------------: | ---------------- |
| Frontend | `sarojisanyasi/dso202-frontend:1.0` |          8080 | NodePort `30080` |
| Backend  | `sarojisanyasi/dso202-backend:1.0`  |          8080 | ClusterIP `8080` |
| Database | `sarojisanyasi/dso202-db:1.0`       |          5432 | Headless `5432`  |

The kind configuration maps host port `8080` to frontend NodePort `30080`.

## Configuration mapping

`configmap.yaml` contains `DB_HOST`, `DB_PORT`, `DB_NAME`, `APP_PORT`,
`CORS_ORIGIN`, `POSTGRES_DB`, and `BACKEND_URL`. `secret.yaml` contains the
credential values under both naming conventions required by the application:

| Backend variables | PostgreSQL image variables |
| ----------------- | -------------------------- |
| `DB_NAME`         | `POSTGRES_DB`              |
| `DB_USER`         | `POSTGRES_USER`            |
| `DB_PASSWORD`     | `POSTGRES_PASSWORD`        |

The backend connects to `db-svc`. The browser frontend uses the same-origin
`/api` path, which nginx proxies internally to `backend-svc:8080`; this keeps
the backend and database unreachable from outside the cluster.

Kubernetes Secret values are base64-encoded, not encrypted at rest by default.
Production deployments should enable encryption at rest and use stronger
secret-management controls. The permissive backend CORS setting is also only
for classroom use; production should restrict it to known origins.

## Resource governance

The ResourceQuota allows up to six Pods, 1 CPU and 1 GiB of requested memory,
and 2 CPUs and 2 GiB of memory limits. The three single-replica Deployments
fit within these bounds while leaving room for a replacement Pod during a
rolling update. The LimitRange supplies defaults of 100m CPU and 128Mi memory
per container, caps containers at 500m CPU and 512Mi memory, and prevents
containers from requesting less than 50m CPU and 64Mi memory.

## Apply and verify

Use the assignment cluster before applying:

```bash
kubectl config use-context kind-dso202
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml -f secret.yaml -f quota.yaml
kubectl apply -f frontend/configmap.yaml
kubectl apply -f database/ -f backend/ -f frontend/
kubectl get all,pvc,configmap,secret,resourcequota,limitrange -n dso202-assignment-01
```

Open the frontend at `http://localhost:8080` or use a port-forward when the
kind port mapping is unavailable.

## Assignment evidence

- CRUD create, list, update, and delete: screenshots 2.2, 3, 4, and 5.
- Service DNS resolution from the frontend Pod: screenshot 6.
- Backend Pod self-healing: screenshots 7 and 7.1.
- Data persistence after backend replacement: screenshot 9.
- Namespace objects and running resources: screenshot 1.
- ResourceQuota and LimitRange: terminal evidence from `kubectl get` and
  `kubectl describe`.
- Declarative versus imperative management: `kubectl apply -f namespace.yaml`
  and `kubectl create configmap imperative-evidence ...` were both executed.

The remaining evidence to capture is a frontend browser screenshot showing the
CRUD workflow through `http://localhost:8080`.

## Declarative versus imperative operation

Declarative management uses version-controlled YAML and `kubectl apply`, so
the desired state is repeatable and reviewable. Imperative management uses a
direct command such as `kubectl create namespace example-imperative`, which is
quick for one-off actions but does not keep the complete desired state in the
repository. This assignment uses declarative YAML for the submitted resources.
# DSO202_Assignment_2
