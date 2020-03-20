#!/bin/sh

# download docker 
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum list docker-ce --showduplicates | sort -r
yum install docker-ce-18.06.3.ce-3.el7 -y
systemctl start docker

# install k8s
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm kubectl 
yum install kubectl-1.15.3-0 kubelet-1.15.3-0 kubeadm-1.15.3-0 -y --disableexcludes=kubernetes

# 检查需要那些镜像
kubeadm config images list
# 下载相关镜像
#!/bin/bash
images=(
    kube-apiserver:v1.15.3
    kube-controller-manager:v1.15.3
    kube-scheduler:v1.15.3
    kube-proxy:v1.15.3
    pause:3.1
    etcd:3.3.10
    coredns:1.3.1

    pause-amd64:3.1

    kubernetes-dashboard-amd64:v1.10.0
    heapster-amd64:v1.5.4
    heapster-grafana-amd64:v5.0.4
    heapster-influxdb-amd64:v1.5.2
)

for imageName in ${images[@]} ; do
    docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
    docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
done

sh -c "echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables"
sh -c "echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables"

echo '{"exec-opts":["native.cgroupdriver=systemd"]}' > /etc/docker/daemon.json
systemctl restart docker
systemctl enable docker
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false --cgroup-driver=cgroupfs"' > /etc/sysconfig/kubelete
systemctl daemon-reload && systemctl enable kubelet

# 關閉防火牆
systemctl stop firewalld && systemctl disable firewalld
# 關閉swap
swapoff -a
kubeadm init --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 

cd ~
mkdir .kube
cp -i /etc/kubernetes/admin.conf .kube/config

