import Anthropic from '@anthropic-ai/sdk';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();
  
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const { message } = req.body;
  
  const msg = await client.messages.create({
    model: 'claude-3-haiku-20240307',
    max_tokens: 500,
    messages: [{ role: 'user', content: message }]
  });
  
  return res.status(200).json({ reply: msg.content[0].text });
}
