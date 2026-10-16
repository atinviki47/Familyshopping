module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET') return res.status(405).json({ error: 'GET only' });
  const key = process.env.PREJ_API_KEY;
  if (req.query.mode === 'status') return res.status(200).json({ configured: Boolean(key) });
  if (!key || !/^prej_[A-Za-z0-9_\-]+$/.test(key)) return res.status(503).json({ error: 'PREJ_API_KEY is not configured correctly in Vercel.' });
  const path = req.query.path;
  if (typeof path !== 'string' || !/^\/v1\/(stats|products(?:\/batch)?)$/.test(path)) return res.status(400).json({ error: 'Unsupported API path.' });
  const url = new URL('https://api.prej.app' + path);
  for (const [k,v] of Object.entries(req.query)) {
    if (k !== 'path' && typeof v === 'string' && /^[a-z_]+$/.test(k)) url.searchParams.set(k, v);
  }
  try {
    const upstream = await fetch(url, { headers: { Authorization: 'Bearer ' + key, Accept: 'application/json' }, signal: AbortSignal.timeout(12000) });
    const contentType = upstream.headers.get('content-type') || '';
    if (!contentType.includes('json')) return res.status(502).json({ error: 'Prej returned a non-JSON response.' });
    const data = await upstream.json();
    return res.status(upstream.status).json(data);
  } catch (error) {
    return res.status(502).json({ error: 'Could not contact Prej. Please try again.' });
  }
};
