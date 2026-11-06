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

Click **Start Lab**, wait for the green dot, then click **AWS Details**. Copy the
`[default]` block from the Cloud Access panel into `~/.aws/credentials`. It
expires after 4 hours.

```bash
mkdir -p ~/.aws
vi ~/.aws/credentials
printf '[default]\nregion = us-east-1\n' > ~/.aws/config
aws sts get-caller-identity
```

## 2. Apply

```bash
cd Week02
terraform init
terraform apply        # asks for key_name
```

## 3. Connect

```bash
terraform output
chmod 400 your-key.pem               # ssh refuses a key that others can read
ssh -i your-key.pem ubuntu@<public_ip>
```

The lab stops the machine between sessions, and the address changes. Run
`terraform refresh` first.

## 4. The lab

| Script | Run it on |
|---|---|
| `runAWS_EC2.sh` | the EC2 machine |
| `localMachine.sh` | your laptop |

Run them section by section. Do not run a whole file. Both serve on 8080.

## 5. Destroy

```bash
terraform destroy
```

## Notes

- `r6i.large`, 2 vCPU, 16 GB. The lab blocks `xlarge` and larger.
- Ubuntu 26.04 matches `FROM ubuntu:26.04` in the Dockerfile.
- SSH is open to `0.0.0.0/0`. The image takes a key, not a password.
