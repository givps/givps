/*
 * Proxy Bridge (Cleaner Version)
 * Original Author: PANCHO7532 - P7COMUnications LLC (c) 2021
 * Modified by gilper0x
 */

const net = require("net");

// Default configuration
let dhost = "127.0.0.1";    // Destination host
let dport = null;            // Destination port
let mainPort = null;         // Local listening port
let packetsToSkip = 0;       // Number of initial packets to ignore
let gcwarn = true;           // Garbage collector warning flag

// Parse command line arguments
for (let c = 0; c < process.argv.length; c++) {
  switch (process.argv[c]) {
    case "-skip":
      packetsToSkip = parseInt(process.argv[c + 1], 10) || 0;
      break;
    case "-dhost":
      dhost = process.argv[c + 1];
      break;
    case "-dport":
      dport = parseInt(process.argv[c + 1], 10);
      break;
    case "-mport":
      mainPort = parseInt(process.argv[c + 1], 10);
      break;
  }
}

// Validate required arguments
if (!dport || !mainPort) {
  console.error("[ERROR] Missing required arguments: -dport and -mport");
  process.exit(1);
}

// Garbage collector function
function gcollector() {
  if (global.gc) {
    global.gc();
  } else if (gcwarn) {
    console.warn("[WARN] Garbage Collector not enabled! Start Node.js with --expose-gc");
    gcwarn = false;
  }
}
setInterval(gcollector, 10000); // Run every 10 seconds to avoid spam

// Proxy server
const server = net.createServer((socket) => {
  let packetCount = 0;

  console.log(`[INFO] Connection from ${socket.remoteAddress}:${socket.remotePort}`);

  // Send handshake (fake HTTP upgrade)
  socket.write(
    "HTTP/1.1 101 Switching Protocols\r\nContent-Length: 1048576000000\r\n\r\n",
    (err) => {
      if (err) console.error("[ERROR] Failed handshake:", err.message);
    }
  );

  // Connect to remote host
  const conn = net.createConnection({ host: dhost, port: dport });

  // Client → Remote
  socket.on("data", (data) => {
    if (packetCount < packetsToSkip) {
      packetCount++;
      return;
    }
    conn.write(data, (err) => {
      if (err) console.error("[EWRITE] Failed client→remote:", err.message);
    });
  });

  // Remote → Client
  conn.on("data", (data) => {
    socket.write(data, (err) => {
      if (err) console.error("[EWRITE] Failed remote→client:", err.message);
    });
  });

  // Error handling
  socket.on("error", (err) => {
    console.error(`[SOCKET] ${err.message} from ${socket.remoteAddress}:${socket.remotePort}`);
    conn.destroy();
  });
  conn.on("error", (err) => {
    console.error("[REMOTE] " + err.message);
    socket.destroy();
  });

  // Cleanup on close
  socket.on("close", () => {
    console.log(`[INFO] Client disconnected ${socket.remoteAddress}:${socket.remotePort}`);
    conn.destroy();
  });
  conn.on("close", () => {
    socket.destroy();
  });
});

// Server events
server.on("error", (err) => {
  console.error("[SRV] Error:", err.message);
});

// Start listening
server.listen(mainPort, () => {
  console.log(`[INFO] Proxy listening on port ${mainPort}`);
  console.log(`[INFO] Redirecting traffic to ${dhost}:${dport}`);
});
