#!/bin/bash
set -e
echo "[1] setup locale"
# env
export LANG=C.UTF-8
export LANGUAGE=C
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# setup sources.list
echo "[2] setup apt sources"

cat << 'EOF' > /etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse
EOF

# apt update 
echo "[3] apt update"
echo "nameserver 8.8.8.8" > /etc/resolv.conf
apt update

# install base packages
echo "[4] install base packages"
apt install -y \
    bash \
    systemd \
    systemd-sysv \
    util-linux \
    nano \
    vim \
    tzdata \
    ca-certificates \
    sudo \
    dbus \
    kmod \
    net-tools \
    iproute2 \
    udev \
    iputils-ping

update-ca-certificates || true
#  install baseic services
echo "[5] install basic services"
apt install -y \
    rsyslog \
    cron \
    systemd-timesyncd
systemctl enable rsyslog || true
systemctl enable cron || true

# enable networking
echo "[6] install network packages"
apt install -y \
    ifupdown \
    isc-dhcp-client \
    wpasupplicant \
    wireless-tools \
    iw
systemctl enable networking || true
systemctl enable wpa_supplicant || true

# enable ssh server
echo "[7] install ssh server"
apt install -y openssh-server
systemctl enable ssh || true
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# enable X11 minimal
echo "[8] install X11 minimal"
apt install -y \
    xterm \
    x11-apps \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    xserver-xorg-input-libinput \
    mesa-utils \
    libgl1 \
    libegl1 


# Python minimal
echo "[9] install python"
apt install -y \
    python3 \
    python3-pip


# enable serial console
echo "[10] enable serial console ttyFIQ0"

mkdir -p /etc/systemd/system/serial-getty@ttyFIQ0.service.d

cat > /etc/systemd/system/serial-getty@ttyFIQ0.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -L 1500000 ttyFIQ0 vt100
EOF

systemctl enable serial-getty@ttyFIQ0.service || true

grep -qxF 'ttyFIQ0' /etc/securetty || echo 'ttyFIQ0' >> /etc/securetty



# root password
echo "[11] set root password"
echo "root:fa" | chpasswd

# rom-version / firmware / modules
echo "[12] setup rom-version and kernel dirs"
echo "$(date +%Y%m%d)" > /etc/rom-version
[ -e /lib/firmware ] || mkdir -p /lib/firmware
[ -e /lib/modules ] || mkdir -p /lib/modules

#hostname / hosts
echo "[13] set hostname"

echo "ubuntu" > /etc/hostname

cat << 'EOF' > /etc/hosts
127.0.0.1       ubuntu localhost
::1             localhost ip6-localhost ip6-loopback
EOF

#setup mirror
echo "[14] setup apt mirror"

cat << 'EOF' > /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports jammy-security main restricted universe multiverse
EOF

#final system init
echo "[15] final system setup"

# 网络：默认 eth0 DHCP（对应 Alpine answer_file）
cat << 'EOF' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# 时区（先简单设 UTC，对齐 Alpine）
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# NTP
systemctl enable systemd-timesyncd || true

# 防止 dpkg 残留状态问题
dpkg --configure -a || true

# 清理 apt cache（减小 rootfs）
apt clean
rm -rf /var/lib/apt/lists/*