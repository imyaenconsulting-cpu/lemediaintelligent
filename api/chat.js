export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();
  try {
    const { message } = req.body;
    if (!message) return res.status(400).json({ error: 'Message vide' });
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-opus-4-6',
        max_tokens: 500,
        messages: [{ role: 'user', content: message }]
      })
    });
    const d = await r.json();
    if (!r.ok) return res.status(r.status).json({ error: JSON.stringify(d) });
    return res.status(200).json({ reply: d.content[0].text });
  } catch(e) {
    return res.status(500).json({ error: e.message });
  }
}
