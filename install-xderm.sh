#!/bin/sh

# =========================================================
# XDERM LIMITER - ULTRA PRECISION VERSION
# Created by: roisulx-coder
# =========================================================

# Variabel Lokasi
WWW_DIR="/www/xderm"
CTRL_PATH="/usr/lib/lua/luci/controller/xderm-limit.lua"
VIEW_PATH="/usr/lib/lua/luci/view/xderm-limit.htm"

echo "Mengecek paket pendukung (screen, tc, php)..."
opkg update && opkg install screen tc-full php8-cgi

echo "Membuat struktur folder..."
mkdir -p "$WWW_DIR/limitdir"
mkdir -p "$WWW_DIR/img"
mkdir -p "$WWW_DIR/js"
mkdir -p "/usr/lib/lua/luci/controller"
mkdir -p "/usr/lib/lua/luci/view"

# ---------------------------------------------------------
# 1. MEMBUAT FILE CONTROLLER (LUA)
# ---------------------------------------------------------
cat <<'EOF' > "$CTRL_PATH"
module("luci.controller.xderm-limit", package.seeall)
function index()
entry({"admin","services","xderm-limit"}, template("xderm-limit"), _("Xderm Limiter"), 24).leaf=true
end
EOF

# ---------------------------------------------------------
# 2. MEMBUAT FILE VIEW (HTM)
# ---------------------------------------------------------
cat <<'EOF' > "$VIEW_PATH"
<%+header%>
<div class="cbi-map">
<iframe id="xderm-limit" style="width: 100%; min-height: 100vh; border: none; border-radius: 12px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("xderm-limit").src = window.location.protocol + "//" + window.location.host + "/xderm/limit.php";
</script>
<%+footer%>
EOF

# ---------------------------------------------------------
# 3. MEMBUAT FILE BASH LIMIT (ENGINE PERBAIKAN TOTAL)
# ---------------------------------------------------------
cat <<'EOF' > "$WWW_DIR/limit"
#!/bin/bash
iface="br-lan"
mkdir -p limitdir
echo "{$(date +%H:%M)} Engine Aktif (Mode Ultra Precision)" > limitdir/log.txt

# Bersihkan aturan lama saat start
tc qdisc del dev $iface root > /dev/null 2>&1

while true; do
    status=$(cat limitdir/st | tr -d ' ')
    if [ "$status" = "Start" ]; then
        tc qdisc del dev $iface root > /dev/null 2>&1
        exit 0
    fi

    # Ambil nilai limit dari file
    size_raw=$(cat limitdir/sz | tr -d ' ')
    [ -z "$size_raw" ] && size_raw=3
    rate_val="${size_raw}mbit"
    ceil_val="${size_raw}mbit"

    # Inisialisasi HTB jika belum ada
    if ! tc qdisc show dev $iface | grep -q "htb 1:"; then
        tc qdisc add dev $iface root handle 1: htb default 10
        # Jalur Utama (Total bandwidth dianggap 1Gbps agar tidak bottleneck di router)
        tc class add dev $iface parent 1: classid 1:1 htb rate 1000mbit
    fi

    # Baca file leases untuk cek client aktif
    while read -r line; do
        ip_client=$(echo "$line" | awk '{print $3}')
        # Ambil angka terakhir IP sebagai ID Class (misal 192.168.1.50 -> ID 50)
        class_id=$(echo "$ip_client" | cut -d. -f4)
        
        [ -z "$ip_client" ] && continue

        # CEK PENGECUALIAN IP
        useip_status=$(grep "use_ip=" limitdir/useip | cut -d= -f2)
        if [ "$useip_status" = "yes" ]; then
            if grep -q "$ip_client" limitdir/ip.list; then 
                # Jika IP dikecualikan, hapus limit jika sebelumnya ada
                if tc class show dev $iface | grep -q "1:$class_id"; then
                    tc filter del dev $iface protocol ip parent 1: prio 1 handle 800::$class_id u32 > /dev/null 2>&1
                    tc class del dev $iface parent 1:1 classid 1:$class_id > /dev/null 2>&1
                    echo "{$(date +%H:%M)} Pengecualian Aktif -> $ip_client" >> limitdir/log.txt
                fi
                continue 
            fi
        fi

        # TERAPKAN LIMIT PER IP
        # Cek apakah class untuk IP ini sudah ada, jika belum buat baru
        if ! tc class show dev $iface | grep -q "1:$class_id"; then
            # Buat class khusus untuk IP ini
            tc class add dev $iface parent 1:1 classid 1:$class_id htb rate $rate_val ceil $ceil_val burst 15k cburst 15k
            # Arahkan trafik IP tujuan (dst) ke class tersebut
            tc filter add dev $iface protocol ip parent 1: prio 1 u32 match ip dst $ip_client flowid 1:$class_id
            echo "{$(date +%H:%M)} Limit Terpasang -> $ip_client [$rate_val]" >> limitdir/log.txt
        fi
    done < /tmp/dhcp.leases

    sleep 10
