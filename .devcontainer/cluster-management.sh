#!/bin/bash

# OpenShift/Kubernetes Multi-Cluster Management Functions
# This file is automatically sourced in new shell sessions

# Function to switch to hub cluster
use-hub() {
    export KUBECONFIG="/root/.kube/kubeconfig-hub"
    echo "🔄 Switched to HUB cluster"
    if oc whoami >/dev/null 2>&1; then
        local user=$(oc whoami)
        local nodes=$(oc get nodes --no-headers | wc -l)
        echo "✅ Connected as: $user"
        echo "📊 Cluster has $nodes nodes"
        oc get nodes --no-headers | awk '{print "   - " $1 " (" $2 ")"}'
    else
        echo "❌ Cannot connect to hub cluster"
    fi
}

# Function to switch to test cluster
use-test() {
    export KUBECONFIG="/root/.kube/kubeconfig-test"
    echo "🔄 Switched to TEST cluster"
    if oc whoami >/dev/null 2>&1; then
        local user=$(oc whoami)
        local nodes=$(oc get nodes --no-headers | wc -l)
        echo "✅ Connected as: $user"
        echo "📊 Cluster has $nodes nodes"
        oc get nodes --no-headers | awk '{print "   - " $1 " (" $2 ")"}'
    else
        echo "❌ Cannot connect to test cluster"
    fi
}

# Function to switch to sno cluster
use-sno() {
    export KUBECONFIG="/root/.kube/kubeconfig-sno"
    echo "🔄 Switched to SNO cluster"
    if oc whoami >/dev/null 2>&1; then
        local user=$(oc whoami)
        local nodes=$(oc get nodes --no-headers | wc -l)
        echo "✅ Connected as: $user"
        echo "📊 Cluster has $nodes nodes"
        oc get nodes --no-headers | awk '{print "   - " $1 " (" $2 ")"}'
    else
        echo "❌ Cannot connect to sno cluster"
    fi
}

# Function to show current cluster context
current-cluster() {
    if [ -z "$KUBECONFIG" ]; then
        echo "❌ No cluster selected"
        echo "💡 Use 'hub', 'test', or 'sno' to connect to a cluster"
        return 1
    fi

    local cluster_name=$(basename $KUBECONFIG | sed 's/kubeconfig-//')
    echo "📍 Current cluster: $cluster_name"
    echo "📁 Kubeconfig: $KUBECONFIG"

    if oc whoami >/dev/null 2>&1; then
        echo "👤 User: $(oc whoami)"
        echo "🏷️  Context: $(oc config current-context 2>/dev/null || echo 'default')"
        echo "🖥️  Nodes:"
        oc get nodes
    else
        echo "❌ Not connected or not authenticated"
    fi
}

# Quick cluster status
cluster-status() {
    echo "🌐 Available clusters:"

    local original_kubeconfig="$KUBECONFIG"

    for config in /root/.kube/kubeconfig-*; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" | sed 's/kubeconfig-//')
            local current=""
            [ "$KUBECONFIG" = "$config" ] && current=" (current)"

            export KUBECONFIG="$config"
            if oc whoami >/dev/null 2>&1; then
                local nodes=$(oc get nodes --no-headers | wc -l)
                echo "  ✅ $name: $nodes nodes$current"
            else
                echo "  ❌ $name: not accessible$current"
            fi
        fi
    done

    # Restore original KUBECONFIG
    export KUBECONFIG="$original_kubeconfig"
}

# Show available clusters on first load
show-clusters() {
    echo "🌐 OpenShift Clusters Available:"

    for config in /root/.kube/kubeconfig-*; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" | sed 's/kubeconfig-//')
            echo "  📋 $name"
        fi
    done

    echo ""
    echo "💡 Quick commands:"
    echo "   hub, test, sno     - Switch between clusters"
    echo "   current            - Show current cluster info"
    echo "   status             - Show all cluster status"
    echo "   clusters           - List kubeconfig files"
    echo ""
}

# Aliases for convenience
alias k='kubectl'
alias kc='kubectl'
alias hub='use-hub'
alias test='use-test'
alias sno='use-sno'
alias current='current-cluster'
alias status='cluster-status'
alias clusters='ls -la /root/.kube/kubeconfig-*'

# Auto-complete for cluster switching
complete -W "hub test sno" use-

# Show available clusters when this script is sourced
if [ -d "/root/.kube" ] && ls /root/.kube/kubeconfig-* >/dev/null 2>&1; then
    show-clusters
else
    echo "⚠️  Kubeconfig files not found. Please ensure they are placed in /root/.kube/"
fi
