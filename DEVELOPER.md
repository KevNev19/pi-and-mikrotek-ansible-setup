# Developer Guide

This document covers how to extend, modify, and maintain the Ansible configuration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Git Repository (GitHub)                      │
│                                                                  │
│  pi-and-mikrotek-ansible-setup/                                  │
│  ├── playbooks/site.yml        (orchestration)                   │
│  ├── roles/                    (modular configuration)           │
│  ├── group_vars/all.yml        (variables)                       │
│  └── scripts/boot-sync.sh      (automation)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ git pull (on boot)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Raspberry Pi 4 (keeper)                       │
│                       192.168.88.253                             │
├─────────────────────────────────────────────────────────────────┤
│  systemd: ansible-boot-sync.service                              │
│    1. Wait for network                                           │
│    2. Git pull latest config                                     │
│    3. Run ansible-playbook                                       │
├─────────────────────────────────────────────────────────────────┤
│  Docker Containers:                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │ Prometheus  │ │   Grafana   │ │Home Assistant│                │
│  │   :9090     │ │   :3000     │ │    :8123     │                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │  Portainer  │ │ Watchtower  │ │   cAdvisor  │                │
│  │   :9443     │ │  (no port)  │ │    :8080    │                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
│  ┌─────────────┐ ┌─────────────┐                                 │
│  │Node Exporter│ │SNMP Exporter│                                 │
│  │   :9100     │ │    :9116    │                                 │
│  └─────────────┘ └─────────────┘                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
.
├── ansible.cfg                 # Ansible settings
├── requirements.yml            # Galaxy collection dependencies
├── inventory/
│   └── localhost.yml           # Inventory (local connection)
├── group_vars/
│   └── all.yml                 # All variables in one place
├── playbooks/
│   └── site.yml                # Main entry point
├── roles/
│   ├── common/                 # Base OS configuration
│   │   └── tasks/main.yml
│   ├── docker/                 # Docker installation
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   ├── monitoring/             # Prometheus/Grafana stack
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   ├── files/
│   │   │   ├── docker-compose.yml
│   │   │   └── prometheus.yml
│   │   └── templates/
│   │       └── grafana-datasources.yml.j2
│   ├── homeassistant/          # Home Assistant + HACS
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   └── templates/
│   │       ├── configuration.yaml.j2
│   │       └── secrets.yaml.j2
│   ├── tailscale/              # Tailscale VPN
│   │   └── tasks/main.yml
│   └── boot-sync/              # Systemd service management
│       ├── tasks/main.yml
│       └── handlers/main.yml
├── systemd/                    # Systemd unit files
│   ├── ansible-boot-sync.service
│   ├── ansible-sync.service
│   └── ansible-sync.timer
└── scripts/
    ├── bootstrap.sh            # Initial Pi setup script
    └── boot-sync.sh            # Boot automation script
```

## Adding a New Role

### 1. Create the Directory Structure

```bash
mkdir -p roles/newrole/{tasks,handlers,files,templates,defaults}
```

### 2. Create the Main Tasks File

```yaml
# roles/newrole/tasks/main.yml
---
- name: Install something
  ansible.builtin.apt:
    name: some-package
    state: present
  tags:
    - newrole

- name: Configure something
  ansible.builtin.template:
    src: config.j2
    dest: /etc/something/config
  notify: Restart something
  tags:
    - newrole
```

### 3. Create Handlers (if needed)

```yaml
# roles/newrole/handlers/main.yml
---
- name: Restart something
  ansible.builtin.systemd:
    name: something
    state: restarted
```

### 4. Add to the Main Playbook

```yaml
# playbooks/site.yml
roles:
  # ... existing roles ...
  - role: newrole
    tags:
      - newrole
```

### 5. Add Variables (if needed)

```yaml
# group_vars/all.yml
# -----------------------------------------------------------------------------
# New Role Configuration
# -----------------------------------------------------------------------------
newrole_port: 8080
newrole_config_dir: "{{ pi_home }}/newrole"
```

## Adding a New Docker Service

### 1. Edit the Docker Compose File

```yaml
# roles/monitoring/files/docker-compose.yml

services:
  # ... existing services ...

  newservice:
    image: someimage:latest
    container_name: newservice
    restart: unless-stopped
    ports:
      - "8888:8888"
    volumes:
      - newservice-data:/data
    environment:
      - TZ=Europe/London
    networks:
      - monitoring

volumes:
  # ... existing volumes ...
  newservice-data:
    name: newservice-data
```

### 2. Add Prometheus Scrape Config (if metrics exposed)

```yaml
# roles/monitoring/files/prometheus.yml

scrape_configs:
  # ... existing configs ...

  - job_name: 'newservice'
    static_configs:
      - targets: ['newservice:8888']
        labels:
          instance: 'newservice'
