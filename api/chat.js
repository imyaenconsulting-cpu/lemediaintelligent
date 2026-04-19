const https = require('https');

module.exports = function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  let body = '';
  req.on('data', chunk => { body += chunk; });
  req.on('end', () => {
    let message = '';
    try { message = JSON.parse(body).message; } catch(e) {}
    
    if (!message) { res.status(400).json({ error: 'Message vide' }); return; }

    const data = JSON.stringify({
      model: 'claude-3-haiku-20240307',
      max_tokens: 500,
      messages: [{ role: 'user', content: message }]
    });

    const options = {
      hostname: 'api.anthropic.com',
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Length': Buffer.byteLength(data)
      }
    };

    const apiReq = https.request(options, apiRes => {
      let result = '';
      apiRes.on('data', chunk => { result += chunk; });
      apiRes.on('end', () => {
        try {
          const parsed = JSON.parse(result);
          if (parsed.content && parsed.content[0]) {
            res.status(200).json({ reply: parsed.content[0].text });
          } else {
            res.status(500).json({ error: result });
          }
        } catch(e) { res.status(500).json({ error: result }); }
      });
    });

    apiReq.on('error', e => res.status(500).json({ error: e.message }));
    apiReq.write(data);
    apiReq.end();
  });
};
