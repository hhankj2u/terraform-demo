provider "aws" {
  region = var.aws_region
}

locals {
  lambda_name         = "calculate-weekdays"
  source_path         = "../src/CalculateWeekdaysFunction"
  lambda_package_name = "CalculateWeekdaysFunction-${formatdate("YYYYMMDD", timestamp())}"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role" {
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
  name               = "lambda-trigger"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_execution" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "this" {
  vpc_id = module.vpc.vpc_id
  name   = "${module.vpc.name}-sg"

  ingress {
    protocol  = "tcp"
    from_port = 55555
    to_port   = 55555
    self      = true
    description = "allow tcp connection on port 55555"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.private_subnets
    description = "allow from all"
  }

  lifecycle {
    create_before_destroy = true
  }

  description = "security group for vpc"
}


####################################################
# Package dotnet project
####################################################
resource "null_resource" "this" {
  provisioner "local-exec" {
    command = "cd ${local.source_path} && dotnet lambda package -o ${local.lambda_package_name}"
  }
  triggers = {
    always_run = timestamp()
  }
}

####################################################
# Lambda Function (deploying existing package from local)
####################################################
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "3.3.1"

  function_name = local.lambda_name
  description   = "Calculate weekdays between two dates"
  handler       = "CalculateWeekdaysFunction::CalculateWeekdaysFunction.Function::FunctionHandler"
  runtime       = "dotnet6"

  create_role = false
  lambda_role = aws_iam_role.iam_role.arn

  create_package         = false
  local_existing_package = "${local.source_path}/${local.lambda_package_name}.zip"
  source_path            = "../src/CalculateWeekdaysFunction"

  vpc_subnet_ids                = module.vpc.private_subnets
  vpc_security_group_ids        = [aws_security_group.this.id]
  attach_cloudwatch_logs_policy = false

  create_lambda_function_url = true
  authorization_type         = "NONE"

  memory_size = 128
  timeout     = 3

  tags = {
    Name = local.lambda_name
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = var.private_subnets
}
