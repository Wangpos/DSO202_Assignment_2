#!/usr/bin/env bash
# =============================================================================
# scripts/make-tls.sh - self-signed certificate for the Ingress (Unit II 2.2.1)
#
# Creates tls/tasktracker.{key,crt} for host tasktracker.local and stores them
# in the kubernetes.io/tls Secret 'tasktracker-tls' referenced by
# manifests/08-ingress.yaml. The tls/ directory is git-ignored: private keys
# are never committed. In production cert-manager would issue and renew this.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
NS=dso202-assignment-02
mkdir -p tls

openssl req -x509 -nodes -newkey rsa:2048 -days 90 \
  -keyout tls/tasktracker.key -out tls/tasktracker.crt \
  -subj "/CN=tasktracker.local/O=DSO202" \
  -addext "subjectAltName=DNS:tasktracker.local" 2>/dev/null

openssl x509 -in tls/tasktracker.crt -noout -subject -ext subjectAltName -enddate

# --dry-run | apply makes the script safe to re-run (create would fail twice).
kubectl create secret tls tasktracker-tls -n "$NS" \
  --cert=tls/tasktracker.crt --key=tls/tasktracker.key \
  --dry-run=client -o yaml | kubectl apply -f -
