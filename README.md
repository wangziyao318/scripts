# Scripts

Various scripts for personal use.

## vps.sh

VPS script to set up vless+tls+xhttp and mcp-searxng.

```bash
export EMAIL= DOMAIN= CF_Token= CF_Zone_ID= SSH_PUBLIC_KEY= &&
    curl -fsSL https://raw.githubusercontent.com/wangziyao318/scripts/refs/heads/main/vps.sh | bash

export EMAIL= DOMAIN= CF_Token= CF_Zone_ID= SSH_PUBLIC_KEY= &&
    wget -qO- https://raw.githubusercontent.com/wangziyao318/scripts/refs/heads/main/vps.sh | bash
```

## dirx.sh

Run command in each sub-directory.

```bash
dirx.sh <command>
```

## unzip.sh

Unzip all zips in parallel in the current directory.

## jpg2jxl.sh

Convert all jpgs to jxl losslessly in parallel in the current directory.
