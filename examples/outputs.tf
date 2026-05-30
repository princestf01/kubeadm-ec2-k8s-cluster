
output "localos_public_cidr" {
  value = nonsensitive(data.localos_public_ip.my_ip.cidr)
}

output "localos_public_ip" {
  value = nonsensitive(data.localos_public_ip.my_ip.ip)
}
output "nodes_defult" {
  description = "Default nodes configuration."
  value       = module.nodes
}
output "kubeadm_token" {
  value = local.kubeadm_token
}