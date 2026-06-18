#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

##
# Global variables
##

declare -l IPv4 IPv6 RECORD UUID TOKEN XHTTP_PATH
RECORD="$(hostname -s)"
[[ "${RECORD}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] ||
    { echo_error "Invalid hostname: ${RECORD}."; exit 1; }

##
# Helper functions
##

echo_error() { printf '\033[0;31m[ERROR] %s\033[0m\n' "${1}" >&2; }
echo_warn() { printf '\033[0;33m[WARN] %s\033[0m\n' "${1}" >&2; }
echo_info() { printf '\033[0;32m[INFO] %s\033[0m\n' "${1}"; }
echo_data() { printf '\033[0;34m%s\033[0m\n' "${1}"; }

##
# Check functions
##

check_env() {
    local var
    for var in EMAIL DOMAIN CF_Token CF_Zone_ID SSH_PUBLIC_KEY; do
        [[ -n "${!var}" ]] || { echo_error "${var} not set."; return 1; }
    done
}

check_root() {
    (( EUID == 0 )) || { echo_error 'Please run as root.'; return 1; }
}

check_os() {
    local -r supported_os='debian ubuntu'
    local os
    os=$(. /etc/os-release && printf '%s' "${ID}") ||
        { echo_error '/etc/os-release not found.'; return 1; }
    [[ " ${supported_os} " == *" ${os} "* ]] || { echo_error "Unsupported os: ${os}."; return 1; }
}

check_network() {
    local cmd
    command -v curl >/dev/null && cmd='curl -fsS -m 5' || {
        command -v wget >/dev/null && cmd='wget -nv -O- --max-redirect=0 -T 5 -t 1' || {
            echo_error 'Neither curl nor wget installed.'
            return 1
        }
    }

    IPv4=$(${cmd} 'https://1.1.1.1/cdn-cgi/trace' | sed -n 's/^ip=//p')
    [[ -n "${IPv4}" ]] || { echo_error 'Failed to detect public IPv4.'; return 1; }
    IPv6=$(${cmd} 'https://[2606:4700:4700::1111]/cdn-cgi/trace' | sed -n 's/^ip=//p')
    [[ -n "${IPv6}" ]] || { echo_error 'Failed to detect public IPv6.'; return 1; }
    echo_info "Public IPv4 ${IPv4} and IPv6 ${IPv6}."
}

##
# Install functions
##

install_packages() {
    echo_info 'Updating apt...'
    apt-get update -qq
    echo_info 'Upgrading apt...'
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -qq -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" >/dev/null
    echo_info 'Installing packages...'
    DEBIAN_FRONTEND=noninteractive apt-get install curl jq nginx podman ufw unzip -qq -y >/dev/null
    echo_info 'curl jq nginx podman ufw unzip installed.'

    [[ -x /usr/local/bin/xray ]] || {
        curl -fsSL 'https://github.com/XTLS/Xray-install/raw/main/install-release.sh' |
            bash -s install -u root &>/dev/null
        echo_info 'xray installed.'
    }

    [[ -x /root/.acme.sh/acme.sh ]] || {
        curl -fsSL 'https://get.acme.sh' | sh -s email="${EMAIL}" &>/dev/null
        echo_info 'acme.sh installed.'
    }
}

##
# Config functions
##

config_swap() {
    swapon --show --noheadings | grep -q . || {
        rm -f /swapfile
        fallocate -l 1G /swapfile || { echo_error 'Failed to fallocate swap.'; return 1; }
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
        swapon /swapfile >/dev/null
        grep -qF '/swapfile' /etc/fstab || printf '%s\n' '/swapfile none swap sw 0 0' >>/etc/fstab
        echo_info 'swap configured.'
    }
}

config_bbr() {
    sysctl net.ipv4.tcp_congestion_control | grep -qF 'bbr' || {
        {
            printf '%s\n' 'net.ipv4.tcp_congestion_control=bbr'
            printf '%s\n' 'net.core.default_qdisc=fq'
        } >>/etc/sysctl.conf
        sysctl -p >/dev/null
        echo_info 'bbr configured.'
    }
}

config_ssh() {
    grep -qF "${SSH_PUBLIC_KEY}" /root/.ssh/authorized_keys 2>/dev/null || {
        install -D -m 600 - /root/.ssh/authorized_keys <<<"${SSH_PUBLIC_KEY}"
    }
    sed -i \
        -e '/^#*Include/d' \
        -e 's|^#*Port.*|Port 39000|' \
        -e 's|^#*AuthorizedKeysFile.*|AuthorizedKeysFile .ssh/authorized_keys|' \
        -e 's|^#*PasswordAuthentication.*|PasswordAuthentication no|' \
        -e 's|^#*X11Forwarding.*|X11Forwarding no|' \
        /etc/ssh/sshd_config
    echo_info 'ssh configured to use port 39000 without password authentication.'
}

config_ufw() {
    ufw --force reset >/dev/null
    rm -f /etc/ufw/*.rules.*[0-9]
    ufw allow 22/tcp >/dev/null
    ufw allow 443 >/dev/null
    ufw allow 39000/tcp >/dev/null
    ufw --force enable >/dev/null
    echo_info 'ufw configured and enabled.'
}

config_hostname() {
    local base_url="https://api.cloudflare.com/client/v4/zones/${CF_Zone_ID}/dns_records"
    local record_type record_id cf_url http_method json_data
    local -A type_ips=([A]="${IPv4}" [AAAA]="${IPv6}")

    for record_type in "${!type_ips[@]}"; do
        record_id=$(curl -fsSL "${base_url}?type=${record_type}&name=${RECORD}.${DOMAIN}" \
            -H "Authorization: Bearer ${CF_Token}" \
            -H 'Content-Type: application/json' | jq -r '.result[0].id // empty')

        cf_url="${base_url}"
        http_method='POST'
        [[ -z "${record_id}" ]] || { cf_url+="/${record_id}"; http_method='PUT'; }

        json_data=$(jq -n \
            --arg type "${record_type}" \
            --arg name "${RECORD}.${DOMAIN}" \
            --arg content "${type_ips[${record_type}]}" \
            '{type: $type, name: $name, content: $content, ttl: 3600, proxied: false}')

        curl -fsSL -o /dev/null -X "${http_method}" "${cf_url}" \
            -H "Authorization: Bearer ${CF_Token}" \
            -H 'Content-Type: application/json' \
            -d "${json_data}" ||
            { echo_error "DNS record ${record_type} update failed."; return 1; }

    echo_info "DNS record ${RECORD}.${DOMAIN}: A=${IPv4}, AAAA=${IPv6}."
}

config_searxng() {
    command -v podman >/dev/null || { echo_error 'podman not installed.'; return 1; }
    podman pull -q docker.io/searxng/searxng:latest >/dev/null
    podman pull -q docker.io/isokoliuk/mcp-searxng:latest >/dev/null
    mkdir -p /etc/searxng /etc/containers/systemd
    cat >/etc/searxng/settings.yml <<EOF
use_default_settings:
    engines:
        keep_only:
            - brave
            - duckduckgo
            - google
search:
    formats:
        - html
        - json
EOF
    : >/etc/searxng/limiter.toml
    cat >/etc/containers/systemd/searxng.pod <<EOF
[Unit]
Description=SearXNG Pod

[Pod]
PodName=searxng
PublishPort=127.0.0.1:3000:3000

[Install]
WantedBy=multi-user.target
EOF
    cat >/etc/containers/systemd/searxng.container <<EOF
[Unit]
Description=SearXNG Server
Documentation=https://docs.searxng.org/

[Container]
Image=docker.io/searxng/searxng:latest
ContainerName=searxng
Pod=searxng.pod
Volume=/etc/searxng:/etc/searxng
Environment=SEARXNG_SECRET=$(openssl rand -hex 32)
Environment=GRANIAN_BLOCKING_THREADS=2

[Install]
WantedBy=multi-user.target
EOF
    cat >/etc/containers/systemd/mcp-searxng.container <<EOF
[Unit]
Description=SearXNG MCP Server
Documentation=https://github.com/ihor-sokoliuk/MCP-searxng/

[Container]
Image=docker.io/isokoliuk/mcp-searxng:latest
ContainerName=mcp-searxng
Pod=searxng.pod
Environment=SEARXNG_URL=http://127.0.0.1:8080/
Environment=MCP_HTTP_HOST=0.0.0.0
Environment=MCP_HTTP_PORT=3000

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    echo_info 'mcp-searxng configured.'
}

config_xray() {
    [[ -x /usr/local/bin/xray ]] || { echo_error 'xray not installed.'; return 1; }
    UUID="$(/usr/local/bin/xray uuid)"
    XHTTP_PATH="$(openssl rand -hex 32)"
    cat >/usr/local/etc/xray/config.json <<EOF
{
    "version": {
        "min": "25.8.3"
    },
    "log": {
        "access": "none",
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "ip": [
                    "geoip:private",
                    "geoip:cn"
                ],
                "outboundTag": "blackhole-out"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "/dev/shm/xray.socket,0666",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "xhttp",
                "xhttpSettings": {
                    "path": "/${XHTTP_PATH}"
                }
            },
            "tag": "vless-in"
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "freedom-out"
        },
        {
            "protocol": "blackhole",
            "tag": "blackhole-out"
        }
    ]
}
EOF
    echo_info 'xray configured.'
}

config_nginx() {
    command -v nginx >/dev/null || { echo_error 'nginx not installed.'; return 1; }
    TOKEN="sk-$(openssl rand -hex 32)"
    cat >/etc/nginx/sites-enabled/default <<EOF
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    listen 443 quic default_server;
    listen [::]:443 quic default_server;
    server_name _;

    ssl_reject_handshake on;
}
server {
    listen 443 ssl reuseport;
    listen [::]:443 ssl reuseport;
    listen 443 quic reuseport;
    listen [::]:443 quic reuseport;
    server_name ${RECORD}.${DOMAIN};

    access_log off;

    http2 on;
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    location = / {
        default_type application/json;
        return 200 '{"status":"ok","code":200}';
    }

    location /mcp-searxng/ {
        if (\$http_authorization != "Bearer ${TOKEN}") {
            return 401 '{"error":"unauthorized","code":401}';
        }

        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location /${XHTTP_PATH}/ {
        grpc_pass unix:/dev/shm/xray.socket;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_read_timeout 5m;
        grpc_send_timeout 5m;
        client_max_body_size 0;
    }

    location /api/ {
        default_type application/json;
        return 401 '{"error":"unauthorized","code":401}';
    }

    location / {
        default_type application/json;
        return 404 '{"error":"not_found","code":404}';
    }
}
EOF
    echo_info 'nginx configured as gateway.'
}

config_acme() {
    [[ -x /root/.acme.sh/acme.sh ]] || { echo_error 'acme.sh not installed.'; return 1; }
    mkdir -p /etc/nginx/ssl
    echo_info "Issuing ${RECORD}.${DOMAIN} certificates..."
    /root/.acme.sh/acme.sh --list | grep -qF "${RECORD}.${DOMAIN}" ||
        /root/.acme.sh/acme.sh --issue --dns dns_cf -d "${RECORD}.${DOMAIN}" >/dev/null
    /root/.acme.sh/acme.sh --install-cert -d "${RECORD}.${DOMAIN}" \
        --key-file /etc/nginx/ssl/key.pem \
        --fullchain-file /etc/nginx/ssl/fullchain.pem \
        --reloadcmd 'systemctl reload nginx' >/dev/null
    echo_info "acme.sh configured to renew ${RECORD}.${DOMAIN} certificates."
}

##
# Cleanup functions
##

print_info() {
    echo_info 'VPS Information'
    # https://www.man7.org/linux/man-pages/man1/ssh.1.html
    echo_data "ssh -p 39000 root@${IPv4}"
    echo_data "ssh -p 39000 root@${IPv6}"
    # https://modelcontextprotocol.io/specification/2025-03-26/basic/transports#streamable-http
    echo_data "https://${RECORD}.${DOMAIN}/mcp-searxng/mcp -H \"Authorization: Bearer ${TOKEN}\""
    # https://github.com/XTLS/Xray-core/discussions/716
    echo_data "vless://${UUID}@[${IPv6}]:443?type=xhttp&security=tls&path=%2F${XHTTP_PATH}\
&mode=packet-up&extra=%7B%22downloadSettings%22%3A%7B%22address%22%3A%22${IPv6}%22%2C%22port\
%22%3A443%2C%22network%22%3A%22xhttp%22%2C%22security%22%3A%22tls%22%2C%22tlsSettings%22%3A%7B%22\
serverName%22%3A%22${RECORD}.${DOMAIN}%22%2C%22alpn%22%3A%5B%22h2%22%5D%7D%2C%22xhttpSettings\
%22%3A%7B%22path%22%3A%22%2F${XHTTP_PATH}%22%2C%22mode%22%3A%22stream-up%22%7D%2C%22sockopt\
%22%3A%7B%22tcpFastOpen%22%3Atrue%7D%7D%7D&sni=${RECORD}.${DOMAIN}&alpn=h3&tfo=1#${RECORD^^}"
}

restart_os() {
    echo_warn 'Reboot now.'
    reboot
}

check_env
check_root
check_os
check_network

config_swap
install_packages

config_bbr
config_ssh
config_ufw
config_hostname
config_searxng
config_xray
config_nginx
config_acme

print_info
restart_os
