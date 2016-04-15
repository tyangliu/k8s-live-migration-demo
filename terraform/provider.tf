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
# etcd node
##########################################################################
resource "digitalocean_droplet" "k8s_etcd" {
	image = "ubuntu-15-10-x64"
	name = "k8s-etcd"
	region = "nyc3"
	size = "512mb"
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

	# Start the etcd daemon
	provisioner "remote-exec" {
		inline = [
			"chmod +x /usr/local/bin/etcd",
			"mkdir /tmp/etcddata",
			"etcd -data-dir /tmp/etcddata	--bind-addr=${self.ipv4_address}:4001 >/dev/null 2>/dev/null &"
		]
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

	# Start the daemons
	provisioner "remote-exec" {
		inline = [
			"chmod +x -R /usr/local/bin",
			"docker daemon >/dev/null 2>/dev/null &",
			"kube-apiserver --allow-privileged --v=5 --insecure-bind-address=${self.ipv4_address} --insecure-port=8080 --etcd-servers=http://${digitalocean_droplet.k8s_etcd.ipv4_address}:4001 --service-cluster-ip-range=10.0.0.0/24 --cors-allowed-origins=. >/dev/null 2>/dev/null &",
			"sleep 5",
			"kube-controller-manager --v=5 --enable-hostpath-provisioner=false --allocate-node-cidrs=true --cluster-cidr=10.1.0.0/16 --master=${self.ipv4_address}:8080 >/dev/null 2>/dev/null &",
			"kube-scheduler --v=5 --master=${self.ipv4_address}:8080 >/dev/null 2>/dev/null &"
		]
	}
}
