const express = require('express');
const router = express.Router();
const db = require('../lib/db');
const { fetchLogo } = require('../lib/remote');

// Planted: object-level authorization missing. The id is bound, and nothing
// checks whose invoice it is.
router.get('/invoices/:id', async (req, res) => {
  const invoice = await db.query('SELECT * FROM invoices WHERE id = $1', [req.params.id]);
  res.json(invoice);
});

// Decoy: looks like the same bug, and the queryset is scoped to the caller.
router.get('/receipts/:id', async (req, res) => {
  const receipt = await db.query(
    'SELECT * FROM receipts WHERE id = $1 AND owner_id = $2',
    [req.params.id, req.user.id]
  );
  res.json(receipt);
});

// Planted: the order column is interpolated into SQL.
router.get('/invoices', async (req, res) => {
  const order = req.query.order || 'created_at';
  const rows = await db.query(`SELECT * FROM invoices WHERE owner_id = $1 ORDER BY ${order}`, [req.user.id]);
  res.json(rows);
});

// Decoy: interpolation from a closed allowlist, never from the request.
const SORTABLE = { date: 'created_at', amount: 'total_cents' };
router.get('/payments', async (req, res) => {
  const column = SORTABLE[req.query.sort] || SORTABLE.date;
  const rows = await db.query(`SELECT * FROM payments WHERE owner_id = $1 ORDER BY ${column}`, [req.user.id]);
  res.json(rows);
});

// Planted: server-side request forgery, the URL comes from the body.
router.post('/branding/preview', async (req, res) => {
  const image = await fetchLogo(req.body.logoUrl);
  res.type('image/png').send(image);
});

module.exports = router;
