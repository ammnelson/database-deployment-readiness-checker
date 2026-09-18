module "networking" {
  source   = "./modules/networking"
  vpc_cidr = var.vpc_cidr
}

module "security" {
  source      = "./modules/security"
  vpc_id      = module.networking.vpc_id
  allowed_ips = var.allowed_ips
}

module "compute" {
  source            = "./modules/compute"
  subnet_id         = module.networking.public_subnet_ids[0]
  security_group_id = module.security.security_group_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  public_key_path   = var.public_key_path
}

module "serverless" {
  source      = "./modules/serverless"
  enable_sqs  = var.enable_sqs
  alert_email = var.alert_email
}
