# KEDA Redis queue POC

The Python `order-worker` consumes JSON orders from the Redis list `orders`. It uses only Python's standard library and is mounted from a ConfigMap, so no custom image build or registry is required.

## Deploy

```bash
kubectl apply -f poc.yaml
```

## Test scale-up

Watch the worker:

```bash
watch -n 2 'kubectl -n keda-demo get deploy,pods,hpa,scaledobject'
```

Push 40 orders:

```bash
kubectl -n keda-demo run order-producer --rm -i --restart=Never \
  --image=redis:7-alpine -- sh -c \
  'for i in $(seq 1 40); do redis-cli -h redis RPUSH orders "{\"order_id\":$i,\"operation\":\"checkout\"}"; done'
```

Show the Python service consuming them:

```bash
kubectl -n keda-demo logs -l app=order-worker --prefix --tail=30 -f
```

The worker scales from zero to multiple replicas, processes orders in parallel, then returns to zero after the queue drains and the cooldown expires.

## Cleanup

```bash
kubectl delete namespace keda-demo
```
