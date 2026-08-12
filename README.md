# N2 Durum Sayfası — Frontend + Backend, Kubernetes ve CI/CD

İki katmanlı (frontend + backend) bir örnek uygulama: statik bir durum
sayfası (Nginx) ile küçük bir Node.js API'si (backend), her ikisi de
non-root konteynerlerde çalışır, Kubernetes üzerinde declarative
(bildirimsel) yöntemle dağıtılır ve GitHub Actions ile uçtan uca
otomatikleştirilir (CI/CD).

## Mimari

```text
Tarayıcı
   │
   ▼
Nginx (frontend, 2 replica)
   ├─ statik siteyi sunar (/)
   ├─ sağlık kontrolü (/healthz)
   └─ /api/ isteklerini backend'e yönlendirir (reverse proxy)
         │
         ▼
   Backend Service (ClusterIP)
         │
         ▼
   Backend (Node.js, 2 replica) — /api/status: pod adı + zaman damgası döner
```

Her iki katman da ayrı Deployment/Service olarak Kubernetes'te çalışır,
birbirlerine Kubernetes'in kendi iç DNS'i (Service adı) üzerinden ulaşır.

## Ön koşullar

- Docker (Compose dahil)
- Bir Kubernetes cluster'ı ve `kubectl` (yerelde `minikube` önerilir,
  Windows'ta `--driver=docker` ile)
- `curl`

## Proje yapısı

```text
site/            → Statik frontend dosyaları (index.html, style.css)
nginx/           → Frontend'in Nginx yapılandırması (reverse proxy dahil)
backend/         → Node.js backend kaynak kodu ve Dockerfile'ı
deploy/          → Kubernetes manifestleri (Namespace, Deployment, Service)
scripts/         → Test ve smoke-test script'leri
docs/            → Mimari, ADR ve runbook dokümanları
.github/workflows/ci.yml → CI/CD pipeline tanımı
```

## Yerel çalıştırma (Docker Compose — sadece frontend)

```bash
docker compose up -d --build
curl http://localhost:8080/
curl http://localhost:8080/healthz
docker compose down
```

## Backend'i yerelde tek başına çalıştırma

```bash
docker build -t n2-backend:0.1.0 ./backend
docker run -d -p 3000:3000 n2-backend:0.1.0
curl http://localhost:3000/api/status
```

## Kubernetes'e dağıtım (frontend + backend)

1. Lokal cluster başlat (yoksa):
```bash
   minikube start --driver=docker
```
2. İmajları build et:
```bash
   docker build -t n2-durum-sayfasi:0.1.0 .
   docker build -t n2-backend:0.1.0 ./backend
```
3. minikube'a yükle:
```bash
   minikube image load n2-durum-sayfasi:0.1.0
   minikube image load n2-backend:0.1.0
```
4. Manifestleri uygula (declarative):
```bash
   kubectl apply -f deploy/namespace.yaml
   kubectl apply -f deploy/deployment.yaml
   kubectl apply -f deploy/service.yaml
   kubectl apply -f deploy/backend.yaml
   kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi
   kubectl -n n2-durum rollout status deploy/n2-backend
```
5. Görüntüle:
```bash
   minikube service n2-durum-sayfasi -n n2-durum
```
   Açılan sayfada, backend'den gelen canlı veri ("Backend cevap verdi ->
   Pod: ...") en üstte görünür. `/api/status` adresine giderek backend'in
   JSON cevabını doğrudan da görebilirsin.

## Yeni sürüm dağıtma / Rollback

```bash
kubectl -n n2-durum set image deploy/n2-durum-sayfasi site=n2-durum-sayfasi:<yeni-tag>
kubectl -n n2-durum set image deploy/n2-backend backend=n2-backend:<yeni-tag>
kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi
kubectl -n n2-durum rollout status deploy/n2-backend

# geçmiş / geri alma
kubectl -n n2-durum rollout history deploy/n2-durum-sayfasi
kubectl -n n2-durum rollout undo deploy/n2-durum-sayfasi
```

## CI/CD (GitHub Actions)

`main` dalına her `push` işleminde `.github/workflows/ci.yml` otomatik
tetiklenir:

1. **test** — statik dosya/config doğrulaması (bulut runner'ında)
2. **build-frontend** / **build-backend** — iki image paralel build edilir
   (self-hosted runner'da, çünkü sonraki adım yerel minikube'a erişmeli)
3. **deploy** — image'lar minikube'a yüklenir, manifestler `kubectl apply`
   ile uygulanır, Deployment'lar `kubectl set image` ile güncellenir,
   rollout'un tamamlanması beklenir
4. **smoke-test** — dağıtım sonrası `/`, `/healthz`, `/api/status` gerçekten
   doğru cevap veriyor mu, çalışan pod içinden test edilir

### Self-hosted runner gereksinimi

Bu proje şu an tamamen **yerel bir minikube cluster'ına** dağıtım yaptığı
için, GitHub'ın bulut runner'ları cluster'a erişemez. Bu yüzden
build/deploy/smoke-test aşamaları bir **self-hosted runner** üzerinde
çalışır — bu, projeyi klonlayan herkesin kendi bilgisayarında
`actions-runner` kurup GitHub'a bağlaması gerektiği anlamına gelir
(bkz. GitHub → Settings → Actions → Runners → New self-hosted runner).
Gerçek bir bulut cluster'ına (EKS/GKE) taşınırsa bu gereksinim ortadan
kalkar, bulut runner'ları yeterli olur.

## Kaldırma

```bash
kubectl delete -f deploy/backend.yaml
kubectl delete -f deploy/service.yaml
kubectl delete -f deploy/deployment.yaml
kubectl delete -f deploy/namespace.yaml
docker compose down -v
```

## Dokümanlar

- [Mimari](docs/architecture.md)
- [ADR-001: Container seçimi](docs/adr-001-container-secimi.md)
- [Runbook: Site açılmıyor](docs/runbook-site-acilmiyor.md)