```

## Variables Reference

All variables are defined in `group_vars/all.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `pi_hostname` | keeper | System hostname |
| `pi_timezone` | Europe/London | System timezone |
| `pi_ip` | 192.168.88.253 | Static IP address |
| `pi_user` | pi | Primary user |
| `pi_home` | /home/pi | Home directory |
| `mikrotik_ip` | 192.168.88.1 | Router IP for SNMP |
| `prometheus_port` | 9090 | Prometheus web UI |
| `grafana_port` | 3000 | Grafana web UI |
| `grafana_admin_password` | ChangeMe123! | Grafana admin password |
| `homeassistant_port` | 8123 | Home Assistant web UI |
| `portainer_port` | 9443 | Portainer web UI (HTTPS) |
| `tailscale_advertise_routes` | 192.168.88.0/24 | Subnet to advertise |

## Tags Reference

Run specific parts of the playbook using tags:

```bash
# Run only common role
ansible-playbook playbooks/site.yml --tags common

# Run Docker and monitoring
ansible-playbook playbooks/site.yml --tags "docker,monitoring"

# Skip Tailscale
ansible-playbook playbooks/site.yml --skip-tags tailscale

# List all available tags
ansible-playbook playbooks/site.yml --list-tags
```

Available tags:
- `common`, `base` - Base system configuration
- `docker` - Docker installation
- `monitoring`, `prometheus`, `grafana` - Monitoring stack
- `homeassistant` - Home Assistant
- `tailscale`, `vpn` - Tailscale VPN
- `always` - Pre/post tasks (always run)

## Testing Changes

### Syntax Check

```bash
ansible-playbook playbooks/site.yml --syntax-check
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbooks/site.yml --check
```

### Diff Mode (Show Changes)

```bash
ansible-playbook playbooks/site.yml --check --diff
```

### Run on Specific Tags

```bash
ansible-playbook playbooks/site.yml --tags "common" --check
```

### Verbose Output

```bash
# Increasing verbosity levels
ansible-playbook playbooks/site.yml -v
ansible-playbook playbooks/site.yml -vv
ansible-playbook playbooks/site.yml -vvv
```

## Boot Sync Script

The `scripts/boot-sync.sh` script handles automated deployment:

### Flow

1. **Lock Check**: Prevents concurrent runs
2. **Network Wait**: Waits up to 60s for connectivity
3. **Git Sync**: Pulls latest from origin/main
4. **Requirements**: Installs Ansible Galaxy collections
5. **Ansible Run**: Executes playbook with retries (3 attempts)
6. **Cleanup**: Removes lock file

### Configuration

Edit these variables in `scripts/boot-sync.sh`:

```bash
REPO_URL="https://github.com/KevNev19/pi-and-mikrotek-ansible-setup.git"
CONFIG_DIR="/home/pi/pi-and-mikrotek-ansible-setup"
LOG_FILE="/var/log/ansible-boot-sync.log"
MAX_RETRIES=3
RETRY_DELAY=10
```

### Logs

```bash
# Systemd journal
sudo journalctl -u ansible-boot-sync.service -f

# Log file
tail -f /var/log/ansible-boot-sync.log
```

## Secrets Management

### Using Ansible Vault

For sensitive data, use Ansible Vault:

```bash
# Create encrypted vars file
ansible-vault create group_vars/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# Run playbook with vault
ansible-playbook playbooks/site.yml --ask-vault-pass
```

### Vault File Example

```yaml
# group_vars/vault.yml (encrypted)
vault_grafana_password: "SuperSecretPassword123!"
vault_tailscale_authkey: "tskey-auth-xxxxx"
```

### Reference in all.yml

```yaml
# group_vars/all.yml
grafana_admin_password: "{{ vault_grafana_password }}"
tailscale_authkey: "{{ vault_tailscale_authkey }}"
```

## Common Patterns

### Idempotent File Creation

```yaml
- name: Create config file
  ansible.builtin.copy:
    dest: /etc/app/config.yml
    content: |
      setting: value
    mode: '0644'
    owner: root
    group: root
```

### Template with Variables

```yaml
- name: Template config
  ansible.builtin.template:
    src: config.yml.j2
    dest: /etc/app/config.yml
    mode: '0644'
  notify: Restart app
```

### Conditional Execution

```yaml
- name: Run only if Docker not installed
  ansible.builtin.command: install-docker.sh
  when: docker_installed.rc != 0
```

### Loop Over Items

```yaml
- name: Create directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /opt/app/config
    - /opt/app/data
    - /opt/app/logs
```

### Wait for Service

```yaml
- name: Wait for service to be ready
  ansible.builtin.uri:
    url: "http://localhost:8080/health"
    status_code: 200
  register: result
  until: result.status == 200
  retries: 30
  delay: 5
```

## Workflow Summary

```
Developer Machine                    Raspberry Pi
─────────────────                    ────────────

1. Edit files locally
        │
2. git commit && git push
        │
        └──────────────────────────► 3. Boot or manual trigger
                                            │
                                     4. git pull
                                            │
                                     5. ansible-playbook
                                            │
                                     6. Services configured
```

## Contributing

1. Create a feature branch
2. Make changes
3. Test with `--check` mode
4. Commit with descriptive message
5. Push and create PR
