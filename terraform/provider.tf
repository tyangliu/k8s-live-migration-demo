# Config to set up a DigitalOcean k8s cluster for demo including:
# - Ubuntu 15.10
# - Custom Docker binary, forked from boucher/docker cr-defunct
# - CRIU 1.8.1
# - Custom Kubernetes binaries with modifications for live migration demo

variable "do_token" {}
variable "pub_key" {}
variable "pvt_key" {}
variable "ssh_fingerprint" {}
variable "num_workers" {}

provider "digitalocean" {
	token = "${var.do_token}"
}

##########################################################################
# etcd start script
##########################################################################
resource "template_file" "start_etcd" {
	template = "${file("etcd.yaml")}"
	vars {
		ETCD_DIR = "/tmp/etcddata"
	}
}

##########################################################################
# etcd node
##########################################################################
resource "digitalocean_droplet" "k8s_etcd" {
	image = "ubuntu-15-10-x64"
	name = "k8s-etcd"
	region = "nyc3"
	size = "512mb"
	user_data = "${template_file.start_etcd.rendered}"
	ssh_keys = [
		"${var.ssh_fingerprint}"
	]

	connection {
		user = "root"
		type = "ssh"
		key_file = "${var.pvt_key}"
		timeout = "2m"
	}

	# Load etcd binary onto machine
	provisioner "file" {
		source = "./bin/etcd"
		destination = "/usr/local/bin/etcd"
	}

	# Run the start script to start daemons
	provisioner "local-exec" {
		command = <<EOF
			ssh -o "StrictHostKeyChecking no" root@${self.ipv4_address} /home/start.sh
EOF
	}
}

##########################################################################
# k8s master start script
##########################################################################
resource "template_file" "start_master" {
	template = "${file("master.yaml")}"
	vars {
		ETCD_IP = "${digitalocean_droplet.k8s_etcd.ipv4_address}"
		CLUSTER_CIDR = "10.1.0.0/16"
		SERVICE_IP_RANGE = "10.0.0.0/24"
	}
}

##########################################################################
# k8s master node
##########################################################################
resource "digitalocean_droplet" "k8s_master" {
	image = "ubuntu-15-10-x64"
	name = "k8s-master"
	region = "nyc3"
	size = "512mb"
	user_data = "${template_file.start_master.rendered}"
	ssh_keys = [
		"${var.ssh_fingerprint}"
	]

	connection {
		user = "root"
		type = "ssh"
		key_file = "${var.pvt_key}"
		timeout = "2m"
	}

	# Load dependencies onto machine
	provisioner "file" {
		source = "./bin/docker"
		destination = "/usr/local/bin/docker"
	}
	provisioner "file" {
		source = "./bin/criu"
		destination = "/usr/local/bin/criu"
	}
	provisioner "file" {
		source = "./bin/protoc"
		destination = "/usr/local/bin/protoc"
	}
	provisioner "file" {
		source = "./lib/libprotobuf-c.so"
		destination = "/usr/local/lib/libprotobuf-c.so"
	}

	# Load k8s binaries onto machine
	provisioner "file" {
		source = "./bin/k8s/kube-apiserver"
		destination = "/usr/local/bin/kube-apiserver"
	}
	provisioner "file" {
		source = "./bin/k8s/kube-controller-manager"
		destination = "/usr/local/bin/kube-controller-manager"
	}
	provisioner "file" {
		source = "./bin/k8s/kube-scheduler"
		destination = "/usr/local/bin/kube-scheduler"
	}

	# Run the start script to start daemons
	provisioner "local-exec" {
		command = <<EOF
			ssh -o "StrictHostKeyChecking no" root@${self.ipv4_address} /home/start.sh
EOF
	}
}

##########################################################################
# k8s minion start script
##########################################################################
resource "template_file" "start_minion" {
	template = "${file("minion.yaml")}"
	vars {
		ETCD_IP = "${digitalocean_droplet.k8s_etcd.ipv4_address}"
		MASTER_IP = "${digitalocean_droplet.k8s_master.ipv4_address}"
		MASTER_PORT = 8080
	}
}

##########################################################################
# k8s minion nodes
##########################################################################
resource "digitalocean_droplet" "k8s_minion" {
	count = "${var.num_workers}"

	image = "ubuntu-15-10-x64"
	name = "${format("k8s-minion-%02d", count.index + 1)}"
	region = "nyc3"
	size = "512mb"
	user_data = "${template_file.start_minion.rendered}"
	ssh_keys = [
		"${var.ssh_fingerprint}"
	]

	connection {
		user = "root"
		type = "ssh"
		key_file = "${var.pvt_key}"
		timeout = "2m"
	}

	# Load dependencies onto machine
	provisioner "file" {
		source = "./bin/docker"
		destination = "/usr/local/bin/docker"
	}
	provisioner "file" {
		source = "./bin/criu"
		destination = "/usr/local/bin/criu"
	}
	provisioner "file" {
		source = "./bin/protoc"
		destination = "/usr/local/bin/protoc"
	}
	provisioner "file" {
		source = "./lib/libprotobuf-c.so"
		destination = "/usr/local/lib/libprotobuf-c.so"
	}

	# Load k8s binaries onto machine
	provisioner "file" {
		source = "./bin/k8s/kubelet"
		destination = "/usr/local/bin/kubelet"
	}
	provisioner "file" {
		source = "./bin/k8s/kube-proxy"
		destination = "/usr/local/bin/kube-proxy"
	}

	# Run the start script to start daemons
	provisioner "local-exec" {
		command = <<EOF
			ssh -o "StrictHostKeyChecking no" root@${self.ipv4_address} /home/start.sh
EOF
	}
}

##########################################################################
# Setup kubectl
##########################################################################
resource "null_resource" "setup_kubectl" {
	depends_on = ["digitalocean_droplet.k8s_minion"]
	provisioner "local-exec" {
		command = <<EOF
			kubectl config set-cluster local \
				--server=http://${digitalocean_droplet.k8s_master.ipv4_address}:8080 \
				--insecure-skip-tls-verify=true
			kubectl config set-context local --cluster=local
			kubectl config use-context local
EOF
	}
}
