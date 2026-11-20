module "avm_utl_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.10.0"

  enable_telemetry = var.enable_telemetry
  location         = var.location
  # Role names are resolved to IDs by this module (see data.azapi_resource_list.role_definitions), so
  # the utility only builds the bodies. A single instance serves every assignment this module creates;
  # each assignment's placement is set by its own parent_id.
  role_assignment_definition_lookup_enabled = false
  role_assignments                          = local.interface_role_assignments
}
