# syntax=docker/dockerfile:1
# Frontend Angular za nginx. Kontekst: rynek-frontend. Zapytania /api i /ws nginx przekazuje do bramy (GATEWAY_URL).
FROM node:24-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
ENV GATEWAY_URL=http://api-gateway:8080
# Obraz nginx podstawia zmienne środowiskowe do plików z /etc/nginx/templates (envsubst).
COPY <<'CONF' /etc/nginx/templates/default.conf.template
server {
    listen 80;
    root /usr/share/nginx/html;

    location /api/ {
        proxy_pass ${GATEWAY_URL};
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 50m;
    }

    location /ws/ {
        proxy_pass ${GATEWAY_URL};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 1h;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
CONF
COPY --from=build /src/dist/rynek-frontend/browser /usr/share/nginx/html
EXPOSE 80
