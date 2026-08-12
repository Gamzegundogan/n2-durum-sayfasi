// Basit bir Node.js sunucusu -- hicbir ek kutuphane (npm paketi) kullanmiyoruz,
// boylece Dockerfile daha basit oluyor (npm install gerekmez).
const http = require('http');
const os = require('os');

const server = http.createServer((req, res) => {
    if (req.url === '/api/status' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            message: 'Merhaba, backend calisiyor!',
            pod: os.hostname(),
            timestamp: new Date().toISOString()
        }));
        return;
    }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'bulunamadi' }));
});

server.listen(3000, () => {
    console.log('Backend 3000 portunda calisiyor');
});