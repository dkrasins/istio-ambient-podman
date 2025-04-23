# istio-ambient-podman
Resources to reproduce an issue with Istio Ambient mode and Podman.  If Podman is used to create a container inside a container in a Kubernetes pod, that container is not able to access networking outside the cluster.  

# Reproducing

If you have [Oracle Cloud Native Environment](github.com/oracle-cne/ocne) installed, you can just run `sh bug.sh`.  Otherwise, install Kubernetes and Istio in ambient mode via [the Istio Ambient mode installation guide](https://istio.io/latest/docs/ambient/install/helm/) and remove the cluster provisioning step from `bug.sh`.

# Results

This results assume that `ocne` is used to provision the cluster and Istio.  Two namespaces are created.  One has ambient mode enabled, the other does not use any Istio data plane.  In the unlabelled namespace, networking works fine inside the container.  In the labelled namespace, networking fails.

```
$ sh bug.sh 
+ ocne cluster start -c istio-ambient.yaml
INFO[2025-04-23T16:43:45Z] Creating new Kubernetes cluster with version 1.31 named ambient-curl 
INFO[2025-04-23T16:44:46Z] Waiting for the Kubernetes cluster to be ready: ok 
INFO[2025-04-23T16:44:48Z] Installing core-dns into kube-system: ok 
INFO[2025-04-23T16:44:49Z] Installing kube-proxy into kube-system: ok 
INFO[2025-04-23T16:44:52Z] Installing kubernetes-gateway-api-crds into kube-system: ok 
INFO[2025-04-23T16:44:52Z] Installing flannel into kube-flannel: ok 
INFO[2025-04-23T16:44:53Z] Installing ocne-catalog into ocne-system: ok 
...
++ ocne cluster show -C ambient-curl
+ export KUBECONFIG=/home/opc/.kube/kubeconfig.ambient-curl.local
+ KUBECONFIG=/home/opc/.kube/kubeconfig.ambient-curl.local
+ kubectl -n istio-system rollout status deployment istiod
Waiting for deployment "istiod" rollout to finish: 0 of 1 updated replicas are available...
deployment "istiod" successfully rolled out
+ kubectl create ns noistio
namespace/noistio created
+ kubectl create ns ambient
namespace/ambient created
+ kubectl label namespace ambient istio.io/dataplane-mode=ambient
namespace/ambient labeled
+ testCurl noistio
+ NS=noistio
+ kubectl -n noistio apply -f -
pod/testpod created
+ kubectl -n noistio wait --for=condition=ready pod/testpod
pod/testpod condition met
+ echo 'Testing namespace noistio'
Testing namespace noistio
+ kubectl -n noistio exec -ti testpod -- microdnf install podman
Downloading metadata...
Downloading metadata...
Package                                                                                                                                                             Repository                                                        Size
Installing:                                                                                                                                                                                                                               
 acl-2.2.53-3.el8.x86_64                                                                                                                                            ol8_baseos_latest                                              81.9 kB
... [ A BUNCH OF DNF OUTPUT ]
+ kubectl -n noistio exec -ti testpod -- podman run --rm container-registry.oracle.com/os/oraclelinux:8-slim curl https://raw.githubusercontent.com/oracle-cne/ocne/refs/heads/main/doc/table-of-contents.md
Trying to pull container-registry.oracle.com/os/oraclelinux:8-slim...
Getting image source signatures
Copying blob 63ad4437b990 done   | 
Copying config d5b14c4279 done   | 
Writing manifest to image destination
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   486  100   486    0     0   6075      0 --:--:-- --:--:--# Table of Contents

* [Cluster Management](cluster-management/cluster-management.md)
* [Application Management](application-management/application-management.md)
* [Mirroring Catalogs](application-management/mirroring-catalogs.md)
* [Administration](administration/administration.md)
* [Configuration](configuration/configuration.md)
* [Creating Custom Images](images/images.md)
* [End To End Examples](end-to-end/end-to-end.md)
* [Troubleshooting](troubleshooting/troubleshooting.md)
 --:--:--  6151
+ testCurl ambient
+ NS=ambient
+ kubectl -n ambient apply -f -
pod/testpod created
+ kubectl -n ambient wait --for=condition=ready pod/testpod
pod/testpod condition met
+ echo 'Testing namespace ambient'
Testing namespace ambient
+ kubectl -n ambient exec -ti testpod -- microdnf install podman
Downloading metadata...
Downloading metadata...
Package                                                                                                                                                             Repository                                                        Size
Installing:                                                                                                                                                                                                                               
 acl-2.2.53-3.el8.x86_64                                                                                                                                            ol8_baseos_latest                                              81.9 kB
... [ A BUNCH OF DNF OUTPUT ]
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
Complete.
+ kubectl -n ambient exec -ti testpod -- podman run --rm container-registry.oracle.com/os/oraclelinux:8-slim curl https://raw.githubusercontent.com/oracle-cne/ocne/refs/heads/main/doc/table-of-contents.md
Trying to pull container-registry.oracle.com/os/oraclelinux:8-slim...
Getting image source signatures
Copying blob 63ad4437b990 done   | 
Copying config d5b14c4279 done   | 
Writing manifest to image destination
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:10 --:--:--     0
curl: (35) OpenSSL SSL_connect: SSL_ERROR_SYSCALL in connection to raw.githubusercontent.com:443 
command terminated with exit code 35
```
