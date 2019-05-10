---
title: Kubernetes 学习札记 - 在 Google Cloud 上搭建集群
date: 2018-07-06T19:10:12+0800
toc: true
categories: 学习
tags:
  - kubernetes
  - 学习札记
---

#### Target

* 搭建 Kubernetes 集群（Master * 1 + Node * 2）
<!-- more -->


#### Machines

Hostname|Machine Type
--------|------------
kube-master|n1-standard
kube-node-1|n1-standard
kube-node-2|n1-standard



#### Preparation on Master Machine

1. 安装 `Docker` 和 `Kubeadm`

   保存下面脚本为 `init-k8s-master.sh`

   ```shell
   #!/bin/sh

   # install docker
   apt-get update
   apt-get install -y apt-transport-https ca-certificates curl software-properties-common
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
   sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
   apt-get update
   apt-get install -y docker-ce

   # install k8s
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
   echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >> /etc/apt/sources.list.d/kubernetes.list
   apt-get update
   apt-get install -y kubelet kubeadm kubectl

   # ONLY run on master
   # configure cgroup
   sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
   systemctl daemon-reload
   systemctl restart kubelet
   ```

   执行上述脚本 `sudo source init-k8s-master.sh`

2. 选择一个 Pod 网络组件（Pod Network Add-on）

   组件有很多种，这里我选择了 `Flannel`，具体操作见接下来两个步骤

3. 启动集群 Master

   ```shell
   # 这里的 --pod-network-cidr=10.244.0.0/16 取决于你选择的网络组件
   sudo kubeadm init --pod-network-cidr=10.244.0.0/16
   ```

   启动了之后从结果的最后几行里面获得一串命令行，用于操作 Node 加入集群，记下来，这个命令行有用

   ```shell
   # 获得一串类似于这样子的命令
   # 10.0.0.3 是我的 Master IP
   kubeadm join 10.0.0.3:6443 --token 8qn683.9ft7dc6xa0re697a --discovery-token-ca-cert-hash sha256:65773046272db8297b64cbc1ce8ebc3884fa932976673fad7715c2bd8c53c6a0
   ```

4. 设置环境变量，方便调用 `kubectl`

   如果想让非 root 用户使用 `kubectl` ，执行

   ```shell
   mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```

   对于 root 用户，直接设置环境变量

   ```shell
   export KUBECONFIG=/etc/kubernetes/admin.conf
   ```

   这样设置之后， `kubectl` 才能正常运行

5. 安装网络组件

   检查节点

   ```shell
   $ kubectl get nodes
   NAME          STATUS       ROLES     AGE       VERSION
   kube-master   NotReady     master    1m        v1.11.0
   ```

   会发现 STATUS 为 NotReady ，运行 `kubectl describe nodes` 得到最后一行日志是 `Container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized` ，说明网络组件还没有配置好，需要设置一下。

   这里我选择了 `Flannel` 作为网络组件，执行

   ```shell
   kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml
   ```

   再次检查节点

   ```shell
   $ kubectl get nodes
   NAME          STATUS    ROLES     AGE       VERSION
   kube-master   Ready     master    2m        v1.11.0
   ```

   至此 Master 配置完毕，准备配置 Node



#### Preparation for Node Machines

1. 安装 `Docker` 和 `Kubeadm`

   参照 Master 安装教程，删去 `cgroup` 配置部分

2. 加入集群

   ```shell
   # 在 Master 进行 kubeadm init 的时候获得的提示
   kubeadm join 10.0.0.3:6443 --token 8qn683.9ft7dc6xa0re697a --discovery-token-ca-cert-hash sha256:65773046272db8297b64cbc1ce8ebc3884fa932976673fad7715c2bd8c53c6a0
   ```

3. 检查节点状态

   在 Master 上执行 `kubectl get nodes`

   ```shell
   $ kubectl get nodes
   NAME          STATUS    ROLES     AGE       VERSION
   kube-master   Ready     master    2m        v1.11.0
   kube-node-1   Ready     master    3m        v1.11.0
   kube-node-2   Ready     master    3m        v1.11.0
   ```

   所有 STATUS 均为 Ready，完美



资料参考：

* [Creating a single master cluster with kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/)
