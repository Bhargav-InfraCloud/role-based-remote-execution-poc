module "runner_core" {
  source       = "./modules/helm"
  cluster_name = "bhargav-cluster-ecf-kaneki"
  aws_region   = "us-east-2"
  namespace    = "runner"
  prefix       = "bhargav"
}
