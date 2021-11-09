#!/usr/bin/env bash
#
# Script creates necessary configs, installs internal registry and ingress.
#

if ! type kind >> /dev/null; then echo "Before run this script, you need to install Kind."; exit 1; fi

# Create a kind cluster user config
test ! -f ~/.kind/.config && mkdir -p ~/.kind && cat <<EOF >> ~/.kind/.config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
    endpoint = ["http://kind-registry:5000"]
EOF

cat ~/.kind/.config | kind create cluster --name=magpie --config=-

# Install registry
./scripts/kind-with-registry.sh

# Install nginx-ingress
oc apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
oc wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
