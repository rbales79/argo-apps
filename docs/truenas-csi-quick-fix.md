# TrueNAS CSI Driver - Quick Fix Guide

## Current Error: ECONNRESET

If you're seeing this error:

```
TrueNAS api is unavailable: Error: FreeNAS error getting system version info: {"errors":{"v2":"Error: read ECONNRESET"}}
```

## Immediate Troubleshooting Steps

### Step 1: Run the diagnostic script

```bash
cd /workspaces/openshift
./scripts/diagnose-truenas-csi.sh
```

### Step 2: Verify API Key Format

The ECONNRESET error often means the API key format is incorrect. TrueNAS API keys should:

- Be a long alphanumeric string (typically 64+ characters)
- NOT include quotation marks
- NOT have spaces or newlines

**Check in Infisical:**

1. Go to your Infisical project
2. Find `TRUENAS_API_KEY` secret
3. Verify the value is JUST the key (no quotes, no spaces)

Example of CORRECT format:

```
1-aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789aBcDeFgHiJkLmNoPqRsTuV
```

Example of INCORRECT formats:

```
"1-aBcDeFgH..."     # Has quotes - WRONG
Bearer 1-aBcDeFgH...  # Has Bearer prefix - WRONG
1-aBcDeFgH... \n    # Has newline - WRONG
```

### Step 3: Test API Key Manually

On your TrueNAS system or from a machine that can reach it:

```bash
curl -k -H "Authorization: Bearer YOUR_API_KEY_HERE" \
  https://truenas.roybales.com/api/v2.0/system/version
```

Expected response if key is valid:

```json
{ "version": "TrueNAS-SCALE-23.10.1.1" }
```

If you get `401` or `403`, the API key is invalid.

### Step 4: Regenerate API Key in TrueNAS

If the key doesn't work:

1. **In TrueNAS UI:**

   - Go to **System Settings** → **API Keys**
   - Delete the old key
   - Click **Add** to create a new one
   - Give it a name (e.g., "kubernetes-csi")
   - Copy the generated key

2. **Update in Infisical:**

   - Go to your Infisical project
   - Update the `TRUENAS_API_KEY` value
   - Paste the new key (no quotes, no extra characters)

3. **Force sync in Kubernetes:**

   ```bash
   kubectl annotate externalsecret democratic-csi-truenas-config \
     -n democratic-csi \
     force-sync=$(date +%s) --overwrite
   ```

4. **Restart CSI driver:**

   ```bash
   kubectl delete pod -n democratic-csi -l app.kubernetes.io/name=democratic-csi
   ```

5. **Watch logs:**
   ```bash
   kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi \
     -c democratic-csi-driver -f
   ```

### Step 5: Check for Network/Firewall Issues

If API key is correct but still getting ECONNRESET:

```bash
# From within the cluster, test connectivity
kubectl run -it --rm test-truenas --image=nicolaka/netshoot --restart=Never -- \
  curl -k -v https://truenas.roybales.com:443/api/v2.0/system/version
```

Look for:

- ✓ SSL handshake completes
- ✓ Gets HTTP response (even if 401)
- ✗ Connection reset during handshake = firewall/network issue

### Step 6: Verify TrueNAS API Version

Ensure TrueNAS is using API v2:

```bash
# Check what API endpoints are available
curl -k https://truenas.roybales.com/api/docs
```

The democratic-csi driver expects `/api/v2.0/` endpoints.

## Common Fixes

### Fix 1: API Key Has Quotes

**Problem:** API key stored as `"1-abc..."` instead of `1-abc...`
**Solution:** Remove quotes from Infisical value, force sync

### Fix 2: API Key Expired

**Problem:** API key was deleted or expired in TrueNAS
**Solution:** Generate new key, update Infisical

### Fix 3: Wrong API Version

**Problem:** TrueNAS running older version without v2 API
**Solution:** Upgrade TrueNAS or use v1 API (not recommended)

### Fix 4: Firewall Blocking

**Problem:** TrueNAS firewall blocking connections from cluster nodes
**Solution:** Add allow rule for cluster node IPs/subnet

### Fix 5: Certificate Issues

**Problem:** Even with `allowInsecure: true`, connection fails
**Solution:** Check TrueNAS SSL certificate isn't corrupted

## Success Indicators

When working correctly, you'll see:

```bash
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi -c democratic-csi-driver --tail=20
```

```json
{"level":"info","message":"new request - driver: FreeNASApiDriver method: Probe"}
{"level":"info","message":"response - driver: FreeNASApiDriver method: Probe"}
```

NO errors about "TrueNAS api is unavailable"

## Still Not Working?

Run full diagnostic and save output:

```bash
./scripts/diagnose-truenas-csi.sh > truenas-diagnostic.log 2>&1
```

Then review the diagnostic log for specific failure points.
