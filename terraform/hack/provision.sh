#!/bin/bash

# To use this script, you need to:
# export DO_PAT=<<your DigitalOcean access token>>
# export SSH_FINGERPRINT=<<your SSH fingerprint>>

source hack/utils.sh

plan_provision
apply_provision
