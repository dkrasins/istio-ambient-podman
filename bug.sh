#! /bin/bash
set -x

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

ocne cluster start -c istio-ambient.yaml
export KUBECONFIG="$(ocne cluster show -C ambient-curl)"

kubectl -n istio-system rollout status deployment istiod

kubectl create ns noistio
kubectl create ns ambient

kubectl label namespace ambient istio.io/dataplane-mode=ambient

testCurl noistio
testCurl ambient
