const express = require('express');
const { Pool } = require('pg');
const os = require('os');

const app = express();
app.use(express.json());

// pg kutuphanesi, PGHOST/PGUSER/PGPASSWORD/PGDATABASE/PGPORT ortam
// degiskenlerini OTOMATIK okur -- kod icinde sifre yazmiyoruz.
const pool = new Pool();

async function ensureTable() {
    await pool.query(`
    CREATE TABLE IF NOT EXISTS guestbook (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      message TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

app.get('/api/status', (req, res) => {
    res.json({
        message: 'Merhaba, backend calisiyor!',
        pod: os.hostname(),
        timestamp: new Date().toISOString(),
    });
});

// Son 5 ziyaretci mesajini getir
app.get('/api/guestbook', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT id, name, message, created_at FROM guestbook ORDER BY created_at DESC LIMIT 5'
        );
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'veritabani hatasi' });
    }
});

// Yeni bir ziyaretci mesaji ekle
app.post('/api/guestbook', async (req, res) => {
    const { name, message } = req.body || {};
    if (!name || !message) {
        res.status(400).json({ error: 'name ve message zorunlu' });
        return;
    }
    try {
        await pool.query(
            'INSERT INTO guestbook (name, message) VALUES ($1, $2)',
            [name, message]
        );
        res.status(201).json({ ok: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'veritabani hatasi' });
    }
});

const PORT = 3000;

async function startWithRetry(maxDenemeSayisi = 10, bekleMs = 3000) {
    for (let deneme = 1; deneme <= maxDenemeSayisi; deneme++) {
        try {
            await ensureTable();
            app.listen(PORT, () => console.log(`Backend ${PORT} portunda calisiyor`));
            return;
        } catch (err) {
            console.log(`Veritabanina baglanilamadi (deneme ${deneme}/${maxDenemeSayisi}): ${err.message}`);
            if (deneme === maxDenemeSayisi) {
                console.error('Maksimum deneme sayisina ulasildi, cikiliyor.');
                process.exit(1);
            }
            await new Promise((resolve) => setTimeout(resolve, bekleMs));
        }
    }
}

startWithRetry();