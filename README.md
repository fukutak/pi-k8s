# Let's make kubernetes cluster using raspberry-pi
## construction
- raspberry pi 4 model 8GB * 1 (for control plane)
- raspberry pi 4 model 4GB * 2 (for worker)

## Ansible
### roles: setup
set up sshd_config and put key to ssh for each nodes.
- set ssh pub key to authorized_keys
- set ssh priv key to ssh each nodes
- modify sshd_config
  - off root login
  - off passwd auth.
- add nodes in /etc/hosts to ssh each nodes


### k8s_prepare
install docker in each nodes.
- swap off requred [k8s setup](https://kubernetes.io/ja/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- docker install

```
cd ansible
ansible-playbook  -i inventory/inventory.yml playbook.yml
```
