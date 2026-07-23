const http = require('http');

const INSTANCE_ID = process.env.INSTANCE_ID || 'unknown-instance';
const DB_HOST = process.env.DB_HOST || '10.0.21.10';

function queryDatabase() {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        users: 42,
        posts: 156,
        lastUpdate: new Date().toISOString()
      });
    }, 100);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({ status: 'healthy', instance: INSTANCE_ID }));
    return;
  }

  if (req.url === '/api/stats') {
    const dbData = await queryDatabase();
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      instance: INSTANCE_ID,
      database: DB_HOST,
      data: dbData
    }));
    return;
  }

  const dbData = await queryDatabase();
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>3-Tier Application</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 10px; backdrop-filter: blur(10px); }
        .tier { margin: 20px 0; padding: 15px; background: rgba(255,255,255,0.2); border-radius: 5px; }
        .data { color: #ffd700; font-weight: bold; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🏗️ 3-Tier Architecture Demo</h1>
        
        <div class="tier">
          <h2>📱 Tier 1: Presentation Layer</h2>
          <p>You're seeing this through the Application Load Balancer</p>
        </div>
        
        <div class="tier">
          <h2>⚙️ Tier 2: Application Layer</h2>
          <p>Served by Application Server</p>
          <p class="data">Instance: ${INSTANCE_ID}</p>
        </div>
        
        <div class="tier">
          <h2>💾 Tier 3: Data Layer</h2>
          <p>Database Information:</p>
          <p class="data">Database Host: ${DB_HOST}</p>
          <p class="data">Total Users: ${dbData.users}</p>
          <p class="data">Total Posts: ${dbData.posts}</p>
          <p class="data">Last Update: ${dbData.lastUpdate}</p>
        </div>
        
        <p style="margin-top: 30px; text-align: center; opacity: 0.8;">
          🎓 Cloud Engineering Bootcamp - Week 3 Lab
        </p>
      </div>
    </body>
    </html>
  `);
});

server.listen(80, () => {
  console.log(`App server running on port 80 (Instance: ${INSTANCE_ID})`);
});