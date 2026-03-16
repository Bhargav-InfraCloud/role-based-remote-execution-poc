# Core remote EC2 infrastructure module.
provider "aws" {
  region = var.region
}

# Create a VPC.
resource "aws_vpc" "this" {
  # CIDR block is large to allow for future expansion if needed.
  cidr_block = "10.0.0.0/16"
  # Enable DNS support and hostnames for EKS cluster access.
  enable_dns_support = true
  # Enable DNS hostnames to allow the EC2 instance to resolve cluster endpoints and other AWS services.
  enable_dns_hostnames = true

  # Tags for identifying resources.
  tags = {
    Name = "${var.prefix}-remote-vpc"
  }
}

# Create a public subnet.
resource "aws_subnet" "public" {
  # Associate the subnet with the VPC created above.
  vpc_id = aws_vpc.this.id
  # CIDR block is a subset of the VPC's CIDR block, allowing for future private subnets if needed.
  cidr_block = "10.0.1.0/24"
  # Enable auto-assign public IPs for instances launched in this subnet, which is necessary for SSH access and EKS
  # cluster communication.
  map_public_ip_on_launch = true
  # Select the first available AZ in the region for simplicity.
  availability_zone = data.aws_availability_zones.available.names[0]

  # Tags for identifying resources.
  tags = {
    Name = "${var.prefix}-remote-public-subnet"
  }
}

# Get the list of available availability zones in the region to select one for the subnet. This ensures the subnet is
# created in a valid AZ and allows for future expansion to multiple AZs if needed.
data "aws_availability_zones" "available" {}

# Create an internet gateway
resource "aws_internet_gateway" "this" {
  # Associate the internet gateway with the VPC created above to allow instances in the public subnet to access the
  # internet.
  vpc_id = aws_vpc.this.id

  # Tags for identifying resources.
  tags = {
    Name = "${var.prefix}-remote-igw"
  }
}

# Create a route table.
resource "aws_route_table" "public" {
  # Associate the route table with the VPC created above.
  vpc_id = aws_vpc.this.id
  # Add a default route to the internet gateway to allow instances in the public subnet to access the internet, which is
  # necessary for SSH access and EKS cluster communication.
  route {
    # The CIDR block for all traffic.
    cidr_block = "0.0.0.0/0"
    # The ID of the internet gateway created above to route traffic to the internet.
    gateway_id = aws_internet_gateway.this.id
  }

  # Tags for identifying resources.
  tags = {
    Name = "${var.prefix}-remote-public-rt"
  }
}

# Associate subnet with route table.
resource "aws_route_table_association" "public" {
  # The ID of the subnet created above to associate with the route table.
  subnet_id = aws_subnet.public.id
  # The ID of the route table created above to associate with the subnet.
  route_table_id = aws_route_table.public.id
}

