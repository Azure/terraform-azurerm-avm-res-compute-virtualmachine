# Extension with protected settings (Windows)

This example deploys a Windows VM with two extensions from a single `extensions` map:

- a **Custom Script** extension whose `commandToExecute` is delivered exclusively through
  `protected_settings`, alongside a non-secret `settings` payload; and
- a **BGInfo** extension with public settings and no protected settings at all.

It is the regression scenario for extension protected settings. Azure never returns
`protectedSettings` on a read, so a secret the module silently fails to deliver cannot be
detected by an idempotency check - the deployment has to fail for the gap to be visible. Putting
`commandToExecute` only in `protected_settings` and leaving `failure_suppression_enabled = false`
turns a dropped secret into a failed apply.

The two extensions together cover both directions of the payload split:

- carrying a secret must not strip the non-sensitive properties that share the same `properties`
  object; and
- an extension that supplies no protected settings must still deploy from the same map.

The scale set module shipped precisely this bug ([#159][vmss159]) because no example exercised the
path, and had to add the equivalent coverage afterwards.

[vmss159]: https://github.com/Azure/terraform-azurerm-avm-res-compute-virtualmachinescaleset/issues/159
