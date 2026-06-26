# Scripts

Various scripts for personal use.

## `vps.sh`

VPS script to set up vless+tls+xhttp and mcp-searxng.

```bash
export EMAIL= DOMAIN= CF_Token= CF_Zone_ID= SSH_PUBLIC_KEY= &&
    curl -fsSL https://raw.githubusercontent.com/wangziyao318/scripts/refs/heads/main/vps.sh | bash

export EMAIL= DOMAIN= CF_Token= CF_Zone_ID= SSH_PUBLIC_KEY= &&
    wget -qO- https://raw.githubusercontent.com/wangziyao318/scripts/refs/heads/main/vps.sh | bash
```

## `dirx.sh`

Run command in each sub-directory.

```bash
dirx.sh <command> [args...]
```

## `imv-zip.sh`

Extend imv to read zip archive.

```bash
imv-zip.sh <file.zip>
```

## `parallel-*.sh`

Use GNU parallel to accelerate commands.
