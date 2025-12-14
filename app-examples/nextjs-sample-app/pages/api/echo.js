export default function handler(req, res) {
  res.status(200).json({
    method: req.method,
    path: req.url,
    query: req.query,
  });
}

