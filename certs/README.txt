Place your TLS certificate chain in fullchain.pem and private key in privkey.pem.

# From the project root
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout certs/privkey.pem -out certs/fullchain.pem \
  -subj "/CN=waf.local" \
  -addext "subjectAltName=DNS:waf.local,DNS:localhost,IP:127.0.0.1"

Use names you’ll actually hit (replace waf.local, add more DNS:/IP: entries if needed).