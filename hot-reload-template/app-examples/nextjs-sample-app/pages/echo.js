import { useRouter } from 'next/router';

export default function Echo() {
  const router = useRouter();
  const { query } = router;

  return (
    <main style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
      <h1>Echo Page</h1>
      <p>This page displays query parameters.</p>
      <div style={{ marginTop: '1rem', padding: '1rem', backgroundColor: '#f5f5f5', borderRadius: '4px' }}>
        <h2>Query Parameters:</h2>
        <pre>{JSON.stringify(query, null, 2)}</pre>
      </div>
      <p style={{ marginTop: '1rem' }}>
        <a href="/">Back to Home</a>
      </p>
    </main>
  );
}

