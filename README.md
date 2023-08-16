# Let's make kubernetes cluster using raspberry-pi
## Construction
- raspberry pi 4 model 8GB * 1 (for control plane)
  - pi-master
- raspberry pi 4 model 4GB * 2 (for worker)
  - pi-worker1
  - pi-worker2
## first raspi setup
```
sudo raspi-config
```
bellow settings, kubernetes cluster needs unique host name each nodes.
```
---
change hostname
expand memory
set localization
---
```
reboot after settings
```
sudo reboot
```
edit cmdline.txt
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
```
git clone https://github.com/fukutak/k8s.git
```
### roles: setup
Set up sshd_config and put key to ssh for each nodes.
- set ssh pub key to authorized_keys
- set ssh priv key to ssh each nodes
- modify sshd_config
  - off root login
  - off passwd auth.
- add nodes in /etc/hosts to ssh each nodes

### prepare for setup
create ssh key and edit `inventory/inventory.yml` in host name.
add ssh key to `ansible/roles/setup/files/authorized_keys`

### roles: k8s_prepare
- swap off required [k8s setup](https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- install docker as CRI
- install kubeadm, kubelet, kubectl

### Edit playbook.yml
In `ansible/playbook.yml`, comfirm `when`.
```
- hosts: cluster_nodes
  become: true
  roles:
    - { role: setup, when: 1 }
```
Set `when: 1` in setup role and others `when: 0`.

### Usage
```
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
### install flannel [[ref](https://qiita.com/kentarok/items/6e818c2e6cf66c55f19a)]
```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
kubectl get pods --all-namespaces | grep coredns # confirm coredns is running.
```
### join worker nodes to k8s cluster!
```
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```
Add labels of nodes.
```
k label node pi-worker1 node-role.kubernetes.io/worker1=pi-worker1
```
refs:
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/


## Install MetalLB
[refs](https://metallb.universe.tf/installation/)
preparation
```
kubectl edit configmap -n kube-system kube-proxy

apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

<!-- [refs](https://kimama.cloud/2020/08/02/raspi-de-k8s/)
[refs](https://blog.framinal.life/entry/2020/04/16/022042) -->
On Master node
```
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
$ kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```
setting local IP addresses for use
```
$ vi metallb.config.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.3.200-192.168.3.205

$ kubectl apply -f metallb.config.yaml
```

## kubernetes dashboard UI
[ref](https://kimama.cloud/2020/08/02/raspi-de-k8s-2/)
Install kubernetes dashboard
```
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml
```
Edit service type LoadBalancer
```
vi recommended.yaml

 kind: Service 
 apiVersion: v1 
 metadata: 
   labels: 
     k8s-app: kubernetes-dashboard 
   name: kubernetes-dashboard 
   namespace: kubernetes-dashboard 
 spec: 
   ports: 
     - port: 443 
       targetPort: 8443 
   selector: 
     k8s-app: kubernetes-dashboard 
+  type: LoadBalancer
```
apply
```
kubectl apply -f recommended.yaml
```

## Install kubernetes metrics server
[ref](https://qiita.com/yyojiro/items/febfaeadabd2fe8eed08)
```
pi-k8s$ wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
$ vi components.yaml
```
Edit bellow two lines
```
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
        - args:
            - --cert-dir=/tmp
            - --secure-port=4443
+           - --kubelet-insecure-tls
+           - --kubelet-preferred-address-types=InternalDNS,InternalIP,ExternalDNS,ExternalIP,Hostname
            # - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
```
deploy metrics server
```
kubectl apply -f components.yaml
```

## Create token to login
```
$ vi admin-user.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---

$ kubectl apply -f admin-user.yaml
```
Comfirm token
```
$ kubectl describe secret -n kubernetes-dashboard $(kubectl get secret -n kubernetes-dashboard | grep admin-user | awk '{print $1}') | grep ^token:
```
Comfirm endpoint LB in kubernetes-dashboard
```
pi@pi-master:~ $ kubectl get service -n kubernetes-dashboard
NAME                        TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP      10.103.16.90   <none>          8000/TCP        11h
kubernetes-dashboard        LoadBalancer   10.106.23.6    192.168.3.200   443:31629/TCP   11h
```
Access `https://192.168.3.200`