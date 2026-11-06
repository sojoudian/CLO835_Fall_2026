# CLO835 Assignment 2 — report

The report is mandatory. Keep it short. Write what you met, not a tutorial.

| | |
|---|---|
| Name | |
| Student ID | |
| Language chosen | |
| Docker Hub image | `<user>/<repo>` |
| Your repository | `https://github.com/<user>/<repo>` |

## 1. The pipeline

Describe how your workflow builds and pushes the image. Name the two secrets
that you created.

## 2. The problems that you met

List each problem, then how you solved it. One short paragraph for each.

1.
2.
3.

## 3. The rollout

Give the output of these three commands, after you released version 0.3.

```
kubectl rollout history deployment/<name>
kubectl get rs
kubectl get pods -o wide
```

## 4. The rollback

Explain what changed after `kubectl rollout undo`. Say which ReplicaSet held
the Pods before, and which one holds them after.

## 5. Proof

Add a screenshot of the browser, on a node public address, for both versions.

| Version | Address | Screenshot |
|---|---|---|
| 0.2 | `http://<ip>:30000` | |
| 0.3 | `http://<ip>:30000` | |
