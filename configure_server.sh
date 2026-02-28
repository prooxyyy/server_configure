#!/bin/bash

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install zip unzip screen htop iftop mc dstat ca-certificates apt-transport-https curl btop

# Настройка sysctl
cat >> /etc/sysctl.conf <<EOF

# Запрет ICMP пакетов с перенаправлением
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Максимальное количество подключений
net.ipv4.netfilter.ip_conntrack_max = 1048576
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syncookies = 1 по рекомендациям глеба лучше врубить
#net.ipv4.tcp_syncookies = 0
net.ipv4.tcp_max_syn_backlog = 20000
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_wmem = 8192 65536 16777216
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_rmem = 8192 87380 16777216
net.ipv4.udp_rmem_min = 16384
#net.ipv4.tcp_mem = 65536 131072 262144
#net.ipv4.udp_mem = 65536 131072 262144
#net.ipv4.tcp_sack = 1
net.ipv4.tcp_congestion_control = htcp
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.ip_forward = 0

# Защита от IP спуфинга
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.lo.rp_filter = 1
net.ipv4.conf.eth0.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Отключение маршрутизации от источника
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.lo.accept_source_route = 0
net.ipv4.conf.eth0.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

net.core.netdev_max_backlog = 1000
net.core.optmem_max = 25165824
net.core.somaxconn = 20000
net.core.rmem_default=65536
net.core.wmem_default=65536
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

vm.swappiness = 10
EOF
sysctl -p

# Установка времени
echo "Europe/Moscow" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Установка ntp и отключение сервака
apt-get -y install ntp
echo '' >> /etc/ntp.conf
echo 'disable monitor' >> /etc/ntp.conf
service ntp restart
sed -i "2i exit 0" /etc/network/if-up.d/ntpdate

# Установка Docker
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

cat > /usr/local/sbin/conntrack-off.sh <<'EOF'
iptables -t raw -C PREROUTING -j CT --notrack 2>/dev/null || iptables -t raw -I PREROUTING 1 -j CT --notrack
iptables -t raw -C OUTPUT     -j CT --notrack 2>/dev/null || iptables -t raw -I OUTPUT 1 -j CT --notrack
EOF

chmod +x /usr/local/sbin/conntrack-off.sh

sudo tee /etc/systemd/system/conntrack-off.service >/dev/null <<'EOF'
[Unit]
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/conntrack-off.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now notrack.service

echo "Done! Better reboot"
