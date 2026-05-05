# Linux VM from Existing Managed Disk (Attach Mode)

This example demonstrates creating a Linux VM by attaching an existing managed disk as the OS disk, using the `os_managed_disk_id` parameter.

This is useful for scenarios such as:

    - Restoring a VM from a backup (attaching a restored OS disk)
    - Disaster recovery (rebuilding a VM around preserved disks)
    - Migration from vendor-supplied VHD images (converting VHD to managed disk, then attaching)

It includes the following resources:

    - A managed disk created from a platform image (simulating a pre-existing OS disk)
    - A Linux VM that attaches the managed disk as its OS disk
    - A VNet with a subnet and NAT gateway for outbound connectivity

> **Note:** When using `os_managed_disk_id`, the module does not manage OS profile settings (admin credentials, computer name, custom data, patching configuration, etc.) since the OS is pre-configured on the existing disk.
