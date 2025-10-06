# What's it


Repository: https://github.com/kubernetes-sigs/aws-load-balancer-controller

# Why use it?

AWS ALB Controller is one of the multiple ways to expose a Kubernetes service to the world outside (privately or to the internet) and works with EKS.

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

The AWS Application Load Balancer act as a reverse proxy routing requests to targets, so **order matters**. I mean, if you have a rule like `path: /api/*` with priority 1 and another rule `path: /api/v2/*` with priority 2, requests to `/api/v2/consumer` or `/api/v2/orders` or anything after the `/api` would redirect the request to the target defined in the first rule because it comes first. The request will never reach the second rule because the first one already matches it. 

Let me talk a little bit more about rules, ordering and priorities.

### One ALB per Ingress

Sometimes we don't want multiples ingress per one single ALB, to do so we simply NOT add the `alb.ingress.kubernetes.io/group.name:` annotation and the `aws alb controller` will create a new ALB whenever an ingress gets created.

In this scenario, rules priorities will consider only **the order the rules are added to the ingress**, it will respect the precedence. See more [here](./manifests/2.ingress-multiple-rules.md#order-matters).


### One ALB per multiple ingresses
![multiple-rules-ingress](https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/load-balancer-routing.png)

This is a more complex scenario where one single ALB will handle multiple ingresses rules so the ordering changes a little bit. 

**1st - Ingress order** - If the `group.order` annotation is not set, it will set the priority 0 to all ingresses and will are determine ALB order (or priority) by the lexical order of Ingress’s namespace/name.

**2nd - Ingresses rules** - After defining the ingresses order to add the rules to the ALB, it will also respect the order the rules are set in ingress.

In the [ingress-multiple-rules.md](./manifests/2.ingress-multiple-rules.md#how-it-works) I explain in details how it works.


## Target group binding

TargetGroupBinding is a custom resource managed by the AWS Load Balancer Controller. It allows you to expose Kubernetes applications using existing load balancers. A TargetGroupBinding resource binds a Kubernetes Service with a load balancer target group. When you create a TargetGroupBinding resource, the controller automatically configures the target group to route traffic to a Service.

Whenever an ingress is added, it creates this `TargetGroupBinding` resource but it's also to create it when we want to use an ALB that wasn't created by the `aws alb controller`.


![targetGroup Binding ](https://d2908q01vomqb2.cloudfront.net/fe2ef495a1152561572949784c16bf23abb28057/2023/03/22/TargetGroupBinding.png)


### Load balance application traffic across clusters
ALB can distribute traffic to multiple backends using weighted target groups. You can use this feature to route traffic to multiple clusters by first creating a target group for each cluster and then binding the target group to Services in multiple clusters. This strategy allows you to control the percentage of traffic you send to each cluster.

Such traffic controls are especially useful when performing blue/green cluster upgrades. You can migrate traffic from the older cluster to the newer in a controlled manner.

## Traffic mode 

AWS Load Balancer controller supports two traffic modes:
- Instance mode

By default, Instance mode is used, users can explicitly select the mode via alb.ingress.kubernetes.io/target-type annotation.

Ingress traffic starts at the ALB and reaches the Kubernetes nodes through each service's NodePort. This means that services referenced from ingress resources must be exposed by type:NodePort in order to be reached by the ALB.

- IP mode

Ingress traffic starts at the ALB and reaches the Kubernetes pods directly. CNIs must support directly accessible POD ip via secondary IP addresses on ENI.

# Performance test
I ran some tests with a single app and a load balancer with 181 rules pointing to different apps.
This is the command I used: `https://my-app/health-check`

## Explanation

- Without OR: One rule per host
- With OR: I changed the rules to evaluate 3 different hosts with an `OR` condition


## Results

| Test                              | Avg Latency (s) | Req/sec | Success (200) | Fail (503) | Notes                    |
|------------------------------------|-----------------|---------|---------------|------------|--------------------------|
| With OR                           | 0.2578          | 193.9   | 11657         | 0          | Baseline with complex rule|
| Without OR 1                      | 0.2537          | 196.6   | 11842         | 0          | Slightly faster          |
| Without OR 2                      | 0.2461          | 203.1   | 5406          | 6799       | 503 spike (possible misroute)|
| With OR on alb2                   | 0.2504          | 199.2   | 11995         | 0          | Stable and solid         |
| With OR on alb2, alb3, alb9       | 0.2548          | 196.1   | 11787         | 0          | Slight degradation       |
| With OR on alb2, alb3, alb9 until priority 30 | 0.2523 | 198.1   | 11915         | 0          | Stable again             |

## Analysis

1. Performance Difference (OR vs No OR)

I didn't see significant differeces running the tests with or without the `OR` condition. The results and perception during the tests look very similar.
Important to mention that I ran from my local computer, using `hey` and there were no real traffic in that specific ALB.


# References

- https://aws.amazon.com/blogs/containers/a-deeper-look-at-ingress-sharing-and-target-group-binding-in-aws-load-balancer-controller/
- https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.13/
- https://github.com/kubernetes-sigs/aws-load-balancer-controller
- https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2203
- https://kubernetes.io/docs/concepts/services-networking/ingress/#multiple-matches