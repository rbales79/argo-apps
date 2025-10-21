# TrueNAS CSI Driver Troubleshooting Guide

## Common Issues

### 1. Connection Reset Error (ECONNRESET)

**Symptom:**

```
TrueNAS api is unavailable: Error: FreeNAS error getting system version info: {"errors":{"v2":"Error: read ECONNRESET"}}
```

**Possible Causes:**

- TrueNAS API is not accessible from the cluster
- API key is invalid or expired
- SSL/TLS certificate issues
- Firewall blocking the connection
- Wrong API version configuration

**Diagnostic Steps:**

1. **Verify API Key in Infisical:**

   - Check that `TRUENAS_API_KEY` exists in your Infisical project
   - Verify the API key is valid and has not expired
   - Test the API key manually: `curl -H "Authorization: Bearer YOUR_API_KEY" https://truenas.roybales.com/api/v2.0/system/version`

2. **Check External Secret Sync:**

   ```bash
   kubectl get externalsecret democratic-csi-config -n democratic-csi
   kubectl describe externalsecret democratic-csi-config -n democratic-csi
   ```

3. **Verify Secret Content:**

   ```bash
   kubectl get secret democratic-csi-config -n democratic-csi -o yaml
   kubectl get secret democratic-csi-config -n democratic-csi -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d
   ```

4. **Test Network Connectivity from Cluster:**

   ```bash
   # Test basic connectivity
   kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
     curl -k -v https://truenas.roybales.com:443/api/v2.0/system/version

   # Test with API key (replace YOUR_API_KEY)
   kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
     curl -k -H "Authorization: Bearer YOUR_API_KEY" https://truenas.roybales.com/api/v2.0/system/version
   ```

5. **Check Controller Logs:**
   ```bash
   kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi -c democratic-csi-driver --tail=100
   ```

### 2. Fix Options

**Option 1: Verify API Configuration**

Ensure your `values.yaml` has correct settings:

```yaml
cluster:
  storage:
    democratic-csi:
      httpConnection:
        host: truenas.roybales.com
        port: 443
        protocol: https
        allowInsecure: true # Set to false if you have valid certs
```

**Option 2: Update API Key**

1. Generate a new API key in TrueNAS:

   - Go to TrueNAS UI > System Settings > API Keys
   - Create new API key with full permissions

2. Update in Infisical:

   - Navigate to your Infisical project
   - Update the `TRUENAS_API_KEY` secret value

3. Force External Secret refresh:
   ```bash
   kubectl annotate externalsecret democratic-csi-config -n democratic-csi \
     force-sync=$(date +%s) --overwrite
   ```

**Option 3: Check TrueNAS API Version**

The driver now explicitly sets `apiVersion: 2`. If using TrueNAS SCALE or newer:

- Verify the API endpoint is `/api/v2.0`
- Check TrueNAS logs for any API errors

**Option 4: Firewall/Network**

Ensure:

- TrueNAS API port (443) is accessible from cluster nodes
- No firewall rules blocking traffic
- DNS resolution works: `kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- nslookup truenas.roybales.com`

### 3. Restart CSI Driver

After making configuration changes:

```bash
# Delete the controller pod to force restart
kubectl delete pod -n democratic-csi -l app.kubernetes.io/name=democratic-csi

# Watch for successful startup
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi -c democratic-csi-driver -f
```

### 4. Common Configuration Errors

**Missing or Invalid API Key:**

- Error: Authentication failed
- Fix: Regenerate API key in TrueNAS and update in Infisical

**Wrong Host/Port:**

- Error: Connection timeout or refused
- Fix: Verify TrueNAS hostname resolves and port is correct

**SSL Certificate Issues:**

- Error: SSL handshake failed
- Fix: Set `allowInsecure: true` or install proper CA certificates

**Network Policies:**

- Error: Connection timeout
- Fix: Check for NetworkPolicies blocking egress traffic

## Validation

Once fixed, you should see:

```bash
# Successful probe
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi -c democratic-csi-driver --tail=20

# Should show:
# GRPC response: {}
# (without any errors)
```

## Reference

- Democratic CSI Documentation: https://github.com/democratic-csi/democratic-csi
- TrueNAS API Documentation: https://www.truenas.com/docs/api/
