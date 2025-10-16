#!/bin/bash

set -e

# Check if run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

echo "=== Updating system packages ==="
apt update && apt upgrade -y

echo "=== Installing prerequisites ==="
apt install -y wget curl tar unzip software-properties-common

echo "=== Creating user and directories for Prometheus ==="
useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus /var/lib/prometheus

echo "=== Downloading Prometheus ==="
cd /tmp
PROM_VERSION="2.52.0"
wget https://github.com/prometheus/prometheus/releases/download/v$PROM_VERSION/prometheus-$PROM_VERSION.linux-amd64.tar.gz
tar xvf prometheus-$PROM_VERSION.linux-amd64.tar.gz

echo "=== Installing Prometheus binaries ==="
cd prometheus-$PROM_VERSION.linux-amd64
cp prometheus promtool /usr/local/bin/
cp -r consoles/ console_libraries/ /etc/prometheus/

echo "=== Configuring Prometheus ==="
cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

echo "=== Creating Prometheus systemd service ==="
cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus/ \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

echo "=== Starting Prometheus ==="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now prometheus

echo "=== Installing Grafana ==="
wget -q -O - https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list

apt update
apt install -y grafana

echo "=== Starting Grafana ==="
systemctl enable --now grafana-server

echo "=== Installation complete ==="
echo "------------------------------------------"
echo "Prometheus: http://localhost:9090"
echo "Grafana:    http://localhost:3000"
echo "Grafana default login -> user: admin | password: admin"
echo "Remember to change the password after first login!"
