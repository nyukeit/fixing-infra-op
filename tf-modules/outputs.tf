# Output of Public IPs

output "public_ips" {

  value = aws_instance.infra-op-ec2[*].public_ip

}

output "private_ips" {
  value = aws_instance.infra-op-ec2[*].private_ip
}
