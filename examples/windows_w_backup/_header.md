# Windows with backup

This example demonstrates a Windows virtual machine configured with Azure Backup protection. It showcases the integration between the AVM compute module and Azure Recovery Services for automated backup functionality. It contains the following configuration:
    - Azure Backup configuration with daily backup schedule

It includes the following resources in addition to the VM resource:

    - Two resource groups (one for VM resources, one for backup infrastructure)
    - A VNet with two subnets
    - A user-assigned managed identity for additional identity management
    - A Recovery Services Vault with system-assigned managed identity
    - A backup policy configured for daily backups with 10-day retention
    - Automatic VM SKU selection based on performance requirements (2 vCPUs with premium storage support)


