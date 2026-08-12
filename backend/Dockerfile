# node:20-alpine -- kucuk boyutlu, resmi Node.js image'i.
# Icinde zaten root olmayan "node" adli bir kullanici hazir geliyor.
FROM node:20-alpine

WORKDIR /app
COPY server.js .

# Root olmayan, image'in kendi hazir kullanicisiyla calis.
USER node

EXPOSE 3000
CMD ["node", "server.js"]