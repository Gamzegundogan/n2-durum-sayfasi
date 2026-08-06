# N2 Durum Sayfası — Güvenli Statik Dağıtım

Statik bir HTML/CSS durum sayfasını, non-root Nginx container'ında,
CI ile test edilip Kubernetes'e sürümlü ve geri alınabilir şekilde
dağıtan örnek proje.

## Ön koşullar

- Docker (Compose dahil)
- Bir Kubernetes cluster'ı ve `kubectl` (yerelde `minikube` veya `kind`
  önerilir)
- `curl`

## Yerel çalıştırma (Docker Compose)

```bash
docker compose up -d --build
curl http://localhost:8080/
curl http://localhost:8080/healthz
docker compose down
```

## Test

```bash
bash scripts/test.sh          # statik dosya + config kontrolleri
bash scripts/smoke-test.sh    # çalışan servise karşı uçtan uca kontrol
```

## Kubernetes'e dağıtım

1. Lokal cluster başlat (yoksa):
   ```bash
   minikube start
   ```
2. İmajı build et ve cluster'ın kullanacağı şekilde yükle
   (minikube için):
   ```bash
   GIT_SHA=$(git rev-parse --short HEAD)
   docker build --build-arg GIT_SHA=$GIT_SHA -t n2-durum-sayfasi:$GIT_SHA .
   minikube image load n2-durum-sayfasi:$GIT_SHA
   ```
3. `deploy/deployment.yaml` içindeki `image:` alanını bu tag ile
   güncelle (veya `kubectl set image` kullan — aşağıda).
4. Manifestleri uygula:
   ```bash
   kubectl apply -f deploy/namespace.yaml
   kubectl apply -f deploy/deployment.yaml
   kubectl apply -f deploy/service.yaml
   kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi
   ```
5. Görüntüle:
   ```bash
   kubectl -n n2-durum port-forward svc/n2-durum-sayfasi 8080:80
   # tarayıcıda http://localhost:8080
   ```
6. Smoke test:
   ```bash
   bash scripts/smoke-test.sh http://localhost:8080
   ```

## Yeni sürüm dağıtma / Rollback

```bash
# yeni sürüm
kubectl -n n2-durum set image deploy/n2-durum-sayfasi site=n2-durum-sayfasi:<yeni-tag>
kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi

# geçmiş
kubectl -n n2-durum rollout history deploy/n2-durum-sayfasi

# önceki sürüme dön
kubectl -n n2-durum rollout undo deploy/n2-durum-sayfasi
```

## Kaldırma

```bash
kubectl delete -f deploy/service.yaml
kubectl delete -f deploy/deployment.yaml
kubectl delete -f deploy/namespace.yaml
docker compose down -v
```

## Dokümanlar

- [Mimari](docs/architecture.md)
- [ADR-001: Container seçimi](docs/adr-001-container-secimi.md)
- [Runbook: Site açılmıyor](docs/runbook-site-acilmiyor.md)

