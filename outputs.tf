output "master_private_ip" {
  value = "${aws_instance.k8s-master.private_ip}"
}

output "master_public_ip" {
  value = "${aws_instance.k8s-master.public_ip}"
}
