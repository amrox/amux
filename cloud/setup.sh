#!/usr/bin/env bash
# cmux cloud VM bootstrap — runs as root via GCP startup script
# Also works standalone: sudo bash setup.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
STORAGE_DEV="/dev/disk/by-id/google-cmux-storage"
STORAGE_MOUNT="/mnt/storage"
CMUX_USER="cmux"

log() { echo "[cmux-setup] $(date '+%H:%M:%S') $*"; }

# ── System packages ──
log "Updating packages..."
apt-get update -qq
apt-get install -y -qq \
  tmux git curl wget unzip jq htop \
  python3 python3-pip python3-venv \
  build-essential ca-certificates gnupg lsb-release

# ── Node.js 22 LTS ──
if ! command -v node &>/dev/null; then
  log "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -qq nodejs
fi

# ── Tailscale ──
if ! command -v tailscale &>/dev/null; then
  log "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi
log "Connecting to Tailscale..."
tailscale up --authkey="${tailscale_auth_key}" --hostname=cmux-cloud --ssh || true

# ── Mount storage disk ──
if [ -b "$STORAGE_DEV" ] && ! mountpoint -q "$STORAGE_MOUNT"; then
  log "Setting up storage disk..."
  mkdir -p "$STORAGE_MOUNT"
  # Format only if no filesystem exists
  if ! blkid "$STORAGE_DEV" &>/dev/null; then
    mkfs.ext4 -q -L cmux-storage "$STORAGE_DEV"
  fi
  # Ensure fstab entry
  if ! grep -q cmux-storage /etc/fstab; then
    echo "LABEL=cmux-storage $STORAGE_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mount -a
  log "Storage mounted at $STORAGE_MOUNT"
fi

# ── Create cmux user ──
if ! id "$CMUX_USER" &>/dev/null; then
  log "Creating user $CMUX_USER..."
  useradd -m -s /bin/bash "$CMUX_USER"
  usermod -aG sudo "$CMUX_USER"
  echo "$CMUX_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cmux
fi
# Give user access to storage
chown -R "$CMUX_USER:$CMUX_USER" "$STORAGE_MOUNT" 2>/dev/null || true

# ── code-server ──
if ! command -v code-server &>/dev/null; then
  log "Installing code-server..."
  curl -fsSL https://code-server.dev/install.sh | sh
fi
mkdir -p /home/$CMUX_USER/.config/code-server
cat > /home/$CMUX_USER/.config/code-server/config.yaml <<'CSCFG'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
CSCFG
chown -R "$CMUX_USER:$CMUX_USER" /home/$CMUX_USER/.config

# code-server systemd service
cat > /etc/systemd/system/code-server.service <<CSSVC
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=$CMUX_USER
ExecStart=/usr/bin/code-server --config /home/$CMUX_USER/.config/code-server/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
CSSVC
systemctl daemon-reload
systemctl enable --now code-server

# ── Claude Code CLI ──
log "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code || true

# ── cmux itself ──
CMUX_DIR="/home/$CMUX_USER/cmux"
if [ ! -d "$CMUX_DIR" ]; then
  log "Cloning cmux..."
  sudo -u "$CMUX_USER" git clone https://github.com/ethanzrd/cmux.git "$CMUX_DIR" 2>/dev/null || {
    # If repo isn't public yet, create the directory structure
    sudo -u "$CMUX_USER" mkdir -p "$CMUX_DIR"
    log "cmux repo not available — directory created, copy files manually"
  }
fi

# Symlink centralized MCP config into claude code's config location
CLAUDE_DIR="/home/$CMUX_USER/.claude"
sudo -u "$CMUX_USER" mkdir -p "$CLAUDE_DIR"
if [ -f "$CMUX_DIR/mcp.json" ]; then
  ln -sf "$CMUX_DIR/mcp.json" "$CLAUDE_DIR/mcp.json"
  log "Linked mcp.json into Claude config"
fi

# ── cmux server as systemd service ──
cat > /etc/systemd/system/cmux.service <<CMXSVC
[Unit]
Description=cmux server
After=network.target

[Service]
Type=simple
User=$CMUX_USER
WorkingDirectory=$CMUX_DIR
ExecStart=/usr/bin/python3 $CMUX_DIR/cmux-server.py --port 8822
Restart=always
RestartSec=5
Environment=HOME=/home/$CMUX_USER

[Install]
WantedBy=multi-user.target
CMXSVC
systemctl daemon-reload
systemctl enable cmux

# ── Shell config ──
BASHRC="/home/$CMUX_USER/.bashrc"
if ! grep -q "cmux-cloud" "$BASHRC" 2>/dev/null; then
  cat >> "$BASHRC" <<'SHELL'

# ── cmux cloud env ──
export PATH="$HOME/cmux:$PATH"
export CMUX_STORAGE="/mnt/storage"
alias ll='ls -alF'
alias cls='clear'

# Auto-start tmux on SSH login
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ]; then
  tmux new-session -A -s main
fi
SHELL
  chown "$CMUX_USER:$CMUX_USER" "$BASHRC"
fi

# ── tmux config ──
TMUX_CONF="/home/$CMUX_USER/.tmux.conf"
if [ ! -f "$TMUX_CONF" ]; then
  cat > "$TMUX_CONF" <<'TMUX'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "screen-256color"
set -g status-style "bg=colour235,fg=colour248"
set -g status-left "#[fg=colour39,bold] cmux-cloud #[default]"
set -g status-right "#[fg=colour245]%H:%M "
set -g base-index 1
setw -g pane-base-index 1
TMUX
  chown "$CMUX_USER:$CMUX_USER" "$TMUX_CONF"
fi

log "Setup complete."
log "  Tailscale:   ssh cmux@cmux-cloud"
log "  code-server: http://cmux-cloud:8080"
log "  cmux:        https://cmux-cloud:8822"
log "  Storage:     $STORAGE_MOUNT ($(df -h $STORAGE_MOUNT 2>/dev/null | awk 'NR==2{print $2}' || echo 'not mounted'))"
