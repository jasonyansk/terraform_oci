# Terraform for Oracle Cloud Infrastructure (OCI)

Reusable Terraform configuration to provision network infrastructure and compute instances on Oracle Cloud Infrastructure (OCI). Written for learning purposes, so it relies on the simplest possible setup: Security Token authentication and local state.

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
        └── app/                      # App layer: compute instances
```

### Layers

Infrastructure is split into two layers that are applied in order:

1. **`_platform`** — creates the Virtual Cloud Network (VCN), subnets, and Network Security Groups (NSGs). Its outputs are written to a local state file.
2. **`app`** — creates compute instances and reads the platform layer's subnet and NSG OCIDs from its local state via `terraform_remote_state`.

This keeps networking and compute in separate state files so each can be changed independently.



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