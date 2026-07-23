const http = require('http');
const net = require('net');

const DB_HOST = process.env.DB_HOST || '10.0.21.10';
const DB_PORT = process.env.DB_PORT || 3306;

function checkTcpSocket(host, port, timeout = 500) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    socket.setTimeout(timeout);
    socket.on('connect', () => { socket.destroy(); resolve(true); });
    socket.on('error', () => { socket.destroy(); resolve(false); });
    socket.on('timeout', () => { socket.destroy(); resolve(false); });
    socket.connect(port, host);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
    return;
  }

  const dbConnected = await checkTcpSocket(DB_HOST, DB_PORT);
  const dbBadge = dbConnected 
    ? '<span style="background:#22c55e; color:#000; padding:4px 12px; border-radius:12px; font-weight:bold;">CONNECTED (LIVE TCP 3306 OK)</span>'
    : '<span style="background:#ef4444; color:#fff; padding:4px 12px; border-radius:12px; font-weight:bold;">DISCONNECTED</span>';

  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>3-Tier Enterprise Architecture</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 40px; background: #0f172a; color: #f8fafc; }
        .container { max-width: 800px; margin: auto; background: #1e293b; padding: 30px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        .tier { margin: 20px 0; padding: 20px; background: #334155; border-radius: 8px; border-left: 5px solid #38bdf8; }
        .data { color: #38bdf8; font-weight: bold; font-family: monospace; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🏗️ Production 3-Tier Architecture</h1>
        <div class="tier">
          <h2>📱 Tier 1: Presentation Layer</h2>
          <p>Traffic routed via Application Load Balancer across Public Subnets.</p>
        </div>
        <div class="tier">
          <h2>⚙️ Tier 2: Application Layer</h2>
          <p>Node.js Runtime running on Private Subnet Auto Scaling Group.</p>
        </div>
        <div class="tier">
          <h2>💾 Tier 3: Data Layer</h2>
          <p>Database Status: ${dbBadge}</p>
          <p>Target Database Host: <span class="data">${DB_HOST}:${DB_PORT}</span></p>
        </div>
      </div>
    </body>
    </html>
  `);
});

server.listen(80, () => {
  console.log('App server running on port 80');
});
