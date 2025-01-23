AWS_REGION=ap-south-1
AWS_PROFILE=a2
AWS_ACCOUNT_NUMBER=$(shell aws sts get-caller-identity --query "Account" --output text --profile ${AWS_PROFILE})

deploy-vpc:
	terraform apply \
	-target="aws_vpc.my_vpc" \
	-target="aws_subnet.public_subnet" \
	-target="aws_subnet.private_subnet" \
	-target="aws_internet_gateway.my_igw" \
	-target="aws_route_table.public_route_table" \
	-target="aws_route_table_association.public_subnet_association" \
	-target="aws_route_table.private_route_table" \
	-target="aws_route_table_association.private_subnet_association" \
	-var="region=${AWS_REGION}" \
	--auto-approve

deploy-security-group:
	terraform apply -target="aws_security_group.allow_all_traffic" -var="region=${AWS_REGION}" --auto-approve

deploy-ecs-cluster:
	terraform apply \
	-target="aws_service_discovery_http_namespace.example" \
	-target="aws_ecs_cluster.example" \
	-var="region=${AWS_REGION}" \
	--auto-approve

deploy-ecr-images:
	terraform apply -target="aws_ecr_repository.service_a_ecr_repository" -var="region=${AWS_REGION}" --auto-approve
	aws ecr get-login-password --region ap-south-1 --profile ${AWS_PROFILE} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_REGION}.amazonaws.com
	docker build -t service_a_ecr_repository app/ServiceA
	docker tag service_a_ecr_repository:latest ${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_REGION}.amazonaws.com/service_a_ecr_repository:latest
	docker push ${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_REGION}.amazonaws.com/service_a_ecr_repository:latest
	terraform apply -target="aws_ecr_repository.service_b_ecr_repository" -var="region=${AWS_REGION}" --auto-approve
	aws ecr get-login-password --region ap-south-1 --profile ${AWS_PROFILE} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_REGION}.amazonaws.com
	docker build -t service_b_ecr_repository app/ServiceB
	docker tag service_b_ecr_repository:latest ${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_REGION}.amazonaws.com/service_b_ecr_repository:latest
	docker push ${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_REGION}.amazonaws.com/service_b_ecr_repository:latest

deploy-iam-roles:
	terraform apply \
	-target="aws_iam_role.ecs_task_role" \
	-target="aws_iam_policy.ecs_task_policy" \
	-target="aws_iam_role_policy_attachment.ecs_task_policy_attach" \
	-target="aws_iam_role.ecs_task_execution_role" \
	-target="aws_iam_policy.ecs_execution_policy" \
	-target="aws_iam_role_policy_attachment.ecs_execution_policy_attach" \
	-var="region=${AWS_REGION}" \
	--auto-approve

deploy-task-definitions:
	terraform apply \
	-target="aws_ecs_task_definition.servicea-td" \
	-target="aws_ecs_task_definition.serviceb-td" \
	-target="aws_cloudwatch_log_group.servicea-lg" \
	-target="aws_cloudwatch_log_group.serviceb-lg" \
	-var="region=${AWS_REGION}" \
	--auto-approve

deploy-ecs-services:
	terraform apply \
	-target="aws_ecs_service.servicea" \
	-target="aws_ecs_service.serviceb" \
	-var="region=${AWS_REGION}" \
	--auto-approve

deploy-private-links:
	terraform apply \
	-target="aws_vpc_endpoint.ecr_api" \
	-target="aws_vpc_endpoint.ecr_docker" \
	-target="aws_vpc_endpoint.s3" \
	-target="aws_vpc_endpoint.cloudwatch_logs" \
	-var="region=${AWS_REGION}" \
	--auto-approve

destroy:
	terraform destory -var="region=${AWS_REGION}" --auto-approve

