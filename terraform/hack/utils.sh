#!/bin/bash

function plan_provision {
	terraform plan \
		-var "do_token=${DO_PAT}" \
		-var "pub_key=$HOME/.ssh/id_rsa.pub" \
		-var "pvt_key=$HOME/.ssh/id_rsa" \
		-var "ssh_fingerprint=$SSH_FINGERPRINT" \
		-var "num_workers=3"
}

function apply_provision {
	terraform apply \
		-var "do_token=${DO_PAT}" \
		-var "pub_key=$HOME/.ssh/id_rsa.pub" \
		-var "pvt_key=$HOME/.ssh/id_rsa" \
		-var "ssh_fingerprint=$SSH_FINGERPRINT" \
		-var "num_workers=3"
}

function plan_destroy {
	terraform plan -destroy -out=terraform.tfplan \
		-var "do_token=${DO_PAT}" \
		-var "pub_key=$HOME/.ssh/id_rsa.pub" \
		-var "pvt_key=$HOME/.ssh/id_rsa" \
		-var "ssh_fingerprint=$SSH_FINGERPRINT" \
		-var "num_workers=3"
}

function apply_destroy {
	terraform apply terraform.tfplan
	rm terraform.tfplan
}
