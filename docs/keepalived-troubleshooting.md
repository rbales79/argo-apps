# Keepalived Operator Troubleshooting

## Quick Diagnostics

Run these commands to check the current state:

### 1. Check if the ApplicationSet exists

```bash
oc get applicationset -n openshift-gitops | grep keepalived
```

### 2. Check if the Application was created

```bash
oc get application -n openshift-gitops keepalived-operator
```

### 3. Check Application status

```bash
oc describe application -n openshift-gitops keepalived-operator
```

### 4. Check if namespace was created

```bash
oc get namespace keepalived-operator
```

### 5. Check operator subscription

```bash
oc get subscription -n keepalived-operator keepalived-operator
```

### 6. Check operator deployment

```bash
oc get deployment -n keepalived-operator
```

### 7. Check operator pods

```bash
oc get pods -n keepalived-operator
```

### 8. Check KeepalivedGroup CRD

```bash
oc get crd keepalivedgroups.redhatcop.redhat.io
```

### 9. Check KeepalivedGroup resources

```bash
oc get keepalivedgroup -n keepalived-operator
```

### 10. Check for events

```bash
oc get events -n keepalived-operator --sort-by='.lastTimestamp'
```

## Common Issues

### Issue 1: ApplicationSet not creating Application

**Check:**

```bash
oc get applicationset -n openshift-gitops -o yaml | grep -A 50 keepalived
```

**Possible causes:**

- Sync wave 50 hasn't been reached yet
- Values aren't being passed correctly
- ApplicationSet generator has issues

### Issue 2: Application exists but not syncing

**Check:**

```bash
oc get application keepalived-operator -n openshift-gitops -o yaml
```

**Look for:**

- Sync status
- Health status
- Error messages in status conditions

### Issue 3: Operator not installing

**Check:**

```bash
oc get csv -n keepalived-operator
```

**Possible causes:**

- Subscription pointing to wrong catalog source
- Starting CSV version not available
- Catalog source not healthy

**Check catalog sources:**

```bash
oc get catalogsource -n openshift-marketplace
oc get pods -n openshift-marketplace
```

### Issue 4: KeepalivedGroup not being created

**Check the rendered values:**

```bash
oc get application keepalived-operator -n openshift-gitops -o jsonpath='{.spec.source.helm.valuesObject}' | yq eval -P
```

**Look for:**

- Does `network.lan.defaultGateway` exist?
- Are values structured correctly at root level?

### Issue 5: SCC permissions

**Check:**

```bash
oc get scc controller-manager -o yaml
```

**Verify user:**

```bash
oc get scc controller-manager -o jsonpath='{.users}'
```

Should include: `system:serviceaccount:keepalived-operator:default`

## Expected Resource Order

1. **Wave -1**: Namespace
2. **Wave 0**: Subscription, OperatorGroup
3. **Wave 1**: SecurityContextConstraints
4. **Wave 10**: KeepalivedGroup(s)

## Manual Test

To test if the chart would render correctly with your values:

```bash
# Create a test values file
cat > /tmp/keepalived-test-values.yaml <<EOF
network:
  lan:
    defaultGateway: 192.168.1.1
cluster:
  name: sno
EOF

# Test rendering (requires helm)
helm template test charts/infrastructure/keepalived-operator -f /tmp/keepalived-test-values.yaml
```

## Force Sync

If everything looks correct but it's not deploying:

```bash
# Force sync the main cluster application
oc patch application cluster -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Or force sync the keepalived application specifically
oc patch application keepalived-operator -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## Logs

Check ArgoCD application controller logs:

```bash
oc logs -n openshift-gitops deployment/openshift-gitops-application-controller | grep keepalived
```

Check operator logs (if operator is running):

```bash
oc logs -n keepalived-operator -l control-plane=controller-manager --tail=100
```
