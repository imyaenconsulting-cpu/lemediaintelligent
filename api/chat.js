export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  const { message } = req.body;
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      system: 'Tu es un assistant IA du Média Intelligent. Tu informes sur l\'actualité mondiale de façon factuelle et neutre.',
      messages: [{ role: 'user', content: message }]
    })
  });
  const data = await response.json();
  res.json({ reply: data.content?.[0]?.text || 'Erreur' });
}
