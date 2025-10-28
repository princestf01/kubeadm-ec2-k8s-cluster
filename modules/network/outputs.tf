
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}
output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.vpc.arn
}
output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = { for key, value in aws_subnet.subnet : key => value.id }
}

output "subnet_arns" {
  description = "Map of subnet ARNs"
  value       = { for key, value in aws_subnet.subnet : key => value.arn }
}
