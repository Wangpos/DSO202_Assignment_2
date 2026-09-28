#!/usr/bin/env bash
# =============================================================================
# scripts/rbac-check.sh - prove the RBAC design in manifests/04-rbac.yaml
#
# Asks the API server (kubectl auth can-i --as=...) what each identity may do.
# The API server answers from the real Roles/RoleBindings, so this is evidence
# of behaviour, not a reading of the YAML (lecture 2.3.6).
# =============================================================================
NS=dso202-assignment-02
check() { # <identity> <verb> <resource> <namespace>
  printf '%-22s %-7s %-30s %-22s -> %s\n' "$1" "$2" "$3" "$4" \
    "$(kubectl auth can-i "$2" "$3" -n "$4" --as="system:serviceaccount:$NS:$1" 2>/dev/null)"
}
printf '%-22s %-7s %-30s %-22s    %s\n' IDENTITY VERB RESOURCE NAMESPACE ALLOWED
check tasktracker-viewer   list   pods                  $NS
check tasktracker-viewer   get    pods/log              $NS
check tasktracker-viewer   get    secrets               $NS
check tasktracker-viewer   delete pods                  $NS
check tasktracker-viewer   list   pods                  kube-system
check tasktracker-deployer patch  deployments.apps      $NS
check tasktracker-deployer patch  statefulsets.apps     $NS
check tasktracker-deployer create ingresses.networking.k8s.io $NS
check tasktracker-deployer delete deployments.apps      $NS
check tasktracker-deployer get    secrets               $NS
check tasktracker-deployer create deployments.apps      dso202-assignment-01
check backend-sa           list   pods                  $NS
