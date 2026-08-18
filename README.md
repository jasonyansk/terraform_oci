# Terraform for Oracle Cloud Infrastructure (OCI)

Reusable Terraform configuration to provision network infrastructure and compute instances on Oracle Cloud
Infrastructure (OCI). Written for learning purposes, so it relies on the simplest possible setup: Security
Token authentication and local state.

The `production/uk-london-1` environment provisions a **3-node kubeadm Kubernetes cluster** (1 control-plane
+ 2 workers) sized to fit entirely inside the OCI **Always Free** tier — a hands-on lab for CKA (Certified
Kubernetes Administrator) study.

## Repository Structure

```
.
├── modules/                          # Reusable modules
│   └── oci/
│       ├── compute/instance/         # Compute instances, block volumes, agent config
│       ├── networking/vcn/           # VCN, subnets, Internet Gateway, route tables
│       └── security/nsg/             # Network Security Groups with ingress/egress rules
└── envs/                             # Environment-specific configurations
    └── production/oci/uk-london-1/
        ├── _platform/                # Platform layer: VCN, subnets, NSGs
        └── app/                      # App layer: the Kubernetes cluster's compute instances
            └── templates/            # Cloud-init script that bootstraps each k8s node
```

### Layers

Infrastructure is split into two layers that are applied in order:

1. **`_platform`** — creates the Virtual Cloud Network (VCN), subnets, and Network Security Groups (NSGs). Its outputs are written to a local state file.
2. **`app`** — creates the cluster's compute instances and reads the platform layer's subnet and NSG OCIDs from its local state via `terraform_remote_state`.

This keeps networking and compute in separate state files so each can be changed independently.

## The Kubernetes cluster

Bootstrapped with `kubeadm` (not OKE — the point is to practice the manual cluster-admin workflow the CKA
exam tests) and split across OCI's **two separate** Always Free compute pools:

| Node                 | Shape                  | Arch    | OCPU  | Memory   | Boot volume | Role                        |
|-----------------------|-------------------------|---------|-------|----------|-------------|------------------------------|
| `k8s-control-plane`  | VM.Standard.A1.Flex     | aarch64 | 1     | 6 GB     | 50 GB       | control-plane + Flannel CNI |
| `k8s-worker-1`        | VM.Standard.A1.Flex     | aarch64 | 1     | 6 GB     | 50 GB       | worker                      |
| `k8s-worker-2`        | VM.Standard.E2.1.Micro  | x86_64  | 1/8   | 1 GB     | 50 GB       | worker                      |
| **Total**             |                          |         |       |          | **150 GB**  |                              |

- **Ampere A1 pool** (control-plane + worker-1): 2 OCPU / 12 GB total. Oracle cut this tenancy-wide
  allowance in half in 2026 (it used to be 4 OCPU / 24 GB) and started enforcing the new cap on
  2026-08-18 — provisioning above 2 OCPU / 12 GB now risks the excess A1 instances being disabled and
  deleted. See "Gotchas" below.
- **AMD Micro pool** (worker-2): a *separate* Always Free allowance (up to 2 `VM.Standard.E2.1.Micro`
  instances, 1/8 OCPU + 1 GB each) untouched by the A1 cut — used here to keep a 3-node cluster without
  spending any A1 quota. It's memory-tight and x86_64 (different arch from the other two nodes), which is
  itself decent CKA practice (mixed-arch scheduling considerations).
- 150 GB of the 200 GB Always Free block volume allowance (boot + block volumes combined, across both
  pools) is used. Networking (VCN, subnets, NSGs, Internet Gateway) is free regardless of tier.

