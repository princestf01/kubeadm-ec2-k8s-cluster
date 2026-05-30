
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}
output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.vpc.arn
}
output "vpc_cidr_block" {
  description = "vpc cidr range"
  value = aws_vpc.vpc.cidr_block
}
output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = { for key, value in aws_subnet.subnet : key => value.id }
}

output "subnet_arns" {
  description = "Map of subnet ARNs"
  value       = { for key, value in aws_subnet.subnet : key => value.arn }
}

output "subnet_cidrs" {
  description = "Map of subnet cidr rangers"
  value = { for key, value in aws_subnet.subnet : key => value.cidr_block }
}
