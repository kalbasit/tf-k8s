resource "aws_iam_role" "k8s-minion" {
  name               = "k8s-minion"
  path               = "/infra/${var.env}/k8s/minion/"
  assume_role_policy = "${file("${path.module}/templates/assume-role-ec2.json")}"
}

data "template_file" "k8s-minion-iam-role-policy" {
  template = "${file("${path.module}/templates/policy-k8s-minion-role.json")}"
}

resource "aws_iam_role_policy" "k8s-minion" {
  name   = "k8s-minion"
  role   = "${aws_iam_role.k8s-minion.id}"
  policy = "${data.template_file.k8s-minion-iam-role-policy.rendered}"
}

resource "aws_iam_instance_profile" "k8s-minion" {
  name  = "k8s-minion"
  path  = "/infra/${var.env}/k8s/minion/"
  roles = ["${aws_iam_role.k8s-minion.name}"]
}

data "template_file" "minion-cloud-config" {
  template = "${file("${path.module}/templates/minion-cloud-config.yml")}"

  vars {
    discovery_url       = "${var.discovery_url}"
    master_private_ip   = "${aws_instance.k8s-master.0.private_ip}"
    aws_private_key     = "${base64encode(var.master_aws_private_key)}"
    kubelet_repo        = "${var.kubelet_repo}"
    kubelet_version     = "${var.kubelet_version}"
    kubelet_cluster_dns = "${var.kubelet_cluster_dns}"
  }
}

resource "aws_security_group" "k8s-minion" {
  name_prefix = "k8s-minion-"
  description = "The security group for kubernetes minion node."
  vpc_id      = "${var.vpc_id}"

  tags {
    KubernetesCluster = "${var.name}"
    role              = "minion"
    env               = "${var.env}"
  }
}

resource "aws_security_group_rule" "k8s-minion-allow-all-icmp-out" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-all-tcp-out" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-all-udp-out" {
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-all-icmp-in" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-ssh-from-bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.bastion_sg_id}"
  security_group_id        = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-https-from-all" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-all-from-self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = "${aws_security_group.k8s-minion.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-all-tcp-from-master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-minion.id}"
  source_security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_security_group_rule" "k8s-minion-allow-all-udp-from-master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "udp"
  security_group_id        = "${aws_security_group.k8s-minion.id}"
  source_security_group_id = "${aws_security_group.k8s-master.id}"
}

resource "aws_launch_configuration" "k8s-minion" {
  name_prefix          = "k8s-minion-"
  image_id             = "${var.minion_ami}"
  instance_type        = "${var.minion_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.k8s-minion.id}"
  key_name             = "${var.minion_aws_key_name}"
  security_groups      = ["${aws_security_group.k8s-minion.id}"]
  user_data            = "${data.template_file.minion-cloud-config.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "k8s-minion" {
  availability_zones        = ["${var.minion_azs}"]
  name                      = "k8s-minion"
  max_size                  = "${var.minion_scaling_group_max_size}"
  min_size                  = "${var.minion_scaling_group_min_size}"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["${var.minion_subnet_ids}"]
  launch_configuration      = "${aws_launch_configuration.k8s-minion.name}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "role"
    value               = "k8s-minion"
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = "${var.env}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "k8s-minions-scale-up" {
  name                   = "minions-scale-up"
  scaling_adjustment     = "${var.minion_scale_up_adjustment}"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.minion_scale_up_cooldown}"
  autoscaling_group_name = "${aws_autoscaling_group.k8s-minion.name}"
}

resource "aws_autoscaling_policy" "k8s-minions-scale-down" {
  name                   = "minions-scale-down"
  scaling_adjustment     = "${var.minion_scale_down_adjustment}"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.minion_scale_down_cooldown}"
  autoscaling_group_name = "${aws_autoscaling_group.k8s-minion.name}"
}

resource "aws_cloudwatch_metric_alarm" "k8s-minion-memory-high" {
  alarm_name          = "k8s-minion-memory-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.minion_scaling_mem_upper_avg_threshold}"
  alarm_description   = "This metric monitors ec2 memory for high utilization on k8s-minion hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-minions-scale-up.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-minion.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s-minion-memory-low" {
  alarm_name          = "k8s-minion-memory-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.minion_scaling_mem_lower_avg_threshold}"
  alarm_description   = "This metric monitors ec2 memory for low utilization on k8s-minion hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-minions-scale-down.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-minion.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s-minion-cpu-high" {
  alarm_name          = "k8s-minion-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.minion_scaling_cpu_upper_avg_threshold}"
  alarm_description   = "This metric monitors ec2 cpu for high utilization on k8s-minion hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-minions-scale-up.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-minion.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s-minion-cpu-low" {
  alarm_name          = "k8s-minion-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.minion_scaling_cpu_lower_avg_threshold}"
  alarm_description   = "This metric monitors ec2 cpu for low utilization on k8s-minion hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-minions-scale-down.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-minion.name}"
  }
}
