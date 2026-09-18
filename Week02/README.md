# CLO835 — Week 02: one EC2 machine, deployed by hand

One Ubuntu 26.04 EC2 machine in the AWS Academy Learner Lab. It has `git` and
nothing else. Deploy the Flask app on it by hand, then build the same app as a
container image and compare.

App: <https://github.com/sojoudian/simple-webapp-flask>

## Prerequisites

- Learner Lab access: <https://www.awsacademy.com/vforcesite/LMS_Login>
- An EC2 key pair (AWS Console → EC2 → Key Pairs), `.pem` downloaded
- Laptop: AWS CLI v2, Terraform, Git, Docker

## 1. Credentials

Click **Start Lab** and wait for the dot beside AWS to turn green. Then click
**AWS Details** at the top. A **Cloud Access** panel opens on the right, with a
block that starts with `[default]`. Copy the whole block.

Paste it into `~/.aws/credentials`, and replace everything that is already in
the file.

```bash
mkdir -p ~/.aws
nano ~/.aws/credentials
```

The block looks like this. The three values are different every time.

```ini
[default]
aws_access_key_id=ASIA...
aws_secret_access_key=...
aws_session_token=...
```

Set the region once. You do not repeat this step.

```bash
printf '[default]\nregion = us-east-1\n' > ~/.aws/config
```

Check it.

```bash
aws sts get-caller-identity
```

The session lasts 4 hours. When it ends, or when you click **End Lab**, the
three values stop working. Copy the block again from **AWS Details**.

## 2. Apply

```bash
cd Week02
cp terraform.tfvars.example terraform.tfvars   # set key_name
chmod 400 your-key.pem

terraform init
terraform apply
```

Takes about a minute. Terraform asks for `key_name` if `terraform.tfvars` does
not set it.

## 3. Connect

```bash
terraform output                     # public_ip, private_ip, urls
ssh -i your-key.pem ubuntu@<public_ip>
```

The Learner Lab stops the machine between sessions, and the address changes. Run
`terraform refresh` before `terraform output`.

## 4. The lab

| Script | Run it on | Port |
|---|---|--:|
| `runAWS_EC2.sh` | the EC2 machine | 8080 |
| `localMachine.sh` | your laptop | 18080 |

Run them section by section, next to the slides. Do not run a whole file.

The app reads `PORT`. It uses 8080 when `PORT` is absent. The Dockerfile sets
`ENV PORT=18080`. The security group opens 22, 8080, and 18080.

## 5. Destroy

```bash
terraform destroy
```

Run it at the end of class. A stopped machine still pays for the disk.

## Notes

- `r6i.large`, 2 vCPU, 16 GB. The Learner Lab blocks `xlarge` and larger.
- Ubuntu 26.04 matches `FROM ubuntu:26.04` in the Dockerfile.
- SSH is open to `0.0.0.0/0`. The image takes a key only, not a password.
