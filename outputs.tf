output "master_private_ip" {
  value = "${aws_instance.k8s-master.private_ip}"
}

output "master_public_ip" {
  value = "${aws_instance.k8s-master.public_ip}"
}

output "master_sgs_id" {
  value = "${aws_security_group.k8s-master.id}"
}

output "minion_sgs_id" {
  value = "${aws_security_group.k8s-minion.id}"
}
