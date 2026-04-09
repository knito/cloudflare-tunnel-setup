# ============================================================
# Makefile for simple-hello-world-ts
# ============================================================

K8S_HOST    := 192.168.1.10
TUNNEL_NAME := "tunnel-name"

.DEFAULT_GOAL := help

# ------------------------------------------------------------
# Cloudflare Tunnel (Remote Access)
# ------------------------------------------------------------

.PHONY: tunnel-install
tunnel-install: ## Install cloudflared (Cloudflare Tunnel client)
	@echo "Installing cloudflared for $(shell uname -s)..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		brew install cloudflare/cloudflare/cloudflared; \
	else \
		echo "Downloading cloudflared for ARM64..."; \
		curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /tmp/cloudflared && \
		chmod +x /tmp/cloudflared && \
		sudo mv /tmp/cloudflared /usr/local/bin/cloudflared && \
		echo "Installation complete!"; \
	fi
	@cloudflared --version

.PHONY: tunnel-list
tunnel-list: ## List all Cloudflare Tunnels
	cloudflared tunnel list

.PHONY: tunnel-info
tunnel-info: ## Show detailed info for a specific tunnel
	@read -p "Enter tunnel name or UUID: " TUNNEL; \
	cloudflared tunnel info $$TUNNEL

.PHONY: tunnel-dns
tunnel-dns: ## Create DNS route for a tunnel
	@read -p "Enter tunnel name or UUID: " TUNNEL; \
	read -p "Enter subdomain (e.g., www): " SUBDOMAIN; \
	echo "Creating DNS route: $$TUNNEL -> $$SUBDOMAIN"; \
	cloudflared tunnel route dns $$TUNNEL $$SUBDOMAIN

.PHONY: tunnel-login
tunnel-login: ## Authenticate with Cloudflare
	cloudflared tunnel login

.PHONY: tunnel-create
tunnel-create: ## Create the tunnel
	cloudflared tunnel create $(TUNNEL_NAME)

.PHONY: tunnel-route
tunnel-route: ## Configure ingress rules via config file (requires user input)
	@echo "=== Cloudflare Tunnel - Configure Ingress Rules ===" && \
	read -p "Enter domain name (e.g., www.example.com): " DOMAIN; \
	TUNNEL_INFO=$$(cloudflared tunnel info $(TUNNEL_NAME) 2>&1); \
	if echo "$$TUNNEL_INFO" | grep -q "error\|not found" || [ -z "$$TUNNEL_INFO" ]; then \
		echo "ERROR: Could not find tunnel '$(TUNNEL_NAME)'. Run 'make tunnel-create' first."; \
		exit 1; \
	fi; \
	TUNNEL_ID=$$(echo "$$TUNNEL_INFO" | grep -oP '(?<=ID: )[a-f0-9-]+' | head -1); \
	if [ -z "$$TUNNEL_ID" ]; then \
		echo "WARNING: Could not extract tunnel ID, using tunnel name instead."; \
		TUNNEL_ID=$(TUNNEL_NAME); \
	fi; \
	mkdir -p ~/.cloudflared && \
	{ \
		echo "tunnel: $$TUNNEL_ID"; \
		echo "credentials-file: ~/.cloudflared/$$TUNNEL_ID.json"; \
		echo "ingress:"; \
		echo "  - hostname: $$DOMAIN"; \
		echo "    service: http://$(K8S_HOST):$(NODE_PORT)"; \
		echo "  - service: http_status:503"; \
	} > ~/.cloudflared/config.yml && \
	echo "✓ Ingress rules configured in ~/.cloudflared/config.yml" && \
	echo "" && \
	echo "Next steps:" && \
	echo "1. Run 'make tunnel-run' to start the tunnel" && \
	echo "2. Create a CNAME record in Cloudflare DNS:" && \
	echo "   Name: $$DOMAIN" && \
	echo "   Target: $$TUNNEL_ID.cfargotunnel.com" && \
	echo ""

.PHONY: tunnel-run
tunnel-run: ## Run the tunnel (requires 'make tunnel-route' to configure ingress first)
	@echo "Starting Cloudflare Tunnel for simple-hello-world..."
	@echo "Proxying to http://$(K8S_HOST):$(NODE_PORT)"
	@echo "Note: Run 'make tunnel-route' first if you haven't configured the ingress."
	cloudflared tunnel run $(TUNNEL_NAME)

.PHONY: tunnel-service-install
tunnel-service-install: ## Install cloudflared as systemd service (auto-start)
	@echo "Installing cloudflared as systemd service..."
	sudo mkdir -p /etc/cloudflared
	sudo cp ~/.cloudflared/cert.pem /etc/cloudflared/cert.pem
	sudo cp ~/.cloudflared/*.json /etc/cloudflared/
	sudo cp ~/.cloudflared/config.yml /etc/cloudflared/config.yml
	sudo sed -i 's|~/.cloudflared|/etc/cloudflared|g' /etc/cloudflared/config.yml
	sudo cloudflared service install
	sudo systemctl enable cloudflared
	sudo systemctl start cloudflared
	@echo "Cloudflared service enabled and started"
	@echo "Check status: sudo systemctl status cloudflared"
	@echo "View logs: sudo journalctl -u cloudflared -f"

.PHONY: tunnel-service-uninstall
tunnel-service-uninstall: ## Uninstall cloudflared systemd service
	@echo "Stopping and uninstalling cloudflared service..."
	sudo systemctl stop cloudflared
	sudo systemctl disable cloudflared
	sudo cloudflared service uninstall
	@echo "Cloudflared service removed"

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

.PHONY: help
help: ## List all available targets with descriptions
	@printf "\nUsage: make <target>\n\n"
	@printf "%-20s %s\n" "Target" "Description"
	@printf "%-20s %s\n" "------" "-----------"
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*##"}; {printf "  %-18s %s\n", $$1, $$2}'
	@printf "\n"
