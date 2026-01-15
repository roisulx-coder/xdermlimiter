#!/bin/sh
# XDERM LIMITER - MODERN AUTO INSTALLER

# Warna untuk output terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== XDERM LIMITER INSTALLER ===${NC}"

# 1. Deteksi & Instal Dependensi
echo "Mengecek repository dan dependensi..."
opkg update
PHP_VER=$(opkg list | grep -q "^php8-cgi" && echo "php8-cgi" || echo "php7-cgi")
opkg install screen tc-full $PHP_VER

# 2. Konfigurasi UHTTPD (Fix Bad Gateway)
echo "Konfigurasi Web Server..."
uci set uhttpd.main.interpreter=".php=/usr/bin/php-cgi"
uci commit uhttpd

# 3. Setup Direktori
mkdir -p /www/xderm/limitdir /usr/lib/lua/luci/controller /usr/lib/lua/luci/view

# 4. Membuat Controller LuCI
cat <<EOF > /usr/lib/lua/luci/controller/xderm-limit.lua
module("luci.controller.xderm-limit", package.seeall)
function index()
    entry({"admin","services","xderm-limit"}, template("xderm-limit"), _("Xderm Limiter"), 24).leaf=true
end
EOF

# 5. Membuat View LuCI
cat <<EOF > /usr/lib/lua/luci/view/xderm-limit.htm
<%+header%>
<iframe src="/xderm/limit.php" style="width:100%; min-height:85vh; border:none;"></iframe>
<%+footer%>
EOF

# 6. Membuat Engine (Bash)
cat <<'EOF' > /www/xderm/limit
#!/bin/bash
DIR="/www/xderm/limitdir"
IFACE="br-lan"
[ ! -f $DIR/sz ] && echo "3" > $DIR/sz
tc qdisc del dev $IFACE root handle 1: > /dev/null 2>&1
tc qdisc add dev $IFACE root handle 1: htb default 5
tc class add dev $IFACE parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit
echo "[$(date +%T)] Engine Started" > $DIR/log.txt
while true; do
    LIMIT=$(cat $DIR/sz)
    awk '{print $3}' /tmp/dhcp.leases | while read -r ip; do
        ID=$(echo $ip | cut -d. -f4)
        if [ $(tc class show dev $IFACE | grep -c "1:1$ID") -eq 0 ]; then
            tc class add dev $IFACE parent 1:1 classid 1:1$ID htb rate ${LIMIT}mbit ceil ${LIMIT}mbit
            tc filter add dev $IFACE protocol ip parent 1:0 prio 1 u32 match ip dst $ip flowid 1:1$ID
            echo "[$(date +%T)] Limit Aktif: $ip (${LIMIT}Mbps)" >> $DIR/log.txt
        fi
    done
    sleep 15
done
EOF

# 7. Membuat Dashboard (PHP)
cat <<'EOF' > /www/xderm/limit.php
<?php
$d = 'limitdir/';
if(isset($_POST['go'])){
    if(trim(@file_get_contents($d.'st'))=='Stop'){
        exec('killall -9 limit; tc qdisc del dev br-lan root; echo Start > '.$d.'st');
    } else {
        exec('chmod +x limit; screen -d -m /www/xderm/limit; echo Stop > '.$d.'st');
    }
}
if(isset($_POST['save'])){ file_put_contents($d.'sz', $_POST['sz']); }
$st = trim(@file_get_contents($d.'st')) ?: 'Start';
?>
<body style="font-family:sans-serif; background:#eee; display:flex; justify-content:center; padding:20px;">
<div style="background:#fff; padding:20px; border-radius:10px; box-shadow:0 4px 6px rgba(0,0,0,0.1); width:320px;">
    <h3 style="text-align:center; margin-top:0;">Xderm Limiter</h3>
    <form method="post">
        <button name="go" style="width:100%; padding:10px; color:#fff; border:none; border-radius:5px; background:<?=($st=='Start'?'#10b981':'#ef4444')?>"><?=($st=='Start'?'START':'STOP')?> ENGINE</button>
        <p>Limit: <input type="number" name="sz" value="<?=trim(@file_get_contents($d.'sz'))?:3?>" style="width:50px"> Mbps</p>
        <button name="save" style="width:100%; padding:10px; background:#2563eb; color:#fff; border:none; border-radius:5px;">SIMPAN</button>
    </form>
    <div style="background:#000; color:#0f0; padding:10px; font-size:10px; height:120px; overflow-y:auto; margin-top:10px;">
        <?=nl2br(@file_get_contents($d.'log.txt'))?>
    </div>
</div>
</body>
EOF

# 8. Finalisasi
chmod -R 755 /www/xderm
chmod +x /www/xderm/limit
/etc/init.d/uhttpd restart
rm -f /tmp/luci-indexcache

echo -e "${GREEN}INSTALASI SELESAI!${NC}"
echo "Akses melalui menu: Services -> Xderm Limiter"
