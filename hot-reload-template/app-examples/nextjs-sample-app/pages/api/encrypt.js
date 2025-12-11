const CryptoJS = require('crypto-js');

export default function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed. Use POST.' });
  }

  const { text } = req.body;
  
  if (!text) {
    return res.status(400).json({ error: 'Missing text field in request body' });
  }

  const encrypted = CryptoJS.AES.encrypt(text, 'secret-key-123').toString();
  
  res.status(200).json({
    original: text,
    encrypted: encrypted,
  });
}

