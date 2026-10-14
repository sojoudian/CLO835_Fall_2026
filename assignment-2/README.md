# CLO835 Assignment 2 — automate the build, deploy a versioned app

Build one small web service. Let GitHub Actions build the image and push it to
Docker Hub. Deploy it to the **three-node Kubernetes cluster from Week 05**, then
release a second version and roll it back.

Assignment 1 is in [`../assignment-1`](../assignment-1).

---

## Where this runs

This semester the cluster is a **real kubeadm cluster on EC2**, the same one that
Week 04 and Week 05 build. It is not kind, and not minikube.

| | |
|---|---|
| Machines | 1 control plane and 2 workers |
| Image | Ubuntu 26.04, `m5.large` |
| Kubernetes | v1.35, Flannel |
| Build it with | `Week05/main.tf` |
| Node ports open | 30000-32767, to the internet |

Build the cluster from the `Week05` folder of this repository.

```bash
cd Week05
terraform init
terraform apply          # it asks for your key pair name
terraform output
ssh -i your-key.pem ubuntu@<master_public_ip>
```

Run every `kubectl` command of this assignment **on the control plane machine**.

Destroy the cluster when you finish for the day. The Learner Lab credentials
expire after 4 hours.

---

## What you build

A web service that answers on **port 8080** with one line of text. You release
two versions.

| Version | The app answers |
|---|---|
| **0.2** | `Hello world from the CLO835 class!` |
| **0.3** | `Hello world from the CLO835 class and 10112233!` |

Replace `10112233` with **your own Seneca student ID**. Each running application
is then unique.

---

## Start your own repository

The pipeline only runs from the **root** of a repository. Copy the contents of
this folder to the root of a new repository of your own.

```bash
# in an empty folder of your own
cp -R <this-repo>/assignment-2/. .
git init
git add .
git commit -m "assignment 2 starter"
```

Check that `.github/workflows/docker.yml` sits at the root. A workflow in a
sub-folder never runs.

GitHub names the first branch `main`. This repository uses `master`. The supplied
workflow accepts both names, so either one works.

---

## Pick ONE language

Programming is not the subject of this course. You may use an AI tool to help.
Choose one starter from [`apps/`](apps/).

| Language | Folder | Run it on your laptop |
|---|---|---|
| Python | [`apps/python`](apps/python) | `python3 app.py` |
| Go | [`apps/go`](apps/go) | `go run main.go` |
| Rust | [`apps/rust`](apps/rust) | `cargo run` |
| Java | [`apps/java`](apps/java) | `java Main.java` |
| C# (.NET) | [`apps/csharp`](apps/csharp) | `dotnet run` |
| Node.js | [`apps/nodejs`](apps/nodejs) | `node server.js` |

Test it.

```bash
curl http://localhost:8080
# Hello world from the CLO835 class!
```

Each starter holds one clearly marked `MESSAGE` constant. **To release version
0.3, change that one line.** Add your student ID, commit, and let the pipeline
build the new image.

Every starter also answers `/healthz` and `/readyz` with `200`. Use these two
paths if you add the bonus probes.

---

## What YOU complete

The repository holds **placeholder** files. Each one carries `TODO` comments.
They do not hold the answers. This is the graded work.

1. **`Dockerfile`** — build your application into an image that serves on port
   8080.
2. **`.github/workflows/docker.yml`** — on a push to your default branch, log in
   to Docker Hub, then build and push the image. Tag it with the version (`0.2`)
   and with the commit SHA.
3. **`k8s/deployment.yaml`** — a Deployment with **3 replicas**.
4. **`k8s/service.yaml`** — a **NodePort** Service, pinned to port **30000**.

See the handout on Blackboard for the full requirements and the grade breakdown.

---

## Build for the correct CPU

The EC2 nodes are **x86_64**. A Mac with Apple Silicon builds **arm64** images.
An arm64 image on an x86_64 node fails with `exec format error`. Week 02 Step 5
shows this.

The GitHub Actions runner `ubuntu-latest` is x86_64, so the pipeline builds the
correct image for you. If you also build on your laptop, add the platform.

```bash
docker buildx build --platform linux/amd64 -t <user>/<repo>:0.2 --push .
```

---

## Deploy, update and roll back

Run these on the control plane machine.

```bash
# 1. deploy version 0.2
kubectl apply -f deployment.yaml -f service.yaml
kubectl get deploy,rs,pods,svc

# 2. open it in your browser, on ANY of the three public addresses
#    http://<master_public_ip>:30000
#    http://<worker1_public_ip>:30000
#    http://<worker2_public_ip>:30000
curl -s http://localhost:30000

# 3. release version 0.3, after the pipeline pushed <user>/<repo>:0.3
kubectl set image deployment/<name> <container>=<user>/<repo>:0.3
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>

# 4. two ReplicaSets now exist. The old one holds 0 Pods.
kubectl get rs

# 5. roll back to version 0.2
kubectl rollout undo deployment/<name>
kubectl rollout status deployment/<name>
```

A NodePort opens on **every** node, not only on the node that runs a Pod. All
three addresses must answer.

---

## Rules

- **Never commit a Docker Hub password or token.** Keep them as GitHub Actions
  secrets, named `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
- Make every commit **before** the due date.
- The **report** of the problems you met is **mandatory**. Use
  [`report.md`](report.md).
- Your **student ID must show** in the answer of version 0.3.

---

## Clean up

```bash
kubectl delete -f deployment.yaml -f service.yaml
cd Week05 && terraform destroy
```

---

## If something does not work

| Symptom | Cause |
|---|---|
| The pipeline never starts | `.github/workflows/` is not at the repository root |
| `exec format error` in the Pod | the image is arm64, the node is x86_64 |
| `ImagePullBackOff` | the image name, the tag, or the Docker Hub secret is wrong |
| The browser times out | the Service is `ClusterIP`, or the node port is not 30000 |
| Only one address answers | you reached a Pod directly, not the Service |
