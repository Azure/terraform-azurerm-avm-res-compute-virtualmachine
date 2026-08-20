module "avm_utl_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  enable_telemetry = var.enable_telemetry
  # Role definitions are looked up by name against this scope. The scope only resolves built-in role
  # names to resource IDs; each assignment's own placement is set by its parent_id, so a single
  # instance serves every assignment this module creates.
  role_assignment_definition_scope = local.virtualmachine_resource_id
  role_assignments                 = local.interface_role_assignments
}
