# Runbook: Site Açılmıyor / Erişilemiyor

## Belirti
Kullanıcı `GET /` isteğine yanıt alamıyor (timeout, connection refused,
5xx veya sürekli 404).

## Adım 1 — Belirtiyi tekrar üret ve zamanı kaydet
```bash
date -u
curl -v http://localhost:8080/
# veya cluster içindeyse:
kubectl -n n2-durum port-forward svc/n2-durum-sayfasi 8080:80 &
curl -v http://localhost:8080/
```

## Adım 2 — Pod'ların durumuna bak (Running != Sağlıklı)
```bash
kubectl -n n2-durum get pods -o wide
kubectl -n n2-durum describe pods -l app=n2-durum-sayfasi
```
- `ImagePullBackOff` görülüyorsa → image tag/registry erişimi yanlış.
- `CrashLoopBackOff` görülüyorsa → Adım 4'e (loglar) geç.
- Pod `Running` ve `READY 1/1` ama yine erişilemiyorsa → Adım 3'e geç
  (Pod'un Running olması hizmetin çalıştığını kanıtlamaz).

## Adım 3 — Service / Endpoint / Label eşleşmesini kontrol et
```bash
kubectl -n n2-durum get endpoints n2-durum-sayfasi
kubectl -n n2-durum get pods --show-labels
kubectl -n n2-durum get svc n2-durum-sayfasi -o yaml | grep -A3 selector
```
Endpoint listesi boşsa: Service `selector` ile Pod `labels` alanı
eşleşmiyor demektir. En dar (minimum) değişiklikle selector veya
label'ı düzelt, tekrar kontrol et.

## Adım 4 — Loglara ve readiness probe geçmişine bak
```bash
kubectl -n n2-durum logs -l app=n2-durum-sayfasi --tail=100
kubectl -n n2-durum describe pod <pod-adı> | grep -A5 Events
```
Nginx config hatası varsa container başlarken hemen çöker; bu loglarda
görünür (örn. "unknown directive", "host not found").

## Olası nedenler → düzeltme
| Neden | Düzeltme |
|---|---|
| Service selector ≠ Pod label | `deploy/service.yaml` veya `deploy/deployment.yaml` label'ını düzelt, `kubectl apply -f deploy/` |
| Yanlış/var olmayan image tag | `deploy/deployment.yaml` içindeki `image:` alanını doğru tag ile güncelle |
| `/healthz` yolu yanlış yazılmış | `nginx/default.conf` ve probe `path` alanının birebir aynı olduğunu doğrula |
| Nginx config syntax hatası | `docker run --rm <image> nginx -t` ile config'i doğrula |

## Doğrulama
```bash
kubectl -n n2-durum rollout status deploy/n2-durum-sayfasi
bash scripts/smoke-test.sh http://localhost:8080
```
Her iki komut da başarıyla dönene kadar olay kapatılmaz.

## Önleme
- CI'a `kubectl apply --dry-run=server` veya bir manifest-lint adımı
  eklemek, selector/label uyuşmazlıklarını merge öncesi yakalar.
- `smoke-test.sh`'ın deploy sonrası otomatik çalışması, bu sınıf
  hataları insan fark etmeden pipeline'da yakalar.
