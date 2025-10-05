#!/bin/bash
set -euo pipefail

tmux new -s work3

mkdir -p x
cd x

openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=ea.com"

wget https://www.7-zip.org/a/7z2501-linux-x64.tar.xz
tar -xvf 7z2501-linux-x64.tar.xz

SEVENZ_BIN=$(find . -maxdepth 2 -type f -name '7zz' -print -quit)
if [ -z "$SEVENZ_BIN" ]; then
  echo "7zz not found"
  exit 1
fi
chmod +x "$SEVENZ_BIN"

wget https://github.com/XTLS/Xray-core/releases/download/v25.9.11/Xray-linux-64.zip

"$SEVENZ_BIN" x Xray-linux-64.zip

XRAY_BIN=$(find . -maxdepth 3 -type f \( -name 'xray' -o -name 'Xray' \) -print -quit)
if [ -z "$XRAY_BIN" ]; then
  echo "xray not found"
  exit 1
fi
chmod +x "$XRAY_BIN"

cat <<'EOF' > config.json
{
  "log": {
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
            "decryption": "none"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "cert.pem",
              "keyFile": "key.pem"
            }
          ],
          "alpn": ["http/1.1"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

"$XRAY_BIN" -c config.json &

echo "✅ done"
