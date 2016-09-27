resource "aws_iam_role" "k8s-master" {
  name               = "k8s-master"
  path               = "/infra/${var.env}/k8s/master/"
  assume_role_policy = "${file("${path.module}/templates/assume-role-ec2.json")}"
}

data "template_file" "k8s-master-iam-role-policy" {
  template = "${file("${path.module}/templates/policy-k8s-master-role.json")}"
}

resource "aws_iam_policy" "k8s-master" {
  name   = "k8s-master"
  policy = "${data.template_file.k8s-master-iam-role-policy.rendered}"
}

resource "aws_iam_role_policy_attachment" "k8s-master" {
  role       = "${aws_iam_role.k8s-master.name}"
  policy_arn = "${aws_iam_policy.k8s-master.arn}"
}

resource "aws_iam_role_policy_attachment" "k8s-master-extra" {
  count = "${var.master_iam_policies_count}"

  role       = "${aws_iam_role.k8s-master.name}"
  policy_arn = "${element(var.master_iam_policies, count.index)}"
}

resource "aws_iam_instance_profile" "k8s-master" {
  name  = "k8s-master"
  path  = "/infra/${var.env}/k8s/master/"
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

resource "aws_security_group" "k8s-master" {
  name_prefix = "k8s-master-"
  description = "The security group for kubernetes master node."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    KubernetesCluster = "${var.name}"
    role              = "master"
    env               = "${var.env}"
  }
}

resource "aws_security_group_rule" "k8s-master-allow-all-icmp-out" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-all-tcp-out" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-all-udp-out" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-all-icmp-in" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-ssh-from-bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.bastion_sg_id}"
  security_group_id        = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-https-from-all" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-all-from-self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-all-tcp-from-minion" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-master.id}"
  source_security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-master-allow-all-udp-from-minion" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "udp"
  security_group_id        = "${aws_security_group.k8s-master.id}"
  source_security_group_id = "${aws_security_group.k8s-minion.id}"
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
  vpc_security_group_ids  = ["${aws_security_group.k8s-master.id}"]

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
