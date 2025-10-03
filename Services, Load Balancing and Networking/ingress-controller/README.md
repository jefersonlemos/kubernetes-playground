# What's an ingress

An Ingress may be configured to give Services externally-reachable URLs, load balance traffic, terminate SSL / TLS, and offer name-based virtual hosting. **An Ingress controller is responsible for fulfilling the Ingress**, usually with a load balancer, though it may also configure your edge router or additional frontends to help handle the traffic.

An Ingress does not expose arbitrary ports or protocols. Exposing services other than HTTP and HTTPS to the internet typically uses a service of type Service.Type=NodePort or Service.Type=LoadBalancer (uses AWS NLB).

# What's an ingress controller

Unlike other types of controllers which run as part of the kube-controller-manager binary, Ingress controllers are not started automatically with a cluster.

**You must have an Ingress controller to satisfy an Ingress. Only creating an Ingress resource has no effect.**
https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress


