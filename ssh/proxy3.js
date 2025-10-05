/*
 * Proxy Bridge (Robust Version)
 * Original Author: PANCHO7532 - P7COMUnications LLC (c) 2021
 * Modified by gilper0x & AI Assistant
 */

const net = require("net");
const { Writable, Duplex, pipeline } = require("stream");
const { argv } = process;

// --- Configuration Defaults ---
let dhost = "127.0.0.1";    // Destination host
let dport = null;            // Destination port
let mainPort = null;         // Local listening port
let packetsToSkip = 0;       // Number of initial packets to ignore (obfuscation)

// --- Argument Parsing ---
for (let i = 0; i < argv.length; i++) {
  switch (argv[i]) {
    case "-skip":
      packetsToSkip = parseInt(argv[i + 1], 10) || 0;
      break;
    case "-dhost":
      dhost = argv[i + 1];
      break;
    case "-dport":
      dport = parseInt(argv[i + 1], 10);
      break;
    case "-mport":
      mainPort = parseInt(argv[i + 1], 10);
      break;
  }
}

// --- Validation ---
if (!dport || !mainPort) {
  console.error("[FATAL] Missing required arguments: -dport and -mport");
  process.exit(1);
}

// --- Custom Stream for Packet Skipping ---
class SkipStream extends Duplex {
    constructor(skipCount, options) {
        super(options);
        this.skipCount = skipCount;
        this.packetCount = 0;
    }

    // Handle data coming from the client (readable side)
    _write(chunk, encoding, callback) {
        if (this.packetCount < this.skipCount) {
            this.packetCount++;
            // Log the skipped data (optional)
            // console.log(`[SKIP] Skipping packet #${this.packetCount}`);
        } else {
            // Push data to the destination (writable side)
            this.push(chunk);
        }
        callback();
    }

    _read(size) {
        // We don't implement a readable side, data is pushed via _write
    }
}

// --- Proxy Server Logic ---
const server = net.createServer((clientSocket) => {
    const clientAddr = `${clientSocket.remoteAddress}:${clientSocket.remotePort}`;
    console.log(`[INFO] New connection from ${clientAddr}`);

    // 1. Send Handshake (Fake HTTP Upgrade)
    const handshakeHeader = "HTTP/1.1 101 Switching Protocols\r\nContent-Length: 1048576000000\r\n\r\n";
    
    // Use write with a callback to handle errors and ensure header is sent
    clientSocket.write(handshakeHeader, (err) => {
        if (err) {
            console.error(`[ERROR] Failed handshake to ${clientAddr}: ${err.message}`);
            clientSocket.destroy();
        }
    });

    // 2. Connect to Remote Destination
    const remoteConn = net.createConnection({ host: dhost, port: dport });

    // 3. Setup Proxy Pipeline
    const skipStream = new SkipStream(packetsToSkip);

    // Pipeline: ClientSocket (Readable) -> SkipStream (Duplex) -> RemoteConn (Writable)
    pipeline(
        clientSocket,
        skipStream,
        remoteConn,
        (err) => {
            if (err) {
                if (err.code !== 'ECONNRESET' && err.code !== 'EPIPE') {
                    console.error(`[PROXY] Client->Remote pipeline error for ${clientAddr}: ${err.message}`);
                }
            }
        }
    );

    // Pipe: RemoteConn (Readable) -> ClientSocket (Writable)
    // Use simple .pipe() for the remote->client path as no transformation is needed.
    remoteConn.pipe(clientSocket);

    // --- Cleanup & Error Handling ---

    // Remote errors should destroy both ends
    remoteConn.on("error", (err) => {
        console.error(`[REMOTE] Error from ${dhost}:${dport}: ${err.message}`);
        clientSocket.destroy();
    });

    // Client errors or close events trigger cleanup
    clientSocket.on("error", (err) => {
        if (err.code !== 'ECONNRESET') {
            console.error(`[CLIENT] Error from ${clientAddr}: ${err.message}`);
        }
    });
    
    clientSocket.on("close", () => {
        console.log(`[INFO] Client disconnected ${clientAddr}`);
        remoteConn.destroy(); // Ensure remote connection is also closed
    });

    // Clean up if remote connection closes first
    remoteConn.on("close", () => {
        clientSocket.destroy();
    });
});

// --- Server Events & Startup ---
server.on("error", (err) => {
  console.error(`[SRV] Fatal Server Error on port ${mainPort}: ${err.message}`);
  // If the port is in use (EADDRINUSE), exit
  if (err.code === 'EADDRINUSE') {
      process.exit(1);
  }
});

server.listen(mainPort, () => {
  console.log(`[INFO] Proxy bridge started successfully.`);
  console.log(`[INFO] Listening on port: ${mainPort}`);
  console.log(`[INFO] Proxying to: ${dhost}:${dport}`);
  console.log(`[INFO] Initial packets to skip: ${packetsToSkip}`);
});