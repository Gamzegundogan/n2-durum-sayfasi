# ADR-001: Container Base Image ve Build Stratejisi

## Durum
Kabul edildi

## Bağlam
Statik bir HTML/CSS sayfasını container içinde, root olmayan bir
kullanıcıyla, küçük bir image ile sunmamız gerekiyor. Derleme adımı
(compile/bundle) yok.

## Karar
- Base image: `nginxinc/nginx-unprivileged:1.27-alpine`
- Multi-stage build **kullanılmadı**.

## Alternatifler ve neden elenmedi
1. **Resmi `nginx:alpine` + manuel non-root ayarı**: mümkün ama
   `nginxinc/nginx-unprivileged` zaten bu işi doğru şekilde (8080 portu,
   yazma izinleri, PID dosyası konumu) çözmüş durumda. Kendi
   elimizle yeniden yapmak gereksiz risk (yanlış dosya izni, unutulan
   dizin) ekliyor.
2. **`node:alpine` veya build-stage ile statik dosya "derlemek"**:
   projede derlenecek bir şey yok (saf HTML/CSS, bundler/paket
   yöneticisi kullanılmıyor). Multi-stage burada karmaşıklık
   ekler, fayda sağlamaz -- bu yüzden bilinçli olarak
   uygulanmadı. İleride site bir framework'e (örn. bir SSG) geçerse
   bu karar yeniden değerlendirilmeli.
3. **`distroless` benzeri minimal image**: nginx binary'sini distroless
   üzerine oturtmak ekstra bakım yükü getiriyor; `alpine` tabanlı
   image de yeterince küçük (~20MB) ve güncel CVE takibi kolay.

## Sonuçlar
- (+) Image küçük, non-root garantisi image seviyesinde geliyor.
- (+) Tek aşamalı Dockerfile, okunması ve bakımı basit.
- (-) İleride derleme adımı gerekirse Dockerfile'ın yeniden
  yapılandırılması (multi-stage'e geçiş) gerekecek.
