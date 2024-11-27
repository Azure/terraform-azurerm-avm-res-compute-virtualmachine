# Default

This example demonstrates the creation of a simple Ubuntu VM with the following features using the v3 version of the AzureRM provider:

    - a single private IPv4 address
    - an auto-generated SSH key for an admin user named azureuser
    - password authentication disabled
    - a single default OS 128gb OS disk
    - deploys into a randomly selected region

It includes the following resources in addition to the VM resource:

    - A Vnet with two subnets
    - A keyvault for storing the login secrets
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.
