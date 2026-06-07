// Tiny zero-dependency static server for the Noum before/after preview.
// Prints standard "ready" lines to stdout so the Claude Preview harness detects it.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = '/Users/jordan/src/GitHub/Noum/.screenshots/2026-06-07_mockups/preview';
const PORT = 4322;
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

const server = http.createServer((req, res) => {
  let p = decodeURIComponent((req.url || '/').split('?')[0]);
  if (p === '/' || p === '') p = '/index.html';
  const fp = path.join(ROOT, p);
  if (!fp.startsWith(ROOT)) {
    res.writeHead(403);
    return res.end('forbidden');
  }
  fs.readFile(fp, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('not found');
    }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(fp)] || 'application/octet-stream' });
    res.end(data);
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('Local:   http://localhost:' + PORT + '/');
  console.log('ready - started server on http://localhost:' + PORT);
  console.log('Server listening on http://localhost:' + PORT);
});
