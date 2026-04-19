export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { message } = req.body;
    if (!message) return res.status(400).json({ error: 'Message requis' });

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Clé API manquante' });

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1000,
        system: 'Tu es l assistant IA du Media Intelligent. Tu es expert en information mondiale, geopolitique, economie, technologie et OSINT. Tu analyses l actualite de facon factuelle et neutre. Tu luttes contre la desinformation. Tu reponds en moins de 150 mots, de maniere claire et directe. Tu reponds toujours dans la langue de l utilisateur.',
        messages: [{ role: 'user', content: message }]
      })
    });

    if (!response.ok) {
      const err = await response.json();
      return res.status(response.status).json({ error: err.error?.message || 'Erreur API' });
    }

    const data = await response.json();
    const reply = data.content?.[0]?.text || 'Pas de reponse disponible.';
    return res.status(200).json({ reply });

  } catch (error) {
    console.error('Erreur:', error);
    return res.status(500).json({ error: 'Erreur serveur: ' + error.message });
  }
}
