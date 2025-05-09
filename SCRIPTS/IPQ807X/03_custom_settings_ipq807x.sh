#!/bin/bash

# Optimize for x86-64-v2
sed -i 's/O2/O2 -march=x86-64-v2/g' include/target.mk

# Fix libsodium build flags
sed -i 's,no-mips16 no-lto,no-mips16,g' feeds/packages/libs/libsodium/Makefile

# Create /etc/rc.local for custom init
cat > ./package/base-files/files/etc/rc.local <<'EOF'
#!/bin/sh
# Custom commands executed after system init

if ! grep "Default string" /tmp/sysinfo/model > /dev/null; then
    echo "should be fine"
else
    echo "Generic PC" > /tmp/sysinfo/model
fi

status=$(cat /sys/devices/system/cpu/intel_pstate/status)
if [ "$status" = "passive" ]; then
    echo "active" | tee /sys/devices/system/cpu/intel_pstate/status
fi

exit 0
EOF

# Vermagic hash fix
curl -s https://downloads.openwrt.org/releases/24.10.1/targets/x86/64/openwrt-24.10.1-x86-64.manifest \
| grep "^kernel -" | awk '{print $3}' \
| sed -n 's/.*~\([a-f0-9]\+\)-r[0-9]\+/\1/p' > vermagic
sed -i 's#grep '\''=\[ym\]'\'' \$(LINUX_DIR)/\.config\.set | LC_ALL=C sort | \$(MKHASH) md5 > \$(LINUX_DIR)/\.vermagic#cp \$(TOPDIR)/vermagic \$(LINUX_DIR)/.vermagic#g' include/kernel-defaults.mk

# Cleanup patch leftovers
find ./ -name "*.orig" -o -name "*.rej" | xargs rm -f

# Install AdGuardHome binary
mkdir -p files/usr/bin
AGH_CORE=$(curl -sL https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest \
    | grep /AdGuardHome_linux_amd64 | awk -F '"' '{print $4}')
wget -qO- "$AGH_CORE" | tar xOvz > files/usr/bin/AdGuardHome
chmod +x files/usr/bin/AdGuardHome

# Install OpenClash components
mkdir -p files/etc/openclash/core
wget -qO- https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz \
    | tar xOvz > files/etc/openclash/core/clash_meta
wget -qO- https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat \
    > files/etc/openclash/GeoIP.dat
wget -qO- https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat \
    > files/etc/openclash/GeoSite.dat
chmod +x files/etc/openclash/core/clash*

# Install Caddy binary
mkdir -p files/usr/bin
wget -qO- https://github.com/lmq8267/caddy/releases/download/v2.10.0/caddy-amd64-upx > files/usr/bin/caddy
chmod +x files/usr/bin/caddy

# Clone default-settings package
git clone --depth=1 -b openwrt-24.10 https://github.com/oppen321/default-settings package/default-settings

# Add distfeeds.conf with TUNA mirror
mkdir -p files/etc/opkg
cat > files/etc/opkg/distfeeds.conf <<EOF
src/gz openwrt_base https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.1/packages/x86_64/base
src/gz openwrt_luci https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.1/packages/x86_64/luci
src/gz openwrt_packages https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.1/packages/x86_64/packages
src/gz openwrt_routing https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.1/packages/x86_64/routing
src/gz openwrt_telephony https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.1/packages/x86_64/telephony
src/gz openwrt_core https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.1/targets/x86/64/kmods/6.6.86-1-af351158cfb5febf5155a3aa53785982
EOF

exit 0

