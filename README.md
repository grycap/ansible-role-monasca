monasca-ansible
===============

Ansible playbook for Monasca!

## What does it do?

Install and configure the following services:

* monasca-api
* monasca-persister
* monasca-notification
* monasca-thresh
* monasca-agent
* monitoring dashboard for monasca

## Deploying DevStack + Monasca:

2 instances (devstack, monasca).

**Minimal instance configuration**

1. devstack
    * 2 VCPU
    * 4GB memory
    * 20GB storage
    * Ubuntu 16.04

2. monasca
    * 4 VCPU
    * 12GB memory
    * 20GB storage
    * Ubuntu 16.04

**Ports on security group:**

- 22 (SSH)
- 80 (HTTP)
- 3000 (grafana)
- 5000 (keystone)
- 8070 (monasca-api)
- 35357 (keystone-admin)

**On devstack:**

```bash
sudo apt-get update && sudo apt-get install git -y
git clone https://git.openstack.org/openstack-dev/devstack
cd devstack
# Configure local.conf
./stack
```

**On your machine:**

```bash
sudo apt-get update && sudo apt-get install git -y
git clone https://git.lsd.ufcg.edu.br/monag/monasca-ansible.git
cd monasca-ansible
sudo scripts/bootstrap-ansible.sh
# Add devstack and monasca IP address to the inventory file
ansible-playbook setup-everything.yml
```
