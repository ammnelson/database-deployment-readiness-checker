variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "public_key_path" {
  type = string
}

# Ubuntu 24.04 AMI looked up at plan time - no hardcoded AMI ids
data "aws_ssm_parameter" "ubuntu_2404" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "build_host" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.public_key_path))
}

# Instance profile: CloudWatch agent permissions now; the scoped
# Lambda deploy policy gets added in Phase 3 once the functions exist
resource "aws_iam_role" "build_host" {
  name = "ddrc-module5-build-host"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.build_host.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "build_host" {
  name = "ddrc-module5-build-host"
  role = aws_iam_role.build_host.name
}

resource "aws_instance" "build_host" {
  ami                    = data.aws_ssm_parameter.ubuntu_2404.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.build_host.key_name
  iam_instance_profile   = aws_iam_instance_profile.build_host.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "ddrc-module5-build-host" }
}

output "public_ip" {
  value = aws_instance.build_host.public_ip
}

output "iam_role_name" {
  value = aws_iam_role.build_host.name
}
