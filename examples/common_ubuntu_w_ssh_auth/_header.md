# Ubuntu VM with a number of common VM features

This example demonstrates the creation of a simple Ubuntu VM with the following features:

    - a single private IPv4 address
    - an user provided SSH key for an admin user named azureuser
    - password authentication disabled
    - a default OS 128gb OS disk encrypted with a disk encryption set
    - deploys into a randomly selected region
    - An additional data disk encrypted with a disk encryption set
    - A User Assigned and System Assigned Managed identity Configured
    - Role Assignment on the individual resource
    - Role Assignment giving the System Assigned Managed Identity access to the key vault keys

It includes the following resources in addition to the VM resource:

    - A Vnet with two subnets
    - A keyvault for storing the login secrets
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.
