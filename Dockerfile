# nginxinc/nginx-unprivileged: resmi nginx image'ının root gerektirmeyen
# resmi varyantı. Statik dosya sunduğumuz için ayrı bir build aşamasına
# (multi-stage) ihtiyaç yok -- derlenecek kod yok, bu yüzden tek aşama
# kullanılıyor (gerekçe: docs/adr-001-container-secimi.md).
FROM nginxinc/nginx-unprivileged:1.27-alpine

# İzlenebilirlik için build zamanında verilecek, imajı git commit'ine
# bağlayan etiket (docker build --build-arg GIT_SHA=$(git rev-parse --short HEAD))
ARG GIT_SHA=unknown
LABEL org.opencontainers.image.revision="${GIT_SHA}" \
    org.opencontainers.image.title="n2-durum-sayfasi"

# Varsayılan nginx config'in yerine kendi config'imizi koyuyoruz
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Statik siteyi kopyala
COPY site/ /usr/share/nginx/html/

# nginx-unprivileged imajı zaten "nginx" adlı, root olmayan sabit UID'li
# (101) bir kullanıcı ile geliyor ve varsayılan kullanıcı olarak onu
# kullanıyor -- ayrıca USER satırına gerek yok, ama açıkça belirtelim:
USER 101

EXPOSE 8080

# Container'ın gerçekten trafik verebildiğini kontrol eder (Docker/Compose
# seviyesinde; Kubernetes'te ayrıca readiness/liveness probe kullanılacak)
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
