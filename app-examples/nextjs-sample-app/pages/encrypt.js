import { useState } from 'react';
import CryptoJS from 'crypto-js';

export default function Encrypt() {
  const [input, setInput] = useState('');
  const [encrypted, setEncrypted] = useState('');
  const [error, setError] = useState('');

  const handleEncrypt = async () => {
    if (!input.trim()) {
      setError('Please enter some text');
      return;
    }

    try {
      const response = await fetch('/api/encrypt', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: input }),
      });

      const data = await response.json();
      
      if (response.ok) {
        setEncrypted(data.encrypted);
        setError('');
      } else {
        setError(data.error || 'Encryption failed');
      }
    } catch (err) {
      setError('Failed to encrypt: ' + err.message);
    }
  };

  return (
    <main style={{ fontFamily: 'sans-serif', padding: '2rem', maxWidth: '600px' }}>
      <h1>Encrypt Page</h1>
      <p>Encrypt text using crypto-js library.</p>
      
      <div style={{ marginTop: '1rem' }}>
        <label>
          <strong>Text to encrypt:</strong>
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            style={{
              width: '100%',
              minHeight: '100px',
              marginTop: '0.5rem',
              padding: '0.5rem',
              fontSize: '14px',
            }}
            placeholder="Enter text to encrypt..."
          />
        </label>
      </div>

      <button
        onClick={handleEncrypt}
        style={{
          marginTop: '1rem',
          padding: '0.5rem 1rem',
          fontSize: '16px',
          cursor: 'pointer',
        }}
      >
        Encrypt
      </button>

      {error && (
        <div style={{ marginTop: '1rem', color: 'red' }}>
          <strong>Error:</strong> {error}
        </div>
      )}

      {encrypted && (
        <div style={{ marginTop: '1rem', padding: '1rem', backgroundColor: '#f5f5f5', borderRadius: '4px' }}>
          <h3>Encrypted Result:</h3>
          <pre style={{ wordBreak: 'break-all', whiteSpace: 'pre-wrap' }}>{encrypted}</pre>
        </div>
      )}

      <p style={{ marginTop: '1rem' }}>
        <a href="/">Back to Home</a>
      </p>
    </main>
  );
}

