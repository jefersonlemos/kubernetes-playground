# Next POCS

1. Gateway API - The successor of Ingress
    [ ] Test it locally in K3s
    [ ] Test it in EKS with the *aws-alb-controller*
2. Kong API Manager
    * It's not exactly an ingress controller but it's another way to route traffic 
    * All traffic goes through NLB > Kong > App service
    * The idea is to have a better understanding of how this routing works
    * Test it with Gateway API too