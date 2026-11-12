# Applying this empty configuration to a test state destroys everything in it, as terraform
# destroy would, and later runs can still check what Azure kept.
terraform {
  required_version = ">= 1.16, < 2.0"
}
