const escapeHtml = require('escape-html');

// Free-text note the customer typed on the invoice.
function invoiceNote(note) {
  return `<div class="note">${note}</div>`;
}

// Customer name in the invoice header.
function customerName(name) {
  return `<span class="name">${escapeHtml(name)}</span>`;
}

// Page footer.
function footer(year) {
  return `<footer>Invoices ${Number(year)}</footer>`;
}

module.exports = { invoiceNote, customerName, footer };
