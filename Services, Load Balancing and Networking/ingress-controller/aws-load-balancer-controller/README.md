# What's it


Repository: https://github.com/kubernetes-sigs/aws-load-balancer-controller

# How it works

![AWS Load Balancer Controller Architecture](https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/groups-in-action.png)


## Highlights
* It watches the Kubernetes API server for updates to Ingress resources. When it detects changes, it updates resources such as the Application Load Balancer, listeners, target groups, and listener rules, it has a [mutation webhook](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/helm/aws-load-balancer-controller/templates/webhook.yaml) to listen to the ingress changes.
* A Target group gets created for every Kubernetes Service mentioned in the ingress resource
* ALB Listeners are created for every port defined in the ingress resource’s annotations
* Listener rules (also called ingress rules) are created for each path in Ingress resource definition
* It's possible to use an `OR` operator and create less rules via [conditions](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.13/guide/ingress/annotations/#conditions) annotation. 
* Having an ALB with the number of rules close to limit(100) may cause issues on the ALB reconciliation process
    * In my experience, an ALB with extended limit(200), when reached the rules limit, started to:
        * Fail to delete ingress because it's no longer able to delete rules on ALB
        * Fail to reconcile, even if rules get deleted, ALB priorities will never sync withe resource Id tag (alb controller uses it)

## Rules

The AWS Application Load Balancer act as a reverse proxy routing requests to targets, so **order matters**. I mean, if you have a rule like `path: /api/*` with priority 1 and another rule `path: /api/v2/*` with priority 2, requests to `/api/v2/consumer` or `/api/v2/orders` or anything after the `/api` would redirect the request to the target defined in the first rule because it comes first. The request will never reach the second rule because the first one already matches it. Let me talk a little bit more about ordering and priorities.

#TODO - Add a quick text talking about the simple 1x1 use case and then drill down to the 1xN
### One ALB per Ingress

#TODO - ALB with multiple ingresses
### One ALB per multiple ingresses
![imagem mostrando o roteamento](https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/load-balancer-routing.png)

why use it?
ingress group
    An important aspect to consider before using IngressGroup in a multi-tenant environment is conflict resolution. When AWS Load Balancer Controller configures ingress rules in ALB, it uses the `group.order` field to set the order of evaluation. **If you don’t declare a value for group.order, the Controller defaults to 0.**


ingress order
    ingress rules and priority
    ordem de criação (priority)
        https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2203
        https://kubernetes.io/docs/concepts/services-networking/ingress/#multiple-matches
    
    Rules with lower order value are evaluated first. By default, the rule order between Ingresses within an IngressGroup is determined by the lexical order of Ingress’s namespace/name.

#TODO - Finish here
### Paths ordering
pathType        

https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/3450

The priority on the rules is decided on the PathType. The prefix type take higher priority here than the implementations specific. https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/spec/#ingress-specification


### Summary

examples:
1x1 - 1 alb per 1 ingress -> how rules will look like
1xn - 1 alb many ingresses -> how rules will look like

#TODO - Add here something like a precedence list, if possible

ingress
    |_ rule
        |_pathType


#TODO - Finish here
## Target group binding

TargetGroupBinding is a custom resource managed by the AWS Load Balancer Controller. It allows you to expose Kubernetes applications using existing load balancers. A TargetGroupBinding resource binds a Kubernetes Service with a load balancer target group. When you create a TargetGroupBinding resource, the controller automatically configures the target group to route traffic to a Service. Here’s an example of a TargetGroupBinding resource:

![targetGroup Binding ]https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/TargetGroupBinding.png


#TODO - Nao conhecia isso, deixar por ultimo e ver a complexidade e ver se faz sentdo ter aqui.
## Load balance application traffic across clusters
ALB can distribute traffic to multiple backends using weighted target groups. You can use this feature to route traffic to multiple clusters by first creating a target group for each cluster and then binding the target group to Services in multiple clusters. This strategy allows you to control the percentage of traffic you send to each cluster.

Such traffic controls are especially useful when performing blue/green cluster upgrades. You can migrate traffic from the older cluster to the newer in a controlled manner.



#TODO Dar uma lida rapida sore isso e add here, é importante

## Traffic mode 

AWS Load Balancer controller supports two traffic modes:

Instance mode
IP mode
By default, Instance mode is used, users can explicitly select the mode via alb.ingress.kubernetes.io/target-type annotation.

Instance mode¶
Ingress traffic starts at the ALB and reaches the Kubernetes nodes through each service's NodePort. This means that services referenced from ingress resources must be exposed by type:NodePort in order to be reached by the ALB.

IP mode¶
Ingress traffic starts at the ALB and reaches the Kubernetes pods directly. CNIs must support directly accessible POD ip via secondary IP addresses on ENI.


# TODO's
[] comparativo de performance quando usando o multiplos ingress/apps no ALB. isso aqui é legal de fazer




# References

https://aws.amazon.com/blogs/containers/a-deeper-look-at-ingress-sharing-and-target-group-binding-in-aws-load-balancer-controller/

https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.13/
https://github.com/kubernetes-sigs/aws-load-balancer-controller