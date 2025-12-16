# Pi and MikroTik Ansible Setup

A self-healing, Git-driven configuration management system for Raspberry Pi 4. On every boot, the Pi pulls the latest configuration from Git and runs Ansible to ensure everything is configured correctly.

## Features

- **Automated Boot Sync**: Pulls latest config and applies it on every boot
- **Monitoring Stack**: Prometheus, Grafana, Node Exporter, cAdvisor, SNMP Exporter
- **Container Management**: Docker, Portainer, Watchtower (auto-updates)
- **Smart Home**: Home Assistant
- **Remote Access**: Tailscale VPN with subnet routing
- **MikroTik Integration**: SNMP monitoring of your router

## Quick Start

### Prerequisites

- Raspberry Pi 4 running Raspberry Pi OS (64-bit)
- Network connectivity
- SSH access enabled

### 1. Install Ansible on the Pi

```bash
ssh pi@192.168.88.253

sudo apt update
sudo apt install ansible git -y
ansible --version
```

### 2. Clone This Repository

```bash
cd /home/pi
git clone https://github.com/KevNev19/pi-and-mikrotek-ansible-setup.git
cd pi-and-mikrotek-ansible-setup
```

### 3. Install Ansible Galaxy Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

### 4. Make Boot Script Executable

```bash
chmod +x scripts/boot-sync.sh
```

### 5. Create the Systemd Service

```bash
sudo tee /etc/systemd/system/ansible-boot-sync.service << 'EOF'
[Unit]
Description=Ansible Boot Sync - Pull and Apply Configuration
After=network-online.target docker.service
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=3

[Service]
Type=oneshot
User=root
Group=root
WorkingDirectory=/home/pi/pi-and-mikrotek-ansible-setup
ExecStart=/home/pi/pi-and-mikrotek-ansible-setup/scripts/boot-sync.sh
TimeoutStartSec=900
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ansible-boot-sync
Environment="HOME=/root"
Environment="ANSIBLE_FORCE_COLOR=true"
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
```

### 6. Create Log File

```bash
sudo touch /var/log/ansible-boot-sync.log
sudo chown pi:pi /var/log/ansible-boot-sync.log
```

### 7. Enable and Start the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable ansible-boot-sync.service
sudo systemctl start ansible-boot-sync.service
```

### 8. Watch the Logs

```bash
sudo journalctl -u ansible-boot-sync.service -f
```

## Configuration

### Default Values

| Setting | Value |
|---------|-------|
| Pi IP | 192.168.88.253 |
| Hostname | keeper |
| Timezone | Europe/London |
| MikroTik IP | 192.168.88.1 |

To customize, edit `group_vars/all.yml`.

### Services & Ports

| Service | Port | URL |
|---------|------|-----|
| Grafana | 3000 | http://192.168.88.253:3000 |
| Prometheus | 9090 | http://192.168.88.253:9090 |
| Home Assistant | 8123 | http://192.168.88.253:8123 |
| Portainer | 9443 | https://192.168.88.253:9443 |
| Node Exporter | 9100 | http://192.168.88.253:9100 |
| cAdvisor | 8080 | http://192.168.88.253:8080 |
| SNMP Exporter | 9116 | http://192.168.88.253:9116 |

### Default Credentials

- **Grafana**: admin / ChangeMe123! (change this!)

## Usage

### Manual Sync

```bash
# Trigger sync manually
sudo systemctl start ansible-boot-sync.service

# Or use the alias (after first run)
ansible-sync
```

### Check Status

```bash
# Service status
sudo systemctl status ansible-boot-sync.service

# View logs
sudo journalctl -u ansible-boot-sync.service -f

# Last successful run
cat ~/.ansible-last-run
```

### Run Ansible Manually

```bash
cd ~/pi-and-mikrotek-ansible-setup

# Full run
sudo ansible-playbook playbooks/site.yml

# Specific tags only
sudo ansible-playbook playbooks/site.yml --tags "docker,monitoring"

# Dry run (check mode)
sudo ansible-playbook playbooks/site.yml --check

# Verbose output
sudo ansible-playbook playbooks/site.yml -vvv
```

### Making Changes

1. Edit files on your development machine
2. Commit and push to GitHub
3. On the Pi, either:
   - Wait for next boot
   - Run `ansible-sync` manually
   - Reboot: `sudo reboot`

## Repository Structure

```
.
├── ansible.cfg                 # Ansible configuration
├── requirements.yml            # Galaxy dependencies
├── inventory/
│   └── localhost.yml           # Local inventory
├── group_vars/
│   └── all.yml                 # Global variables
├── playbooks/
│   └── site.yml                # Main playbook
├── roles/
│   ├── common/                 # Base system config
│   ├── docker/                 # Docker installation
│   ├── monitoring/             # Prometheus, Grafana, exporters
│   ├── homeassistant/          # Home Assistant
│   └── tailscale/              # Tailscale VPN
├── scripts/
│   └── boot-sync.sh            # Boot sync script
└── pi-ansible-boot-sync-guide.md  # Detailed guide
```

## Tailscale Setup

After the first Ansible run, connect Tailscale manually:

```bash
sudo tailscale up --advertise-routes=192.168.88.0/24 --accept-routes
```

Then approve the subnet routes in the [Tailscale admin console](https://login.tailscale.com/admin/machines).

## MikroTik DNS (Optional)

Add these DNS entries to your MikroTik router for friendly names:

```
/ip dns static
add name=homeassistant.home address=192.168.88.253
add name=grafana.home address=192.168.88.253
add name=prometheus.home address=192.168.88.253
add name=keeper.home address=192.168.88.253
```

## Troubleshooting

### Service Won't Start

```bash
# Check for lock file
ls -la /tmp/ansible-boot-sync.lock

# Remove stale lock
sudo rm /tmp/ansible-boot-sync.lock

# Check logs
sudo journalctl -u ansible-boot-sync.service -n 100
```

### Ansible Fails

```bash
# Check syntax
ansible-playbook playbooks/site.yml --syntax-check

# Run with verbose output
sudo ansible-playbook playbooks/site.yml -vvv

# Run specific role only
sudo ansible-playbook playbooks/site.yml --tags "common"
```

### Docker Issues

```bash
# Check containers
docker ps -a

# View logs
docker logs <container_name>

# Restart stack
cd ~/network-monitoring
docker compose down && docker compose up -d
```

### Reset Repository

```bash
cd ~/pi-and-mikrotek-ansible-setup
git fetch origin
git reset --hard origin/main
git clean -fd
```

## Bash Aliases

After the first Ansible run, these aliases are available:

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