Each node's cloud-init (`app/templates/k8s-node-init.sh.tftpl`) disables swap, opens the host firewall
(Oracle's Ubuntu images default-deny most inbound traffic at the iptables level even when the NSG allows
it), and installs containerd + kubeadm/kubelet/kubectl. The control-plane node additionally runs
`kubeadm init` and applies the [Flannel](https://github.com/flannel-io/flannel) CNI automatically.

**Joining the workers is a manual step, on purpose** — running `kubeadm join` yourself is CKA-exam-relevant,
and it avoids a Terraform apply depending on SSH access to itself. See "Deploying" below.

## Deploying

1. **Authenticate** your CLI session (Security Token auth):

   ```sh
   oci session authenticate --region uk-london-1
   ```

2. **Find Ubuntu images for both shapes** and put their OCIDs in
   `envs/production/oci/uk-london-1/app/terraform.tfvars` — the aarch64 one in `source_image_id` (the
   default, used by the two A1 nodes), the x86_64 one in `k8s-worker-2`'s `instances[...].source_image_id`
   override:

   ```sh
   # aarch64 — for VM.Standard.A1.Flex (control-plane, worker-1)
   oci compute image list --compartment-id <compartment_id> --operating-system "Canonical Ubuntu" \
     --shape "VM.Standard.A1.Flex" --region uk-london-1 --sort-by TIMECREATED --sort-order DESC

   # x86_64 — for VM.Standard.E2.1.Micro (worker-2)
   oci compute image list --compartment-id <compartment_id> --operating-system "Canonical Ubuntu" \
     --shape "VM.Standard.E2.1.Micro" --region uk-london-1 --sort-by TIMECREATED --sort-order DESC
   ```

3. **Review `terraform.tfvars`** in both `_platform` and `app` — compartment OCID, your SSH public key, and
   your admin IP (the NSG only allows SSH/6443/NodePorts from that CIDR).

4. **Apply the platform layer**, then the app layer:

   ```sh
   cd envs/production/oci/uk-london-1/_platform
   terraform init && terraform apply

   cd ../app
   terraform init && terraform apply
   ```

5. **Wait for cloud-init** to finish on the control-plane (a few minutes — it's installing packages and
   running `kubeadm init`). Then SSH in and fetch the join command:

   ```sh
   ssh ubuntu@<control-plane-public-ip>
   cat kubeadm-join.sh
   ```

6. **Join each worker** — SSH into `k8s-worker-1` and `k8s-worker-2` and run the `kubeadm join ...` command
   from step 5 with `sudo`.

7. **Use the cluster** — from the control-plane node (or copy `/home/ubuntu/.kube/config` to your laptop):

   ```sh
   kubectl get nodes -o wide
   ```

### Tearing down / resetting

- Full teardown: `terraform destroy` in `app`, then in `_platform`.
- To re-practice `kubeadm init`/`join` without destroying the VMs: `kubeadm reset` on each node, then re-run
  the relevant commands from steps 5–6 (or just re-run the control-plane's `/var/log/k8s-node-init.log`
  steps by hand).

### Gotchas

- **A1 pool is tenancy-wide and has been cut before — check it hasn't changed again.** As of 2026-08-18,
  Always Free entitles a tenancy to **2 OCPU / 12 GB total** across *all* Ampere A1 instances combined (down
  from 4 OCPU / 24 GB before mid-2026). This app layer's two A1 nodes are sized to use exactly that. If you
  add another A1 instance or bump `ocpus`/`memory_in_gbs`, you go over the free allowance — Oracle's
  documented behavior is to disable, then delete after 30 days, any A1 instances beyond it, unless the
  tenancy is upgraded to a paid account (in which case the excess is likely billed instead — behavior wasn't
  consistently documented at the time this was written). Re-check
  [Oracle's Always Free docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm) before resizing.
- **A1.Flex capacity**: Always Free Ampere A1 capacity is popular and region-constrained. If `apply` fails
  with an "out of host capacity" error, retry later or reduce OCPU/memory per node.
- **Image architecture**: each instance's `source_image_id` must match its shape's architecture — an
  x86_64 image won't boot on `VM.Standard.A1.Flex`, and an aarch64 image won't boot on
  `VM.Standard.E2.1.Micro`. The per-instance `source_image_id` override in `instances[...]` exists
  specifically because this cluster mixes both.
- **`VM.Standard.E2.1.Micro` is memory-tight**: 1 GB total, shared between the OS, containerd, and kubelet.
  Fine as a 3rd node for `kubeadm join`/`kubectl drain`/`cordon` practice, but don't expect to schedule
  much real workload on it.

## Authentication

The provider is configured to use Security Token authentication:

```hcl
provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = var.config_file_profile
  region              = var.region
}
```

Authenticate your CLI session before applying:

```sh
oci session authenticate --region uk-london-1
```

The profile used is controlled by `config_file_profile` (defaults to `DEFAULT` in `~/.oci/config`).
