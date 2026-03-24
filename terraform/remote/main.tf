module "remote_core" {
  source               = "./modules/ec2"
  cluster_name         = "bhargav-cluster-ecf-kaneki"
  region               = "us-east-2"
  ami_id               = "ami-00399ec92321828f5" # Amazon Linux 2 AMI for Ubuntu 20.04 for us-east-2
  instance_type        = "t2.micro"
  iam_instance_profile = ""
  ssh_key_pair_name    = "bhargav-ec2-runner-key"
  ssh_private_key_path = "../../keys/bhargav-ec2-runner-key.pem"
  prefix               = "bhargav"
  github_pat           = "TODO"
  github_user          = "Bhargav-Infracloud"
  license_file_path    = "/home/bhargav-ravuri/InfraCloud/Exostellar/license.InfraCloud_Exostellar.json"
}
