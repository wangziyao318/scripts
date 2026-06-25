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
dirx.sh <command> [args...]
```

## unzip.sh

Unzip all zips in parallel in the current directory.

## img2jxl.sh

Convert all jpgs to jxl losslessly and all pngs to jxl in parallel in the current directory.

## wav2flac.sh

Convert all wavs to flac losslessly in parallel in the current directory.
