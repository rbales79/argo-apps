#!/bin/bash
#
# Cluster Cleanup Script
# Purpose: Clean up stuck resources, finalizers, and problematic operators
# Usage: ./cleanup-cluster.sh [options]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Remove finalizers from Argo CD applications
cleanup_argocd_applications() {
    log_info "Cleaning up Argo CD applications..."

    local apps=$(oc get applications -n openshift-gitops -o name 2>/dev/null || echo "")

    if [ -z "$apps" ]; then
        log_info "No Argo CD applications found"
        return
    fi

    for app in $apps; do
        log_info "Removing finalizers from $app"
        oc patch $app -n openshift-gitops --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    done

    log_success "Argo CD applications cleaned"
}

# Clean up stuck terminating namespaces
cleanup_stuck_namespaces() {
    log_info "Cleaning up stuck terminating namespaces..."

    local stuck_ns=$(oc get namespaces | grep Terminating | awk '{print $1}')

    if [ -z "$stuck_ns" ]; then
        log_info "No stuck namespaces found"
        return
    fi

    for ns in $stuck_ns; do
        log_warning "Found stuck namespace: $ns"

        # Remove finalizers from all pods
        log_info "  Removing pod finalizers in $ns..."
        for pod in $(oc get pods -n $ns -o name 2>/dev/null); do
            oc patch $pod -n $ns --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
        done

        # Remove finalizers from all PVCs
        log_info "  Removing PVC finalizers in $ns..."
        for pvc in $(oc get pvc -n $ns -o name 2>/dev/null); do
            oc patch $pvc -n $ns --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
        done

        # Remove finalizers from all PVs
        log_info "  Removing PV finalizers for $ns..."
        for pv in $(oc get pv -o name 2>/dev/null | grep "$ns"); do
            oc patch $pv --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
        done

        # Check for any remaining resources
        log_info "  Checking for remaining resources in $ns..."
        local remaining=$(oc api-resources --verbs=list --namespaced -o name 2>/dev/null | \
                         xargs -n 1 oc get --show-kind --ignore-not-found -n $ns 2>&1 | \
                         grep -v "^Warning:" | grep -v "^NAME" | grep -v "packagemanifest" | head -5)

        if [ -n "$remaining" ]; then
            log_warning "  Found remaining resources in $ns:"
            echo "$remaining"
        fi

        log_success "  Cleaned $ns"
    done
}

# Clean up Kasten resources
cleanup_kasten() {
    log_info "Cleaning up Kasten K10..."

    # Remove Kasten API services
    local kasten_api=$(oc get apiservices 2>/dev/null | grep "kio.kasten.io" | awk '{print $1}')
    if [ -n "$kasten_api" ]; then
        log_info "  Removing Kasten API services..."
        echo "$kasten_api" | xargs oc delete apiservice 2>/dev/null || true
        log_success "  Kasten API services removed"
    fi

    # Remove Kasten CRDs
    local kasten_crds=$(oc get crd 2>/dev/null | grep "kio.kasten.io" | awk '{print $1}')
    if [ -n "$kasten_crds" ]; then
        log_info "  Removing Kasten CRDs..."
        echo "$kasten_crds" | xargs oc delete crd 2>/dev/null || true
        log_success "  Kasten CRDs removed"
    fi

    # Remove k10 CR if exists
    if oc get k10.apik10.kasten.io/k10 -n kasten-io &>/dev/null; then
        log_info "  Removing k10 CR finalizers..."
        oc patch k10.apik10.kasten.io/k10 -n kasten-io --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    fi

    log_success "Kasten cleanup complete"
}

# Clean up External Secrets Operator
cleanup_external_secrets() {
    log_info "Cleaning up External Secrets Operator..."

    # Remove ClusterSecretStore CRs
    local css=$(oc get clustersecretstores -o name 2>/dev/null)
    if [ -n "$css" ]; then
        log_info "  Removing ClusterSecretStore CRs..."
        echo "$css" | xargs oc delete 2>/dev/null || true
    fi

    # Remove ExternalSecret CRs
    local es=$(oc get externalsecrets --all-namespaces -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null)
    if [ -n "$es" ]; then
        log_info "  Removing ExternalSecret CRs..."
        while IFS= read -r line; do
            ns=$(echo $line | awk '{print $1}')
            name=$(echo $line | awk '{print $2}')
            oc delete externalsecret $name -n $ns 2>/dev/null || true
        done <<< "$es"
    fi

    # Remove OperatorConfig CRs
    local oc_res=$(oc get operatorconfigs --all-namespaces -o name 2>/dev/null)
    if [ -n "$oc_res" ]; then
        log_info "  Removing OperatorConfig CRs..."
        echo "$oc_res" | xargs oc delete 2>/dev/null || true
    fi

    # Remove ESO CRDs
    local eso_crds=$(oc get crd 2>/dev/null | grep "external-secrets.io" | awk '{print $1}')
    if [ -n "$eso_crds" ]; then
        log_info "  Removing ESO CRDs..."
        echo "$eso_crds" | xargs oc delete crd 2>/dev/null || true
        log_success "  ESO CRDs removed"
    fi

    # Remove ESO API services
    local eso_api=$(oc get apiservices 2>/dev/null | grep "external-secrets.io" | awk '{print $1}')
    if [ -n "$eso_api" ]; then
        log_info "  Removing ESO API services..."
        echo "$eso_api" | xargs oc delete apiservice 2>/dev/null || true
    fi

    # Remove failed install plans
    local failed_plans=$(oc get installplan -n openshift-operators 2>/dev/null | grep "external-secrets" | awk '{print $1}')
    if [ -n "$failed_plans" ]; then
        log_info "  Removing failed install plans..."
        echo "$failed_plans" | xargs oc delete installplan -n openshift-operators 2>/dev/null || true
    fi

    log_success "External Secrets Operator cleanup complete"
}

