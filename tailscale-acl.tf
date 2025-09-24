resource "tailscale_acl" "main" {
  acl = file("${path.module}/tailscale-acl.json")
}

