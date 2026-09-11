variable "vpc_id" {
  type = string
}

variable "allowed_ips" {
  type = list(string)
}

resource "aws_security_group" "build_host" {
  name        = "ddrc-module5-build-host"
  description = "Build host - SSH and Jenkins from trusted IPs only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from trusted IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  ingress {
    description = "Jenkins UI from trusted IPs"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ddrc-module5-build-host-sg" }
}

output "security_group_id" {
  value = aws_security_group.build_host.id
}
