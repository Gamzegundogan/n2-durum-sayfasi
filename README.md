# N2 Durum Sayfası — Frontend + Backend + PostgreSQL, Kubernetes ve CI/CD

3 katmanlı bir örnek uygulama: statik bir durum sayfası + ziyaretçi
defteri (Nginx), bir Node.js/Express API'si (backend) ve kalıcı bir
PostgreSQL veritabanı. Her katman non-root konteynerlerde çalışır,
Kubernetes üzerinde declarative (bildirimsel) yöntemle dağıtılır ve
GitHub Actions ile uçtan uca otomatikleştirilir (CI/CD).

## Mimari

```text
Tarayıcı
   │
   ▼
Nginx (frontend, 2 replica)
   ├─ statik siteyi ve ziyaretçi defteri arayüzünü sunar (/)
   ├─ sağlık kontrolü (/healthz)
   └─ /api/ isteklerini backend'e yönlendirir (reverse proxy)
         │
         ▼
   Backend Service (ClusterIP)
         │
         ▼
   Backend (Node.js/Express, 2 replica)
   ├─ /api/status    → pod adı + zaman damgası
   └─ /api/guestbook → ziyaretçi mesajlarını okur/yazar
         │
         ▼
   Veritabanı Service (ClusterIP)
         │
         ▼
   PostgreSQL (1 replica, PersistentVolumeClaim ile kalıcı disk)
```

Her katman ayrı Deployment/Service olarak çalışır, birbirine
Kubernetes'in kendi iç DNS'i (Service adı) üzerinden ulaşır.
Veritabanı kimlik bilgileri bir Kubernetes Secret'ında tutulur.

## Ön koşullar

- Docker (Compose dahil)
- Bir Kubernetes cluster'ı ve `kubectl` (yerelde `minikube` önerilir,
  Windows'ta `--driver=docker` ile)
- `curl` / PowerShell (`Invoke-RestMethod`)

## Proje yapısı

```text
site/            → Frontend dosyaları (index.html, style.css)
nginx/           → Frontend'in Nginx yapılandırması (reverse proxy dahil)
backend/         → Node.js/Express backend kaynak kodu ve Dockerfile'ı
deploy/          → Kubernetes manifestleri:
  namespace.yaml     → n2-durum namespace'i
  deployment.yaml    → frontend Deployment
  service.yaml       → frontend Service
  backend.yaml       → backend Deployment + Service
  db.yaml            → PostgreSQL PVC + Deployment + Service
  db-secret.yaml     → veritabanı kimlik bilgileri (Secret)
scripts/         → Test ve smoke-test script'leri
docs/            → Mimari, ADR ve runbook dokümanları
.github/workflows/ci.yml → CI/CD pipeline tanımı
```

## Yerel çalıştırma (Docker Compose — frontend + backend + db)

```bash
docker compose up -d --build
curl http://localhost:8080/
curl http://localhost:3000/api/guestbook
docker compose down -v
```

## Kubernetes'e dağıtım (tüm katmanlar)

1. Lokal cluster başlat (yoksa):
```bash
   minikube start --driver=docker
```
2. İmajları build et:
```bash
   docker build -t n2-durum-sayfasi:0.4.0 .
   docker build -t n2-backend:0.2.0 ./backend
```
3. minikube'a yükle (PostgreSQL image'ı için gerekmez, Docker Hub'dan
   otomatik çekilir):
```bash
   minikube image load n2-durum-sayfasi:0.4.0
   minikube image load n2-backend:0.2.0
```
4. Manifestleri sırayla uygula (declarative):
```bash
   kubectl apply -f deploy/namespace.yaml
   kubectl apply -f deploy/db-secret.yaml
   kubectl apply -f deploy/db.yaml
   kubectl apply -f deploy/deployment.yaml
   kubectl apply -f deploy/service.yaml
   kubectl apply -f deploy/backend.yaml
   kubectl -n n2-durum rollout status deploy/n2-db
   kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi
   kubectl -n n2-durum rollout status deploy/n2-backend
```
5. Görüntüle:
```bash
   minikube service n2-durum-sayfasi -n n2-durum
```
   Açılan sayfada canlı backend bilgisini ve ziyaretçi defteri formunu
   görürsün; forma yazılan mesajlar PostgreSQL'de kalıcı olarak saklanır.

## Yeni sürüm dağıtma / Rollback

```bash
kubectl -n n2-durum set image deploy/n2-durum-sayfasi site=n2-durum-sayfasi:<yeni-tag>
kubectl -n n2-durum set image deploy/n2-backend backend=n2-backend:<yeni-tag>
kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi
kubectl -n n2-durum rollout status deploy/n2-backend

kubectl -n n2-durum rollout history deploy/n2-durum-sayfasi
kubectl -n n2-durum rollout undo deploy/n2-durum-sayfasi
```

## CI/CD (GitHub Actions)

`main` dalına her `push` işleminde `.github/workflows/ci.yml` otomatik
tetiklenir:

1. **test** — statik dosya/config doğrulaması (bulut runner'ında)
2. **build-frontend** / **build-backend** — iki image paralel build
   edilir (self-hosted runner'da; PostgreSQL için ayrı bir build
   job'u yoktur çünkü resmi, hazır bir image kullanılır)
3. **deploy** — image'lar minikube'a yüklenir, tüm manifestler
   (namespace, secret, db, frontend, backend) `kubectl apply` ile
   uygulanır, her Deployment'ın rollout'u beklenir
4. **smoke-test** — dağıtım sonrası `/`, `/healthz`, `/api/status` ve
   `/api/guestbook` gerçekten doğru cevap veriyor mu, çalışan pod
   içinden test edilir

### Self-hosted runner gereksinimi

Bu proje şu an tamamen **yerel bir minikube cluster'ına** dağıtım
yaptığı için, GitHub'ın bulut runner'ları cluster'a erişemez. Bu
yüzden build/deploy/smoke-test aşamaları bir **self-hosted runner**
üzerinde çalışır (bkz. GitHub → Settings → Actions → Runners → New
self-hosted runner). Gerçek bir bulut cluster'ına taşınırsa bu
gereksinim ortadan kalkar.

### Güvenlik notu — Secret dosyası hakkında

`deploy/db-secret.yaml`, öğrenme/demo amacıyla veritabanı şifresini
düz metin olarak içerir ve bu repoda commitlenmiştir. **Gerçek bir
üretim projesinde şifreler asla bu şekilde bir public repoya
gönderilmemelidir** — bunun yerine CI/CD secret yönetimi (GitHub
Secrets, HashiCorp Vault, Sealed Secrets vb.) kullanılır.

## Kaldırma

```bash
kubectl delete -f deploy/backend.yaml
kubectl delete -f deploy/db.yaml
kubectl delete -f deploy/db-secret.yaml
kubectl delete -f deploy/service.yaml
kubectl delete -f deploy/deployment.yaml
kubectl delete -f deploy/namespace.yaml
docker compose down -v
```

## Dokümanlar

- [Mimari](docs/architecture.md)
- [ADR-001: Container seçimi](docs/adr-001-container-secimi.md)
- [Runbook: Site açılmıyor](docs/runbook-site-acilmiyor.md)