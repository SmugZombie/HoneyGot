const fs = require('fs');
const https = require('https');
const express = require('express');
const path = require('path');

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'login.html'));
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'about.html'));
});

app.post('/login', (req, res) => {
  const { username, user, email, password, pass } = req.body || {};
  const u = username || user || email || '';
  console.log(`[origin] Login attempt from ${req.ip} user=${u}`);
  setTimeout(() => {
    res.status(200).send(`
      <html><head><title>Origin</title></head>
      <body style="font-family: system-ui, sans-serif">
        <h1>Origin received credentials</h1>
        <p>User: <b>${String(u).replace(/</g, "&lt;")}</b></p>
        <p>(Password hidden)</p>
        <p><a href="/">Back</a></p>
      </body></html>`);
  }, 100);
});

const key = fs.readFileSync(path.join(__dirname, 'privkey.pem'));
const cert = fs.readFileSync(path.join(__dirname, 'fullchain.pem'));
https.createServer({ key, cert }, app).listen(443, () => {
  console.log('[origin] HTTPS server listening on 443');
});
