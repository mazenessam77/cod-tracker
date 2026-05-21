/* ============================================
   Call of Duty Achievement Tracker — REST API
   Node.js · Express · MySQL2
   ============================================ */

const express = require('express');
const cors    = require('cors');
const mysql   = require('mysql2/promise');

const app  = express();
const PORT = process.env.PORT || 5000;

/* ---------- Middleware ---------- */
app.use(cors());
app.use(express.json());

// Request logger — METHOD URL STATUS duration_ms
app.use((req, res, next) => {
  const t0 = Date.now();
  res.on('finish', () => {
    console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - t0}ms`);
  });
  next();
});

/* ---------- Database Pool ---------- */
const pool = mysql.createPool({
  host:     process.env.DB_HOST     || 'localhost',
  user:     process.env.DB_USER     || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME     || 'cod_tracker',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

/* ---------- Auto-create table on startup ---------- */
async function initDatabase() {
  const createTableSQL = `
    CREATE TABLE IF NOT EXISTS achievements (
      id         INT            AUTO_INCREMENT PRIMARY KEY,
      title      VARCHAR(255)   NOT NULL,
      map        VARCHAR(255)   DEFAULT NULL,
      kills      INT            DEFAULT 0,
      notes      TEXT           DEFAULT NULL,
      createdAt  TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `;

  try {
    const conn = await pool.getConnection();
    await conn.execute(createTableSQL);
    conn.release();
    console.log('Database table "achievements" is ready.');
  } catch (err) {
    console.error('Could not initialize database:', err.message);
    process.exit(1);
  }
}

/* ============================================
   ROUTES
   ============================================ */

/**
 * GET /api/achievements
 * Returns all achievement records, newest first.
 */
app.get('/api/achievements', async (_req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT * FROM achievements ORDER BY createdAt DESC'
    );
    res.json(rows);
  } catch (err) {
    console.error('GET /api/achievements error:', err.message);
    res.status(500).json({ error: 'Failed to fetch achievements.' });
  }
});

/**
 * POST /api/achievements
 * Creates a new achievement record.
 * Body: { title, map?, kills?, notes? }
 */
app.post('/api/achievements', async (req, res) => {
  const { title, map, kills, notes } = req.body;

  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Title is required.' });
  }

  try {
    const [result] = await pool.execute(
      'INSERT INTO achievements (title, map, kills, notes) VALUES (?, ?, ?, ?)',
      [title.trim(), map?.trim() || null, parseInt(kills, 10) || 0, notes?.trim() || null]
    );

    // Return the newly created record so the frontend can render it immediately
    const [rows] = await pool.execute(
      'SELECT * FROM achievements WHERE id = ?',
      [result.insertId]
    );

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('POST /api/achievements error:', err.message);
    res.status(500).json({ error: 'Failed to create achievement.' });
  }
});

/**
 * DELETE /api/achievements/:id
 * Removes a single achievement by ID.
 */
app.delete('/api/achievements/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const [result] = await pool.execute(
      'DELETE FROM achievements WHERE id = ?',
      [id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Achievement not found.' });
    }

    res.json({ message: 'Achievement deleted.', id });
  } catch (err) {
    console.error('DELETE /api/achievements/:id error:', err.message);
    res.status(500).json({ error: 'Failed to delete achievement.' });
  }
});

/* ---------- 404 catch-all ---------- */
app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found.' });
});

/* ============================================
   START SERVER
   ============================================ */
async function start() {
  await initDatabase();
  app.listen(PORT, () => {
    console.log(`COD Tracker API running on port ${PORT}`);
  });
}

start();
