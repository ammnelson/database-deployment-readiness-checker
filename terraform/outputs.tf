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

output "api_endpoint" {
  description = "Live DDRC validation endpoint"
  value       = "${module.serverless.api_endpoint}/validate"
}

output "queue_url" {
  value = module.serverless.queue_url
}

output "dlq_url" {
  value = module.serverless.dlq_url
}

output "results_table" {
  value = module.serverless.table_name
}
