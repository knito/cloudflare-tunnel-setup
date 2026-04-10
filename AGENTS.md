# AGENTS.md: Cloudflare Tunnel Setup

## Overview

This repository is a simple reference for setting up and managing a Cloudflare Tunnel using `cloudflared`. All commands are defined in the `Makefile`.

## Key Configuration

- Configuration is fully interactive via the `make` commands.
- **Default Target Host**: `192.168.1.10` (used as default during `make tunnel-route` if not specified).

## Critical Workflow

1. **`make tunnel-install`** — Install `cloudflared` (platform-aware: brew on macOS, curl for Linux ARM64)
2. **`make tunnel-login`** — Authenticate with Cloudflare (creates credentials in `~/.cloudflared/`)
3. **`make tunnel-create`** — Create the tunnel
4. **`make tunnel-route`** — Configure ingress rules and generate `~/.cloudflared/config.yml` (interactive: prompts for domain name)
5. **`make tunnel-run`** — Start the tunnel (requires config.yml from step 4)

Optional systemd service setup:
- **`make tunnel-service-install`** — Install as auto-start systemd service (copies config to `/etc/cloudflared/` and enables)
- **`make tunnel-service-uninstall`** — Remove the service

## Non-Obvious Details

- **DNS route creation**: Use `make tunnel-dns` to create DNS routes (interactive: prompts for tunnel and subdomain)
- **Tunnel info**: Use `make tunnel-info` to inspect tunnel details (interactive: prompts for tunnel name or UUID)
- **Config file location**: Generated at `~/.cloudflared/config.yml`; systemd service copies it to `/etc/cloudflared/config.yml`
- **Credentials file**: Named after tunnel ID (e.g., `~/.cloudflared/UUID.json`)
- **Service logs**: Check with `sudo journalctl -u cloudflared -f`
- **Service status**: Check with `sudo systemctl status cloudflared`

## Common Pitfalls

- Running `make tunnel-run` without first running `make tunnel-route` will fail (config.yml must exist)
- Tunnel must exist before running `make tunnel-route` — run `make tunnel-create` first
- The systemd service requires sudo (installation and management)
- On Linux ARM64, `cloudflared` is downloaded via curl; macOS uses Homebrew

## Useful Commands

- `make help` — Lists all available targets
- `make tunnel-list` — List all existing tunnels
