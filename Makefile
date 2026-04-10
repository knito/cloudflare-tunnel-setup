# K8S_HOST    := 192.168.1.10
# TUNNEL_NAME := "tunnel-name"

.DEFAULT_GOAL := help

# ------------------------------------------------------------
# Cloudflare Tunnel (Remote Access)
# ------------------------------------------------------------

.PHONY: tunnel-install
tunnel-install: ## Install cloudflared (Cloudflare Tunnel client)
	@echo "Installing cloudflared for $(shell uname -s)..."
	@if [ "$(uname -s)" = "Darwin" ]; then \
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
	cloudflared tunnel info ${TUNNEL}

.PHONY: tunnel-dns
tunnel-dns: ## Create DNS route for a tunnel
	@read -p "Enter tunnel name or UUID: " TUNNEL; \
	read -p "Enter subdomain (e.g., www): " SUBDOMAIN; \
	echo "Creating DNS route: ${TUNNEL} -> ${SUBDOMAIN}"; \
	cloudflared tunnel route dns ${TUNNEL} ${SUBDOMAIN}

.PHONY: tunnel-login
tunnel-login: ## Authenticate with Cloudflare
	cloudflared tunnel login

.PHONY: tunnel-create
tunnel-create: ## Create the tunnel
	@read -p "Enter the desired tunnel name: " NEW_TUNNEL_NAME; \
	cloudflared tunnel create ${NEW_TUNNEL_NAME}

.PHONY: tunnel-route
tunnel-route: ## Configure ingress rules via config file (supports multiple hostnames)
	@echo "=== Cloudflare Tunnel - Configure Multiple Ingress Rules ==="; \
	read -p "Enter the tunnel name or UUID: " TUNNEL_TO_ROUTE; \
	[ -z "$${TUNNEL_TO_ROUTE}" ] && echo "ERROR: Tunnel name/UUID is required" && exit 1; \
	read -p "Enter the default target host [192.168.1.10]: " DEFAULT_HOST; \
	DEFAULT_HOST=$${DEFAULT_HOST:-192.168.1.10}; \
	echo "Checking tunnel info for: $${TUNNEL_TO_ROUTE}"; \
	TUNNEL_INFO=$$(cloudflared tunnel info "$${TUNNEL_TO_ROUTE}" 2>&1); \
	echo "Tunnel info output:"; \
	echo "$${TUNNEL_INFO}"; \
	if echo "$${TUNNEL_INFO}" | grep -q "error\|not found" || [ -z "$${TUNNEL_INFO}" ]; then \
		echo "ERROR: Could not find tunnel '$${TUNNEL_TO_ROUTE}'. Run 'make tunnel-create' first or provide a valid tunnel name/UUID."; \
		exit 1; \
	fi; \
	TUNNEL_ID=$$(echo "$${TUNNEL_INFO}" | grep 'ID:' | sed 's/.*ID: *//g' | sed 's/ .*//g' | head -1); \
	echo "Extracted Tunnel ID: $${TUNNEL_ID}"; \
	if [ -z "$${TUNNEL_ID}" ]; then \
		echo "WARNING: Could not extract tunnel ID, using provided name/UUID as fallback."; \
		TUNNEL_ID="$${TUNNEL_TO_ROUTE}"; \
	fi; \
	mkdir -p ~/.cloudflared && \
	echo "tunnel: $${TUNNEL_ID}" > ~/.cloudflared/config.yml && \
	echo "credentials-file: ~/.cloudflared/$${TUNNEL_ID}.json" >> ~/.cloudflared/config.yml && \
	echo "ingress:" >> ~/.cloudflared/config.yml && \
	echo "" && \
	echo "Now add your hostnames and services. Press Enter without input to finish." && \
	DOMAIN_COUNT=0; \
	DNS_RECORDS=""; \
	while true; do \
		echo ""; \
		read -p "Enter hostname (e.g., plex.example.com) or press Enter to finish: " HOSTNAME; \
		[ -z "$${HOSTNAME}" ] && break; \
		read -p "Enter service host [$${DEFAULT_HOST}]: " SERVICE_HOST; \
		SERVICE_HOST=$${SERVICE_HOST:-$${DEFAULT_HOST}}; \
		read -p "Enter service port: " SERVICE_PORT; \
		[ -z "$${SERVICE_PORT}" ] && echo "ERROR: Port is required" && continue; \
		echo "  - hostname: $${HOSTNAME}" >> ~/.cloudflared/config.yml; \
		echo "    service: http://$${SERVICE_HOST}:$${SERVICE_PORT}" >> ~/.cloudflared/config.yml; \
		DOMAIN_COUNT=$$((DOMAIN_COUNT + 1)); \
		DNS_RECORDS="$${DNS_RECORDS}   - $${HOSTNAME} -> $${TUNNEL_ID}.cfargotunnel.com\n"; \
		echo "✓ Added: $${HOSTNAME} -> http://$${SERVICE_HOST}:$${SERVICE_PORT}"; \
	done; \
	echo "  - service: http_status:503" >> ~/.cloudflared/config.yml && \
	echo "" && \
	echo "✓ Ingress rules configured in ~/.cloudflared/config.yml" && \
	echo "✓ Total hostnames configured: $${DOMAIN_COUNT}" && \
	echo "" && \
	echo "Configuration summary:" && \
	cat ~/.cloudflared/config.yml && \
	echo "" && \
	echo "Next steps:" && \
	echo "1. Run 'make tunnel-run' to start the tunnel" && \
	echo "2. Create CNAME records in Cloudflare DNS:" && \
	printf "$${DNS_RECORDS}" && \
	echo ""

