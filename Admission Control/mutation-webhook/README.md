# Purpose of this POC

Understand what Mutating webhook is and how it works on Kubernetes.

# Scenario

To see how it works, I've deployed a custom admission controler of the mutating type using Go. This webhook will be triggered whenever a new pod is scheduled and will add an additional environment variable to them. It will patch the pod manifest not the deployment, which means that this might not be a permanent change.

# How to deploy

You can read the official K8s doc to have a better understanding but in summary, these are the necessary steps to make it work:
* Build the [api ](./app/main.go)(it can be in other languages as well) and deploy it along with the [service](./k8s/deployment.yaml), [secrets](./k8s/secrets_certificate.yaml)(generate them before deploying) and everything it needs.
* Deploy the [MutatingWebhookConfiguration](./k8s/webhook.yaml)
* Deploy the [testing app](./k8s/testing-app.yaml)

After the deployment finishes, you should see a new environment variable added to the pod.

# Context

## What's admission control

An admission controller is a piece of code that intercepts requests to the Kubernetes API server prior to persistence of the resource, but after the request is authenticated and authorized. It's basically, code within the Kubernetes API server that check the data arriving in a request to modify a resource.

**Admission controllers apply to requests that create, delete, or modify objects**. Admission controllers can also block **custom verbs**, such as a request to connect to a pod via an API server proxy. Admission controllers **do not (and cannot) block requests to read (get, watch or list) objects**, because reads bypass the admission control layer.

## Types

Admission control mechanisms may be validating, mutating, or both. Mutating controllers may modify the data for the resource being modified; validating controllers may not.

Within the [full list](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-does-each-admission-controller-do), there are three special controllers: MutatingAdmissionWebhook, ValidatingAdmissionWebhook, and ValidatingAdmissionPolicy

MutatingAdmissionWebhook is the admission controller i'm learning with this POC.

## Built-in 

**Admission controllers are compiled into the kube-apiserver binary**. See [here](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/#options) the list of the recomended admission controllers that are enabled by default, check the list in the flag `--enable-admission-plugins`

In Kubernetes 1.34, the default ones are:
```
CertificateApproval, CertificateSigning, CertificateSubjectRestriction, DefaultIngressClass, DefaultStorageClass, DefaultTolerationSeconds, LimitRanger, MutatingAdmissionWebhook, NamespaceLifecycle, PersistentVolumeClaimResize, PodSecurity, Priority, ResourceQuota, RuntimeClass, ServiceAccount, StorageObjectInUseProtection, TaintNodesByCondition, ValidatingAdmissionPolicy, ValidatingAdmissionWebhook
```

You can enable additional admission controllers by setting the `enable-admission-plugins`. This is the [list of admission controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-does-each-admission-controller-do) you can enable with the flag.


Several important features of Kubernetes require an admission controller to be enabled in order to properly support the feature. As a result, a Kubernetes API server that is not properly configured with the right set of admission controllers is an incomplete server and will not support all the features you expect.

## Dynamic Admission Control
In addition to compiled-in admission plugins, admission plugins can be developed as extensions and run as webhooks configured at runtime. 

This is also what what I'm learning this POC.

## How it works

The webhook (mutatingwebhookconfigurations object) handles the AdmissionReview request sent by the API servers, and sends back its decision as an AdmissionReview object in the same version it received.

[Request](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#request)
[Response](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#response)






# References

* https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
* https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-does-each-admission-controller-do
* https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/
* https://blog.stonegarden.dev/articles/2024/03/proxmox-k8s-with-cilium/
* https://rickt.io/posts/12-deploying-kubernetes-locally-on-proxmox/
* https://github.com/JamesTurland/JimsGarage/blob/main/Kubernetes/K3S-Deploy/k3s.sh