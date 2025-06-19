# Include all settings from the root Terragrunt configuration file
include {
  path = find_in_parent_folders("root.hcl")
  merge_strategy = "deep"
}

locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  proj    = read_terragrunt_config(find_in_parent_folders("proj.hcl"))
  region  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract variables
  # environment = local.env.locals.env_name
  account_id  = local.account.locals.account_id

  identifier = local.env.locals.env_name

  aws_region = local.region.locals.aws_region

  tags = merge(local.env.locals.environment_tags, local.proj.locals.project_tags)

}

# Use VPC as a dependency to get VPC ID and CIDR
dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id = "vpc-12345678"
    vpc_cidr = "10.0.0.0/16"
    public_subnets = ["subnet-12345678"]
  }
}

terraform {
  source = "Mat0ps/Playground-base/cloudflare/cloudflare-tunnel-warp"
}

inputs = {
  # Cloudflare configurations
  cloudflare_account_id       = local.proj.locals.cloudflare.cloudflare_account_id
  cloudflare_token_secret_arn = local.proj.locals.cloudflare.cloudflare_token_secret_arn
  zone_id                     = local.proj.locals.cloudflare.zone_id
  domain                      = local.domain
  team_name                   = "team"
  vpc_id                      = dependency.vpc.outputs.vpc_id
  vpc_cidr                    = dependency.vpc.outputs.vpc_cidr
  subnet_id                   = dependency.vpc.outputs.public_subnets[0]
  instance_type               = "t3.micro"
  identifier                  = "${local.identifier}-routing"
  aws_region                  = local.aws_region
  tags                        = local.tags
  
  # Name configurations
  tunnel_name                 = "${local.identifier}-cloudflare-tunnel-routing"
  tunnel_token_secret_name    = "${local.identifier}-cloudflare-tunnel-routing-token"
  security_group_name         = "${local.identifier}-cloudflare-routing-sg"
  key_pair_name               = "${local.identifier}-cloudflare-routing-key"
  iam_role_name               = "${local.identifier}-cloudflare-routing-role"
  iam_policy_name             = "${local.identifier}-cloudflare-routing-policy"
  iam_instance_profile_name   = "${local.identifier}-cloudflare-routing-profile"
  instance_name               = "${local.identifier}-cloudflare-routing-host"
  private_key_secret_name     = "${local.identifier}-cloudflare-routing/private-key"
}  


