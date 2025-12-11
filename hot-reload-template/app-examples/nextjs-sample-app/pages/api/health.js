export default function handler(req, res) {
  res.status(200).json({ status: 'ok', service: 'nextjs-sample', timestamp: new Date().toISOString() });
}