done
EOF

# ---------------------------------------------------------
# 4. MEMBUAT FILE PHP (MODERN UI SESUAI REQUEST)
# ---------------------------------------------------------
cat <<'EOF' > "$WWW_DIR/limit.php"
<?php
error_reporting(E_ERROR | E_PARSE);
if (!file_exists('limitdir')) { exec('mkdir -p limitdir'); }
exec("cat limitdir/st", $sst);
if (!$sst[0]) { exec('echo Start > limitdir/st'); };
exec("cat limitdir/sz", $ssz);
if (!$ssz[0]) { exec('echo 3 > limitdir/sz'); };

if (isset($_POST['button1'])) {
    exec('cat limitdir/st', $o);
    if (trim($o[0]) == 'Start') {
        exec('killall -q limit');
        exec('chmod +x limit');
        exec('screen -d -m ./limit');
        exec('echo Stop > limitdir/st');
    } else {
        exec('killall -q limit');
        exec('echo "Auto Limit Client Stopped." > limitdir/log.txt');
        exec('tc qdisc del dev br-lan root > /dev/null 2>&1');
        exec('echo Start > limitdir/st');
    }
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

if (isset($_POST['simpan'])) {
    $ipl = $_POST['iplist'];
    $sz = $_POST['size'];
    $use_ip = isset($_POST['use_ip']) ? 'yes' : 'no';
    file_put_contents("limitdir/sz", $sz);
    file_put_contents("limitdir/ip.list", $ipl);
    file_put_contents("limitdir/useip", "use_ip=" . $use_ip);
    exec("echo 'Berhasil Disimpan, Restart Engine untuk Efek!' > limitdir/log.txt");
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}
?>
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script type="text/javascript" src="js/jquery-2.1.3.min.js"></script>
    <meta charset="UTF-8">
    <title>Xderm Limitation</title>
    <style>
        body { background-color: #1E293B; color: #f8fafc; font-family: 'Segoe UI', sans-serif; margin: 0; display: flex; flex-direction: column; align-items: center; min-height: 100vh; }
        .box_script { width: 95%; max-width: 450px; background: rgba(30, 41, 59, 0.9); backdrop-filter: blur(10px); padding: 25px; border-radius: 16px; border: 1px solid rgba(255, 255, 255, 0.1); box-shadow: 0 15px 35px rgba(0,0,0,0.5); text-align: center; margin-top: 20px; box-sizing: border-box; }
        .btn { padding: 10px 20px; border-radius: 8px; font-weight: bold; cursor: pointer; border: none; transition: 0.3s; margin: 5px; display: inline-block; }
        .geser { background: #3182ce; color: white; box-shadow: 0 4px 10px rgba(49, 130, 206, 0.3); }
        #log { background: #0f172a; padding: 12px; border-radius: 8px; color: #34d399; font-family: 'Courier New', monospace; text-align: left; font-size: 11px; height: 180px; overflow-y: auto; border: 1px solid rgba(255,255,255,0.05); margin-top: 15px; white-space: pre-wrap; }
        textarea { width: 100%; background: #0f172a; color: #34d399; border: 1px solid #334155; border-radius: 8px; padding: 10px; box-sizing: border-box; }
        input[type='text'] { background: #0f172a; color: #fff; border: 1px solid #334155; padding: 5px; border-radius: 4px; text-align: center; }
        .footer-text { margin-top: 20px; font-size: 11px; color: #64748b; letter-spacing: 1px; }
    </style>
    <script type="text/javascript">
        $(document).ready(function() {
            setInterval(function() {
                $.ajax({ url: "limitdir/log.txt", cache: false, success: function(result) {
                    $("#log").html(result);
                    var elem = document.getElementById('log');
                    if(elem) elem.scrollTop = elem.scrollHeight;
                }});
            }, 2000);
        });
        if ( window.history.replaceState ) { window.history.replaceState( null, null, window.location.href ); }
    </script>
</head>
<body>
<div class="box_script">
    <img src="img/image.png" style="width: 70%; max-width: 180px; margin-bottom: 10px;">
    <form method="post">
        <div style="display: flex; justify-content: center; gap: 5px;">
            <?php $status_label = trim(file_get_contents('limitdir/st')); ?>
            <input type="submit" name="button1" class="btn geser" value="<?php echo ($status_label == 'Start') ? 'START ENGINE' : 'STOP ENGINE'; ?>"/>
            <input type="submit" name="button2" class="btn" style="background:#475569; color:white;" value="Config"/>
        </div>
        <?php if (isset($_POST['button2'])): ?>
            <div style="margin-top: 20px; text-align: left; border-top: 1px solid rgba(255,255,255,0.1); padding-top
