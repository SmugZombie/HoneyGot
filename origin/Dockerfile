FROM node:20-alpine

WORKDIR /app
RUN apk add --no-cache openssl

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY server.js login.html about.html ./

RUN openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes   -keyout /app/privkey.pem -out /app/fullchain.pem   -subj "/CN=origin" -addext "subjectAltName=DNS:origin,IP:127.0.0.1"

EXPOSE 443
CMD ["node", "server.js"]
