# Raspberry Pi Ansible Git-Based Boot Sync Configuration Guide

## Overview

This guide walks you through setting up a self-healing, Git-driven configuration management system for your Raspberry Pi 4 (hostname: `keeper`). Every time your Pi boots, it will:

1. Pull the latest configuration from your Git repository
2. Run Ansible playbooks to ensure everything is configured correctly
3. Start all Docker services with the correct configuration

This ensures your Pi is always in a known, reproducible state and can be rebuilt from scratch in minutes if needed.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Prerequisites](#prerequisites)
3. [Repository Structure](#repository-structure)
4. [Step-by-Step Setup](#step-by-step-setup)
   - [Step 1: Install Ansible on the Pi](#step-1-install-ansible-on-the-pi)
   - [Step 2: Create the Git Repository](#step-2-create-the-git-repository)
   - [Step 3: Create Ansible Configuration](#step-3-create-ansible-configuration)
   - [Step 4: Create Inventory](#step-4-create-inventory)
   - [Step 5: Create Group Variables](#step-5-create-group-variables)
   - [Step 6: Create Roles](#step-6-create-roles)
   - [Step 7: Create Main Playbook](#step-7-create-main-playbook)
   - [Step 8: Create Boot Sync Script](#step-8-create-boot-sync-script)
   - [Step 9: Create Ansible Requirements](#step-9-create-ansible-requirements)
   - [Step 10: Push to Git](#step-10-push-to-git)
   - [Step 11: Configure Pi Boot Sync Service](#step-11-configure-pi-boot-sync-service)
   - [Step 12: Optional Scheduled Sync](#step-12-optional-scheduled-sync)
5. [Usage and Workflow](#usage-and-workflow)
6. [Troubleshooting](#troubleshooting)
7. [Security Considerations](#security-considerations)
8. [Extending the Configuration](#extending-the-configuration)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Git Repository (GitHub/GitLab)              │
│                                                                 │
│  pi-ansible-config/                                             │
│  ├── ansible.cfg                                                │
│  ├── inventory/                                                 │
│  ├── playbooks/                                                 │
│  ├── roles/                                                     │
│  ├── group_vars/                                                │
│  └── scripts/                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ git pull (on boot)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Raspberry Pi 4 (keeper)                      │
│                       192.168.88.253                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              systemd: ansible-boot-sync.service          │   │
│  │                                                          │   │
│  │  1. Wait for network                                     │   │
│  │  2. Git pull latest config                               │   │
│  │  3. Run ansible-playbook                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Ansible Playbooks                     │   │
│  │                                                          │   │
│  │  Roles:                                                  │   │
│  │  - common (packages, timezone, hostname)                 │   │
│  │  - docker (install & configure Docker)                   │   │
│  │  - monitoring (Prometheus, Grafana, exporters)           │   │
│  │  - homeassistant (Home Assistant container)              │   │
│  │  - tailscale (VPN for remote access)                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Docker Containers                      │   │
│  │                                                          │   │
│  │  - Prometheus (9090)      - Grafana (3000)              │   │
│  │  - Home Assistant (8123)  - Portainer (9443)            │   │
│  │  - Node Exporter (9100)   - cAdvisor (8080)             │   │
│  │  - SNMP Exporter (9116)   - Watchtower (auto-update)    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### On Your Raspberry Pi

- Raspberry Pi 4 running Raspberry Pi OS (64-bit recommended)
- Docker installed and running
- Network connectivity
- SSH access enabled
- Static IP configured (192.168.88.253)

### On Your Development Machine (Mac/PC)

- Git installed
- GitHub/GitLab account
- Text editor (VS Code recommended)

### Current Pi Setup (from previous configuration)

Your Pi should already have:

- Docker and Docker Compose
- Network monitoring stack (Prometheus, Grafana)
- Home Assistant
- Tailscale
- Static IP: 192.168.88.253
- Hostname: keeper

---

## Repository Structure

Create this structure for your Git repository:

```
pi-ansible-config/
├── ansible.cfg                          # Ansible configuration
├── requirements.yml                     # Ansible Galaxy dependencies
├── inventory/
│   └── localhost.yml                    # Inventory for local execution
├── playbooks/
│   └── site.yml                         # Main playbook
├── roles/
│   ├── common/
│   │   └── tasks/
│   │       └── main.yml                 # Base system configuration
│   ├── docker/
│   │   ├── tasks/
│   │   │   └── main.yml                 # Docker installation
│   │   └── handlers/
│   │       └── main.yml                 # Docker handlers
│   ├── monitoring/
│   │   ├── tasks/
│   │   │   └── main.yml                 # Monitoring stack setup
│   │   ├── files/
│   │   │   ├── docker-compose.yml       # Docker Compose configuration
│   │   │   └── prometheus.yml           # Prometheus configuration
│   │   ├── templates/
│   │   │   └── grafana-datasources.yml.j2
│   │   └── handlers/
│   │       └── main.yml                 # Monitoring handlers
│   ├── homeassistant/
│   │   └── tasks/
│   │       └── main.yml                 # Home Assistant setup
│   └── tailscale/
│       └── tasks/
│           └── main.yml                 # Tailscale VPN setup
├── group_vars/
│   └── all.yml                          # Global variables
└── scripts/
    └── boot-sync.sh                     # Boot sync script
```

---

## Step-by-Step Setup

### Step 1: Install Ansible on the Pi

SSH into your Raspberry Pi:

```bash
ssh pi@192.168.88.253
```

Install Ansible and Git:

```bash
sudo apt update
sudo apt install ansible git -y
```

Verify installation:

```bash
ansible --version
```

Expected output:

```
ansible [core 2.14.x]
  config file = None
  configured module search path = ['/home/pi/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /home/pi/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.11.x
```

---

### Step 2: Create the Git Repository

On your development machine (Mac/PC), create the repository:

```bash
mkdir pi-ansible-config
cd pi-ansible-config
git init
```

Create all necessary directories:

```bash
# Create directory structure
mkdir -p inventory
mkdir -p playbooks
mkdir -p roles/common/tasks
mkdir -p roles/docker/tasks
mkdir -p roles/docker/handlers
mkdir -p roles/monitoring/tasks
mkdir -p roles/monitoring/files
mkdir -p roles/monitoring/templates
mkdir -p roles/monitoring/handlers
mkdir -p roles/homeassistant/tasks
mkdir -p roles/tailscale/tasks
mkdir -p group_vars
mkdir -p scripts
```

---

### Step 3: Create Ansible Configuration

Create `ansible.cfg` in the repository root:

```ini
[defaults]
inventory = inventory/localhost.yml
roles_path = roles
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
deprecation_warnings = False
interpreter_python = auto_silent

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
pipelining = True
```

---

### Step 4: Create Inventory

Create `inventory/localhost.yml`:

```yaml
---
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
  vars:
    # Pi User Configuration
    pi_user: pi
    pi_home: /home/pi
    
    # Network Configuration
    pi_ip: 192.168.88.253
    mikrotik_ip: 192.168.88.1
    
    # Directory Paths
    network_monitoring_dir: /home/pi/network-monitoring
    config_repo_dir: /home/pi/pi-ansible-config
```

---

### Step 5: Create Group Variables

Create `group_vars/all.yml`:

```yaml
---
# =============================================================================
# Raspberry Pi Ansible Configuration - Global Variables
# =============================================================================

# -----------------------------------------------------------------------------
# System Configuration
# -----------------------------------------------------------------------------
pi_hostname: keeper
pi_timezone: Europe/London
pi_locale: en_GB.UTF-8

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
pi_ip: 192.168.88.253
mikrotik_ip: 192.168.88.1
network_subnet: 192.168.88.0/24

# -----------------------------------------------------------------------------
# User Configuration
# -----------------------------------------------------------------------------
pi_user: pi
pi_home: /home/pi

# -----------------------------------------------------------------------------
# Directory Paths
# -----------------------------------------------------------------------------
network_monitoring_dir: "{{ pi_home }}/network-monitoring"
config_repo_dir: "{{ pi_home }}/pi-ansible-config"
scripts_dir: "{{ pi_home }}/scripts"

# -----------------------------------------------------------------------------
# Docker Configuration
# -----------------------------------------------------------------------------
docker_compose_version: "3.8"
docker_log_max_size: "10m"
docker_log_max_file: "3"

# -----------------------------------------------------------------------------
# Monitoring Stack Configuration
# -----------------------------------------------------------------------------
# Prometheus
prometheus_port: 9090
prometheus_retention_time: 30d
prometheus_scrape_interval: 30s

# Grafana
grafana_port: 3000
grafana_admin_user: admin
grafana_admin_password: "ChangeMe123!"  # Change this! Consider using ansible-vault

# Node Exporter
node_exporter_port: 9100

# SNMP Exporter
snmp_exporter_port: 9116

# cAdvisor
cadvisor_port: 8080

# -----------------------------------------------------------------------------
# Home Assistant Configuration
# -----------------------------------------------------------------------------
homeassistant_port: 8123
homeassistant_config_dir: "{{ network_monitoring_dir }}/homeassistant"

# -----------------------------------------------------------------------------
# Portainer Configuration
# -----------------------------------------------------------------------------
portainer_port: 9443

# -----------------------------------------------------------------------------
# Watchtower Configuration
# -----------------------------------------------------------------------------
# Schedule format: seconds minutes hours day-of-month month day-of-week
# Default: 4 AM daily
watchtower_schedule: "0 0 4 * * *"
watchtower_cleanup: true

# -----------------------------------------------------------------------------
# Tailscale Configuration
# -----------------------------------------------------------------------------
# Leave empty for interactive authentication
# Or set an auth key for unattended setup (from Tailscale admin console)
tailscale_authkey: ""

# Subnet routing (advertise home network for remote access)
tailscale_advertise_routes: "192.168.88.0/24"
tailscale_accept_routes: true

# -----------------------------------------------------------------------------
# Backup Configuration
# -----------------------------------------------------------------------------
backup_retention_days: 30
backup_dir: "{{ pi_home }}/backups"

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------
ansible_log_dir: /var/log/ansible
boot_sync_log: /var/log/ansible-boot-sync.log
```

---

### Step 6: Create Roles

#### Role: common

Create `roles/common/tasks/main.yml`:

```yaml
---
# =============================================================================
# Common Role - Base System Configuration
# =============================================================================

- name: Set hostname
  ansible.builtin.hostname:
    name: "{{ pi_hostname }}"
  tags:
    - hostname
    - common

- name: Update /etc/hosts with hostname
  ansible.builtin.lineinfile:
    path: /etc/hosts
    regexp: '^127\.0\.1\.1'
    line: "127.0.1.1\t{{ pi_hostname }}"
    state: present
  tags:
    - hostname
    - common

- name: Set timezone
  community.general.timezone:
    name: "{{ pi_timezone }}"
  tags:
    - timezone
    - common

- name: Update apt cache
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600
  tags:
    - packages
    - common

- name: Upgrade all packages
  ansible.builtin.apt:
    upgrade: safe
  tags:
    - packages
    - common
  when: ansible_facts['pkg_mgr'] == 'apt'

- name: Install essential packages
  ansible.builtin.apt:
    name:
      - curl
      - wget
      - vim
      - htop
      - iotop
      - git
      - python3-pip
      - python3-venv
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
      - jq
      - tree
      - ncdu
      - tmux
      - rsync
      - unzip
      - net-tools
      - dnsutils
      - iputils-ping
    state: present
  tags:
    - packages
    - common

- name: Install unattended-upgrades for automatic security updates
  ansible.builtin.apt:
    name:
      - unattended-upgrades
      - apt-listchanges
    state: present
  tags:
    - security
    - common

- name: Configure unattended-upgrades - auto updates
  ansible.builtin.copy:
    dest: /etc/apt/apt.conf.d/20auto-upgrades
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
      APT::Periodic::AutocleanInterval "7";
      APT::Periodic::Download-Upgradeable-Packages "1";
    mode: '0644'
    owner: root
    group: root
  tags:
    - security
    - common

- name: Configure unattended-upgrades - upgrade settings
  ansible.builtin.copy:
    dest: /etc/apt/apt.conf.d/50unattended-upgrades
    content: |
      Unattended-Upgrade::Origins-Pattern {
          "origin=Debian,codename=${distro_codename},label=Debian-Security";
          "origin=Raspbian,codename=${distro_codename},label=Raspbian";
      };
      Unattended-Upgrade::Package-Blacklist {
      };
      Unattended-Upgrade::AutoFixInterruptedDpkg "true";
      Unattended-Upgrade::MinimalSteps "true";
      Unattended-Upgrade::Remove-Unused-Dependencies "true";
      Unattended-Upgrade::Automatic-Reboot "false";
    mode: '0644'
    owner: root
    group: root
  tags:
    - security
    - common

- name: Create scripts directory
  ansible.builtin.file:
    path: "{{ scripts_dir }}"
    state: directory
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0755'
  tags:
    - directories
    - common

- name: Create backup directory
  ansible.builtin.file:
    path: "{{ backup_dir }}"
    state: directory
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0755'
  tags:
    - directories
    - common

- name: Create ansible log directory
  ansible.builtin.file:
    path: "{{ ansible_log_dir }}"
    state: directory
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0755'
  tags:
    - directories
    - common

- name: Configure vim as default editor
  ansible.builtin.lineinfile:
    path: "{{ pi_home }}/.bashrc"
    line: "export EDITOR=vim"
    state: present
    create: yes
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
  tags:
    - shell
    - common

- name: Add useful bash aliases
  ansible.builtin.blockinfile:
    path: "{{ pi_home }}/.bashrc"
    block: |
      # Custom aliases
      alias ll='ls -la'
      alias dc='docker compose'
      alias dps='docker ps --format "table {{"{{"}}.Names{{"}}"}}\t{{"{{"}}.Status{{"}}"}}\t{{"{{"}}.Ports{{"}}"}}"'
      alias dlogs='docker compose logs -f'
      alias ansible-sync='sudo systemctl start ansible-boot-sync.service'
      alias sync-status='sudo systemctl status ansible-boot-sync.service'
      alias sync-logs='sudo journalctl -u ansible-boot-sync.service -f'
    marker: "# {mark} ANSIBLE MANAGED ALIASES"
    create: yes
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
  tags:
    - shell
    - common

- name: Set swappiness to reduce SD card wear
  ansible.posix.sysctl:
    name: vm.swappiness
    value: '10'
    state: present
    reload: yes
  tags:
    - performance
    - common

- name: Enable IP forwarding (for Tailscale subnet routing)
  ansible.posix.sysctl:
    name: "{{ item }}"
    value: '1'
    state: present
    reload: yes
  loop:
    - net.ipv4.ip_forward
    - net.ipv6.conf.all.forwarding
  tags:
    - network
    - common
```

#### Role: docker

Create `roles/docker/tasks/main.yml`:

```yaml
---
# =============================================================================
# Docker Role - Install and Configure Docker
# =============================================================================

- name: Check if Docker is installed
  ansible.builtin.command: docker --version
  register: docker_installed
  ignore_errors: yes
  changed_when: false
  tags:
    - docker

- name: Install Docker
  when: docker_installed.rc != 0
  block:
    - name: Download Docker install script
      ansible.builtin.get_url:
        url: https://get.docker.com
        dest: /tmp/get-docker.sh
        mode: '0755'

    - name: Run Docker install script
      ansible.builtin.command: /tmp/get-docker.sh
      args:
        creates: /usr/bin/docker

    - name: Remove Docker install script
      ansible.builtin.file:
        path: /tmp/get-docker.sh
        state: absent
  tags:
    - docker

- name: Add pi user to docker group
  ansible.builtin.user:
    name: "{{ pi_user }}"
    groups: docker
    append: yes
  tags:
    - docker

- name: Ensure Docker service is running and enabled
  ansible.builtin.systemd:
    name: docker
    state: started
    enabled: yes
  tags:
    - docker

- name: Install Docker Compose plugin
  ansible.builtin.apt:
    name: docker-compose-plugin
    state: present
  tags:
    - docker

- name: Configure Docker daemon
  ansible.builtin.copy:
    dest: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "{{ docker_log_max_size }}",
          "max-file": "{{ docker_log_max_file }}"
        },
        "storage-driver": "overlay2"
      }
    mode: '0644'
    owner: root
    group: root
  notify: Restart Docker
  tags:
    - docker

- name: Install Python Docker library for Ansible
  ansible.builtin.pip:
    name:
      - docker
      - docker-compose
    state: present
    break_system_packages: yes
  tags:
    - docker
```

Create `roles/docker/handlers/main.yml`:

```yaml
---
# =============================================================================
# Docker Role - Handlers
# =============================================================================

- name: Restart Docker
  ansible.builtin.systemd:
    name: docker
    state: restarted
```

#### Role: monitoring

Create `roles/monitoring/tasks/main.yml`:

```yaml
---
# =============================================================================
# Monitoring Role - Prometheus, Grafana, and Supporting Services
# =============================================================================

- name: Create network-monitoring directory
  ansible.builtin.file:
    path: "{{ network_monitoring_dir }}"
    state: directory
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0755'
  tags:
    - monitoring

- name: Create Grafana provisioning directories
  ansible.builtin.file:
    path: "{{ network_monitoring_dir }}/grafana/provisioning/{{ item }}"
    state: directory
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0755'
  loop:
    - datasources
    - dashboards
  tags:
    - monitoring
    - grafana

- name: Copy docker-compose.yml
  ansible.builtin.copy:
    src: docker-compose.yml
    dest: "{{ network_monitoring_dir }}/docker-compose.yml"
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0644'
  notify: Restart monitoring stack
  tags:
    - monitoring

- name: Copy prometheus.yml
  ansible.builtin.copy:
    src: prometheus.yml
    dest: "{{ network_monitoring_dir }}/prometheus.yml"
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0644'
  notify: Restart monitoring stack
  tags:
    - monitoring
    - prometheus

- name: Template Grafana datasources configuration
  ansible.builtin.template:
    src: grafana-datasources.yml.j2
    dest: "{{ network_monitoring_dir }}/grafana/provisioning/datasources/prometheus.yml"
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0644'
  notify: Restart monitoring stack
  tags:
    - monitoring
    - grafana

- name: Create Grafana dashboards configuration
  ansible.builtin.copy:
    dest: "{{ network_monitoring_dir }}/grafana/provisioning/dashboards/dashboards.yml"
    content: |
      apiVersion: 1
      
      providers:
        - name: 'Default'
          orgId: 1
          folder: ''
          type: file
          disableDeletion: false
          updateIntervalSeconds: 10
          allowUiUpdates: true
          options:
            path: /etc/grafana/provisioning/dashboards
    owner: "{{ pi_user }}"
    group: "{{ pi_user }}"
    mode: '0644'
  tags:
    - monitoring
    - grafana

- name: Start Docker Compose monitoring stack
  community.docker.docker_compose_v2:
    project_src: "{{ network_monitoring_dir }}"
    state: present
  become_user: "{{ pi_user }}"
  tags:
    - monitoring

- name: Wait for Grafana to be ready
  ansible.builtin.uri:
    url: "http://localhost:{{ grafana_port }}/api/health"
    method: GET
    status_code: 200
  register: grafana_health
  until: grafana_health.status == 200
  retries: 30
  delay: 5
  tags:
    - monitoring
    - grafana

- name: Wait for Prometheus to be ready
  ansible.builtin.uri:
    url: "http://localhost:{{ prometheus_port }}/-/healthy"
    method: GET
    status_code: 200
  register: prometheus_health
  until: prometheus_health.status == 200
  retries: 30
  delay: 5
  tags:
    - monitoring
    - prometheus
```

Create `roles/monitoring/handlers/main.yml`:

```yaml
---
# =============================================================================
# Monitoring Role - Handlers
# =============================================================================

- name: Restart monitoring stack
  community.docker.docker_compose_v2:
    project_src: "{{ network_monitoring_dir }}"
    state: present
    recreate: always
  become_user: "{{ pi_user }}"
```

Create `roles/monitoring/files/docker-compose.yml`:

```yaml
version: "3.8"

services:
  # ===========================================================================
  # Prometheus - Metrics Collection
  # ===========================================================================
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ===========================================================================
  # SNMP Exporter - MikroTik Metrics
  # ===========================================================================
  snmp-exporter:
    image: prom/snmp-exporter:latest
    container_name: snmp-exporter
    restart: unless-stopped
    ports:
      - "9116:9116"
    networks:
      - monitoring

  # ===========================================================================
  # Grafana - Visualization
  # ===========================================================================
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-ChangeMe123!}
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-clock-panel
      - GF_SERVER_ROOT_URL=http://192.168.88.253:3000
      - GF_USERS_ALLOW_SIGN_UP=false
    networks:
      - monitoring
    depends_on:
      - prometheus
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ===========================================================================
  # Node Exporter - Pi System Metrics
  # ===========================================================================
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /:/host:ro,rslave
    networks:
      - monitoring

  # ===========================================================================
  # cAdvisor - Container Metrics
  # ===========================================================================
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    networks:
      - monitoring

  # ===========================================================================
  # Home Assistant - Smart Home Control
  # ===========================================================================
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    environment:
      - TZ=Europe/London
    volumes:
      - homeassistant-data:/config
    network_mode: host

  # ===========================================================================
  # Watchtower - Automatic Container Updates
  # ===========================================================================
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_REVIVE_STOPPED=true
      - TZ=Europe/London
    networks:
      - monitoring

  # ===========================================================================
  # Portainer - Container Management UI
  # ===========================================================================
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer-data:/data
    networks:
      - monitoring

# =============================================================================
# Networks
# =============================================================================
networks:
  monitoring:
    driver: bridge

# =============================================================================
# Volumes
# =============================================================================
volumes:
  prometheus-data:
    name: prometheus-data
  grafana-data:
    name: grafana-data
  homeassistant-data:
    name: homeassistant-data
  portainer-data:
    name: portainer-data
```

Create `roles/monitoring/files/prometheus.yml`:

```yaml
# =============================================================================
# Prometheus Configuration
# =============================================================================

global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    monitor: 'home-network'
    environment: 'production'

# =============================================================================
# Scrape Configurations
# =============================================================================
scrape_configs:
  # ---------------------------------------------------------------------------
  # MikroTik Router via SNMP
  # ---------------------------------------------------------------------------
  - job_name: 'mikrotik-router'
    static_configs:
      - targets:
        - 192.168.88.1
    metrics_path: /snmp
    params:
      module: [mikrotik]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: snmp-exporter:9116

  # ---------------------------------------------------------------------------
  # Raspberry Pi System Metrics
  # ---------------------------------------------------------------------------
  - job_name: 'raspberry-pi'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'raspberry-pi-keeper'
          host: 'keeper'

  # ---------------------------------------------------------------------------
  # Prometheus Self-Monitoring
  # ---------------------------------------------------------------------------
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus'

  # ---------------------------------------------------------------------------
  # Docker Container Metrics
  # ---------------------------------------------------------------------------
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          instance: 'raspberry-pi-keeper'
          host: 'keeper'

  # ---------------------------------------------------------------------------
  # SNMP Exporter Metrics
  # ---------------------------------------------------------------------------
  - job_name: 'snmp-exporter'
    static_configs:
      - targets: ['snmp-exporter:9116']
        labels:
          instance: 'snmp-exporter'
```

Create `roles/monitoring/templates/grafana-datasources.yml.j2`:

```yaml
# =============================================================================
# Grafana Datasources Configuration (Ansible Managed)
# =============================================================================

apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:{{ prometheus_port }}
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "{{ prometheus_scrape_interval }}"
```

#### Role: tailscale

Create `roles/tailscale/tasks/main.yml`:

```yaml
---
# =============================================================================
# Tailscale Role - VPN for Remote Access
# =============================================================================

- name: Check if Tailscale is installed
  ansible.builtin.command: tailscale --version
  register: tailscale_installed
  ignore_errors: yes
  changed_when: false
  tags:
    - tailscale

- name: Install Tailscale
  when: tailscale_installed.rc != 0
  block:
    - name: Download Tailscale install script
      ansible.builtin.get_url:
        url: https://tailscale.com/install.sh
        dest: /tmp/tailscale-install.sh
        mode: '0755'

    - name: Run Tailscale install script
      ansible.builtin.command: /tmp/tailscale-install.sh
      args:
        creates: /usr/bin/tailscale

    - name: Remove Tailscale install script
      ansible.builtin.file:
        path: /tmp/tailscale-install.sh
        state: absent
  tags:
    - tailscale

- name: Ensure Tailscale service is enabled
  ansible.builtin.systemd:
    name: tailscaled
    state: started
    enabled: yes
  tags:
    - tailscale

- name: Check Tailscale status
  ansible.builtin.command: tailscale status --json
  register: tailscale_status
  ignore_errors: yes
  changed_when: false
  tags:
    - tailscale

- name: Parse Tailscale status
  ansible.builtin.set_fact:
    tailscale_connected: "{{ (tailscale_status.stdout | from_json).BackendState == 'Running' }}"
  when: tailscale_status.rc == 0
  ignore_errors: yes
  tags:
    - tailscale

- name: Connect Tailscale with auth key (if provided)
  ansible.builtin.command: >
    tailscale up
    --authkey={{ tailscale_authkey }}
    --advertise-routes={{ tailscale_advertise_routes }}
    --accept-routes
  when:
    - tailscale_authkey | length > 0
    - not tailscale_connected | default(false)
  tags:
    - tailscale

- name: Display Tailscale connection instructions
  ansible.builtin.debug:
    msg: |
      Tailscale is installed but may not be connected.
      
      To connect manually, run:
        sudo tailscale up --advertise-routes={{ tailscale_advertise_routes }} --accept-routes
      
      Then approve the routes in the Tailscale admin console:
        https://login.tailscale.com/admin/machines
  when:
    - tailscale_authkey | length == 0
    - not tailscale_connected | default(false)
  tags:
    - tailscale

- name: Get Tailscale IP
  ansible.builtin.command: tailscale ip -4
  register: tailscale_ip
  changed_when: false
  ignore_errors: yes
  tags:
    - tailscale

- name: Display Tailscale IP
  ansible.builtin.debug:
    msg: "Tailscale IP: {{ tailscale_ip.stdout | default('Not connected') }}"
  tags:
    - tailscale
```

---

### Step 7: Create Main Playbook

Create `playbooks/site.yml`:

```yaml
---
# =============================================================================
# Main Playbook - Raspberry Pi Configuration
# =============================================================================
# 
# This playbook configures the Raspberry Pi with:
# - Base system configuration (packages, timezone, etc.)
# - Docker and Docker Compose
# - Monitoring stack (Prometheus, Grafana, exporters)
# - Home Assistant
# - Tailscale VPN for remote access
#
# Usage:
#   ansible-playbook playbooks/site.yml
#   ansible-playbook playbooks/site.yml --tags "docker,monitoring"
#   ansible-playbook playbooks/site.yml --skip-tags "tailscale"
#
# =============================================================================

- name: Configure Raspberry Pi - Keeper
  hosts: localhost
  become: yes
  gather_facts: yes

  # ---------------------------------------------------------------------------
  # Pre-Tasks
  # ---------------------------------------------------------------------------
  pre_tasks:
    - name: Display start message
      ansible.builtin.debug:
        msg: |
          ╔════════════════════════════════════════════════════════════════╗
          ║        Raspberry Pi Ansible Configuration Starting             ║
          ╠════════════════════════════════════════════════════════════════╣
          ║  Hostname: {{ ansible_hostname }}
          ║  IP Address: {{ ansible_default_ipv4.address | default('N/A') }}
          ║  OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          ║  Time: {{ ansible_date_time.iso8601 }}
          ╚════════════════════════════════════════════════════════════════╝
      tags:
        - always

    - name: Verify we're running on a Raspberry Pi
      ansible.builtin.assert:
        that:
          - ansible_architecture in ['aarch64', 'armv7l', 'armv6l']
        fail_msg: "This playbook is designed to run on a Raspberry Pi"
        success_msg: "Running on Raspberry Pi ({{ ansible_architecture }})"
      tags:
        - always

    - name: Check available disk space
      ansible.builtin.assert:
        that:
          - ansible_mounts | selectattr('mount', 'equalto', '/') | map(attribute='size_available') | first | int > 1073741824
        fail_msg: "Less than 1GB disk space available!"
        success_msg: "Sufficient disk space available"
      tags:
        - always

  # ---------------------------------------------------------------------------
  # Roles
  # ---------------------------------------------------------------------------
  roles:
    - role: common
      tags:
        - common
        - base

    - role: docker
      tags:
        - docker

    - role: monitoring
      tags:
        - monitoring
        - prometheus
        - grafana

    - role: tailscale
      tags:
        - tailscale
        - vpn

  # ---------------------------------------------------------------------------
  # Post-Tasks
  # ---------------------------------------------------------------------------
  post_tasks:
    - name: Display completion summary
      ansible.builtin.debug:
        msg: |
          ╔════════════════════════════════════════════════════════════════╗
          ║           Configuration Complete!                              ║
          ╠════════════════════════════════════════════════════════════════╣
          ║                                                                ║
          ║  Services Available (Local Network):                           ║
          ║  ─────────────────────────────────────────────────────────────║
          ║  • Grafana:        http://{{ pi_ip }}:{{ grafana_port }}
          ║  • Prometheus:     http://{{ pi_ip }}:{{ prometheus_port }}
          ║  • Home Assistant: http://{{ pi_ip }}:{{ homeassistant_port }}
          ║  • Portainer:      https://{{ pi_ip }}:{{ portainer_port }}
          ║  • cAdvisor:       http://{{ pi_ip }}:{{ cadvisor_port }}
          ║                                                                ║
          ║  With MikroTik DNS configured, also accessible via:            ║
          ║  ─────────────────────────────────────────────────────────────║
          ║  • http://grafana.home:{{ grafana_port }}
          ║  • http://homeassistant.home:{{ homeassistant_port }}
          ║  • http://prometheus.home:{{ prometheus_port }}
          ║                                                                ║
          ║  Remote Access (via Tailscale):                                ║
          ║  ─────────────────────────────────────────────────────────────║
          ║  • Connect to Tailscale on your device                         ║
          ║  • Access services using Tailscale IP or MagicDNS              ║
          ║                                                                ║
          ╚════════════════════════════════════════════════════════════════╝
      tags:
        - always

    - name: Log successful Ansible run
      ansible.builtin.copy:
        content: |
          Last successful Ansible run: {{ ansible_date_time.iso8601 }}
          Hostname: {{ ansible_hostname }}
          Playbook: site.yml
          Git commit: {{ lookup('pipe', 'cd ' + config_repo_dir + ' && git rev-parse --short HEAD 2>/dev/null || echo "unknown"') }}
        dest: "{{ pi_home }}/.ansible-last-run"
        owner: "{{ pi_user }}"
        group: "{{ pi_user }}"
        mode: '0644'
      tags:
        - always

    - name: Display any warnings or manual steps needed
      ansible.builtin.debug:
        msg: |
          ⚠️  Manual Steps Required:
          
          1. If Tailscale isn't connected, run:
             sudo tailscale up --advertise-routes=192.168.88.0/24 --accept-routes
          
          2. Approve subnet routes in Tailscale admin:
             https://login.tailscale.com/admin/machines
          
          3. Change default Grafana password:
             http://{{ pi_ip }}:{{ grafana_port }}
             Default: admin / {{ grafana_admin_password }}
          
          4. Configure MikroTik DNS entries (if not already done):
             /ip dns static
             add name=homeassistant.home address={{ pi_ip }}
             add name=grafana.home address={{ pi_ip }}
             add name=prometheus.home address={{ pi_ip }}
             add name=keeper.home address={{ pi_ip }}
      tags:
        - always
```

---

### Step 8: Create Boot Sync Script

Create `scripts/boot-sync.sh`:

```bash
#!/bin/bash
# =============================================================================
# Raspberry Pi Ansible Boot Sync Script
# =============================================================================
#
# This script is triggered on every boot by systemd to:
# 1. Pull the latest configuration from Git
# 2. Run Ansible playbooks to configure the system
#
# Logs are written to: /var/log/ansible-boot-sync.log
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REPO_URL="https://github.com/YOUR_USERNAME/pi-ansible-config.git"
CONFIG_DIR="/home/pi/pi-ansible-config"
LOG_FILE="/var/log/ansible-boot-sync.log"
LOCK_FILE="/tmp/ansible-boot-sync.lock"
MAX_RETRIES=3
RETRY_DELAY=10

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

cleanup() {
    rm -f "$LOCK_FILE"
    log_info "Cleanup complete"
}

wait_for_network() {
    log_info "Waiting for network connectivity..."
    local attempt=1
    while [ $attempt -le 30 ]; do
        if ping -c 1 -W 2 github.com &> /dev/null; then
            log_info "Network is available"
            return 0
        fi
        log_info "Waiting for network... attempt $attempt/30"
        sleep 2
        ((attempt++))
    done
    log_error "Network not available after 60 seconds"
    return 1
}

sync_repository() {
    log_info "Syncing configuration repository..."
    
    if [ -d "$CONFIG_DIR/.git" ]; then
        log_info "Pulling latest changes..."
        cd "$CONFIG_DIR"
        
        # Fetch and reset to handle force pushes
        git fetch origin
        git reset --hard origin/main
        git clean -fd
        
        log_info "Repository updated to commit: $(git rev-parse --short HEAD)"
    else
        log_info "Cloning repository..."
        rm -rf "$CONFIG_DIR"
        git clone "$REPO_URL" "$CONFIG_DIR"
        log_info "Repository cloned at commit: $(cd "$CONFIG_DIR" && git rev-parse --short HEAD)"
    fi
}

install_ansible_requirements() {
    log_info "Installing Ansible requirements..."
    cd "$CONFIG_DIR"
    
    if [ -f "requirements.yml" ]; then
        ansible-galaxy collection install -r requirements.yml --force 2>&1 | tee -a "$LOG_FILE"
    fi
}

run_ansible() {
    log_info "Running Ansible playbook..."
    cd "$CONFIG_DIR"
    
    # Run with retries
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Ansible run attempt $attempt/$MAX_RETRIES"
        
        if ansible-playbook playbooks/site.yml 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Ansible completed successfully"
            return 0
        else
            log_warn "Ansible failed on attempt $attempt"
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi
        ((attempt++))
    done
    
    log_error "Ansible failed after $MAX_RETRIES attempts"
    return 1
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------
main() {
    # Header
    log_info "=============================================="
    log_info "Ansible Boot Sync Starting"
    log_info "=============================================="
    log_info "Hostname: $(hostname)"
    log_info "Date: $(date)"
    
    # Check for lock file (prevent concurrent runs)
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE")))
        if [ $lock_age -gt 1800 ]; then
            log_warn "Stale lock file found (${lock_age}s old), removing..."
            rm -f "$LOCK_FILE"
        else
            log_error "Lock file exists. Another sync may be running."
            exit 1
        fi
    fi
    
    # Create lock file and setup cleanup trap
    trap cleanup EXIT
    touch "$LOCK_FILE"
    
    # Wait for network
    if ! wait_for_network; then
        log_error "Aborting due to network failure"
        exit 1
    fi
    
    # Sync repository
    if ! sync_repository; then
        log_error "Repository sync failed"
        exit 1
    fi
    
    # Install Ansible requirements
    install_ansible_requirements
    
    # Run Ansible
    if ! run_ansible; then
        log_error "Ansible run failed"
        exit 1
    fi
    
    # Success
    log_info "=============================================="
    log_info "Boot Sync Completed Successfully"
    log_info "=============================================="
    
    exit 0
}

# Run main function
main "$@"
```

---

### Step 9: Create Ansible Requirements

Create `requirements.yml` in the repository root:

```yaml
---
# =============================================================================
# Ansible Galaxy Requirements
# =============================================================================

collections:
  # Docker collection for managing containers
  - name: community.docker
    version: ">=3.4.0"
  
  # General utilities
  - name: community.general
    version: ">=8.0.0"
  
  # POSIX utilities (sysctl, etc.)
  - name: ansible.posix
    version: ">=1.5.0"
```

---

### Step 10: Push to Git

Create a `.gitignore` file:

```
# Ansible
*.retry
*.pyc
__pycache__/

# Secrets (if using ansible-vault)
vault_password
.vault_pass

# Editor files
*.swp
*.swo
*~
.idea/
.vscode/

# OS files
.DS_Store
Thumbs.db

# Logs
*.log
```

Initialize and push the repository:

```bash
cd pi-ansible-config

# Create .gitignore
cat > .gitignore << 'EOF'
*.retry
*.pyc
__pycache__/
vault_password
.vault_pass
*.swp
*.swo
*~
.idea/
.vscode/
.DS_Store
Thumbs.db
*.log
EOF

# Initialize git and commit
git add .
git commit -m "Initial Pi Ansible configuration with boot sync"

# Create repository on GitHub first, then:
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/pi-ansible-config.git
git push -u origin main
```

---

### Step 11: Configure Pi Boot Sync Service

SSH into your Pi and run these commands:

```bash
# SSH to Pi
ssh pi@192.168.88.253

# Clone the repository
cd /home/pi
git clone https://github.com/YOUR_USERNAME/pi-ansible-config.git

# Make the boot sync script executable
chmod +x /home/pi/pi-ansible-config/scripts/boot-sync.sh

# Update the REPO_URL in the script
nano /home/pi/pi-ansible-config/scripts/boot-sync.sh
# Change REPO_URL to your actual repository URL

# Install Ansible collections
cd /home/pi/pi-ansible-config
ansible-galaxy collection install -r requirements.yml

# Create the systemd service
sudo tee /etc/systemd/system/ansible-boot-sync.service << 'EOF'
[Unit]
Description=Ansible Boot Sync - Pull and Apply Configuration
Documentation=https://github.com/YOUR_USERNAME/pi-ansible-config
After=network-online.target docker.service
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=3

[Service]
Type=oneshot
User=root
Group=root
WorkingDirectory=/home/pi/pi-ansible-config
ExecStart=/home/pi/pi-ansible-config/scripts/boot-sync.sh
TimeoutStartSec=900
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ansible-boot-sync

# Environment
Environment="HOME=/root"
Environment="ANSIBLE_FORCE_COLOR=true"

# Restart policy
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create log file with correct permissions
sudo touch /var/log/ansible-boot-sync.log
sudo chown pi:pi /var/log/ansible-boot-sync.log

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable ansible-boot-sync.service

# Test the service manually
sudo systemctl start ansible-boot-sync.service

# Watch the logs
sudo journalctl -u ansible-boot-sync.service -f
```

---

### Step 12: Optional Scheduled Sync

To run the sync periodically (not just on boot), create a timer:

```bash
# Create the timer
sudo tee /etc/systemd/system/ansible-sync.timer << 'EOF'
[Unit]
Description=Run Ansible Sync Periodically
Documentation=https://github.com/YOUR_USERNAME/pi-ansible-config

[Timer]
# Run 5 minutes after boot
OnBootSec=5min

# Then every 6 hours
OnUnitActiveSec=6h

# Add some randomness to prevent thundering herd
RandomizedDelaySec=30min

# Persist timer across reboots
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Create a simple service for the timer (different from boot service)
sudo tee /etc/systemd/system/ansible-sync.service << 'EOF'
[Unit]
Description=Ansible Periodic Sync
Documentation=https://github.com/YOUR_USERNAME/pi-ansible-config
After=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/home/pi/pi-ansible-config/scripts/boot-sync.sh
TimeoutStartSec=900
EOF

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable ansible-sync.timer
sudo systemctl start ansible-sync.timer

# Check timer status
sudo systemctl list-timers ansible-sync.timer
```

---

## Usage and Workflow

### Making Configuration Changes

1. **Edit files locally** on your development machine:
   ```bash
   cd pi-ansible-config
   # Make changes to playbooks, roles, variables, etc.
   ```

2. **Commit and push**:
   ```bash
   git add .
   git commit -m "Description of changes"
   git push
   ```

3. **Apply changes** - choose one method:

   **Option A: Wait for automatic sync** (if timer is enabled)
   - Changes apply within 6 hours

   **Option B: Trigger manual sync via SSH**:
   ```bash
   ssh pi@192.168.88.253 "sudo systemctl start ansible-boot-sync.service"
   ```

   **Option C: Reboot the Pi**:
   ```bash
   ssh pi@192.168.88.253 "sudo reboot"
   ```

### Useful Commands

```bash
# Check sync service status
sudo systemctl status ansible-boot-sync.service

# View sync logs (real-time)
sudo journalctl -u ansible-boot-sync.service -f

# View sync log file
tail -f /var/log/ansible-boot-sync.log

# Manually trigger sync
sudo systemctl start ansible-boot-sync.service

# Check last successful run
cat ~/.ansible-last-run

# Check timer status (if enabled)
sudo systemctl list-timers ansible-sync.timer

# Run Ansible manually with specific tags
cd ~/pi-ansible-config
sudo ansible-playbook playbooks/site.yml --tags "docker,monitoring"

# Run Ansible in check mode (dry run)
sudo ansible-playbook playbooks/site.yml --check

# Run Ansible with verbose output
sudo ansible-playbook playbooks/site.yml -vvv
```

### Bash Aliases (Added by Ansible)

After running the playbook, these aliases are available:

```bash
# Quick docker commands
dc          # docker compose
dps         # docker ps (formatted)
dlogs       # docker compose logs -f

# Ansible sync commands
ansible-sync   # Trigger sync manually
sync-status    # Check sync service status
sync-logs      # Follow sync logs
```

---

## Troubleshooting

### Boot Sync Not Running

1. **Check service status**:
   ```bash
   sudo systemctl status ansible-boot-sync.service
   ```

2. **Check for lock file**:
   ```bash
   ls -la /tmp/ansible-boot-sync.lock
   # Remove if stale:
   sudo rm /tmp/ansible-boot-sync.lock
   ```

3. **Check logs**:
   ```bash
   sudo journalctl -u ansible-boot-sync.service -n 100
   cat /var/log/ansible-boot-sync.log
   ```

### Ansible Fails

1. **Run manually with verbose output**:
   ```bash
   cd ~/pi-ansible-config
   sudo ansible-playbook playbooks/site.yml -vvv
   ```

2. **Check for syntax errors**:
   ```bash
   ansible-playbook playbooks/site.yml --syntax-check
   ```

3. **Run specific role only**:
   ```bash
   ansible-playbook playbooks/site.yml --tags "common"
   ```

### Docker Issues

1. **Check container status**:
   ```bash
   docker ps -a
   ```

2. **View container logs**:
   ```bash
   docker logs <container_name>
   ```

3. **Restart all containers**:
   ```bash
   cd ~/network-monitoring
   docker compose down
   docker compose up -d
   ```

### Network Issues

1. **Check network connectivity**:
   ```bash
   ping github.com
   curl -I https://github.com
   ```

2. **Check DNS resolution**:
   ```bash
   nslookup github.com
   ```

### Git Issues

1. **Check repository status**:
   ```bash
   cd ~/pi-ansible-config
   git status
   git remote -v
   ```

2. **Reset to remote state**:
   ```bash
   git fetch origin
   git reset --hard origin/main
   git clean -fd
   ```

---

## Security Considerations

### Sensitive Data

1. **Use Ansible Vault** for sensitive variables:
   ```bash
   # Create encrypted vars file
   ansible-vault create group_vars/vault.yml
   
   # Edit encrypted file
   ansible-vault edit group_vars/vault.yml
   
   # Run playbook with vault
   ansible-playbook site.yml --ask-vault-pass
   ```

2. **Store vault password securely** - don't commit it to Git

3. **Use environment variables** for secrets in boot-sync script

### Git Repository

1. **Use SSH keys** instead of HTTPS for private repos:
   ```bash
   # Generate SSH key on Pi
   ssh-keygen -t ed25519 -C "pi@keeper"
   
   # Add public key to GitHub
   cat ~/.ssh/id_ed25519.pub
   
   # Update REPO_URL in boot-sync.sh
   REPO_URL="git@github.com:YOUR_USERNAME/pi-ansible-config.git"
   ```

2. **Consider making the repo private** if it contains sensitive information

### Service Hardening

1. **Limit systemd service permissions** if needed
2. **Use firewall rules** to restrict access to services
3. **Enable Tailscale ACLs** to control who can access what

---

## Extending the Configuration

### Adding New Services

1. **Create a new role**:
   ```bash
   mkdir -p roles/newservice/tasks
   mkdir -p roles/newservice/templates
   mkdir -p roles/newservice/files
   mkdir -p roles/newservice/handlers
   ```

2. **Create tasks/main.yml** with the service configuration

3. **Add role to playbooks/site.yml**:
   ```yaml
   roles:
     - role: newservice
       tags:
         - newservice
   ```

4. **Add variables to group_vars/all.yml**

5. **Commit and push**

### Adding More Hosts

To manage multiple Pis or other hosts:

1. **Update inventory/localhost.yml**:
   ```yaml
   all:
     hosts:
       keeper:
         ansible_host: 192.168.88.253
         ansible_user: pi
       other-pi:
         ansible_host: 192.168.88.254
         ansible_user: pi
   ```

2. **Create host-specific variables**:
   ```bash
   mkdir host_vars
   echo "pi_hostname: other-pi" > host_vars/other-pi.yml
   ```

3. **Run playbook for specific host**:
   ```bash
   ansible-playbook playbooks/site.yml --limit other-pi
   ```

---

## Summary

You now have a fully automated, self-healing Raspberry Pi configuration system:

| Component | Purpose |
|-----------|---------|
| **Git Repository** | Single source of truth for all configuration |
| **Ansible Playbooks** | Idempotent, declarative system configuration |
| **Boot Sync Service** | Automatically applies configuration on every boot |
| **Scheduled Timer** | Periodically re-applies configuration (optional) |
| **Watchtower** | Keeps Docker images updated automatically |
| **Unattended Upgrades** | Keeps the OS patched automatically |

### Benefits

- **Reproducibility**: Rebuild your Pi from scratch in minutes
- **Version Control**: Track all changes, rollback if needed
- **Self-Healing**: Configuration drift is automatically corrected
- **Documentation**: Your configuration IS your documentation
- **Disaster Recovery**: SD card dies? Clone repo, run Ansible, done.

### Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    Development Workflow                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Edit configuration locally                              │
│     └── vim roles/monitoring/tasks/main.yml                 │
│                                                             │
│  2. Commit and push                                         │
│     └── git commit -am "Update monitoring" && git push      │
│                                                             │
│  3. Apply changes (choose one):                             │
│     ├── Wait for scheduled sync (every 6 hours)             │
│     ├── SSH: sudo systemctl start ansible-boot-sync         │
│     └── Reboot: sudo reboot                                 │
│                                                             │
│  4. Verify                                                  │
│     └── Check logs, services, dashboards                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                    Quick Reference                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SERVICE ACCESS (Local)                                     │
│  ─────────────────────                                      │
│  Grafana:        http://192.168.88.253:3000                │
│  Prometheus:     http://192.168.88.253:9090                │
│  Home Assistant: http://192.168.88.253:8123                │
│  Portainer:      https://192.168.88.253:9443               │
│                                                             │
│  SERVICE ACCESS (MikroTik DNS)                              │
│  ────────────────────────────                               │
│  Grafana:        http://grafana.home:3000                  │
│  Home Assistant: http://homeassistant.home:8123            │
│  Prometheus:     http://prometheus.home:9090               │
│                                                             │
│  USEFUL COMMANDS                                            │
│  ───────────────                                            │
│  Trigger sync:   sudo systemctl start ansible-boot-sync    │
│  View logs:      sudo journalctl -u ansible-boot-sync -f   │
│  Check status:   sudo systemctl status ansible-boot-sync   │
│  Docker status:  docker ps                                 │
│  Last run:       cat ~/.ansible-last-run                   │
│                                                             │
│  GIT REPOSITORY                                             │
│  ──────────────                                             │
│  Location:       /home/pi/pi-ansible-config                │
│  Pull updates:   cd ~/pi-ansible-config && git pull        │
│  Current commit: git rev-parse --short HEAD                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Author:** Claude (Anthropic)  
**For:** Kevin's Raspberry Pi 4 (keeper) - Home Infrastructure
