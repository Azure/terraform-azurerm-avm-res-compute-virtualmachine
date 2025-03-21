# Simple Windows VM with gallery application

This example demonstrates the creation of a simple Windows Server 2022 VM with run command examples with the following features:

    - a single private NIC with multiple IP configurations
    - a single default OS 128gb OS disk
    - a role assignment giving the deployment user Key Vault Secrets Officer permissions on the key vault
    - an autogenerated password that is stored as a secret in the key vault resource.
    - an optional bastion resource that can be deployed by uncommenting the bastion elements in the example
    - multiple run command examples. Note that the run command secret values have been separated into a separate input to allow for the use of for_each on the run command resource. 

It includes the following resources in addition to the VM resource:

    - A vnet with three subnets 
    - A keyvault for storing the login secrets and disk encryption key
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.
  
