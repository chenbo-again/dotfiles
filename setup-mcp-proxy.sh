#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_HOME=${HOME%/}
key_dir="$TARGET_HOME/.config/opencode"
key_file="$key_dir/mcp-gateway.key"

command -v node >/dev/null 2>&1 || {
  printf 'Error: node is required. Run fetch-tools.sh first.\n' >&2; exit 1
}

# --- Playwright API key ---
install -d -m 700 "$key_dir"
if [[ ! -s $key_file ]]; then
  legacy="$key_dir/tavily-mcp-gateway.key"
  if [[ -s $legacy ]]; then
    install -m 600 "$legacy" "$key_file"
  else
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n' >"$key_file"
    printf '\n' >>"$key_file"
    chmod 600 "$key_file"
  fi
fi
chmod 600 "$key_file"

node=$(command -v node)
proxy="$TARGET_HOME/opencode-plugins/mcp-gateway/node_modules/.bin/mcp-proxy"
playwright="$TARGET_HOME/opencode-plugins/playwright-mcp/node_modules/@playwright/mcp/cli.js"
storage="$TARGET_HOME/.config/opencode/playwright-confluence-storage.json"

for path in "$proxy" "$playwright" "$storage"; do
  [[ -f $path ]] || { printf 'Error: missing: %s\n' "$path" >&2; exit 1; }
done
[[ -x $proxy ]] || { printf 'Error: %s is not executable\n' "$proxy" >&2; exit 1; }
chmod 600 "$storage"

# --- Playwright systemd unit ---
unit_dir="$TARGET_HOME/.config/systemd/user"
install -d -m 755 "$unit_dir"

cat >"$unit_dir/opencode-mcp-playwright.service" <<EOF
[Unit]
Description=MCP proxy for Playwright (port 43102)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'MCP_PROXY_API_KEY=\$(<"\$HOME/.config/opencode/mcp-gateway.key") exec "$node" "\$HOME/opencode-plugins/mcp-gateway/node_modules/.bin/mcp-proxy" --host 127.0.0.1 --port 43102 --server stream -- "$node" "\$HOME/opencode-plugins/playwright-mcp/node_modules/@playwright/mcp/cli.js" --browser chrome --headless --isolated --storage-state "\$HOME/.config/opencode/playwright-confluence-storage.json" --output-dir "\$HOME/.local/share/opencode/playwright-output" --codegen none --image-responses omit'
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now opencode-mcp-playwright.service

# Wait up to 30s for the proxy to be ready
key=$(<"$key_file")
init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"setup","version":"1"}}}'
for _ in {1..30}; do
  code=$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 2 \
    -H "X-API-Key: $key" -H 'Content-Type: application/json' --data "$init" \
    'http://127.0.0.1:43102/mcp' || true)
  [[ $code == 200 ]] && break
  sleep 1
done

unset key init
printf 'Playwright proxy on 127.0.0.1:43102.\n'
printf 'SSH hosts forward 43102 to this machine automatically.\n'
printf 'Restart OpenCode for configuration changes to take effect.\n'
