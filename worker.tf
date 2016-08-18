resource "aws_iam_role" "k8s-worker" {
  name               = "k8s-worker"
  path               = "/infra/k8s/worker/"
  assume_role_policy = "${file("${path.module}/templates/assume-role-ec2.json")}"
}

data "template_file" "k8s-worker-iam-role-policy" {
  template = "${file("${path.module}/templates/policy-k8s-worker-role.json")}"

  vars {
    kms_arn = "${aws_kms_key.enc-dec.arn}"
  }
}

resource "aws_iam_role_policy" "k8s-worker" {
  name   = "k8s-worker"
  role   = "${aws_iam_role.k8s-worker.id}"
  policy = "${data.template_file.k8s-worker-iam-role-policy.rendered}"
}

resource "aws_iam_instance_profile" "k8s-worker" {
  name  = "k8s-worker"
  path  = "/infra/k8s/worker/"
  roles = ["${aws_iam_role.k8s-worker.name}"]
}

data "template_file" "worker-cloud-config" {
  template = "${file("${path.module}/templates/worker-cloud-config.yml")}"

  vars {
    discovery_url       = "${var.discovery_url}"
    master_private_ip   = "${aws_instance.k8s-master.0.private_ip}"
    aws_private_key     = "${base64encode(var.master_aws_private_key)}"
    kubelet_repo        = "${var.kubelet_repo}"
    kubelet_version     = "${var.kubelet_version}"
    kubelet_cluster_dns = "${var.kubelet_cluster_dns}"
  }
}

resource "aws_launch_configuration" "k8s-worker" {
  name_prefix          = "k8s-worker-"
  image_id             = "${var.worker_ami}"
  instance_type        = "${var.worker_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.k8s-worker.id}"
  key_name             = "${var.worker_aws_key_name}"
  security_groups      = ["${var.worker_sgs_ids}"]
  user_data            = "${data.template_file.worker-cloud-config.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "k8s-worker" {
  availability_zones        = ["${var.worker_azs}"]
  name                      = "k8s-worker"
  max_size                  = "${var.worker_scaling_group_max_size}"
  min_size                  = "${var.worker_scaling_group_min_size}"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["${var.worker_subnet_ids}"]
  launch_configuration      = "${aws_launch_configuration.k8s-worker.name}"

  tag {
    key                 = "role"
    value               = "k8s-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = "${var.env}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "k8s-workers-scale-up" {
  name                   = "workers-scale-up"
  scaling_adjustment     = "${var.worker_scale_up_adjustment}"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.worker_scale_up_cooldown}"
  autoscaling_group_name = "${aws_autoscaling_group.k8s-worker.name}"
}

resource "aws_autoscaling_policy" "k8s-workers-scale-down" {
  name                   = "workers-scale-down"
  scaling_adjustment     = "${var.worker_scale_down_adjustment}"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = "${var.worker_scale_down_cooldown}"
  autoscaling_group_name = "${aws_autoscaling_group.k8s-worker.name}"
}

resource "aws_cloudwatch_metric_alarm" "k8s-worker-memory-high" {
  alarm_name          = "k8s-worker-memory-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.worker_scaling_mem_upper_avg_threshold}"
  alarm_description   = "This metric monitors ec2 memory for high utilization on k8s-worker hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-workers-scale-up.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-worker.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s-worker-memory-low" {
  alarm_name          = "k8s-worker-memory-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.worker_scaling_mem_lower_avg_threshold}"
  alarm_description   = "This metric monitors ec2 memory for low utilization on k8s-worker hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-workers-scale-down.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-worker.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s-worker-cpu-high" {
  alarm_name          = "k8s-worker-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.worker_scaling_cpu_upper_avg_threshold}"
  alarm_description   = "This metric monitors ec2 cpu for high utilization on k8s-worker hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-workers-scale-up.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-worker.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "k8s-worker-cpu-low" {
  alarm_name          = "k8s-worker-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.worker_scaling_cpu_lower_avg_threshold}"
  alarm_description   = "This metric monitors ec2 cpu for low utilization on k8s-worker hosts"

  alarm_actions = [
    "${aws_autoscaling_policy.k8s-workers-scale-down.arn}",
  ]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.k8s-worker.name}"
  }
}
