/** GLOBAL **/
variable "name" {
  description = "The name of the cluster"
  type        = "string"
}

variable "env" {
  description = "The environment of the cluster"
  type        = "string"
}

variable "vpc_id" {
  description = "The ID of the VPC where the cluster is running on"
  type        = "string"
}

variable "discovery_url" {
  description = "The discovery URL for etcd"
  type        = "string"
}

variable "bastion_sg_id" {
  description = "The security group of the bastion"
  type        = "string"
}

variable "bastion_host" {
  type        = "string"
  description = "The bastion HOST for the SSH connection"
}

variable "bootkube_repo" {
  description = "The bootkube docker repository"
  default     = "quay.io/coreos/bootkube"
  type        = "string"
}

variable "bootkube_version" {
  description = "The bootkube docker image tag"
  default     = "v0.1.4"
  type        = "string"
}

variable "kubelet_repo" {
  description = "The kubelet docker repository"
  default     = "quay.io/coreos/hyperkube"
  type        = "string"
}

variable "kubelet_version" {
  description = "The kubelet docker image tag"
  default     = "v1.3.4_coreos.0"
  type        = "string"
}

variable "kubelet_cluster_dns" {
  description = "IP address for a cluster DNS server."
  default     = "10.3.0.10"
  type        = "string"
}

variable "asset_path" {
  description = "The path to the kubernetes asset path"
  type        = "string"
}

variable "k8s_etcd_prefix" {
  description = "The etcd_prefix for kubernetes"
  type        = "string"
}

variable "flannel_etcd_prefix" {
  description = "The flannel_etcd_prefix"
  type        = "string"
}

/** MASTER **/
variable "master_disable_api_termination" {
  description = "Enable EC2 Termination protection"
  default     = true
}

variable "master_ami" {
  description = "The AMI for the master nodes"
  type        = "string"
}

variable "master_aws_key_name" {
  description = "The AWS key name for the master nodes"
  type        = "string"
}

variable "master_aws_private_key" {
  description = "Content of the private key to use when connecting to the masters"
  type        = "string"
}

variable "master_azs" {
  description = "A list of Availability zones in the region"
  type        = "list"
}

variable "master_subnet_ids" {
  description = "A list of subnet ids for the master nodes. Must be public subnet."
  type        = "list"
}

variable "master_instance_type" {
  description = "The instance type for the master nodes"
  default     = "m3.medium"
  type        = "string"
}

// This must be kept to one for now as bootkube does not support scaling up yet.
variable "master_node_count" {
  description = "The number of master nodes to bring up."
  default     = "1"
  type        = "string"
}

variable "master_iam_policies" {
  description = "A list of policy arns to apply to masters"
  default     = []
  type        = "list"
}

// workaround for aws_iam_role_policy_attachment not supporting count
// See https://github.com/hashicorp/terraform/issues/3851#issuecomment-155625720
variable "master_iam_policies_count" {
  description = "The count of `master_iam_policies`"
  type        = "string"
  default     = "0"
}

/** MINION **/
variable "minion_ami" {
  description = "The AMI for the minion nodes"
  type        = "string"
}

variable "minion_aws_key_name" {
  description = "The AWS key name for the minion nodes"
  type        = "string"
}

variable "minion_azs" {
  description = "A list of Availability zones in the region"
  type        = "list"
}

variable "minion_subnet_ids" {
  description = "A list of subnet ids for the minion nodes. Must be public subnet."
  type        = "list"
}

variable "minion_instance_type" {
  description = "The instance type for the minion nodes"
  default     = "m3.medium"
  type        = "string"
}

variable "minion_scaling_group_min_size" {
  description = "The minimum size of the minion scaling group"
  default     = "2"
  type        = "string"
}

variable "minion_scaling_group_max_size" {
  description = "The maximum size of the minion scaling group"
  default     = "20"
  type        = "string"
}

variable "minion_scale_up_adjustment" {
  description = "The scaling adjustment for scaling up"
  default     = "1"
  type        = "string"
}

variable "minion_scale_up_cooldown" {
  description = "The scaling cooldown for scaling up"
  default     = "300"
  type        = "string"
}

variable "minion_scale_down_adjustment" {
  description = "The scaling adjustment for scaling down"
  default     = "-1"
  type        = "string"
}

variable "minion_scale_down_cooldown" {
  description = "The scaling cooldown for scaling down"
  default     = "300"
  type        = "string"
}

variable "minion_scaling_mem_lower_avg_threshold" {
  description = "The average lower memory threshold for scaling down"
  default     = "40"
  type        = "string"
}

variable "minion_scaling_mem_upper_avg_threshold" {
  description = "The average upper memory threshold for scaling down"
  default     = "80"
  type        = "string"
}

variable "minion_scaling_cpu_lower_avg_threshold" {
  description = "The average lower cpu threshold for scaling down"
  default     = "25"
  type        = "string"
}

variable "minion_scaling_cpu_upper_avg_threshold" {
  description = "The average upper cpu threshold for scaling down"
  default     = "75"
  type        = "string"
}

variable "minion_iam_policies" {
  description = "A list of policy arns to apply to minions"
  default     = []
  type        = "list"
}

// workaround for aws_iam_role_policy_attachment not supporting count
// See https://github.com/hashicorp/terraform/issues/3851#issuecomment-155625720
variable "minion_iam_policies_count" {
  description = "The count of `minion_iam_policies`"
  type        = "string"
  default     = "0"
}
