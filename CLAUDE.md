# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Reusable Terraform configuration to provision network infrastructure and compute instances on Oracle Cloud
Infrastructure (OCI). Built for learning purposes, so it deliberately uses the simplest setup available:
Security Token authentication (no Vault/OIDC) and local state (no remote backend).

The `production/uk-london-1` environment's `app` layer specifically provisions a 3-node `kubeadm` Kubernetes
cluster (1 control-plane + 2 workers) — a CKA study lab, not a generic app-server pool. It's split across
OCI's two separate Always Free compute pools: 2 nodes on Ampere A1 (aarch64, 1 OCPU/6 GB each = 2 OCPU/12 GB
total, the full tenancy-wide A1 allowance as of the 2026-08-18 cut — see "Always Free sizing is fragile"
below) and 1 node on the AMD Micro pool (`VM.Standard.E2.1.Micro`, x86_64, a separate free allowance). See
README.md for the free-tier sizing table and the deploy/join walkthrough.

## Commands

There is no build/lint/test tooling in this repo (no CI config, Makefile, or test suite). Standard Terraform
workflow, run from inside the specific env directory you're changing (e.g.
`envs/production/oci/uk-london-1/_platform` or `.../app`):

```sh
terraform init
terraform validate
terraform plan
terraform apply
```

Authenticate before planning/applying — Security Token auth requires a live OCI CLI session:

```sh
oci session authenticate --region uk-london-1
```

The profile used comes from `config_file_profile` (defaults to `DEFAULT` in `~/.oci/config`).

To format all modules/envs consistently: `terraform fmt -recursive`.

## Architecture

### Two-layer state split, applied in order

Each region under `envs/` is split into two independently-initialized, independently-applied Terraform roots,
each with its own local state file:

1. **`_platform`** (`envs/production/oci/uk-london-1/_platform`) — creates the VCN, subnets, Internet Gateway,
   public route table, and NSGs. Must be applied first.
2. **`app`** (`envs/production/oci/uk-london-1/app`) — creates compute instances. Reads the platform layer's
   subnet/NSG OCIDs via `data.terraform_remote_state.platform` pointed at
   `../_platform/terraform.tfstate` (local backend, relative path — the two directories must stay siblings).

This split exists so networking and compute can be changed/applied independently without one plan touching
the other's resources. When adding a new region/environment, replicate this same `_platform` + `app` pair
under `envs/<env>/oci/<region>/`, not a single flat root.

### Subnet/NSG resolution in the app layer

`app/main.tf` resolves each instance's `subnet_id` and `nsg_ids` through a fallback chain (see `locals` block):
per-instance override (`instances[key].subnet_id`) → module-level override (`var.subnet_id`) → platform
remote-state output (`appsubnet` / `app_subnet`). The remote-state lookup keys (`"appsubnet"`,
`"app_subnet"`) are hardcoded and must match the corresponding keys in `_platform`'s `var.subnet_cidrs` and
`var.nsgs` maps — renaming a subnet or NSG key in one layer breaks the other layer's defaulting. These keys
still say "appsubnet"/"app_subnet" even though the subnet now carries a Kubernetes cluster, kept as-is
deliberately to avoid an unnecessary destroy/recreate of the VCN subnet, route table attachment, and NSG when
the cluster was introduced — only the NSG's rule list and the app layer's `instances` changed.

### Kubernetes node bootstrap (app layer)

