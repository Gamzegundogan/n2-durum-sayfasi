# Mimari

```text
Geliştirici
    |
    v  (git push / PR)
CI: test.sh -> docker build -> trivy scan -> [main/tag] registry push
    |
    v  (main'e merge sonrası, kontrollü)
kubectl apply -f deploy/  +  kubectl set image (yeni SHA/tag)
    |
    v
Namespace: n2-durum
  Service (ClusterIP, port 80 -> targetPort 8080)
    |
    v
  Deployment (2 replica, RollingUpdate maxUnavailable=0)
    -> Pod (nginx-unprivileged, non-root UID 101)
         GET /          -> statik durum sayfası (200)
         GET /healthz   -> sabit 200
         diğer yollar   -> 404
```

## Bileşenler ve gerekçeleri

- **Nginx (unprivileged image)**: statik içerik sunumu için endüstri
  standardı, küçük ve olgun bir web server. `nginxinc/nginx-unprivileged`
  varyantı root gerektirmeden 8080 portunda çalışabiliyor, bu da ayrı bir
  non-root kullanıcı kurma zahmetini ortadan kaldırıyor.
- **Tek aşamalı Dockerfile**: derlenecek kaynak kod yok (saf HTML/CSS),
  bu yüzden multi-stage build'in getirisi yok. Ayrıntı:
  `docs/adr-001-container-secimi.md`.
- **ClusterIP Service**: bu aşamada dışarıdan (cluster dışı) erişim
  gereksinimi yok; Ingress bilinçli olarak kapsam dışı bırakıldı.
  Erişim `kubectl port-forward` ile sağlanıyor. Gerçek bir üretim
  ortamında Ingress/LoadBalancer eklenir.
- **2 replica + RollingUpdate (maxUnavailable=0)**: tek pod'un
  yeniden başlaması ya da düğüm bakımı sırasında kesinti olmaması
  için. `maxUnavailable: 0` yeni pod hazır olmadan eskisinin
  kapanmamasını garanti eder.
- **Requests/limits**: statik nginx'in gerçek kaynak kullanımı çok
  düşük (tek dijit CPU milli-core, birkaç MB bellek). `docker stats`
  ile lokal ölçüm sonrası `requests: 20m/32Mi`, `limits: 100m/64Mi`
  seçildi -- ani trafik artışında OOM'a girmeyecek kadar geniş,
  ama node kaynağını gereksiz rezerve etmeyecek kadar dar.
