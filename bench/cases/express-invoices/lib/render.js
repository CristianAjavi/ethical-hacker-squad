const escapeHtml = require('escape-html');

// Planted: the note is interpolated into HTML without escaping.
function invoiceNote(note) {
  return `<div class="note">${note}</div>`;
}

// Decoy: same shape, escaped at the sink.
function customerName(name) {
  return `<span class="name">${escapeHtml(name)}</span>`;
}

// Decoy: a template literal built entirely from server constants.
function footer(year) {
  return `<footer>Invoices ${Number(year)}</footer>`;
}

module.exports = { invoiceNote, customerName, footer };
