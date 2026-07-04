#!/bin/bash

GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
BLUE='\033[94m'
CYAN='\033[96m'
RESET='\033[0m'
BOLD='\033[1m'

print_status() {
  local message="$1"
  local status="${2:-info}"
  local prefix=""
  case "$status" in
    success) prefix="${GREEN}[OK]" ;;
    error)   prefix="${RED}[ERR]" ;;
    warning) prefix="${YELLOW}[WARN]" ;;
    info)    prefix="${BLUE}[INFO]" ;;
    debug)   prefix="${CYAN}[DBG]" ;;
  esac
  printf "${prefix} ${message}${RESET}\n"
}

check_dependencies() {
  local missing=""
  for cmd in jq sqlite3; do
    if ! command -v "$cmd" &>/dev/null; then
      missing="$missing $cmd"
    fi
  done
  if [ -n "$missing" ]; then
    print_status "Missing dependencies:$missing" "error"
    print_status "Install via: apt install jq sqlite3 -y" "info"
    exit 1
  fi
}

setup_certificates() {
  local domain="$1"
  local cert_path="/root/cert/$domain"
  
  if [ -f "$cert_path/fullchain.pem" ] && [ -f "$cert_path/privkey.pem" ]; then
    print_status "Certificates already exist at $cert_path" "success"
    
    read -p "Reissue certificates? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status "Using existing certificates" "info"
      return 0
    fi
  fi
  
  print_status "Setting up SSL certificates..." "info"
  
  if [ ! -f ~/.acme.sh/acme.sh ]; then
    print_status "Installing acme.sh..." "info"
    curl -s https://get.acme.sh | sh
    source ~/.bashrc
  fi
  
  print_status "Stopping x-ui to free port 80..." "info"
  systemctl stop x-ui 2>/dev/null
  systemctl stop nginx 2>/dev/null
  
  print_status "Issuing certificate for $domain..." "info"
  
  if ~/.acme.sh/acme.sh --issue -d "$domain" --standalone --force; then
    print_status "Certificate issued successfully" "success"
  else
    print_status "Failed to issue certificate" "error"
    systemctl start x-ui 2>/dev/null
    return 1
  fi
  
  mkdir -p "$cert_path"
  
  print_status "Installing certificate..." "info"
  ~/.acme.sh/acme.sh --install-cert -d "$domain" \
    --key-file "$cert_path/privkey.pem" \
    --fullchain-file "$cert_path/fullchain.pem"
  
  if [ -f "$cert_path/fullchain.pem" ] && [ -f "$cert_path/privkey.pem" ]; then
    print_status "Certificates installed to $cert_path" "success"
    systemctl start x-ui 2>/dev/null
    sleep 2
    return 0
  else
    print_status "Failed to install certificates" "error"
    systemctl start x-ui 2>/dev/null
    return 1
  fi
}

find_database() {
  local paths=(
    "/etc/x-ui/x-ui.db"
    "/opt/etc/x-ui/x-ui.db"
    "/opt/x-ui/x-ui.db"
    "/usr/local/x-ui/bin/x-ui.db"
    "./x-ui.db"
  )
  
  for path in "${paths[@]}"; do
    if [ -f "$path" ]; then
      print_status "Database found: $path" "success" >&2
      echo "$path"
      return 0
    fi
  done
  return 1
}

configure_panel_certificates() {
  local db_path="$1"
  local domain="$2"
  
  print_status "Configuring panel and subscription SSL certificates..." "info"
  
  local cert_path="/root/cert/$domain/fullchain.pem"
  local key_path="/root/cert/$domain/privkey.pem"
  
  # Настройки веб-панели
  sqlite3 "$db_path" "INSERT OR REPLACE INTO settings (key, value) VALUES ('webCertFile', '$cert_path');" 2>/dev/null
  sqlite3 "$db_path" "INSERT OR REPLACE INTO settings (key, value) VALUES ('webKeyFile', '$key_path');" 2>/dev/null
  
  # Настройки подписки (subscription)
  sqlite3 "$db_path" "INSERT OR REPLACE INTO settings (key, value) VALUES ('subCertFile', '$cert_path');" 2>/dev/null
  sqlite3 "$db_path" "INSERT OR REPLACE INTO settings (key, value) VALUES ('subKeyFile', '$key_path');" 2>/dev/null
  
  if [ $? -eq 0 ]; then
    print_status "Panel and subscription certificates configured" "success"
    return 0
  else
    print_status "Failed to configure certificates" "warning"
    return 1
  fi
}

