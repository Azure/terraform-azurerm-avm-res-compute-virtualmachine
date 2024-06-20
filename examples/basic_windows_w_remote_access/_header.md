# Windows with remote access and winRM

This example demonstrates the creation of a simple Windows VM with the following features:

    - how to add Windows SSH and WinRMs (on an alternate port)
    - connect using the different protocols to execute a command
    - a single private IPv4 address
    - an auto-generated password for an admin user named azureuser
    - a single default OS 128gb OS disk
    - deploys into a randomly selected region
    - winRM enabled and listener configured to https
    - keyvault configured to allow the vm to pull the certificate into the local certificate store
    - a user assigned managed identity is attached to the VM and used to pull the renewed certificates
    - a scheduled task that will monitor if the winrm certificate must be updated (not production ready. Welcoming PR for better production support.)
    - connect with winRM on the https port to display the local directory.

It includes the following resources in addition to the VM resource:

    - A Vnet with two subnets
    - A keyvault for storing the login secrets and winrm certificate
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.

