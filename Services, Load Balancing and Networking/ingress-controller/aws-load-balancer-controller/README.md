# What's it


Repository: https://github.com/kubernetes-sigs/aws-load-balancer-controller

# How it works

![AWS Load Balancer Controller Architecture](https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/groups-in-action.png)


It watches the Kubernetes API server for updates to Ingress resources. When it detects changes, it updates resources such as the Application Load Balancer, listeners, target groups, and listener rules. #TODO Tem mutation webhook, comentar sobre isso

A Target group gets created for every Kubernetes Service mentioned in the ingress resource
Listeners are created for every port defined in the ingress resource’s annotations
Listener rules (also called ingress rules) are created for each path in Ingress resource definition


![imagem mostrando o roteamento ](https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/load-balancer-routing.png)

## Rules

ordem de criação (priority)
https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2203
https://kubernetes.io/docs/concepts/services-networking/ingress/#multiple-matches
#TODO ver direitinho, mas acho que prioridade da rule é menor de acordo com o tamanho do path setado no ingress
https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/3450
#TODO ???? porém, como que fica tudo isso quando mistura multiplos ingress com multiplas regras ????
The priority on the rules is decided on the PathType. The prefix type take higher priority here than the implementations specific. https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/spec/#ingress-specification

problem : cost
solucao: ingress group

An important aspect to consider before using IngressGroup in a multi-tenant environment is conflict resolution. When AWS Load Balancer Controller configures ingress rules in ALB, it uses the group.order field to set the order of evaluation. If you don’t declare a value for group.order, the Controller defaults to 0.

Rules with lower order value are evaluated first. By default, the rule order between Ingresses within an IngressGroup is determined by the lexical order of Ingress’s namespace/name.

AWS ALB (Application Load Balancer) has several limits on the number of rules that can be configured per listener. These limits are in place to prevent overloading the load balancer and impacting its performance. For example, each ALB listener can have up to 100 rules by default

https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.13/
https://github.com/kubernetes-sigs/aws-load-balancer-controller

## Target group binding

TargetGroupBinding is a custom resource managed by the AWS Load Balancer Controller. It allows you to expose Kubernetes applications using existing load balancers. A TargetGroupBinding resource binds a Kubernetes Service with a load balancer target group. When you create a TargetGroupBinding resource, the controller automatically configures the target group to route traffic to a Service. Here’s an example of a TargetGroupBinding resource:

https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/TargetGroupBinding.png


## Load balance application traffic across clusters
ALB can distribute traffic to multiple backends using weighted target groups. You can use this feature to route traffic to multiple clusters by first creating a target group for each cluster and then binding the target group to Services in multiple clusters. This strategy allows you to control the percentage of traffic you send to each cluster.

Such traffic controls are especially useful when performing blue/green cluster upgrades. You can migrate traffic from the older cluster to the newer in a controlled manner.


## Traffic mode

AWS Load Balancer controller supports two traffic modes:

Instance mode
IP mode
By default, Instance mode is used, users can explicitly select the mode via alb.ingress.kubernetes.io/target-type annotation.

Instance mode¶
Ingress traffic starts at the ALB and reaches the Kubernetes nodes through each service's NodePort. This means that services referenced from ingress resources must be exposed by type:NodePort in order to be reached by the ALB.

IP mode¶
Ingress traffic starts at the ALB and reaches the Kubernetes pods directly. CNIs must support directly accessible POD ip via secondary IP addresses on ENI.

# Pontos importantes, highlights
- add uma área meio que de quick tips onde vai ter uma bulleted list com pontos importantes tipo
    - ao deletar, controler duplica a regra
        - nao atinja o limite de rule (201)


Ideias pra resolver o problema da LC
- Aumentar limite de rules per ALB ?


# TODO's
[] comparativo de performance quando usando o multiplos ingress/apps no ALB

[] estar (nao necessariamente precisa ir pra POC) :

- testar o group.order com os 40 ingress e ver o que da
    - testar isso primeiro com o webhook e depois sem
    - observar o que acontece ao deletar ingress
        - se duplica rule
        - como fica a priority
            - ver como fica a prioridade quando mescla multiplos ingress e rules per ingress
    - measurements
        - fazer essas medidas com webhook e sem
        - tempo de criação do ingress e alb com group.order
        - tempo de ajuste das priorities apõs a exclusao do ingress
[] colocar aqui os arquivos de config que eu lembrar, tipo 
ingress class









https://aws.amazon.com/blogs/containers/a-deeper-look-at-ingress-sharing-and-target-group-binding-in-aws-load-balancer-controller/