insert_inbound_to_db() {
  local db_path="$1"
  local domain="$2"
  
  local settings
  settings=$(jq -nc --arg domain "$domain" '{
    "clients": [],
    "decryption": "none",
    "encryption": "none",
    "fallbacks": [{
      "alpn": "http/1.1",
      "dest": "8080",
      "name": $domain,
      "path": "/",
      "xver": 0
    }]
  }')
  
  local stream_settings
  stream_settings=$(jq -nc --arg domain "$domain" '{
    "network": "tcp",
    "security": "tls",
    "tcpSettings": {
      "acceptProxyProtocol": false,
      "header": {"type": "none"}
    },
    "tlsSettings": {
      "alpn": ["http/1.1"],
      "certificates": [{
        "buildChain": false,
        "certificateFile": ("/root/cert/" + $domain + "/fullchain.pem"),
        "keyFile": ("/root/cert/" + $domain + "/privkey.pem"),
        "oneTimeLoading": false,
        "usage": "encipherment"
      }],
      "cipherSuites": "",
      "disableSystemRoot": false,
      "echForceQuery": "none",
      "echServerKeys": "",
      "enableSessionResumption": false,
      "maxVersion": "1.3",
      "minVersion": "1.2",
      "rejectUnknownSni": false,
      "serverName": $domain
    }
  }')
  
  local sniffing
  sniffing=$(jq -nc '{
    "enabled": true,
    "destOverride": ["http", "tls", "quic", "fakedns"],
    "metadataOnly": false,
    "routeOnly": true
  }')
  
  local existing
  existing=$(sqlite3 "$db_path" "SELECT id, remark FROM inbounds WHERE port=443;" 2>/dev/null)
  
  if [ -n "$existing" ]; then
    print_status "Inbound on port 443 already exists:" "warning"
    print_status "  $existing" "warning"
    read -p "Replace it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status "Cancelled by user" "info"
      return 1
    fi
    sqlite3 "$db_path" "DELETE FROM inbounds WHERE port=443;" 2>/dev/null
    print_status "Old inbound deleted" "success"
  fi
  
  local settings_escaped="${settings//\'/\'\'}"
  local stream_settings_escaped="${stream_settings//\'/\'\'}"
  local sniffing_escaped="${sniffing//\'/\'\'}"
  
  local sql="INSERT INTO inbounds (
    user_id, up, down, total, all_time, remark, enable, expiry_time,
    traffic_reset, last_traffic_reset_time, listen, port, protocol,
    settings, stream_settings, tag, sniffing
  ) VALUES (
    1, 0, 0, 0, 0, 'VLESS TLS Self-SNI', 1, 0,
    'never', 0, '0.0.0.0', 443, 'vless',
    '$settings_escaped',
    '$stream_settings_escaped',
    'inbound-443',
    '$sniffing_escaped'
  );"
  
  if sqlite3 "$db_path" "$sql" 2>/dev/null; then
    print_status "VLESS TLS inbound added to database" "success"
    
    local new_id
    new_id=$(sqlite3 "$db_path" "SELECT id FROM inbounds WHERE port=443 ORDER BY id DESC LIMIT 1;" 2>/dev/null)
    print_status "Inbound ID: $new_id" "debug"
    
    return 0
  else
    print_status "Failed to insert inbound (SQL error)" "error"
    return 1
  fi
}

