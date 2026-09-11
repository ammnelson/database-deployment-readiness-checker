output "ec2_public_ip" {
  description = "Public IP of the Jenkins build host"
  value       = module.compute.public_ip
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "jenkins_url" {
  value = "http://${module.compute.public_ip}:8080"
}