# Clean up Keepalived resources
cleanup_keepalived() {
    log_info "Cleaning up Keepalived Operator..."

    # Remove Keepalived CRDs
    local keepalived_crds=$(oc get crd 2>/dev/null | grep "keepalived" | awk '{print $1}')
    if [ -n "$keepalived_crds" ]; then
        log_info "  Removing Keepalived CRDs..."
        echo "$keepalived_crds" | xargs oc delete crd 2>/dev/null || true
        log_success "  Keepalived CRDs removed"
    fi

    log_success "Keepalived cleanup complete"
}

# Clean up cert-manager resources
cleanup_cert_manager() {
    log_info "Cleaning up cert-manager..."

    # Remove cert-manager webhooks
    local cm_webhooks=$(oc get validatingwebhookconfigurations,mutatingwebhookconfigurations 2>/dev/null | \
                       grep "cert-manager" | awk '{print $1}')
    if [ -n "$cm_webhooks" ]; then
        log_info "  Removing cert-manager webhooks..."
        echo "$cm_webhooks" | xargs oc delete 2>/dev/null || true
    fi

    log_success "cert-manager cleanup complete"
}

# Clean up stale API services
cleanup_stale_api_services() {
    log_info "Checking for stale API services..."

    local stale=$(oc get apiservices 2>/dev/null | grep "False" | awk '{print $1}')

    if [ -n "$stale" ]; then
        log_warning "Found stale API services:"
        echo "$stale"

        read -p "Do you want to remove these? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$stale" | xargs oc delete apiservice 2>/dev/null || true
            log_success "Stale API services removed"
        fi
    else
        log_info "No stale API services found"
    fi
}

# Main cleanup function
main() {
    log_info "Starting cluster cleanup..."
    echo ""

    # Parse arguments
    CLEANUP_ALL=false
    CLEANUP_ARGO=false
    CLEANUP_NAMESPACES=false
    CLEANUP_KASTEN=false
    CLEANUP_ESO=false
    CLEANUP_KEEPALIVED=false
    CLEANUP_CERTMANAGER=false
    CLEANUP_API=false

    if [ $# -eq 0 ]; then
        CLEANUP_ALL=true
    else
        while [[ $# -gt 0 ]]; do
            case $1 in
                --all)
                    CLEANUP_ALL=true
                    shift
                    ;;
                --argo)
                    CLEANUP_ARGO=true
                    shift
                    ;;
                --namespaces)
                    CLEANUP_NAMESPACES=true
                    shift
                    ;;
                --kasten)
                    CLEANUP_KASTEN=true
                    shift
                    ;;
                --eso|--external-secrets)
                    CLEANUP_ESO=true
                    shift
                    ;;
                --keepalived)
                    CLEANUP_KEEPALIVED=true
                    shift
                    ;;
                --cert-manager)
                    CLEANUP_CERTMANAGER=true
                    shift
                    ;;
                --api-services)
                    CLEANUP_API=true
                    shift
                    ;;
                --help|-h)
                    echo "Usage: $0 [options]"
                    echo ""
                    echo "Options:"
                    echo "  --all              Run all cleanup tasks (default if no options)"
                    echo "  --argo             Clean up Argo CD applications"
                    echo "  --namespaces       Clean up stuck terminating namespaces"
                    echo "  --kasten           Clean up Kasten K10 resources"
                    echo "  --eso              Clean up External Secrets Operator"
                    echo "  --keepalived       Clean up Keepalived Operator"
                    echo "  --cert-manager     Clean up cert-manager resources"
                    echo "  --api-services     Check and clean stale API services"
                    echo "  --help, -h         Show this help message"
                    exit 0
                    ;;
                *)
                    log_error "Unknown option: $1"
                    echo "Use --help for usage information"
                    exit 1
                    ;;
            esac
        done
    fi

    # Execute cleanup tasks
    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_ARGO" = true ]; then
        cleanup_argocd_applications
        echo ""
    fi

    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_NAMESPACES" = true ]; then
        cleanup_stuck_namespaces
        echo ""
    fi

    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_KASTEN" = true ]; then
        cleanup_kasten
        echo ""
    fi

    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_ESO" = true ]; then
        cleanup_external_secrets
        echo ""
    fi

    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_KEEPALIVED" = true ]; then
        cleanup_keepalived
        echo ""
    fi

    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_CERTMANAGER" = true ]; then
        cleanup_cert_manager
        echo ""
    fi

    if [ "$CLEANUP_ALL" = true ] || [ "$CLEANUP_API" = true ]; then
        cleanup_stale_api_services
        echo ""
    fi

    log_success "=========================================="
    log_success "Cluster cleanup complete!"
    log_success "=========================================="
}

# Run main function
main "$@"
