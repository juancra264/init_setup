#!/bin/bash
# Create a Custom Role
pveum role add TerraformRole -privs "VM.Allocate VM.Audit VM.Clone VM.Console VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify Sys.PowerMgmt"

# Create a Group for Terrform Users
pveum group add terraform-prov --comment "Terraform Provisioner Group"

# Grant the group permissions on the root path with role TerraformRole
pveum acl modify / -group terraform-prov -role TerraformRole

# Create the dedicated Terraform user
pveum user add terraform-prov@pve --comment "Terraform Provisioner"

# Add the user to the group
pveum user modify terraform-prov@pve -group terraform-prov

# Generate the API Token
pveum user token add terraform-prov@pve provider-token --privsep 0
