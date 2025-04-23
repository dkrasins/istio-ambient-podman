#! /bin/bash
set -x


OCNE_CLUSTER="true"
OCNE_ISTIO="true"

testCurl() {
	NS="$1"
	kubectl -n "$NS" apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: testpod
spec:
  containers:
    - name: my-container
      command: ["sleep", "10d"]
      securityContext:
        privileged: true
      image: container-registry.oracle.com/os/oraclelinux:8-slim
EOF

	kubectl -n "$NS" wait --for=condition=ready "pod/testpod"

	echo "Testing namespace $NS"
	kubectl -n "$NS" exec -ti testpod -- microdnf install podman
	kubectl -n "$NS" exec -ti testpod -- podman run --rm container-registry.oracle.com/os/oraclelinux:8-slim curl https://raw.githubusercontent.com/oracle-cne/ocne/refs/heads/main/doc/table-of-contents.md
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--nocne ) OCNE_CLUSTER=""; OCNE_ISTIO=""; shift ;;
		--community-istio ) OCNE_ISTIO=""; shift ;;
		* ) echo "$1 is not a supported argument"; exit 1 ;;
	esac
done

if [ -n "$OCNE_CLUSTER" ]; then
	if [ -n "$OCNE_ISTIO" ]; then
		ocne cluster start -c istio-ambient.yaml
		kubectl -n istio-system rollout status deployment istiod
	else
		ocne cluster start -C ambient-curl --worker-nodes 1 --auto-start-ui false
	fi
	export KUBECONFIG="$(ocne cluster show -C ambient-curl)"
else
	echo "Checking nodes"
	kubectl get nodes
	if [ $? != 0 ]; then
		echo "Could not get cluster nodes.  Do you have a valid KUBECONFIG?"
		exit 1
	fi
fi

if [ -z "$OCNE_ISTIO" ]; then
	helm repo add istio https://istio-release.storage.googleapis.com/charts
	helm repo update
	helm install istio-base istio/base -n istio-system --create-namespace --wait
	kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null ||   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
	helm install istiod istio/istiod --namespace istio-system --set profile=ambient --wait
	helm install istio-cni istio/cni -n istio-system --set profile=ambient --wait
	helm install ztunnel istio/ztunnel -n istio-system --wait
fi


kubectl create ns noistio
kubectl create ns ambient

kubectl label namespace ambient istio.io/dataplane-mode=ambient

testCurl noistio
testCurl ambient
