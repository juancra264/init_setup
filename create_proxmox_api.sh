#!/bin/bash
# Create a Custom Role
pveum role add TerraformRole -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify Sys.PowerMgmt"

# Create the dedicated Terraform user
pveum user add terraform-prov@pve --comment "Terraform Provisioner"

# Grant the user permissions on the root path
pveum acl modify / -user terraform-prov@pve -role TerraformRole

# Generate the API Token
pveum user token add terraform-prov@pve provider-token --privsep 0

