# Local Docker Registry

A plain HTTP Docker registry (`registry:2`) deployed inside the `reboot-patterns` namespace. Pattern service images are pushed from Mac via Tailscale IP and pulled by k3s pods via `localhost:30500`.

## Prerequisites

1. **Port 30500 must be open** on the Tailscale/firewall layer before attempting `docker push`. If the port is closed, the push will time out silently with no helpful error message.
2. **`registries.yaml` must be configured** on the Rocky Linux k3s node before any pod references `localhost:30500/...`. Without this mirror config, k3s will try to pull from Docker Hub and fail with `ImagePullBackOff`.

---

## 1. Apply the manifests

```bash
kubectl apply -f infra/k8s/registry/
```

Verify the pod is running:

```bash
kubectl get pod -n reboot-patterns -l app=local-registry
```

---

## 2. One-time manual node setup (Rocky Linux k3s node)

These steps must be performed once on the Rocky Linux server that runs k3s.

### a. Open port 30500 on the firewall

**firewalld (preferred on Rocky Linux):**

```bash
sudo firewall-cmd --permanent --add-port=30500/tcp
sudo firewall-cmd --reload
```

**iptables (alternative):**

```bash
sudo iptables -I INPUT -p tcp --dport 30500 -j ACCEPT
sudo iptables-save | sudo tee /etc/sysconfig/iptables
```

### b. Configure the k3s registry mirror

Create or edit `/etc/rancher/k3s/registries.yaml`:

```bash
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml <<'EOF'
mirrors:
  "100.66.8.44:30500":
    endpoint:
      - "http://localhost:30500"
EOF
```

This tells k3s: when a pod image references `100.66.8.44:30500/<image>`, resolve it via the in-cluster service at `http://localhost:30500/<image>`.

### c. Restart k3s

```bash
sudo systemctl restart k3s
```

### d. Verify the mirror is active

```bash
sudo k3s crictl info | grep -i registry
```

You should see `100.66.8.44:30500` listed under the mirrors section.

---

## 3. Test: push an image from Mac

```bash
docker pull nginx:latest
docker tag nginx:latest 100.66.8.44:30500/test-nginx:latest
docker push 100.66.8.44:30500/test-nginx:latest
```

A successful push ends with a digest line like `latest: digest: sha256:... size: ...`.

---

## 4. Test: pull from within the cluster

Create a test pod that references the local registry:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-registry-pull
  namespace: reboot-patterns
spec:
  containers:
    - name: nginx
      image: localhost:30500/test-nginx:latest
  restartPolicy: Never
```

Apply and verify:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-registry-pull
  namespace: reboot-patterns
spec:
  containers:
    - name: nginx
      image: localhost:30500/test-nginx:latest
  restartPolicy: Never
EOF

kubectl get pod test-registry-pull -n reboot-patterns
```

The pod status should reach `Running` or `Completed` without `ImagePullBackOff`.

Delete the pod and re-create it to confirm it pulls from the local registry on a cold start:

```bash
kubectl delete pod test-registry-pull -n reboot-patterns
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-registry-pull
  namespace: reboot-patterns
spec:
  containers:
    - name: nginx
      image: localhost:30500/test-nginx:latest
  restartPolicy: Never
EOF
kubectl get pod test-registry-pull -n reboot-patterns
```
