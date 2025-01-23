provider "aws" {
  region  = "ap-south-1"
  profile = "a2"
}

variable "region" {
  type    = string
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"  # Define CIDR for the public subnet
  availability_zone = "ap-south-1a"  # Update with your preferred AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"  # Define CIDR for the private subnet
  availability_zone = "ap-south-1b"  # Update with your preferred AZ

  tags = {
    Name = "private-subnet"
  }
}

# Create an Internet Gateway for public access
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-internet-gateway"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private route table (no direct internet access)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

# Associate the private subnet with the private route table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# -------------------------------------------------------------------------------------

resource "aws_security_group" "allow_all_traffic" {
  name        = "allow-all-traffic"
  description = "Security group to allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.my_vpc.id  # Attach this to the VPC created earlier

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"]  # Open to all IP addresses
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-all-traffic"
  }
}

# -------------------------------------------------------------------------------------

# Create an AWS Service Discovery HTTP Namespace
resource "aws_service_discovery_http_namespace" "example" {
  name = "service-connect-demo-namespace"
}

# ECS Cluster with Service Connect Defaults
resource "aws_ecs_cluster" "example" {
  name = "service-connect-demo-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.example.arn
  }
}

# -------------------------------------------------------------------------------------

resource "aws_ecr_repository" "service_a_ecr_repository" {
  name = "service_a_ecr_repository"
  force_delete = true
}

output "service_a_ecr_repository_url" {
  value = aws_ecr_repository.service_a_ecr_repository.repository_url
}

resource "aws_ecr_repository" "service_b_ecr_repository" {
  name = "service_b_ecr_repository"
  force_delete = true
}

output "sservice_b_ecr_repository_url" {
  value = aws_ecr_repository.service_b_ecr_repository.repository_url
}

# -------------------------------------------------------------------------------------

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs_task_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_policy" {
  name   = "ecs_task_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# ECS Task Execution Role - For pulling images and logging
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Execution Role Policy
resource "aws_iam_policy" "ecs_execution_policy" {
  name   = "ecs_execution_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_execution_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_policy.arn
}

# -------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "servicea-td" {
  container_definitions    = jsonencode([
    {
      environment: [],
      environmentFiles: [],
      essential: true,
      image: "${aws_ecr_repository.service_a_ecr_repository.repository_url}:latest",
      logConfiguration: {
        logDriver: "awslogs",
        options: {
          awslogs-region: "${var.region}",
          awslogs-stream-prefix: "ecs",
          awslogs-group: "/ecs/servicea-lg",
          mode: "non-blocking",
          awslogs-create-group: "true",
          max-buffer-size: "25m"
        },
        secretOptions: []
      },
      mountPoints: [],
      name: "servicea",
      portMappings: [
        {
          appProtocol: "http",
          containerPort: 8080,
          hostPort: 8080,
          name: "servicea",
          protocol: "tcp"
        }
      ],
      systemControls: [],
      ulimits: [],
      volumesFrom: []
    }
  ])
  cpu                      = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  family                   = "servicea"
  ipc_mode                 = null
  memory                   = "2048"
  network_mode             = "awsvpc"
  pid_mode                 = null
  requires_compatibilities = ["FARGATE"]
  skip_destroy             = null
  tags                     = {}
  tags_all                 = {}
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  track_latest             = false
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}

resource "aws_ecs_task_definition" "serviceb-td" {
  container_definitions    = jsonencode([
    {
      environment: [],
      environmentFiles: [],
      essential: true,
      image: "${aws_ecr_repository.service_b_ecr_repository.repository_url}:latest",
      logConfiguration: {
        logDriver: "awslogs",
        options: {
          awslogs-region: "${var.region}",
          awslogs-stream-prefix: "ecs",
          awslogs-group: "/ecs/serviceb-lg",
          mode: "non-blocking",
          awslogs-create-group: "true",
          max-buffer-size: "25m"
        },
        secretOptions: []
      },
      mountPoints: [],
      name: "serviceb",
      portMappings: [
        {
          appProtocol: "http",
          containerPort: 8080,
          hostPort: 8080,
          name: "serviceb",
          protocol: "tcp"
        }
      ],
      systemControls: [],
      ulimits: [],
      volumesFrom: []
    }
  ])
  cpu                      = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  family                   = "serviceb"
  ipc_mode                 = null
  memory                   = "2048"
  network_mode             = "awsvpc"
  pid_mode                 = null
  requires_compatibilities = ["FARGATE"]
  skip_destroy             = null
  tags                     = {}
  tags_all                 = {}
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  track_latest             = false
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}

