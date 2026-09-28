#!/usr/bin/env bash
# =============================================================================
# scripts/token-demo.sh <serviceaccount> - act AS a ServiceAccount for real
#
# 'kubectl auth can-i --as' asks the API server a hypothetical question. This
# script goes one step further: it requests a short-lived token for the
# ServiceAccount (TokenRequest API, 10 minutes), writes a throw-away kubeconfig
# that contains ONLY that token, and sends real requests with it. The
# admin client certificate is not present, so every answer below comes from
# authentication (token -> identity) followed by RBAC (identity -> allowed?).
# The token is never printed and the kubeconfig is deleted on exit.
# =============================================================================
set -uo pipefail
NS=dso202-assignment-02
SA=${1:-tasktracker-viewer}
CFG=$(mktemp); trap 'rm -f "$CFG"' EXIT

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$CFG.ca"
TOKEN=$(kubectl create token "$SA" -n "$NS" --duration=10m)
KUBECONFIG="$CFG" kubectl config set-cluster kind --server="$SERVER" --certificate-authority="$CFG.ca" --embed-certs >/dev/null
KUBECONFIG="$CFG" kubectl config set-credentials "$SA" --token="$TOKEN" >/dev/null
KUBECONFIG="$CFG" kubectl config set-context sa --cluster=kind --user="$SA" --namespace="$NS" >/dev/null
KUBECONFIG="$CFG" kubectl config use-context sa >/dev/null
rm -f "$CFG.ca"

run() { echo "+ kubectl $*"; KUBECONFIG="$CFG" kubectl "$@" 2>&1; echo; }
run auth whoami
run get pods -l app=tasktracker
run get secrets
run delete pod db-0 --dry-run=server
run get pods -n kube-system
