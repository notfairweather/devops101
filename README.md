This repo holds the code to test a toy example to show off OpenTofu and Ansible features.

# Introduction

Welcome to LogEverything Co, a fictional IoT company. 

The code in this repo does the following:

1. Helps set up the variables required to run the code
2. Pulls/builds the required container images
2. Runs OpenTofu to create assets - AWS S3 bucket (with static website) and AWS EC2 instance
4. Runs Ansible to install [Vikunja](https://vikunja.io/)

Pre-requisites: 
- Have an AWS account 
    - The services used in this example are all extremely cheap/free - however, you should review the code to understand what is being used, and you should tear down the infrastructure afterwards to minimise costs.
- Install Docker Engine as per instructions [on the Docker Docs](https://docs.docker.com/engine/install/).




# Using the project

These steps were tested on Ubuntu 24.04 (noble) on amd64 architecture.

## Get AWS credentials

Follow the instructions to [manage access keys on AWS docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey).

Ideally, you will want to create a new user and use its access keys, but for the sake of this example, you can use any user's keys, as long as they have the required permissions policies:
- AmazonEC2FullAccess
- AmazonS3FullAccess

Place the access key ID and access key into the file `.secrets/aws.env`. There is a template at `.secrets/aws.env.template` so you can see the required format.

## Set up OpenTofu and Ansible

Install Docker Engine if you haven't already.

Run the following commands to build/create the required containers.

```bash
# Pull OpenTofu container
sudo docker pull ghcr.io/opentofu/opentofu:latest

# Build Ansible container
cd ansible-docker
sudo docker build . -t ansible

cd ..

# Initialise OpenTofu container
sudo docker run --rm -it --workdir=/srv/workspace \
  --mount type=bind,source=$PWD/opentofu,target=/srv/workspace \
  ghcr.io/opentofu/opentofu:latest \
  init
```

Ref: [OpenTofu docs on Docker](https://opentofu.org/docs/intro/install/docker/)

## Set up variables

Create an SSH key pair using `ssh-keygen -f .secrets/ssh-key`.

Create a copy of the file `opentofu/variables.tfvars.template` called `opentofu/variables.tfvars`.

In that file, update the following variable values:
- ec2_ami: Update this if you want to change the AMI. You usually don't need to change this.
- ec2_ssh_pubkey: Get the SSH public key from `.secrets/ssh-key.pub` and put it in here.
- ec2_ssh_inbound_ip: Put your public IP address here. This is used to allow access to the EC2 instance.
- s3_bucket_suffix: This is used on the S3 bucket name. It should be globally unique, so use something that shouldn't already exist.

## Run OpenTofu

Create the AWS assets using the following command.

```bash
sudo docker run --rm -it --workdir=/srv/workspace \
  --mount type=bind,source=$PWD/opentofu,target=/srv/workspace \
  --env-file=.secrets/aws.env \
  ghcr.io/opentofu/opentofu:latest \
  apply -var-file variables.tfvars
```

At the prompt, review the output and enter "yes".

After this completes, note the two outputs. 

Check that you're able to reach the URL to see the public website.

## Update Ansible files

Update the file `devops101/ansible/inventory/inventory.yaml` with the EC2 IP address in the output of the OpenTofu run.

## Run Ansible

```bash
sudo docker run --rm -it \
  -v $PWD/ansible:/ansible \
  -v $PWD/.secrets:/root/.ssh \
  --entrypoint ansible-playbook ansible \
  -i inventory/inventory.yaml playbook.yaml
```

If you added a passphrase to the key, you will need to enter it at the prompt.

You should be able to reach the URL printed out at the final step of the run. You can register a new account to see that the service is working.

## Teardown

```bash
sudo docker run --rm -it --workdir=/srv/workspace \
  --mount type=bind,source=$PWD/opentofu,target=/srv/workspace \
  --env-file=.secrets/aws.env \
  ghcr.io/opentofu/opentofu:latest \
  destroy -var-file variables.tfvars
```

At the prompt, review the output and enter "yes".

You should be able to check that there are no assets remaining in AWS console. 

