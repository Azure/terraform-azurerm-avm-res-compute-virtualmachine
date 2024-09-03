# Ubuntu VM with a number of common VM features

This example demonstrates the creation of a simple Ubuntu VM with the following features:  

**Note: This configuration example shows the use of an auto-generated password for Linux. SSH keys are generally preferred for linux, but this example is included to test the auto-gen password scenarion on linux.

    - a single private IPv4 address
    - an auto-generated password for an admin user named azureuser
    - password authentication enabled
    - a default OS 128gb OS disk 
    - deploys into a randomly selected region

It includes the following resources in addition to the VM resource:

    - A Vnet with two subnets
    - A keyvault for storing the login secrets
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.
