# These local variables are used to store common values that are referenced throughout the terraform code. This helps to avoid hardcoding values and makes it easier to update them in one place if needed.
locals {
  name          = "minecraft-server"
  instance_name = "${local.name}-ec2-instance"
  region        = "us-west-2"
  
  # The t4g.2xlarge instance type is a good choice for a modded Minecraft server as it provides a just enough CPU, memory, and network performance at a reasonable cost.
  # Example: running a fabric server with the Distant Horizons modpack requires a bunch of memory to generate and load the LOD chunks.
  # For a vanilla server with 2-4 players, a smaller instance type like t4g.small may be sufficient.
  instance_type = "t4g.2xlarge"

  vpc_cidr = "10.0.0.0/24"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  # The user data will run a simple bash script to print "Hello Terraform!" to the console when the EC2 instance is launched.
  # This is where you would put the commands to set up and start your Minecraft server.
  # For example, you could use user data to install Java, download the Minecraft server files from the S3 bucket, and start the server.
  # WIP: we will update the repo with examples of user_data bash scripts for setting up a Minecraft server in the future. Also automating server shutdown and backups using cron jobs and AWS CLI commands in the user data script.
  user_data = <<-EOT
    #!/bin/bash
    echo "Hello Terraform!"
  EOT

  tags = {
    Name      = local.name
    Terraform = true
  }
}

# The AWS provider is used to interact with the AWS services. We specify the region where we want to create our resources.
provider "aws" {
  region = local.region
}

# We use a data source to get the most recent Amazon Linux 2023 AMI that is compatible with ARM64 architecture. This AMI will be used to launch our EC2 instance.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^al2023-ami-2023.*-arm64"
}

# We use a data source to get the available availability zones in the specified region. This will be used to create subnets in different availability zones for high availability and fault tolerance.
data "aws_availability_zones" "available" {}



# A VPC is an isolated network to control rules of communication.
# This module is used to create a VPC with public and private subnets.
# The EC2 instance will be placed in a public subnet to allow it to receive a public IP and be reached from the internet.
# The private subnets can be used for other resources that should not be directly accessible from the internet, such as databases or application servers.
module "vpc" {
  # Click into this source link to see the full list of variables that can be used to customize the VPC and its subnets. For example, you can specify the number of public and private subnets, enable or disable NAT gateways, etc.
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr
  azs  = local.azs

  # learn more about cidrsubnet() here: https://developer.hashicorp.com/terraform/language/functions/cidrsubnet
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 8)]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = local.tags
}

# This S3 Bucket will hold server files and backups. e.g. world data, server.properties, and logs, modpacks, etc.
# It is up to the user to decide what files to store in the bucket and how to use it with the EC2 instance.
# Preferrably, you should create the S3 bucket before running this terraform code and place the correct bucket ARN in the IAM policy document below to allow the EC2 instance to interact with the S3 bucket.
/*
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  # The bucket name must be globally unique across all AWS accounts and regions. A common convention is to use the format: [project-name]-[environment]-[purpose].
  bucket = "${local.name}-dev-mcs-terraform-server-files"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }

  tags = local.tags
}
*/

# This IAM policy will be attached to the EC2 instance's IAM role to allow it to interact with the S3 bucket.
# You should have created an S3 bucket before running this terraform code. Be sure to replace <PLACEHOLDER_FOR_BUCKET_ARN> with the correct bucket ARN under "Resource" in the policy document.
module "iam_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "${local.instance_name}-s3-access-policy"
  path        = "/"
  description = "Terraform-generated policy to policy to allow EC2 instance to access S3 bucket for Minecraft server files."

  policy = <<-EOF
    {
	    "Version": "2012-10-17",
	    "Statement": [
		    {
			    "Effect": "Allow",
			    "Action": [
				    "s3:ListBucket",
				    "s3:GetObject",
				    "s3:GetBucketLocation",
				    "s3:PutObject",
				    "s3:PutObjectAcl",
				    "s3:DeleteObject"
			    ],
			  "Resource": [
          "<PLACEHOLDER_FOR_BUCKET_ARN>",
          "<PLACEHOLDER_FOR_BUCKET_ARN>/*"
			    ]
		    }
	    ]
    }
  EOF

  tags = local.tags
}

# A security group is used to control the inbound and outbound traffic to the EC2 instance.
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-sg"
  description = "Security group for Minecraft server EC2 instance."
  vpc_id      = module.vpc.vpc_id

   # The ingress rules allow SSH access and Minecraft client connections to the EC2 instance.
  ingress_with_cidr_blocks = [
    {
      # This rule allows SSH access to the EC2 instance. For diagnostics we allow the internet,
      # but you should restrict this to your IP or a known CIDR in production.
      type        = "ssh"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "${local.instance_name}-ssh-connection"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      # This rule allows Minecraft client connections to the EC2 instance.
      from_port   = 25565
      to_port     = 25565
      protocol    = "tcp"
      description = "${local.instance_name}-allow-minecraft-client-connections"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  
  # The egress rules allow all outbound traffic from the EC2 instance to the internet.
  # This is necessary for the EC2 instance to be able to download updates, interact with the S3 bucket, and allow players to connect to the Minecraft server.
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "${local.instance_name}-allow-all-outbound-traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.tags
}

# A key pair is used to securely connect to the EC2 instance via SSH.
# The private key will be downloaded to your local machine when you apply the terraform code, and you can use it to connect to the EC2 instance.
module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "${local.name}-key-pair"
  create_private_key = true
}

# An EC2 will host and run the actual server. Think of a virtual machine in the cloud.
# We also create a IAM role and attach the S3 access policy to allow the EC2 instance to interact with the S3 bucket.
module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = local.instance_name

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = local.instance_type
  availability_zone           = element(module.vpc.azs, 0)
  # Place the instance in a public subnet so it can receive a public IP and be reached from the internet.
  subnet_id                   = element(module.vpc.public_subnets, 0)
  create_security_group       = false
  vpc_security_group_ids      = [module.security_group.security_group_id]
  key_name                    = module.key_pair.key_pair_name
  user_data                   = local.user_data
  monitoring                  = true
  associate_public_ip_address = true

  create_iam_instance_profile = true
  iam_role_description        = "${local.instance_name}-role"
  iam_role_policies           = { S3Access = module.iam_policy.arn }

  tags = local.tags
}

