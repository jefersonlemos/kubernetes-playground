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
openssl genrsa -out key.pem 2048

cat > csr.conf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}.svc
DNS.2 = ${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}.svc.cluster.local
EOF

openssl req -x509 -new -nodes -key key.pem -sha256 -days 365 \
  -out cert.pem -subj "/CN=${WEBHOOK_SERVICE}.${WEBHOOK_NAMESPACE}.svc" \
  -extensions v3_req -config csr.conf


# Adjusts the secret manifest
if [[ -f cert.pem ]]; then
  
  echo -n "  cert.pem: `cat cert.pem | base64 | tr -d '\n'`" >> k8s/secrets_certificate.yaml 
  echo "" >> k8s/secrets_certificate.yaml
  echo -n "  key.pem: `cat key.pem | base64 | tr -d '\n'`" >> k8s/secrets_certificate.yaml 
fi

# Adds CA Bundle to the webhook configuration
if [[ -f ca.crt ]]; then
  sed -i '/caBundle:/!b;n;c\        '"$(cat cert.pem | base64 | tr -d '\n')" k8s/webhook.yaml
fi

# ################################################## Create the Kubernetes resources

kubectl apply -f k8s/secrets_certificate.yaml
kubectl apply -f k8s/deployment.yaml
sleep 30 # If webhook configuration is applied before the deployment is ready, it will fail
kubectl apply -f k8s/webhook.yaml


################################################## Clean up local files
rm ca.key ca.crt server.csr server.crt server.key
