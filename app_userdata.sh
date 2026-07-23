#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y nodejs stress

mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

cat << 'APP' > /home/ec2-user/app/server.js
const http = require('http');
const net = require('net');

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
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy' }));
    return;
  }

  const instanceId = await getMetadata('instance-id');
  const az = await getMetadata('placement/availability-zone');

  // Dynamically probe Primary DB on TCP 3306
  const primaryDbOk = await checkTcpSocket('10.0.21.10', 3306);

  const dbStatusBadge = primaryDbOk
    ? '<span style="background:#22c55e; color:#000; padding:4px 12px; border-radius:12px; font-weight:bold;">CONNECTED (LIVE TCP 3306 OK)</span>'
    : '<span style="background:#ef4444; color:#fff; padding:4px 12px; border-radius:12px; font-weight:bold;">DISCONNECTED</span>';

  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Project 1: 3-Tier Enterprise Cloud App</title>
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
        <p>Project 1 — AWS Enterprise Infrastructure Deployment</p>
        <div class="tier">
          <h2>📱 Tier 1: Presentation Layer</h2>
          <p>Traffic routed via Application Load Balancer across Public Subnets.</p>
        </div>
        <div class="tier">
          <h2>⚙️ Tier 2: Application Layer (Auto Scaling Group)</h2>
          <p>Instance ID: <span class="data">${instanceId}</span></p>
          <p>Availability Zone: <span class="data">${az}</span></p>
        </div>
        <div class="tier">
          <h2>💾 Tier 3: Data Layer (Private Subnet)</h2>
          <p>Database Status: ${dbStatusBadge}</p>
          <p>Primary DB (us-east-1a): <span class="data">10.0.21.10 (${primaryDbOk ? 'ONLINE' : 'OFFLINE'})</span></p>
        </div>
      </div>
    </body>
    </html>
  `);
});

server.listen(80, () => {
  console.log('App server running on port 80');
});
APP

cat << SERVICEFILE > /etc/systemd/system/nodeapp.service
[Unit]
Description=Tier 2 Node.js Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ec2-user/app
ExecStart=/usr/bin/node /home/ec2-user/app/server.js
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEFILE

systemctl daemon-reload
systemctl enable nodeapp
systemctl start nodeapp
