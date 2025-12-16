# Pi and MikroTik Ansible Setup

A self-healing, Git-driven configuration management system for Raspberry Pi 4. On every boot, the Pi pulls the latest configuration from Git and runs Ansible to ensure everything is configured correctly.

## Features

- **Automated Boot Sync**: Pulls latest config and applies it on every boot
- **Monitoring Stack**: Prometheus, Grafana, Node Exporter, cAdvisor, SNMP Exporter
- **Container Management**: Docker, Portainer, Watchtower (auto-updates)
- **Smart Home**: Home Assistant with HACS pre-installed
- **Remote Access**: Tailscale VPN with subnet routing
- **MikroTik Integration**: SNMP monitoring of your router

## Quick Start

### Prerequisites

- Raspberry Pi 4 with Raspberry Pi OS (64-bit) installed
- Network connectivity (Ethernet recommended for initial setup)
- SSH enabled

### One-Line Bootstrap

SSH into your Pi and run:

```bash
curl -sSL https://raw.githubusercontent.com/KevNev19/pi-and-mikrotek-ansible-setup/main/scripts/bootstrap.sh | bash
```

This will:
1. Install Ansible and Git
2. Clone this repository
3. Install Ansible Galaxy collections
4. Set up systemd services
5. Run the full Ansible playbook

**First run takes 10-15 minutes** as it installs Docker, pulls images, and configures everything.

### Manual Setup (Alternative)

If you prefer step-by-step:

```bash
# 1. Install prerequisites
sudo apt update && sudo apt install -y ansible git

# 2. Clone repo
git clone https://github.com/KevNev19/pi-and-mikrotek-ansible-setup.git
cd pi-and-mikrotek-ansible-setup

# 3. Run bootstrap
./scripts/bootstrap.sh
```

## After Installation

### Services Available

| Service | Port | URL |
|---------|------|-----|
| Grafana | 3000 | http://192.168.88.253:3000 |
| Prometheus | 9090 | http://192.168.88.253:9090 |
| Home Assistant | 8123 | http://192.168.88.253:8123 |
| Portainer | 9443 | https://192.168.88.253:9443 |
| Node Exporter | 9100 | http://192.168.88.253:9100 |
| cAdvisor | 8080 | http://192.168.88.253:8080 |

### Default Credentials

- **Grafana**: admin / ChangeMe123! (change immediately!)

### Post-Setup Tasks

1. **Complete Home Assistant onboarding** at http://192.168.88.253:8123

2. **Add HACS integration**:
   - Settings → Devices & Services → Add Integration
   - Search "HACS" → Authorize with GitHub

3. **Connect Tailscale**:
   ```bash
   sudo tailscale up --advertise-routes=192.168.88.0/24 --accept-routes
   ```
   Then approve routes at https://login.tailscale.com/admin/machines

4. **Change Grafana password** via the web UI

## Configuration

### Default Values

| Setting | Value |
|---------|-------|
| Pi IP | 192.168.88.253 |
| Hostname | keeper |
| Timezone | Europe/London |
| MikroTik IP | 192.168.88.1 |

Edit `group_vars/all.yml` to customize.

### Enable Periodic Sync

By default, sync only runs on boot. To enable 6-hourly syncs:

```yaml
# group_vars/all.yml
boot_sync_timer_enabled: true
```

## Usage

### Trigger Manual Sync

```bash
sudo systemctl start ansible-boot-sync.service

# Or use alias (after first run)
ansible-sync
```

### Check Status

```bash
# Service status
sudo systemctl status ansible-boot-sync.service

# View logs
sudo journalctl -u ansible-boot-sync.service -f

# Last run info
cat ~/.ansible-last-run
```

### Run Ansible Directly

```bash
cd ~/pi-and-mikrotek-ansible-setup

# Full run
sudo ansible-playbook playbooks/site.yml

# Specific tags only
sudo ansible-playbook playbooks/site.yml --tags "docker,monitoring"

# Dry run
sudo ansible-playbook playbooks/site.yml --check
```

## Making Changes

1. Edit files locally or on the Pi
2. Commit and push to GitHub
3. On Pi: `ansible-sync` or wait for next boot

## Repository Structure

```
.
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Galaxy dependencies
├── inventory/localhost.yml  # Inventory
├── group_vars/all.yml       # All variables
├── playbooks/site.yml       # Main playbook
├── roles/
│   ├── common/              # Base system config
│   ├── docker/              # Docker installation
│   ├── monitoring/          # Prometheus, Grafana stack
│   ├── homeassistant/       # Home Assistant + HACS
│   ├── tailscale/           # Tailscale VPN
│   └── boot-sync/           # Systemd service management
├── systemd/                 # Systemd unit files
│   ├── ansible-boot-sync.service
│   ├── ansible-sync.service
│   └── ansible-sync.timer
└── scripts/
    ├── bootstrap.sh         # Initial setup script
    └── boot-sync.sh         # Boot sync script
```

## MikroTik DNS (Optional)

Add friendly DNS names on your MikroTik router:

```
/ip dns static
add name=homeassistant.home address=192.168.88.253
add name=grafana.home address=192.168.88.253
add name=prometheus.home address=192.168.88.253
add name=keeper.home address=192.168.88.253
```

## Troubleshooting

### Bootstrap Failed

```bash
# Check what went wrong
cat /var/log/ansible-boot-sync.log

# Re-run bootstrap
cd ~/pi-and-mikrotek-ansible-setup
./scripts/bootstrap.sh
```

### Service Won't Start

```bash
# Check for lock file
ls -la /tmp/ansible-boot-sync.lock
sudo rm -f /tmp/ansible-boot-sync.lock

# Check logs
sudo journalctl -u ansible-boot-sync.service -n 50
```

### Docker Issues

```bash
# Check containers
docker ps -a

# View container logs
docker logs homeassistant
docker logs grafana

# Restart stack
cd ~/network-monitoring
docker compose down && docker compose up -d
```

### Reset Everything

```bash
cd ~/pi-and-mikrotek-ansible-setup
git fetch origin
git reset --hard origin/main
./scripts/bootstrap.sh
```

## Bash Aliases

After setup, these aliases are available:

```bash
ll              # ls -la
dc              # docker compose
dps             # docker ps (formatted)
dlogs           # docker compose logs -f
ansible-sync    # Trigger sync manually
sync-status     # Check sync service status
sync-logs       # Follow sync logs
```

## License

MIT
