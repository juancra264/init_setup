# Kubernetes Cluster Installation on Debian 13 (Minimal)

This directory contains automated installation scripts for setting up both **Control Plane (Master)** and **Worker** nodes for Kubernetes on **Debian 13 (Trixie) Minimal Server**.

## Included Scripts

- [install-k8s-control-plane.sh](file:///home/jcramirez/k8s/install-k8s-control-plane.sh): Sets up prerequisites, containerd, Kubernetes packages, initializes the cluster control plane via `kubeadm init`, installs the CNI network plugin, and configures `kubeconfig`.
- [install-k8s-worker-node.sh](file:///home/jcramirez/k8s/install-k8s-worker-node.sh): Sets up prerequisites, containerd, Kubernetes packages, and joins the node to the existing control plane cluster.

---

## What the Scripts Automate

1. **Debian Minimal Dependencies**: Installs missing utilities (`curl`, `ca-certificates`, `gnupg`, `iptables`, `iproute2`, `socat`, `conntrack`, `ebtables`, `procps`, etc.).
2. **Swap Management**: Disables swap immediately (`swapoff -a`), permanently comments out swap in `/etc/fstab`, and masks `swap.target` in systemd.
3. **Kernel Modules & Sysctl**: Automatically loads and persists `overlay` and `br_netfilter`, and applies required bridging and IP forwarding parameters (`net.bridge.bridge-nf-call-iptables = 1`, `net.ipv4.ip_forward = 1`).
4. **Container Runtime (`containerd`)**:
   - Generates default config with `SystemdCgroup = true`.
   - Fixes the Debian-specific issue where the CRI plugin may be listed in `disabled_plugins`.
5. **Official Kubernetes Repositories**: Configures official `pkgs.k8s.io` community repository for Debian (default: v1.31) and locks package versions with `apt-mark hold`.

---

## Prerequisites

- **Debian 13 (Trixie)** Minimal Server
- **Control Plane Node Requirements**:
  - Minimum 2 vCPUs, 2 GB RAM (4 GB recommended), 20 GB disk.
  - Inbound ports: `6443` (API Server), `2379-2380` (etcd), `10250` (Kubelet), `10259`, `10257`.
- **Worker Node Requirements**:
  - Minimum 1 vCPU (2 recommended), 1 GB RAM (2 GB recommended), 20 GB disk.
  - Inbound ports: `10250` (Kubelet API), `30000-32767` (NodePort Services).

---

## 1. Setting Up the Control Plane Node

Run these steps on your **Control Plane (Master)** server:

```bash
chmod +x install-k8s-control-plane.sh
sudo ./install-k8s-control-plane.sh
```

### Control Plane Options

```text
Usage: sudo ./install-k8s-control-plane.sh [OPTIONS]

Options:
  -v, --version <version>         Kubernetes version branch (default: 1.31)
  -p, --pod-cidr <cidr>           Pod network CIDR (default: 10.244.0.0/16)
  -c, --cni <flannel|calico|none> CNI network plugin to install (default: flannel)
  -i, --ip <ip-address>           API server advertise IP (default: auto-detected)
  -s, --single-node               Allow running pods on master (removes taints)
  -n, --no-init                   Prepare node only; do not run kubeadm init
```

*Example (Single-node cluster for homelab / dev):*
```bash
sudo ./install-k8s-control-plane.sh --single-node
```

*Example (Calico CNI):*
```bash
sudo ./install-k8s-control-plane.sh --cni calico --pod-cidr 192.168.0.0/16
```

---

## 2. Setting Up a Worker Node

Copy [install-k8s-worker-node.sh](file:///home/jcramirez/k8s/install-k8s-worker-node.sh) to each **Worker** machine.

Make it executable:
```bash
chmod +x install-k8s-worker-node.sh
```

### Option A: Direct Join Using Full Join Command (Recommended)

Copy the `kubeadm join ...` command shown at the end of the control plane setup (or generated via `sudo kubeadm token create --print-join-command`), and pass it directly:

```bash
sudo ./install-k8s-worker-node.sh --join "kubeadm join 192.168.1.100:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
```

### Option B: Join Using Individual Parameters

```bash
sudo ./install-k8s-worker-node.sh \
  --endpoint 192.168.1.100:6443 \
  --token <token> \
  --hash sha256:<hash>
```

### Option C: Prepare Worker Node Only (Join Manually Later)

```bash
sudo ./install-k8s-worker-node.sh
```
This prepares the system, installs containerd and Kubernetes components, and then lets you run `sudo kubeadm join ...` whenever ready.

---

## 3. Verification

On the **Control Plane** node, verify that all nodes and pods are operational:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```