resource "aws_cloudwatch_log_group" "servicea-lg" {
  name              = "/ecs/servicea-lg"
  retention_in_days = 30 # Retains logs for 30 days
}

resource "aws_cloudwatch_log_group" "serviceb-lg" {
  name              = "/ecs/serviceb-lg"
  retention_in_days = 30 # Retains logs for 30 days
}

# -------------------------------------------------------------------------------------

resource "aws_ecs_service" "servicea" {
  availability_zone_rebalancing      = "ENABLED"
  cluster                            = aws_ecs_cluster.example.id
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 0
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  force_delete                       = null
  force_new_deployment               = null
  health_check_grace_period_seconds  = 0
  launch_type                        = "FARGATE"
  name                               = "servicea"
  platform_version                   = "LATEST"
  propagate_tags                     = "NONE"
  scheduling_strategy                = "REPLICA"
  tags                               = {}
  tags_all                           = {}
  task_definition                    = aws_ecs_task_definition.servicea-td.arn
  triggers                           = {}
  wait_for_steady_state              = null
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    assign_public_ip = true
    security_groups  = ["${aws_security_group.allow_all_traffic.id}"]
    subnets          = ["${aws_subnet.public_subnet.id}"]
  }

  service_connect_configuration {
    enabled = true
    namespace = aws_service_discovery_http_namespace.example.arn
  }
}

resource "aws_ecs_service" "serviceb" {
  availability_zone_rebalancing      = "ENABLED"
  cluster                            = aws_ecs_cluster.example.id
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 0
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  force_delete                       = null
  force_new_deployment               = null
  health_check_grace_period_seconds  = 0
  launch_type                        = "FARGATE"
  name                               = "serviceb"
  platform_version                   = "LATEST"
  propagate_tags                     = "NONE"
  scheduling_strategy                = "REPLICA"
  tags                               = {}
  tags_all                           = {}
  task_definition                    = aws_ecs_task_definition.serviceb-td.arn
  triggers                           = {}
  wait_for_steady_state              = null
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    security_groups  = ["${aws_security_group.allow_all_traffic.id}"]
    subnets          = ["${aws_subnet.private_subnet.id}"]
  }

  service_connect_configuration {
    enabled = true
    namespace = aws_service_discovery_http_namespace.example.arn
    service {
      client_alias{
        dns_name = "serviceb.service-connect-demo-namespace"
        port = 8080
      }
      port_name = "serviceb"
      discovery_name = "serviceb"      
    }
  }
}

# -------------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.${var.region}.ecr.api" # ECR API
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.private_subnet.id}"]
  security_group_ids = ["${aws_security_group.allow_all_traffic.id}"]

  private_dns_enabled = true
  tags = {
    Name = "ECR API VPC Endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_docker" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.${var.region}.ecr.dkr" # ECR Docker
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.private_subnet.id}"]
  security_group_ids = ["${aws_security_group.allow_all_traffic.id}"]

  private_dns_enabled = true
  tags = {
    Name = "ECR Docker VPC Endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3" # S3 Gateway
  vpc_endpoint_type = "Gateway"
  route_table_ids   = ["${aws_route_table.private_route_table.id}"]

  tags = {
    Name = "S3 Gateway VPC Endpoint"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.${var.region}.logs" # CloudWatch Logs
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["${aws_subnet.private_subnet.id}"]
  security_group_ids = ["${aws_security_group.allow_all_traffic.id}"]

  private_dns_enabled = true
  tags = {
    Name = "CloudWatch Logs VPC Endpoint"
  }
}

# -------------------------------------------------------------------------------------



# -------------------------------------------------------------------------------------



