# tf-k8s
Terraform Kubernetes module

# Usage

This module requires the [etcd
module](https://github.com/kalbasit/tf-etcd). For the `discovery_url`,
you must use the same one you used for the etcd cluster.

This module assumes you are using a VPC with public/private subnets.
[tf-vpc](https://github.com/kalbasit/tf-vpc) provides such setup. It
also requires a bastion running on the public subnet with access to the
private subnet. [tf-vpc](https://github.com/kalbasit/tf-vpc) also
provides this requirement.

```hcl
module "k8s_us-east-1-staging" {
  source = "github.com/kalbasit/tf-k8s"

  /** GLOBAL **/
  env           = "staging"
  discovery_url = "https://discovery.etcd.io/d3c6482aeb0154d904f3ca44ce986610"
  bastion_host  = "bastion.corp.example.com"

  /** MASTER **/
  master_ami             = "ami-6d138f7a"
  master_aws_key_name    = "ec2-key-name"
  master_aws_private_key = "${file("keys/id_rsa")}"

  master_subnet_ids = ["subnet-0731c4fa"]

  master_sgs_ids = [
    "${module.sgs.out-pub}",
    "${module.sgs.https-pub}",
    "${module.sgs.in-self}",
  ]

  master_azs = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1d",
    "us-east-1e",
  ]

  /** WORKER **/
  minion_ami             = "ami-6d138f7a"
  minion_aws_key_name    = "ec2-key-name"

  minion_subnet_ids = ["subnet-b73bc4f5"]

  minion_sgs_ids = [
    "${module.sgs.out-pub}",
    "${module.sgs.in-self}",
  ]

  minion_azs = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1d",
    "us-east-1e",
  ]
}
```

# Module input variables

- `name` The name of the cluster
- `env` The environment of the cluster
- `discovery_url` The discovery URL for etcd
- `bastion_sg_id` The security group of the bastion
- `bastion_host` The bastion HOST for the SSH connection
- `bootkube_repo` The bootkube docker repository
- `bootkube_version` The bootkube docker image tag
- `kubelet_repo` The kubelet docker repository
- `kubelet_version` The kubelet docker image tag
- `kubelet_cluster_dns` IP address for a cluster DNS server
- `asset_path` The path to the kubernetes asset path
- `master_ami` The AMI for the master nodes
- `master_aws_key_name` The AWS key name for the master nodes
- `master_aws_private_key` Content of the private key to use when connecting to the masters
- `master_azs` A list of Availability zones in the region
- `master_subnet_ids` A list of subnet ids for the master nodes. Must be public subnet.
- `master_instance_type` The instance type for the master nodes
- `master_node_count` The number of master nodes to bring up.
- `minion_ami` The AMI for the minion nodes
- `minion_aws_key_name` The AWS key name for the minion nodes
- `minion_azs` A list of Availability zones in the region
- `minion_subnet_ids` A list of subnet ids for the minion nodes. Must be public subnet.
- `minion_instance_type` The instance type for the minion nodes
- `minion_scaling_group_min_size` The minimum size of the minion scaling group
- `minion_scaling_group_max_size` The maximum size of the minion scaling group
- `minion_scale_up_adjustment` The scaling adjustment for scaling up
- `minion_scale_up_cooldown` The scaling cooldown for scaling up
- `minion_scale_down_adjustment` The scaling adjustment for scaling down
- `minion_scale_down_cooldown` The scaling cooldown for scaling down
- `minion_scaling_mem_lower_avg_threshold` The average lower memory threshold for scaling down
- `minion_scaling_mem_upper_avg_threshold` The average upper memory threshold for scaling down
- `minion_scaling_cpu_lower_avg_threshold` The average lower cpu threshold for scaling down
- `minion_scaling_cpu_upper_avg_threshold` The average upper cpu threshold for scaling down

# Outputs

- `master_private_ip` The private IP of the master node
- `master_public_ip` The public IP of the master node
- `master_sgs_id` The security group id for the master nodes
- `minion_sgs_id` The security group id for the minion nodes

# License

All source code is licensed under the [MIT License](LICENSE).
