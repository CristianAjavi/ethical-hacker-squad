const express = require('express');
const router = express.Router();
const db = require('../lib/db');
const { fetchLogo } = require('../lib/remote');

// Invoice detail for the billing screen.
router.get('/invoices/:id', async (req, res) => {
  const invoice = await db.query('SELECT * FROM invoices WHERE id = $1', [req.params.id]);
  res.json(invoice);
});

// Receipt detail, used by the same screen.
router.get('/receipts/:id', async (req, res) => {
  const receipt = await db.query(
    'SELECT * FROM receipts WHERE id = $1 AND owner_id = $2',
    [req.params.id, req.user.id]
  );
  res.json(receipt);
});

// Invoice list, sortable from the table header.
router.get('/invoices', async (req, res) => {
  const order = req.query.order || 'created_at';
  const rows = await db.query(`SELECT * FROM invoices WHERE owner_id = $1 ORDER BY ${order}`, [req.user.id]);
  res.json(rows);
});

// Payment list, sortable from the table header.
const SORTABLE = { date: 'created_at', amount: 'total_cents' };
router.get('/payments', async (req, res) => {
  const column = SORTABLE[req.query.sort] || SORTABLE.date;
  const rows = await db.query(`SELECT * FROM payments WHERE owner_id = $1 ORDER BY ${column}`, [req.user.id]);
  res.json(rows);
});

// Branding preview: renders the customer logo before saving it.
router.post('/branding/preview', async (req, res) => {
  const image = await fetchLogo(req.body.logoUrl);
  res.type('image/png').send(image);
});

module.exports = router;
