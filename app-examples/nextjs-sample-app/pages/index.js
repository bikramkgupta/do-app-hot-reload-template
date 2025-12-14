import { useEffect, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';

export default function Home() {
  const [randomId, setRandomId] = useState('');

  useEffect(() => {
    // Generate client-side to avoid hydration mismatches
    setRandomId(uuidv4());
  }, []);

  return (
    <main style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <h1>Next.js Sample App</h1>
      <p>This is a minimal Next.js app for DigitalOcean App Platform testing.</p>
      <p>Health endpoint: <code>/api/health</code></p>
      <p>Random ID (uuid): {randomId || 'generating...'}</p>
    </main>
  );
}
