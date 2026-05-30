
output "node_hostnames" {
  description = "List of node hostnames (keys from var.nodes)."
  value       = [for k in keys(var.nodes) : k]
}

output "node_private_ip" {
  description = "Map of node private IP addresses."
  value       = { for k, v in aws_instance.ec2 : k => v.private_ip }
}

output "node_public_ip" {
  description = "Map of node public IP addresses if available "
  value       = { for k, v in aws_instance.ec2 : k => v.public_ip if v.public_ip != null }
}

output "security_group_ids" {
  description = "Map of security groups ids"
  value       = { for k, v in aws_security_group.sg : k => v.id }
}