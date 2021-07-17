# Let's make kubernetes cluster using raspberry-pi
## Construction
- raspberry pi 4 model 8GB * 1 (for control plane)
- raspberry pi 4 model 4GB * 2 (for worker)
## first raspi setup
```
raspi-config
---
change hostname
expand memory
set localization
---
sudo reboot
```
ssh after reboot again
```
sudo nano /boot/cmdline.txt
---append below---
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
---
sudo reboot
```
```
cat /proc/cgroups
---check memory---
memory	6	94	1
```

## Ansible
### roles: setup
set up sshd_config and put key to ssh for each nodes.
- set ssh pub key to authorized_keys
- set ssh priv key to ssh each nodes
- modify sshd_config
  - off root login
  - off passwd auth.
- add nodes in /etc/hosts to ssh each nodes

### roles: k8s_prepare
- swap off required [k8s setup](https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- install docker as CRI
- install kubeadm, kubelet, kubectl

### Usage
```
git clone https://github.com/fukutak/k8s.git
cd ansible
ansible-playbook  -i inventory/inventory.yml playbook.yml
```

## Build k8s cluster using kubeadm
In master node. [[ref](https://qiita.com/sotoiwa/items/e350579d4c81c4a65260)]
```
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
---log---
Your Kubernetes control-plane has initialized successfully!
To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```
install flannel [[ref](https://qiita.com/kentarok/items/6e818c2e6cf66c55f19a)]
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
kubectl get pods --all-namespaces | grep coredns # confirm coredns is running.
```
join worker nodes to k8s cluster!
```
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```
refs:
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

## Install ingress-nginx
ref: https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-manifests/
```
git clone https://github.com/nginxinc/kubernetes-ingress/
cd kubernetes-ingress/deployments/
git checkout v1.12.0
---
kubectl apply -f common/ns-and-sa.yaml
kubectl apply -f rbac/rbac.yaml
---
kubectl apply -f common/default-server-secret.yaml
kubectl apply -f common/nginx-config.yaml
kubectl apply -f common/ingress-class.yaml
---
kubectl apply -f common/crds/k8s.nginx.org_virtualservers.yaml
kubectl apply -f common/crds/k8s.nginx.org_virtualserverroutes.yaml
kubectl apply -f common/crds/k8s.nginx.org_transportservers.yaml
kubectl apply -f common/crds/k8s.nginx.org_policies.yaml
---
kubectl apply -f common/crds/k8s.nginx.org_globalconfigurations.yaml
---
kubectl apply -f common/crds/appprotect.f5.com_aplogconfs.yaml
kubectl apply -f common/crds/appprotect.f5.com_appolicies.yaml
kubectl apply -f common/crds/appprotect.f5.com_apusersigs.yaml
---
kubectl apply -f deployment/nginx-ingress.yaml
---
kubectl get pods --namespace=nginx-ingress
```

uninstall
```
kubectl delete namespace nginx-ingress
kubectl delete clusterrole nginx-ingress
kubectl delete clusterrolebinding nginx-ingress
kubectl delete -f common/crds/
```

ref: https://datatechnologylab.readthedocs.io/ja/latest/container/Level4/ingress/ingress.html
helm install
```
sudo apt update
sudo apt install snapd
sudo reboot
sudo snap install core
sudo snap install helm --classic
```
pod内で資材の確認を行う場合は下記
```
kubectl exec my-nginx-76f4546447-8r57w -i -t -- bash -il
```
`/tmp/build`配下にpodのnginxのドキュメントルートを設定したので、資材を配置しないといけない。
## kubernetes dashboard UI
pending below.

in master node. (https://kubernetes.io/ja/docs/tasks/access-application-cluster/web-ui-dashboard/)
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl proxy
```
access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
