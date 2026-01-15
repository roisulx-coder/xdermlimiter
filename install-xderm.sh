#!/bin/sh

# =========================================================
# XDERM LIMITER - AUTO INSTALLER (FIXED BAD GATEWAY)
# =========================================================

WWW_DIR="/www/xderm"
CTRL_PATH="/usr/lib/lua/luci/controller/xderm-limit.lua"
VIEW_PATH="/usr/lib/lua/luci/view/xderm-limit.htm"

echo "Mengecek dan menginstal dependensi (PHP, Screen, TC)..."
opkg update

# Deteksi PHP yang tersedia di repo (prioritas PHP8)
if opkg list | grep -q "^php8-cgi"; then
    PHP_PKG="php8-cgi"
    PHP_BIN="/usr/bin/php-cgi"
elif opkg list | grep -q "^php7-cgi"; then
    PHP_PKG="php7-cgi"
    PHP_BIN="/usr/bin/php-cgi"
else
    echo "Paket PHP tidak ditemukan di repository!"
    exit 1
fi

opkg install screen tc-full $PHP_PKG

echo "Membuat struktur folder..."
mkdir -p "$WWW_DIR/limitdir"
mkdir -p "$WWW_DIR/img"
mkdir -p "$WWW_DIR/js"
mkdir -p "/usr/lib/lua/luci/controller"
mkdir -p "/usr/lib/lua/luci/view"

# ---------------------------------------------------------
# 1. KONFIGURASI UHTTPD (Penting untuk Fix Bad Gateway)
# ---------------------------------------------------------
echo "Mengonfigurasi uhttpd untuk PHP..."
uci set uhttpd.main.interpreter=".php=$PHP_BIN"
uci commit uhttpd

# ---------------------------------------------------------
# 2. MEMBUAT FILE CONTROLLER (LUA)
# ---------------------------------------------------------
cat <<'EOF' > "$CTRL_PATH"
module("luci.controller.xderm-limit", package.seeall)
function index()
    entry({"admin","services","xderm-limit"}, template("xderm-limit"), _("Xderm Limiter"), 24).leaf=true
end
EOF

# ---------------------------------------------------------
# 3. MEMBUAT FILE VIEW (HTM)
# ---------------------------------------------------------
cat <<'EOF' > "$VIEW_PATH"
<%+header%>
<div class="cbi-map">
    <iframe id="xderm-limit" style="width: 100%; min-height: 80vh; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
    document.getElementById("xderm-limit").src = window.location.protocol + "//" + window.location.host + "/xderm/limit.php";
</script>
<%+footer%>
EOF

# ---------------------------------------------------------
# 4. MEMBUAT FILE BASH LIMIT (CORE ENGINE)
# ---------------------------------------------------------
cat <<'EOF' > "$WWW_DIR/limit"
#!/bin/bash
iface="br-lan"
LIMIT_DIR="/www/xderm/limitdir"
cd /www/xderm
i=$(ifconfig br-lan | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}' | cut -d. -f1-3)

# Reset TC
tc qdisc del dev $iface root handle 1: > /dev/null 2>&1
tc qdisc add dev $iface root handle 1: htb default 5
tc class add dev $iface parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit

echo "[$(date +%H:%M:%S)] Engine Running..." > $LIMIT_DIR/log.txt

while true; do
    size=$(cat $LIMIT_DIR/sz 2>/dev/null | tr -d ' ')
    [[ -z "$size" ]] && size="3"
    
    # Ambil IP dari DHCP leases
    cat /tmp/dhcp.leases | awk '{print $3}' | while read -r ip; do
        last_oct=$(echo $ip | cut -d. -f4)
        if [ $(tc class show dev $iface | grep -c "1:1$last_oct") -eq 0 ]; then
            tc class add dev $iface parent 1:1 classid 1:1$last_oct htb rate ${size}mbit ceil ${size}mbit
            tc filter add dev $iface protocol ip parent 1:0 prio 1 u32 match ip dst $ip flowid 1:1$last_oct
            echo "[$(date +%H:%M:%S)] Limit $ip -> ${size}Mbps" >> $LIMIT_DIR/log.txt
        fi
    done
    sleep 10
done
EOF

# ---------------------------------------------------------
# 5. MEMBUAT FILE PHP DASHBOARD
# ---------------------------------------------------------
cat <<'EOF' > "$WWW_DIR/limit.php"
<?php
$dir = 'limitdir/';
if (!is_dir($dir)) mkdir($dir, 0755);

if (isset($_POST['button1'])) {
    $st = trim(@file_get_contents($dir.'st'));
    if ($st == 'Start' || empty($st)) {
        exec('killall -9 limit > /dev/null 2>&1');
        exec('chmod +x limit && screen -d -m /www/xderm/limit');
        file_put_contents($dir.'st', 'Stop');
    } else {
        exec('killall -9 limit > /dev/null 2>&1');
        exec('tc qdisc del dev br-lan root handle 1: > /dev/null 2>&1');
        file_put_contents($dir.'st', 'Start');
        file_put_contents($dir.'log.txt', 'Engine Stopped.');
    }
    header("Location: limit.php"); exit;
}

if (isset($_POST['simpan'])) {
    file_put_contents($dir.'sz', $_POST['size']);
    header("Location: limit.php"); exit;
}

$status = trim(@file_get_contents($dir.'st')) ?: 'Start';
$limit = trim(@file_get_contents($dir.'sz')) ?: '3';
$log = @file_get_contents($dir.'log.txt') ?: 'No Log available';
?>
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: sans-serif; background: #f4f7f6; padding: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 400px; margin: auto; }
        .btn { padding: 10px; border: none; border-radius: 4px; cursor: pointer; width: 100%; margin-top: 10px; color: white; font-weight: bold; }
        .log { background: #222; color: #0f0; padding: 10px; font-family: monospace; font-size: 11px; height: 150px; overflow-y: auto; margin-top: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <h3 style="text-align:center">XDERM LIMITER</h3>
        <form method="post">
            <input type="submit" name="button1" class="btn" style="background:<?= ($status=='Start')?'#10b981':'#ef4444' ?>" value="<?= ($status=='Start')?'START ENGINE':'STOP ENGINE' ?>">
            <p>Limit per User (Mbps): 
            <input type="number" name="size" value="<?= $limit ?>" style="width:50px"></p>
            <input type="submit" name="simpan" class="btn" style="background:#2563eb" value="SIMPAN SETTING">
        </form>
        <div class="log"><?= nl2br(htmlspecialchars($log)) ?></div>
    </div>
</body>
</html>
EOF

# ---------------------------------------------------------
# 6. FINALISASI
# ---------------------------------------------------------
chmod -R 755 "$WWW_DIR"
chmod +x "$WWW_DIR/limit"
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/*

/etc/init.d/uhttpd restart
echo "Instalasi Selesai. Silakan refresh LuCI."
