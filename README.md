# Infrastructure Optimization

Detailed project report -> [Click Here](/docs/Infra Optimization - Fixing EasyPay.md)

## Steps

### Step 1

#### Clone the Repo

```bash
git clone https://github.com/nyukeit/fixing-infra-op.git
```

### Step 2

#### Create a Key Pair in EC2

Go to the EC2 Dashboard and create a Key Pair named `infra_op`.

Use `.pem` and click on Create. This will download a file named `infra_op.pem`. This key will be used to SSH into the EC2 instances.

#### Change the Permissions (!)

This is an important step, without this, our Ansible commands will not be executed and AWS will reject all SSH connections.

We need to change the permissions of the key pair file to `400`.

```bash
sudo chmod 400 infra_op.pem
```

### Step 3

#### Replace Credentials in Variables

The `variables.tf` file contains a few variables that are specific to your AWS account.

You need to replace the AWS Access and AWS Secret tokens from your own account.

> Note: If your AWS account does not force a security token, you need to comment out that block.

Make sure the region mentioned is the region of your AWS resources/account.

I have mentioned an Ubuntu AMI that has been working fine for me. Make sure you mentioned the AMI based on your AWS region and Ubuntu version.

### Step 4

#### Plan & Apply

The Terraform scripts are inside the folder `tf-modules`. Change into this folder and apply the configuration.

```bash
cd tf-modules
```

Initialize Terraform using the configuration

```bash
terraform init
```

Apply the configuration

```bash
terraform apply
```

### Step 5

#### SSH into the Master Node

 The terraform execution will ideally display public and private IPs of the newly created instances. Although the first Public IP is usually that of the master node, it may not always be the case. To know which one is the master node, we will check the `hosts` file that was created in the process.

```bash
cat hosts
```

Note the IP under the `[master]`.

Now, SSH into this machine, replace the `x.x.x.x` with the IP of your master node.

```bash
ssh -i /path/to/keypair.pem ubuntu@x.x.x.x
```

### Step 6

#### Verify your K8S cluster

Verify if the Kubernetes cluster was initiated correctly.

```bash
kubectl get nodes
```

