# Kubernetes Live Migration Demo
A demo testing rig for Kubernetes criu-based migration, including:
* Terraform script to set up a 3 node, 1 master, 1 etcd node with all
required dependencies
* Sample containers that exhibit in-memory state
* Sample Kubernetes spec files to go along with those containers

## Running Terraform
The Terraform script will deploy and configure a working Kubernetes toy cluster,
and properly point kubectl to the master node's API server.

1. Ensure that you have [Terraform](https://www.terraform.io/downloads.html) installed
and in your system's PATH.
2. Ensure that you have kubectl for your respective platform in your system's PATH.
The binaries can tentatively be found [here](terraform/bin/k8s/kubectl).
2. Clone the repo.
3. Change working directory to `<path-to-cloned-repo>/terraform`.
4. Export the required environment variables.
	* [Setting up DigitalOcean SSH keys](https://www.digitalocean.com/community/tutorials/how-to-use-ssh-keys-with-digitalocean-droplets)
	* [Generating a DigitalOcean personal access token](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2)
  ```shell
  export DO_PAT=<your DigitalOcean access token>
  export SSH_FINGERPRINT=<md5 fingerprint of your DigitalOcean ssh key>
  ```
5. Provision or destroy nodes using Terraform.
	* To provision (create nodes), run `hack/provision.sh` or `sh hack/provision.sh` on Windows
	* To destroy (delete nodes), run `hack/destroy.sh` or `sh hack/provision.sh` on Windows
	* *NOTE FOR WINDOWS:* `ssh` is required in this script, available in the latest W10 Insider Preview.
	Additionally, within *terraform/provider.tf*, you may have to modify:
		* From `ssh -o "StrictHostKeyChecking no" root@${self.ipv4_address} /home/start.sh`
		* To `ssh root@${self.ipv4_address} /home/start.sh`
		* Then, turn StrictHostKeyChecking off through your `~/.ssh/config` file, as described [here](http://askubuntu.com/questions/87449/how-to-disable-strict-host-key-checking-in-ssh/385187)
6. *kubectl* should now be point to the Kubernetes master, and running `kubectl get nodes` you should
see the list of active nodes.
	* Create an unmanaged pod:
	`kubectl create -f <path-to-pod-spec>`
	* Migrating an unmanaged pod:
	`kubectl create -f <path-to-migration-spec>`
		* Example spec files exist [here](specs)