.PHONY: tunnel-run
tunnel-run: ## Run the tunnel (requires 'make tunnel-route' to configure ingress first)
	@read -p "Enter the tunnel name or UUID to run: " TUNNEL_TO_RUN; \
	echo "Starting Cloudflare Tunnel '${TUNNEL_TO_RUN}'..."
	@echo "Note: Ensure 'make tunnel-route' has been run to configure ingress."
	cloudflared tunnel run ${TUNNEL_TO_RUN}

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

.PHONY: tunnel-service-redeploy
tunnel-service-redeploy: ## Re-deploy cloudflared service (uninstall + install with updated config)
	@echo "Re-deploying cloudflared service..."
	@echo "Step 1: Stopping and uninstalling existing service..."
	-sudo systemctl stop cloudflared 2>/dev/null || true
	-sudo systemctl disable cloudflared 2>/dev/null || true
	-sudo cloudflared service uninstall 2>/dev/null || true
	@echo "Step 2: Installing service with updated configuration..."
	sudo mkdir -p /etc/cloudflared
	sudo cp ~/.cloudflared/cert.pem /etc/cloudflared/cert.pem
	sudo cp ~/.cloudflared/*.json /etc/cloudflared/
	sudo cp ~/.cloudflared/config.yml /etc/cloudflared/config.yml
	sudo sed -i 's|~/.cloudflared|/etc/cloudflared|g' /etc/cloudflared/config.yml
	sudo cloudflared service install
	sudo systemctl enable cloudflared
	sudo systemctl start cloudflared
	@echo "✓ Cloudflared service re-deployed successfully"
	@echo "Check status: sudo systemctl status cloudflared"
	@echo "View logs: sudo journalctl -u cloudflared -f"

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

.PHONY: help
help: ## List all available targets with descriptions
	@printf "\nUsage: make <target>\n\n"
	@printf "%-20s %s\n" "Target" "Description"
	@printf "%-20s %s\n" "------" "-----------"
	@grep -E '^[a-zA-Z_-]+:.*##' ${MAKEFILE_LIST} \
		| sort \
		| awk 'BEGIN {FS = ":.*##"}; {printf "  %-18s %s\n", $$1, $$2}'
	@printf "\n"

