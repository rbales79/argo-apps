# Create the GitOps operator subscription

apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
name: openshift-gitops-operator
namespace: openshift-operators
spec:
channel: latest
installPlanApproval: Automatic
name: openshift-gitops-operator
source: redhat-operators
sourceNamespace: openshift-marketplace

---

# sort GitOps rbac

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: argocd-controller-cluster-admin
subjects:

- kind: ServiceAccount
  name: openshift-gitops-argocd-application-controller
  namespace: openshift-gitops
  roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io

---

# only if not using openshift-gitops ns

apiVersion: v1
kind: Namespace
metadata:
name: external-secrets
labels:
kubernetes.io/metadata.name: external-secrets

---

# Create Infisical auth secret

apiVersion: v1
kind: Secret
metadata:
name: infisical-auth-secret
namespace: openshift-gitops
type: Opaque
stringData:
clientId: "your-client-id-here"
clientSecret: "your-client-secret-here"

---

# Create the External Secrets Operator subscription

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: external-secrets-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: external-secrets-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: external-secrets-operator.v0.11.0
---
# Create the External Secrets Operator config
---
apiVersion: operator.external-secrets.io/v1alpha1
kind: OperatorConfig
metadata:
  name: external-secrets
  namespace: openshift-gitops
```