setup_nginx() {
  local domain="$1"
  
  print_status "Setting up Nginx fallback..." "info"
  
  if ! command -v nginx &>/dev/null; then
    print_status "Nginx not found, installing..." "info"
    apt update -qq
    apt install nginx -y
  fi
  
  cat > /etc/nginx/sites-available/default << NGINX_EOF
server {
        listen 80;
        server_name $domain;
        return 301 https://\$http_host\$request_uri;
}

server {
        listen 127.0.0.1:8080;
        server_name $domain;
        root /var/www/html/;
        index index.html;
        add_header Strict-Transport-Security "max-age=63072000" always;
}
NGINX_EOF
  
  print_status "Downloading HTML template..." "info"
  if command -v wget &>/dev/null; then
    wget -q -O /var/www/html/index.html https://raw.githubusercontent.com/pegakmop/xray-with-selfsni/refs/heads/main/var/www/html/index.html
  elif command -v curl &>/dev/null; then
    curl -s -o /var/www/html/index.html https://raw.githubusercontent.com/pegakmop/xray-with-selfsni/refs/heads/main/var/www/html/index.html
  else
    print_status "Neither wget nor curl found, skipping HTML download" "warning"
  fi
  
  if [ -f /var/www/html/index.html ]; then
    print_status "HTML template installed" "success"
  fi
  
  if systemctl restart nginx 2>/dev/null; then
    print_status "Nginx configured and restarted" "success"
    return 0
  else
    print_status "Failed to restart Nginx" "error"
    return 1
  fi
}

restart_xui_service() {
  print_status "Restarting x-ui service..." "info"
  
  if command -v x-ui &>/dev/null; then
    if x-ui restart &>/dev/null; then
      sleep 2
      print_status "x-ui service restarted" "success"
      return 0
    fi
  fi
  
  if systemctl restart x-ui 2>/dev/null; then
    sleep 2
    print_status "x-ui service restarted" "success"
    return 0
  fi
  
  print_status "Failed to restart service automatically" "error"
  print_status "Restart manually: x-ui restart" "info"
  return 1
}

main() {
  printf "\n${BOLD}=== 3x-ui VLESS TLS Inbound Auto-Setup Tool ===${RESET}\n\n"
  
  check_dependencies
  
  local domain="$1"
  
  if [ -z "$domain" ]; then
    print_status "Usage: $0 <domain>" "error"
    print_status "Example: $0 example.com" "info"
    exit 1
  fi
  
  print_status "Domain: $domain" "info"
  
  if ! setup_certificates "$domain"; then
    print_status "Certificate setup failed" "error"
    exit 1
  fi
  
  local db_path
  db_path=$(find_database)
  
  if [ -z "$db_path" ]; then
    print_status "Database not found" "error"
    exit 1
  fi
  
  local backup_path="${db_path}.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$db_path" "$backup_path"
  print_status "Backup created: $backup_path" "success"
  
  print_status "Adding VLESS TLS inbound to database..." "info"
  
  if ! insert_inbound_to_db "$db_path" "$domain"; then
    print_status "Failed to add inbound" "error"
    exit 1
  fi
  
  configure_panel_certificates "$db_path" "$domain"
  
  printf "\n${BOLD}Verifying inbound:${RESET}\n"
  sqlite3 "$db_path" "SELECT id, remark, port, protocol, tag FROM inbounds WHERE port=443;" | while IFS='|' read -r id remark port protocol tag; do
    print_status "ID: $id | Name: $remark | Port: $port | Protocol: $protocol | Tag: $tag" "success"
  done
  
  printf "\n"
  restart_xui_service
  
  printf "\n"
  setup_nginx "$domain"
  
  printf "\n"
  print_status "Setup completed successfully!" "success"
  printf "\n"
  print_status "${BOLD}Summary:${RESET}" "info"
  print_status "  ✓ SSL certificates configured" "success"
  print_status "  ✓ VLESS TLS inbound added on port 443" "success"
  print_status "  ✓ Panel SSL certificates configured" "success"
  print_status "  ✓ Subscription SSL certificates configured" "success"
  print_status "  ✓ Domain: $domain" "success"
  print_status "  ✓ Nginx fallback configured on port 8080" "success"
  print_status "  ✓ HTML template installed" "success"
  print_status "  ✓ Website: https://$domain" "success"
  printf "\n"
  print_status "${BOLD}Next steps:${RESET}" "info"
  print_status "  1. Open 3x-ui web panel" "info"
  print_status "  2. Add clients to 'VLESS TLS Self-SNI' inbound" "info"
  print_status "  3. Configure clients with flow: xtls-rprx-vision" "info"
  printf "\n"
}

main "$@"
