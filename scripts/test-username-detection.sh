#!/bin/bash

# Test script to verify username detection in Windows Git Bash

echo "=== Username Detection Test ==="
echo ""

echo "Raw whoami output:"
whoami

echo ""
echo "Processed username (removing domain):"
CURRENT_USER=$(whoami | sed 's/.*\\//')
echo "Result: '$CURRENT_USER'"

echo ""
echo "Generated kube directory path:"
KUBE_DIR="/c/users/$CURRENT_USER/.kube"
echo "Path: $KUBE_DIR"

echo ""
echo "Checking if path would exist on Windows:"
if [[ -n "$CURRENT_USER" ]]; then
    echo "✅ Username detected successfully"
    echo "📁 Kube directory would be: $KUBE_DIR"
else
    echo "❌ Failed to detect username"
fi

echo ""
echo "=== Test Complete ==="
