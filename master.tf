resource "aws_iam_role" "k8s-master" {
  name               = "k8s-master"
  path               = "/infra/k8s/master/"
  assume_role_policy = "${file("${path.module}/templates/assume-role-ec2.json")}"
}

data "template_file" "k8s-master-iam-role-policy" {
  template = "${file("${path.module}/templates/policy-k8s-master-role.json")}"
}

resource "aws_iam_role_policy" "k8s-master" {
  name   = "k8s-master"
  role   = "${aws_iam_role.k8s-master.id}"
  policy = "${data.template_file.k8s-master-iam-role-policy.rendered}"
}

resource "aws_iam_instance_profile" "k8s-master" {
  name  = "k8s-master"
  roles = ["${aws_iam_role.k8s-master.name}"]
}

data "template_file" "master-cloud-config" {
  template = "${file("${path.module}/templates/master-cloud-config.yml")}"

  vars {
    bootkube_repo       = "${var.bootkube_repo}"
    bootkube_version    = "${var.bootkube_version}"
    kubelet_repo        = "${var.kubelet_repo}"
    kubelet_version     = "${var.kubelet_version}"
    discovery_url       = "${var.discovery_url}"
    kubelet_cluster_dns = "${var.kubelet_cluster_dns}"
  }
}

resource "aws_instance" "k8s-master" {
  count                   = "${var.master_node_count}"
  ami                     = "${var.master_ami}"
  availability_zone       = "${element(var.master_azs, count.index)}"
  subnet_id               = "${element(var.master_subnet_ids, count.index)}"
  user_data               = "${data.template_file.master-cloud-config.rendered}"
  instance_type           = "${var.master_instance_type}"
  iam_instance_profile    = "${aws_iam_instance_profile.k8s-master.id}"
  key_name                = "${var.master_aws_key_name}"
  disable_api_termination = "${var.master_disable_api_termination}"
  vpc_security_group_ids  = ["${var.master_sgs_ids}"]

  tags {
    Name              = "k8s-master-${count.index}"
    role              = "master"
    availability_zone = "${element(var.master_azs, count.index)}"
    env               = "${var.env}"
  }

  connection {
    user        = "core"
    host        = "${self.private_ip}"
    private_key = "${var.master_aws_private_key}"

    bastion_host = "${var.bastion_host}"
  }

  # The following provisioner allows us to force terraform to wait for SSH to
  # be available through the bastion. This is needed for the next local-exec
  # provisioner.
  provisioner "remote-exec" {
    inline = [
      "/usr/bin/true",
    ]
  }

  # The following provisioner are a hack due to the lack of `file-remote`
  # provisioner.
  # Ref: https://github.com/hashicorp/terraform/issues/3379
  provisioner "local-exec" {
    command = <<CMD
      rm -rf ${var.asset_path} \
        && ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -f -N -M -S /tmp/tunnel-to-${self.private_ip} -L 5022:${self.private_ip}:22 core@${var.bastion_host} \
        && ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -p 5022 core@localhost "while [ ! -f /home/core/assets/auth/kubeconfig ]; do echo 'Waiting for /home/core/assets/auth/kubeconfig...'; sleep 1; done" \
        && scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -P 5022 -r core@localhost:assets/ ${var.asset_path} \
        && ssh -S /tmp/tunnel-to-${self.private_ip} -O exit core@${var.bastion_host}
CMD
  }
}