Each entry in `app/variables.tf`'s `instances` map has a `role` (`"control-plane"` or `"worker"`) and an
optional static `private_ip`. `app/main.tf` renders `app/templates/k8s-node-init.sh.tftpl` per instance via
`templatefile()` and passes it in as `user_data_base64` (cloud-init). The template installs
containerd/kubeadm/kubelet/kubectl on every node; when `role == "control-plane"` it additionally runs
`kubeadm init` and applies the Flannel CNI. The control-plane's `private_ip` must be set in tfvars because
`--apiserver-advertise-address` has to be known before the instance exists (a static IP breaks the
chicken-and-egg problem of needing the instance's own address inside its own boot-time user-data). Workers
are deliberately **not** auto-joined by Terraform — the join token/CA hash only exist after the
control-plane's `kubeadm init` runs, and joining a fresh cluster is itself something worth practicing by hand
for the CKA exam. See README.md for the manual join step.

When editing `k8s-node-init.sh.tftpl`, remember it's processed by `templatefile()`: any literal `${...}` is
interpreted as Terraform interpolation (not a bash variable expansion) unless escaped as `$${...}`, and
`%{ if ... }` / `%{ endif }` are Terraform template directives, not shell syntax.

### Modules (`modules/oci/...`)

Generic, environment-agnostic building blocks consumed by the env layers via relative `source` paths
(`../../../../../modules/oci/...` from an env dir):

- **`networking/vcn`** — VCN + `for_each`-driven subnets + optional Internet Gateway/public route table.
  Subnets are a `map(object)` keyed by name; `is_public` subnets get attached to the public route table.
- **`security/nsg`** — one NSG plus `for_each`-driven ingress/egress security rules (list of objects, indexed
  by position). TCP rules use `destination_port_range`; ICMP rules use `icmp_type`; rule shape maps directly
  to `oci_core_network_security_group_security_rule`.
- **`compute/instance`** — one `oci_core_instance` plus optional `for_each`-driven additional block volumes
  (`additional_volumes` map) with attachments. Handles Linux vs Windows metadata differences via
  `local.is_windows` (SSH keys only injected for Linux).

When extending a module's variable shape (e.g. adding a field to `nsgs` rule objects), update the type in
both the module's `variables.tf` and the matching passthrough type in the env layer's `variables.tf`
(`_platform/variables.tf` mirrors `modules/oci/security/nsg`'s rule object types) — they are not shared/DRY,
so they drift independently if only one is edited.

### Instance shape/image architecture must match — this cluster mixes two

`app/terraform.tfvars` uses two different shapes on purpose: `VM.Standard.A1.Flex` (Ampere/ARM, aarch64) for
`k8s-control-plane`/`k8s-worker-1`, and `VM.Standard.E2.1.Micro` (AMD, x86_64) for `k8s-worker-2`. Each
needs an image OCID matching its own architecture — an x86_64 image won't boot on the A1 shape and vice
versa. This is why `instances[key]` has its own optional `source_image_id` (falls back to the top-level
`var.source_image_id`, which holds the aarch64 default): `k8s-worker-2` sets it explicitly to an x86_64
image OCID. There's no cross-check for this in Terraform; a mismatch surfaces as an OCI API error or a boot
failure, not a plan-time error.

### Always Free sizing is fragile — re-verify before resizing

Oracle cut the Always Free **Ampere A1** allowance in half tenancy-wide partway through 2026 (was 4 OCPU /
24 GB, now 2 OCPU / 12 GB — see [Oracle's Always Free docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)),
with enforcement starting 2026-08-18 and no real announcement beyond a docs edit. The two A1 nodes here
(`k8s-control-plane`, `k8s-worker-1`) are sized to use exactly that reduced allowance — 1 OCPU/6 GB each.
Going over it (another A1 instance, or bumping `ocpus`/`memory_in_gbs`) risks the excess A1 instances being
disabled and deleted per Oracle's documented behavior (or billed, on an upgraded/PAYG tenancy — reporting on
this was inconsistent). `k8s-worker-2` deliberately uses the *separate* AMD Micro Always Free pool
(`VM.Standard.E2.1.Micro`, up to 2 instances tenancy-wide) instead of a 3rd A1 instance, specifically to add
a node without spending any A1 quota. Given Oracle already cut this once without notice, re-check current
Always Free limits before changing instance counts/sizes rather than trusting the numbers in this file or
README.md to still be current.

### State and secrets are local, not committed

`*.tfstate*`, `*.tfvars`, and `.terraform.lock.hcl` are gitignored. `terraform.tfvars` in each env directory
holds the real compartment OCID, CIDR ranges, and SSH source IPs — never commit or print its contents back
into a PR/commit. State files contain real resource OCIDs and IPs; treat `terraform.tfstate*` the same way.
