#!/bin/bash
# 1. Ensure Node.js environment is ready
cd /home/ec2-user/app || cd /home/ec2-user || cd /var/www/html

# 2. Write the updated server.js file
cat << 'EOF' > server.js
const http = require('http');
const net = require('net');

const PORT = process.env.PORT || 80;
const PRIMARY_DB_HOST = process.env.DB_HOST || '10.0.21.10';
const STANDBY_DB_HOST = process.env.STANDBY_DB_HOST || '10.0.22.10';
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

async function getMetadata(path) {
  try {
    const tokenRes = await fetch("http://169.254.169.254/latest/api/token", {
      method: "PUT",
      headers: { "X-aws-ec2-metadata-token-ttl-seconds": "21600" }
    });
    const token = await tokenRes.text();
    const metaRes = await fetch(`http://169.254.169.254/latest/meta-data/${path}`, {
      headers: { "X-aws-ec2-metadata-token": token }
    });
    return await metaRes.text();
  } catch (e) {
    return "unknown";
  }
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ status: 'healthy' }));
    return;
  }

  const instanceId = await getMetadata('instance-id');
  const az = await getMetadata('placement/availability-zone');
  
  const primaryDbOk = await checkTcpSocket(PRIMARY_DB_HOST, DB_PORT);
  const standbyDbOk = await checkTcpSocket(STANDBY_DB_HOST, DB_PORT);

  const overallDbOk = primaryDbOk || standbyDbOk;
  const dbBadge = overallDbOk
    ? '<span style="background:#22c55e; color:#fff; padding:4px 12px; border-radius:12px; font-weight:bold;">CONNECTED</span>'
    : '<span style="background:#ef4444; color:#fff; padding:4px 12px; border-radius:12px; font-weight:bold;">DISCONNECTED</span>';

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Production 3-Tier Multi-AZ Architecture</title>
  <style>
    body { 
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; 
      padding: 40px 20px; 
      background-color: #0b1329; 
      color: #ffffff; 
      display: flex;
      justify-content: center;
    }
    .container { 
      background: #172036; 
      padding: 30px; 
      border-radius: 12px; 
      max-width: 650px; 
      width: 100%;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
    }
    h1 { margin-top: 0; font-size: 24px; }
    .subtitle { color: #94a3b8; font-size: 14px; margin-bottom: 25px; }
    .tier { margin: 15px 0; padding: 20px; background: #232d47; border-radius: 8px; text-align: left; }
    .tier h2 { margin-top: 0; font-size: 18px; }
    .tier p { margin: 8px 0; color: #cbd5e1; font-size: 14px; }
    .data { color: #38bdf8; font-weight: bold; }
    .offline { color: #38bdf8; font-weight: bold; }
    pre { background: #0b1329; padding: 12px; border-radius: 6px; color: #38bdf8; overflow-x: auto; font-size: 13px; border: 1px solid #334155; }
    button { padding: 8px 16px; background-color: #22c55e; color: white; border: none; border-radius: 6px; font-weight: bold; cursor: pointer; margin-top: 10px; }
    button:hover { background-color: #16a34a; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Production 3-Tier Multi-AZ Architecture</h1>
    <div class="subtitle">Project 1 - AWS Enterprise Infrastructure Deployment</div>

    <div class="tier">
      <h2>Tier 1: Presentation Layer</h2>
      <p>Traffic routed via Application Load Balancer across Public Subnets.</p>
      <button onclick="checkHealth()">Check /health Status</button>
      <pre id="health-output" style="display: none; margin-top: 10px;"></pre>
    </div>

    <div class="tier">
      <h2>Tier 2: Application Layer (Auto Scaling Group)</h2>
      <p>Instance ID: <span class="data">${instanceId}</span></p>
      <p>Availability Zone: <span class="data">${az}</span></p>
    </div>

    <div class="tier">
      <h2>Tier 3: Multi-AZ Data Layer</h2>
      <p>Database Status: ${dbBadge}</p>
      <p>Primary DB (us-east-1a): <span class="offline">${PRIMARY_DB_HOST} (${primaryDbOk ? 'ONLINE' : 'OFFLINE'})</span></p>
      <p>Standby DB (us-east-1b): <span class="offline">${STANDBY_DB_HOST} (${standbyDbOk ? 'ONLINE' : 'OFFLINE'})</span></p>
    </div>
  </div>

  <script>
    async function checkHealth() {
      try {
        const res = await fetch('/health');
        const data = await res.json();
        const box = document.getElementById('health-output');
        box.style.display = 'block';
        box.innerText = JSON.stringify(data, null, 2);
      } catch (e) {
        console.error('Failed to fetch health check status:', e);
      }
    }
  </script>
</body>
</html>
EOF

# 3. Kill any existing instance and launch the app
sudo pkill -f "node"
sudo PORT=80 node server.js &