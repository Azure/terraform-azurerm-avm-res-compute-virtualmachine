package Azure_Proactive_Resiliency_Library_v2
import rego.v1
# Both rules read the SKU from the OS disk. This example attaches a disk the caller already owns,
# and a disk's SKU belongs to the disk rather than to the machine, so the module omits the property
# in attach mode exactly as the azurerm provider did. The second rule is the AzAPI counterpart of
# the first and has no azurerm equivalent, which is why it only appears once the machine moves to
# AzAPI. The disk this example attaches is Premium_LRS and does satisfy the intent of both.
exception contains rules if {
  rules = ["mission_critical_virtual_machine_should_use_premium_or_ultra_disks", "virtual_machines_should_use_managed_disks"]
}
