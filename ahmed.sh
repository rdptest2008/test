#!/bin/bash
set -euo pipefail

tmux new -d -s work3

mkdir -p x
cd x

openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=ea.com"

wget -q https://www.7-zip.org/a/7z2501-linux-x64.tar.xz
tar -xf 7z2501-linux-x64.tar.xz

SEVENZ_BIN=$(find . -maxdepth 2 -type f -name '7zz' -print -quit)
if [ -z "$SEVENZ_BIN" ]; then
  echo "7zz not found"
  exit 1
fi
chmod +x "$SEVENZ_BIN"

wget -q https://github.com/XTLS/Xray-core/releases/download/v25.9.11/Xray-linux-64.zip

"$SEVENZ_BIN" x Xray-linux-64.zip >/dev/null

XRAY_BIN=$(find . -maxdepth 3 -type f -name 'xray' -print -quit)
if [ -z "$XRAY_BIN" ]; then
  echo "xray not found"
  exit 1
fi
chmod +x "$XRAY_BIN"

cat <<'EOF' > config.json
{
  "log": {
    "access": "access.log",
    "error": "error.log",
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "tag": "vless-in",
      "port": 5555,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "7c6de543-881b-4582-8017-9e1fe8c90d64",
            "level": 0,
            "email": "user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "certificates": [
            {
              "certificateFile": "cert.pem",
              "keyFile": "key.pem"
            }
          ],
          "minVersion": "1.2",
          "maxVersion": "1.3",
          "preferServerCipherSuites": true
        },
        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true,
          "tcpKeepAliveIdle": 2000,
          "tcpKeepAliveInterval": 10000,
          "mark": 255
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "streamSettings": {
        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true
        }
      }
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 0,
        "downlinkOnly": 0
      }
    },
    "system": {
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": []
  },
  "dns": {
    "servers": ["1.1.1.1", "8.8.8.8", "9.9.9.9"]
  }
}
EOF

"$XRAY_BIN" -c config.json &

echo "✅ done"
