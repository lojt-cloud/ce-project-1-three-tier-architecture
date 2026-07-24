const http = require('http');
const net = require('net');

const PORT = process.env.PORT || 80;
const DB_HOST = process.env.DB_HOST || '10.0.21.10';
const DB_PORT = process.env.DB_PORT || 3306;

// Helper function to check TCP socket connectivity to Database
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

// Helper function to fetch IMDSv2 Metadata from EC2
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
  // 1. Health check endpoint for ALB
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy' }));
    return;
  }

  // 2. Fetch Metadata & Probe DB Status
  const instanceId = await getMetadata('instance-id');
  const az = await getMetadata('placement/availability-zone');
  const primaryDbOk = await checkTcpSocket(DB_HOST, DB_PORT);

  const dbBadge = primaryDbOk
    ? '<span style="background:#22c55e; color:#fff; padding:4px 12px; border-radius:12px; font-weight:bold;">CONNECTED (LIVE TCP 3306 OK)</span>'
    : '<span style="background:#ef4444; color:#fff; padding:4px 12px; border-radius:12px; font-weight:bold;">DISCONNECTED</span>';

  // 3. Render Main Web Page
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
<!DOCTYPE html>
<html>
<head>
  <title>Project 1: 3-Tier Enterprise Cloud App</title>
  <style>
    body { 
      font-family: Arial, sans-serif; 
      padding: 50px; 
      background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); 
      color: white; 
      text-align: center; 
    }
    .container { 
      background: rgba(255, 255, 255, 0.05); 
      padding: 30px; 
      border-radius: 10px; 
      backdrop-filter: blur(10px); 
      max-width: 700px; 
      margin: 0 auto; 
    }
    .tier { 
      margin: 20px 0; 
      padding: 15px; 
      background: rgba(255, 255, 255, 0.1); 
      border-radius: 8px; 
      text-align: left; 
    }
    .data { 
      color: #ffd700; 
      font-weight: bold; 
    }
    .info { 
      font-size: 14px; 
      color: #94a3b8; 
    }
    pre { 
      background: rgba(0, 0, 0, 0.4); 
      padding: 10px; 
      border-radius: 5px; 
      color: #38bdf8; 
      overflow-x: auto; 
      font-size: 14px; 
    }
    button {
      padding: 8px 16px; 
      background-color: #22c55e; 
      color: white; 
      border: none; 
      border-radius: 5px; 
      font-weight: bold; 
      cursor: pointer; 
      margin-top: 10px;
    }
    button:hover {
      background-color: #16a34a;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Production 3-Tier Architecture</h1>
    <p class="info">Instance ID: <b>${instanceId}</b> | AZ: <b>${az}</b></p>

    <div class="tier">
      <h2>Tier 1: Presentation Layer</h2>
      <p>Traffic routed via Application Load Balancer across Public Subnets.</p>
      
      <button onclick="checkHealth()">Check /health Status</button>
      <pre id="health-output" style="display: none; margin-top: 10px;"></pre>
    </div>

    <div class="tier">
      <h2>Tier 2: Application Layer</h2>
      <p>Node.js Runtime running on Private Subnet Auto Scaling Group.</p>
    </div>

    <div class="tier">
      <h2>Tier 3: Data Layer</h2>
      <p>Database Status: ${dbBadge}</p>
      <p>Target Database Host: <span class="data">${DB_HOST}:${DB_PORT}</span></p>
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
  `);
});

server.listen(PORT, () => {
  console.log(`App server running on port ${PORT}`);
});