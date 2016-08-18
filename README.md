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
  worker_ami             = "ami-6d138f7a"
  worker_aws_key_name    = "ec2-key-name"

  worker_subnet_ids = ["subnet-b73bc4f5"]

  worker_sgs_ids = [
    "${module.sgs.out-pub}",
    "${module.sgs.in-self}",
  ]

  worker_azs = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1d",
    "us-east-1e",
  ]
}
```

# Module input variables

- `env` The environment of the cluster
- `discovery_url` The discovery URL for etcd
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
- `master_sgs_ids` A list of security group ids for the master nodes
- `master_azs` A list of Availability zones in the region
- `master_subnet_ids` A list of subnet ids for the master nodes. Must be public subnet.
- `master_instance_type` The instance type for the master nodes
- `master_node_count` The number of master nodes to bring up.
- `worker_ami` The AMI for the worker nodes
- `worker_aws_key_name` The AWS key name for the worker nodes
- `worker_sgs_ids` A list of security group ids for the worker nodes
- `worker_azs` A list of Availability zones in the region
- `worker_subnet_ids` A list of subnet ids for the worker nodes. Must be public subnet.
- `worker_instance_type` The instance type for the worker nodes
- `worker_scaling_group_min_size` The minimum size of the worker scaling group
- `worker_scaling_group_max_size` The maximum size of the worker scaling group
- `worker_scale_up_adjustment` The scaling adjustment for scaling up
- `worker_scale_up_cooldown` The scaling cooldown for scaling up
- `worker_scale_down_adjustment` The scaling adjustment for scaling down
- `worker_scale_down_cooldown` The scaling cooldown for scaling down
- `worker_scaling_mem_lower_avg_threshold` The average lower memory threshold for scaling down
- `worker_scaling_mem_upper_avg_threshold` The average upper memory threshold for scaling down
- `worker_scaling_cpu_lower_avg_threshold` The average lower cpu threshold for scaling down
- `worker_scaling_cpu_upper_avg_threshold` The average upper cpu threshold for scaling down

# Outputs

- `master_private_ip` The private IP of the master node
- `master_public_ip` The public IP of the master node

# License

All source code is licensed under the [MIT License](LICENSE).
