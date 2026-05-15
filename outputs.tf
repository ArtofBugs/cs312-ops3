output "minecraft_node_public_ip" {
  description = "Public IP of the Minecraft node"
  value       = aws_instance.ops3_minecraft_node.public_ip
}

output "minecraft_node_private_ip" {
  description = "Private IP of the Minecraft node, used in the Ansible inventory"
  value       = aws_instance.ops3_minecraft_node.private_ip
}

output "vpc_id" {
  description = "ID of the provisioned VPC"
  value       = aws_vpc.ops3.id
}
