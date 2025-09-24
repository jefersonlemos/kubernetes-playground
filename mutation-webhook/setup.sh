#!/bin/bash

# Basic Configuration
WEBHOOK_NAMESPACE="mutation-webhook"
WEBHOOK_SERVICE="mutation-webhook-service"
SECRET_NAME="mutation-webhook-tls"
WEBHOOK_NAME="mutation-webhook"

################################################## Create the namespace

# Create the namespace for the webhook
kubectl apply -f k8s/namespace.yaml

################################################### Create the TLS certificates and keys
# Generate the certificate
openssl genrsa -out ca.key 2048
openssl req -new -x509 -key ca.key -out ca.crt -subj "/CN=${WEBHOOK_NAME}-ca"

# Create the webhook server's certificate signed by the CA
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}.svc" -config <(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${WEBHOOK_SERVICE}
DNS.2 = ${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}
DNS.3 = ${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}.svc
DNS.4 = ${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}.svc.cluster.local
EOF
)
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
openssl req -new -key server.key -out server.csr -subj "/CN=${WEBHOOK_SERVICE}" -config csr.conf

# Adjusts the secret manifest
if [[ -f server.crt ]]; then
  
  echo -n "  tls.crt: `cat server.crt | base64 | tr -d '\n'`" >> k8s/secrets_certificate.yaml 
  echo "" >> k8s/secrets_certificate.yaml
  echo -n "  tls.key: `cat server.key | base64 | tr -d '\n'`" >> k8s/secrets_certificate.yaml 
fi

# Adds CA Bundle to the webhook configuration
if [[ -f ca.crt ]]; then
  sed -i '/caBundle:/!b;n;c\        '"$(cat ca.crt | base64 | tr -d '\n')" k8s/webhook.yaml
fi

# ################################################## Create the Kubernetes resources

kubectl apply -f k8s/secrets_certificate.yaml
kubectl apply -f k8s/deployment.yaml
sleep 30 # If webhook configuration is applied before the deployment is ready, it will fail
kubectl apply -f k8s/webhook.yaml


################################################## Clean up local files
rm ca.key ca.crt server.csr server.crt server.key
