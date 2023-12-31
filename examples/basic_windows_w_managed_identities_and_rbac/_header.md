# Simple Windows VM with managed identities and role assignments

This example demonstrates the creation of a simple Windows Server 2022 VM with the following features:

    - a single private IPv4 address
    - a single default OS 128gb OS disk
    - a system assigned managed identity
    - a user assigned managed identity
    - a role assignment giving the system assigned managed identity Key Vault Secrets Officer permissions on the key vault
    - a role assignment giving the deployment user Virtual Machine Contributor permissions on the deployed virtual machine
    - an autogenerated password that is stored as a secret in the key vault resource.
    - an optional bastion resource that can be deployed by uncommenting the bastion elements in the example

It includes the following resources in addition to the VM resource:

    - A vnet with two subnets
    - A keyvault for storing the login secrets
    - A user assigned managed identity
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.