# Create an IAM role for the EC2 instance with a trust policy that allows EC2 to assume the role. This role will be used
# to grant the EC2 instance permissions to interact with the EKS cluster and other AWS services as needed for cluster
# management and troubleshooting.
resource "aws_iam_role" "ec2_instance_role" {
  # The name of the IAM role, which includes the prefix variable for easy identification and to avoid naming conflicts.
  name = "${var.prefix}-remote-ec2-role"

  # The trust policy that allows EC2 to assume this role. This is necessary for the EC2 instance to be able to use the
  # permissions granted by this role when it is launched.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      # The effect of the policy, which is to allow EC2 to assume this role.
      Effect = "Allow"
      # The principal that is allowed to assume this role, which in this case is the EC2 service. This allows EC2
      # instances to assume this role and use the permissions granted by it.
      Principal = { Service = "ec2.amazonaws.com" }
      # The action that allows EC2 to assume the role, which is required for the EC2 instance to use the permissions
      # granted by this role.
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach least-privilege policy for the remote EC2 instance.
resource "aws_iam_policy" "minimal_policy" {
  # The name of the IAM policy, which includes the prefix variable for easy identification and to avoid naming
  # conflicts.
  name        = "${var.prefix}-minimal-policy"
  description = "Allow minimal access for remote instance."

  # The policy document grants only the permissions needed for the EC2 instance to manage EKS and related AWS resources.
  # This follows the principle of least privilege.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs",
          "eks:DescribeCluster",
          "iam:AttachRolePolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:CreatePolicy",
          "iam:CreateRole",
          "iam:DeleteOpenIDConnectProvider",
          "iam:DeletePolicy",
          "iam:DeleteRole",
          "iam:DetachRolePolicy",
          "iam:GetOpenIDConnectProvider",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:TagOpenIDConnectProvider",
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the minimal policy to allow the EC2 instance to manage EKS and related AWS resources with least privilege.
resource "aws_iam_role_policy_attachment" "minimal_policy_attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.minimal_policy.arn
}

# Attach the SSM policy to allow secure remote management of the EC2 instance using AWS Systems Manager.
resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# # Create an instance profile for the EC2 instance to allow it to use the IAM role created above. This is necessary for
# # the EC2 instance to be able to assume the role and use the permissions granted by it when it is launched.
# resource "aws_iam_instance_profile" "ec2_instance_profile" {
#   name = "${var.prefix}-remote-ec2-profile"
#   role = aws_iam_role.ec2_instance_role.name
# }

# Security group allowing SSH.
resource "aws_security_group" "ssh" {
  name        = "${var.prefix}-remote-ssh"
  description = "Allow SSH"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-remote-ssh"
  }
}

# Create the EC2 instance in the public subnet with the IAM instance profile attached to allow it to assume the role and
# use the permissions granted by it. The instance will have a public IP address for SSH access and EKS cluster
# communication.
resource "aws_instance" "remote" {
  ami           = var.ami_id
  instance_type = var.instance_type
  # iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_pair_name
  tags = {
    Name = "${var.prefix}-remote-instance"
  }
}

# Grant the EC2 instance access to the EKS cluster by creating an access entry and associating it with the
# AmazonEKSClusterAdminPolicy. This allows the EC2 instance to have admin access to the EKS cluster for management and
# troubleshooting purposes.
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.ec2_instance_role.arn
  type          = "STANDARD"
}

# Associate the access entry with the AmazonEKSClusterAdminPolicy to grant admin permissions to the EC2 instance for the
# EKS cluster. This allows the EC2 instance to perform administrative tasks on the EKS cluster, such as managing nodes,
# deploying applications, and troubleshooting cluster issues.
resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.ec2_instance_role.arn
  # Use the AmazonEKSClusterAdminPolicy to grant full admin access to the EKS cluster. This is necessary for the EC2
  # instance to be able to manage the cluster effectively. In a production environment, you may want to create a custom
  # policy with more limited permissions based on the principle of least privilege.
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Run commands inside the instance to set up the environment.
resource "null_resource" "provision" {
  depends_on = [aws_instance.remote]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.remote.public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      # Package management and utilities
      "sudo apt update -y",
      "sudo apt upgrade -y",
      "sudo apt autoremove -y",
      "sudo apt install -y make tree",

      # Install AWS CLI v2, if not already installed.
      "if ! command -v aws >/dev/null; then",
      "  curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "  unzip awscliv2.zip",
      "  sudo ./aws/install",
      "fi",

      # Install kubectl.
      "sudo curl -o /usr/local/bin/kubectl https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl",
      "sudo chmod +x /usr/local/bin/kubectl",

      # Configure AWS CLI access.
      "aws sts get-caller-identity | cat",
      "aws eks update-kubeconfig --name \"${var.cluster_name}\" --region \"${var.region}\"",

      # Install Terraform CLI.
      "sudo apt update -y",
      "sudo apt install -y unzip wget",
      "wget https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip",
      "unzip terraform_1.7.5_linux_amd64.zip",
      "sudo mv terraform /usr/local/bin/",
    ]
  }
}
