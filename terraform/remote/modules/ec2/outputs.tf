output "instance_id" {
  value = aws_instance.remote.id
}

output "public_ip" {
  value = aws_instance.remote.public_ip
}
