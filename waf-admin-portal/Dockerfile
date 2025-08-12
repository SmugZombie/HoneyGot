# Build stage
FROM node:20-alpine AS build
WORKDIR /app

# copy manifests first for better caching
COPY package.json package-lock.json* ./

# install deps (dev deps included for build)
RUN npm install --no-audit --no-fund

# copy the rest
COPY index.html vite.config.js ./
COPY src ./src
COPY public ./public

# optional default API base baked at build
ARG VITE_API_BASE
ENV VITE_API_BASE=${VITE_API_BASE}

RUN npm run build

# Runtime: serve static bundle with nginx
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
RUN printf '%s\n' \
  'server {' \
  '  listen 80;' \
  '  server_name _;' \
  '  add_header Cache-Control "no-store";' \
  '  root /usr/share/nginx/html;' \
  '  location / { try_files $uri /index.html; }' \
  '}' > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
