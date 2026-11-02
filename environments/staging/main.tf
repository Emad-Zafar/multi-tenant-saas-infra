# Defining core resources for Staging environment

# Network Module
module "network" {
  source = "../../modules/network"

  project                 = var.project
  environment             = var.environment
  aws_region              = var.aws_region
  vpc_cidr_block          = var.vpc_cidr_block
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
}

# IAM Module (created before compute and data to provide role ARN)
# Note: S3 bucket ARN will be updated after data module creates the bucket
module "iam" {
  source = "../../modules/iam"

  project       = var.project
  environment   = var.environment
  aws_region    = var.aws_region
  s3_bucket_arn = "arn:aws:s3:::${var.s3_bucket_name}"

  create_app_user_access_key    = false
  create_devops_user_access_key = false
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  # Network configuration
  public_subnet_ids     = module.network.public_subnet_ids
  ec2_security_group_id = module.network.ec2_security_group_id

  # EC2 configuration
  instance_type = var.instance_type
  key_pair_name = var.key_pair_name
  # Note: public_key removed - using existing key pair via data source

  # Volume configuration
  root_volume_size      = 20
  root_volume_type      = "gp3"
  root_volume_encrypted = true

  # IAM instance profile
  iam_instance_profile_name = module.iam.ec2_instance_profile_name
}

# Data Module (RDS and S3)
module "data" {
  source = "../../modules/data"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  # Network configuration
  private_subnet_ids    = module.network.private_subnet_ids
  rds_security_group_id = module.network.rds_security_group_id

  # S3 configuration
  s3_bucket_name   = var.s3_bucket_name
  ec2_iam_role_arn = module.iam.ec2_iam_role_arn

  # RDS configuration
  db_instance_identifier   = var.db_instance_identifier
  db_name                  = var.db_name
  db_username              = var.db_username
  db_engine_version        = var.db_engine_version
  db_instance_class        = var.db_instance_class
  db_parameter_group_name  = var.db_parameter_group_name
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = 100
  skip_final_snapshot      = true
}

