#!/bin/bash

# TrueNAS CSI Connection Diagnostic Script
# This script helps diagnose connectivity issues between democratic-csi and TrueNAS

set -e

NAMESPACE="${NAMESPACE:-democratic-csi}"
SECRET_NAME="democratic-csi-truenas-config"
TRUENAS_HOST="${TRUENAS_HOST:-truenas.roybales.com}"
TRUENAS_PORT="${TRUENAS_PORT:-443}"

echo "=== TrueNAS CSI Driver Diagnostic ==="
echo "Namespace: $NAMESPACE"
echo "Secret: $SECRET_NAME"
echo "TrueNAS Host: $TRUENAS_HOST:$TRUENAS_PORT"
echo ""

# Check if namespace exists
echo "1. Checking namespace..."
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "✓ Namespace '$NAMESPACE' exists"
else
    echo "✗ Namespace '$NAMESPACE' not found"
    exit 1
fi

# Check ExternalSecret
echo ""
echo "2. Checking ExternalSecret..."
if kubectl get externalsecret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✓ ExternalSecret exists"
    kubectl get externalsecret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True" && \
        echo "✓ ExternalSecret is synced" || \
        echo "✗ ExternalSecret is not synced - check status: kubectl describe externalsecret $SECRET_NAME -n $NAMESPACE"
else
    echo "✗ ExternalSecret not found"
    exit 1
fi

# Check Secret
echo ""
echo "3. Checking Secret..."
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✓ Secret exists"

    # Extract and display config (without showing API key)
    echo ""
    echo "4. Checking Secret Configuration..."
    CONFIG=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d)

    if [ -z "$CONFIG" ]; then
        echo "✗ Secret data is empty"
        exit 1
    fi

    echo "✓ Secret has configuration data"
    echo ""
    echo "Configuration (API key redacted):"
    echo "$CONFIG" | sed 's/apiKey:.*/apiKey: [REDACTED]/'

    # Check for API key
    if echo "$CONFIG" | grep -q "apiKey:"; then
        API_KEY=$(echo "$CONFIG" | grep "apiKey:" | awk '{print $2}' | tr -d '"')
        if [ -z "$API_KEY" ] || [ "$API_KEY" = '""' ]; then
            echo ""
            echo "✗ API key is empty or not set"
            exit 1
        else
            echo ""
            echo "✓ API key is present"
        fi
    else
        echo ""
        echo "✗ No API key found in configuration"
        exit 1
    fi
else
    echo "✗ Secret not found"
    exit 1
fi

# Test DNS resolution
echo ""
echo "5. Testing DNS resolution..."
if kubectl run test-dns --rm -i --restart=Never --image=busybox:latest -- nslookup "$TRUENAS_HOST" >/dev/null 2>&1; then
    echo "✓ DNS resolution successful for $TRUENAS_HOST"
else
    echo "✗ DNS resolution failed for $TRUENAS_HOST"
fi

# Test network connectivity
echo ""
echo "6. Testing network connectivity to TrueNAS..."
echo "Testing connection to $TRUENAS_HOST:$TRUENAS_PORT..."

kubectl run test-connection --rm -i --restart=Never --image=nicolaka/netshoot -- \
    timeout 5 bash -c "curl -k -s -o /dev/null -w '%{http_code}' https://$TRUENAS_HOST:$TRUENAS_PORT/api/v2.0/system/version" > /tmp/http_code 2>&1

if [ $? -eq 0 ]; then
    HTTP_CODE=$(cat /tmp/http_code)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "✓ Network connectivity successful (HTTP $HTTP_CODE)"
        if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
            echo "  Note: Authentication required - this is expected without API key"
        fi
    else
        echo "⚠ Unexpected HTTP response: $HTTP_CODE"
    fi
else
    echo "✗ Network connectivity failed - check firewall rules and TrueNAS availability"
fi

# Test with API key
echo ""
echo "7. Testing TrueNAS API with credentials..."
echo "Extracting API key from secret..."

API_KEY=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d | grep "apiKey:" | awk '{print $2}' | tr -d '"')

if [ -n "$API_KEY" ] && [ "$API_KEY" != '""' ]; then
    kubectl run test-api --rm -i --restart=Never --image=nicolaka/netshoot -- \
        bash -c "curl -k -s -H 'Authorization: Bearer $API_KEY' https://$TRUENAS_HOST:$TRUENAS_PORT/api/v2.0/system/version" > /tmp/api_test 2>&1

    if grep -q "version" /tmp/api_test; then
        echo "✓ TrueNAS API authentication successful"
        echo "  TrueNAS Version: $(cat /tmp/api_test | grep -o '"version":"[^"]*"' | cut -d'"' -f4)"
    else
        echo "✗ TrueNAS API authentication failed"
        echo "  Response: $(cat /tmp/api_test)"
        echo ""
        echo "Possible issues:"
        echo "  - API key is invalid or expired"
        echo "  - API key doesn't have required permissions"
        echo "  - TrueNAS API version mismatch"
    fi
else
    echo "⚠ Cannot test API - API key not found in secret"
fi

# Check CSI Driver pods
echo ""
echo "8. Checking CSI Driver pods..."
PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=democratic-csi -o name 2>/dev/null)
if [ -n "$PODS" ]; then
    echo "✓ Found CSI Driver pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=democratic-csi

    echo ""
    echo "Recent logs from controller:"
    kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=democratic-csi,app.kubernetes.io/component=controller -c democratic-csi-driver --tail=10 2>/dev/null || echo "No controller logs available"
else
    echo "✗ No CSI Driver pods found"
fi

echo ""
echo "=== Diagnostic Complete ==="
echo ""
echo "If you see connection errors above, try:"
echo "1. Verify API key in Infisical is correct"
echo "2. Check TrueNAS firewall allows connections from cluster"
echo "3. Restart CSI driver: kubectl delete pod -n $NAMESPACE -l app.kubernetes.io/name=democratic-csi"
echo "4. Check TrueNAS logs for API errors"

# Cleanup
rm -f /tmp/http_code /tmp/api_test
