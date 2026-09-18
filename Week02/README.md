# CLO835 — Week 02 lab: one EC2 machine for the manual deployment

Infrastructure-as-code for **`Week02/Week02.pptx`** (slide 18 — Clone, Create,
Convert, Build, Test, Publish).

**One Ubuntu 26.04 LTS EC2 machine** on AWS Academy Learner Lab. The machine has
`git` and nothing else. You deploy the Flask app on it **by hand**, count the
steps, and then find the same steps inside a `Dockerfile` on your own laptop.

App repository: <https://github.com/sojoudian/simple-webapp-flask>

## What `terraform apply` sets up (≈1 minute)

| Requirement | How this Terraform provides it |
|---|---|
| One Linux machine | 1× **`r6i.large`** (2 vCPU / 16 GB), Ubuntu 26.04 LTS, 30 GB gp3 |
| The same base as the image | Ubuntu **26.04 LTS** (Python 3.14), because the `Dockerfile` says `FROM ubuntu:26.04` |
| A way in | Security group: **22** (SSH) |
| A way to see the result | Security group: **8080** (manual run) and **18080** (container run) |
| The lab steps | [`runAWS_EC2.sh`](runAWS_EC2.sh) on the machine, then [`localMachine.sh`](localMachine.sh) on your laptop |
| Docker on the machine | **Not installed** — the manual way comes first |

## Prerequisites

- AWS Academy Learner Lab access — sign in at <https://www.awsacademy.com/vforcesite/LMS_Login>
- An EC2 **key pair** in the Learner Lab (AWS Console → EC2 → Key Pairs), `.pem` downloaded
- On your laptop: AWS CLI v2, Terraform, Git, Docker

## 1. Get your AWS credentials

Learner Lab page: **Start Lab** → wait for the green dot → **AWS Details → AWS CLI
→ Show**. Paste the whole `[default]` block into `~/.aws/credentials`, set
`region = us-east-1` in `~/.aws/config`. Credentials rotate every session
(~4 h) — re-paste each session. Verify: `aws sts get-caller-identity`.

## 2. Configure and apply

```bash
cd Week02
cp terraform.tfvars.example terraform.tfvars   # set key_name to YOUR key pair
chmod 400 your-key.pem

terraform init
terraform apply        # type yes; wait ~1 min
```

## 3. Connect, then run the lab

```bash
terraform output                     # public_ip, private_ip, urls, next_step

ssh -i your-key.pem ubuntu@<public IP from terraform output>
git --version                        # the only tool that is ready
```

Then follow the two scripts, section by section, next to the slides.

| Script | Where you run it | What it does |
|---|---|---|
| [`runAWS_EC2.sh`](runAWS_EC2.sh) | on the EC2 machine | The manual way: clone, install Python, hit the PEP 668 error, fix it with a venv, run on **8080**. |
| [`localMachine.sh`](localMachine.sh) | on your own laptop | The container way: read the Dockerfile, build, run on **18080**, tag, push. |

The Learner Lab stops the machine between sessions and AWS gives a new public
address at the next start. Run `terraform refresh` before `terraform output`.

## The two ports

| How you run it | Port | Source |
|---|--:|---|
| `python3 app.py` | 8080 | `app.py` default, when `PORT` is absent |
| `docker run` | 18080 | `Dockerfile`: `ENV PORT=18080`, `EXPOSE 18080` |

Both run the same command. One environment variable sets the port, so the code
never changes. This Terraform opens both ports.

## 4. Destroy

```bash
terraform destroy
```

Run it at the end of each class. A stopped machine still pays for the 30 GB disk.
One 4-hour session costs roughly 0.55 USD.
