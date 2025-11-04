A repository to play with Kubernetes. 

I used the [K8s documentation](https://kubernetes.io/docs/home/) to understand the components and do my POCs.


# List of POCS


1. Admission Control 
    1. [Mutating Webhook Configurations](./mutation-webhook/README.md)
2. Services, Load Balancer and Networking
    1. Ingress
        1. Controllers
            1. [x] [aws-load-balancer-controller](./Services,%20Load%20Balancing%20and%20Networking/ingress-controller/aws-load-balancer-controller/README.md)
    2. Gateway API
        1. Controllers
            1. [ ] [Contour](https://projectcontour.io/docs/1.33/config/gateway-api/) as a controller
            2. [ ] Controller - [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.14/guide/gateway/gateway/)
            3. [ ] [Argo Rollouts](https://rollouts-plugin-trafficrouter-gatewayapi.readthedocs.io/en/latest/)
    3. [ ] Envoy Proxy - https://github.com/envoyproxy
