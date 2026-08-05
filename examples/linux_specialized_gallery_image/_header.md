# Linux VM from a Specialized Azure Compute Gallery Image

This example demonstrates deploying a Linux VM from a **specialized** Azure Compute Gallery image.

Specialized images cannot be deployed through `source_image_resource_id`. The `azurerm` provider always sends an `OSProfile` alongside a source image, and Azure rejects that for a specialized image with:

```text
InvalidParameter: Parameter OSProfile is not allowed with a specialized image.
```

The provider only omits the `OSProfile` when `os_managed_disk_id` is set, and that argument is mutually exclusive with both `source_image_id` and `source_image_reference`. See [hashicorp/terraform-provider-azurerm#7772](https://github.com/hashicorp/terraform-provider-azurerm/issues/7772).

The supported pattern is therefore to materialize the gallery image version into a managed disk with `azurerm_managed_disk`, then attach that disk using `os_managed_disk_id` and `os_disk_attach_mode = true`.

It includes the following resources:

    - A managed disk, snapshot, gallery, and specialized image version to produce a specialized image to deploy from
    - A managed disk created from the specialized image version
    - A Linux VM that attaches that managed disk as its OS disk
    - A VNet with a subnet and NAT gateway for outbound connectivity

> **Note:** Credentials must already exist inside the specialized image. In attach mode the module does not manage OS profile settings (admin credentials, computer name, custom data, patching configuration, etc.).

> **Note:** Each VM needs its own managed disk, so this pattern does not scale in the same way as deploying many VMs from a single generalized image.
