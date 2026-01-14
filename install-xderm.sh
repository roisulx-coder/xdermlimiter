#!/bin/sh

# =========================================================
# XDERM LIMITER - AUTO INSTALLER
# Created by: roisulx-coder
# =========================================================

# Variabel Lokasi
WWW_DIR="/www/xderm"
CTRL_PATH="/usr/lib/lua/luci/controller/xderm-limit.lua"
VIEW_PATH="/usr/lib/lua/luci/view/xderm-limit.htm"

echo "Mengecek paket pendukung (screen & tc)..."
opkg update && opkg install screen tc-full

echo "Membuat struktur folder..."
mkdir -p "$WWW_DIR/limitdir"
mkdir -p "$WWW_DIR/img"
mkdir -p "$WWW_DIR/js"
mkdir -p "/usr/lib/lua/luci/controller"
mkdir -p "/usr/lib/lua/luci/view"

# ---------------------------------------------------------
# 1. MEMBUAT FILE CONTROLLER (LUA)
# ---------------------------------------------------------
echo "Memasang Controller LuCI..."
cat <<'EOF' > "$CTRL_PATH"
module("luci.controller.xderm-limit", package.seeall)
function index()
entry({"admin","services","xderm-limit"}, template("xderm-limit"), _("Xderm Limiter"), 24).leaf=true
end
EOF

# ---------------------------------------------------------
# 2. MEMBUAT FILE VIEW (HTM)
# ---------------------------------------------------------
echo "Memasang View LuCI..."
cat <<'EOF' > "$VIEW_PATH"
<%+header%>
<div class="cbi-map">
<iframe id="xderm-limit" style="width: 100%; min-height: 100vh; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("xderm-limit").src = window.location.protocol + "//" + window.location.host + "/xderm/limit.php";
</script>
<%+footer%>
EOF

# ---------------------------------------------------------
# 3. MEMBUAT FILE BASH LIMIT (CORE ENGINE)
# ---------------------------------------------------------
echo "Memasang Core Engine (Bash)..."
cat <<'EOF' > "$WWW_DIR/limit"
#!/bin/bash
iface=br-lan;n=1;mkdir -p limitdir;rm -rf limitdir/log.txt
size=$(cat limitdir/sz|sed 's/ //g')
 if [ -f $size ]; then
echo "{$(date +%M:%S)} Speed Limit Value belom ditentukan!" > limitdir/log.txt;exit
 fi
size=$(echo "$size.mbit"|sed 's/\.//g')
i=$(ifconfig br-lan|grep "inet addr"|awk -F: '{print $3}'|awk '{print $1}'|sed 's/.255//g')
#setup
tc qdisc del dev $iface root handle 1: > /dev/null 2>&1
tc qdisc add dev $iface root handle 1: htb default 5
tc class add dev $iface parent 1: classid 1:1 htb rate 500mbit ceil 500mbit
echo "{$(date +%M:%S)} Auto Limit Client for $(echo $size|sed 's/mbit/mb/g') Running..." >> limitdir/log.txt
sleep 1;k=1;j=1
 while true; do
ip=$(cat /tmp/dhcp.leases 2>/dev/null|awk '{print $3}'|awk -F. '{print $4}'|awk "NR==$n")
   if [ -f $ip ]; then
    j=0;n=1;sleep 2;continue
   fi
  if [ $(ping -w1 -c1 $i.$ip|grep pack|awk '{print $4}') -eq 0 ]; then
   ((n++));sleep 1;continue
  fi
useip=$(cat limitdir/useip|awk -F= '{print $2}')
     if [ ! -f $useip ]; then
    if [ $useip == "yes" ]; then
   if [ ! -f $(grep -r "$i.$ip" limitdir/ip.list) ]; then
    ((n++));continue
   fi
    fi
     fi
  if [ $(tc class show dev $iface|grep -c "1:1$ip") -eq 0 ]; then
   tc class add dev $iface parent 1:1 classid 1:1$ip htb rate $size ceil $size
   tc filter add dev $iface protocol ip parent 1:0 prio 1 u32 match ip dst $i.$ip flowid 1:1$ip
   echo "{$(date +%M:%S)} Limit Aktif -> $i.$ip ($size)" >> limitdir/log.txt
  fi
 ((n++))
done
EOF

# ---------------------------------------------------------
# 4. MEMBUAT FILE PHP DASHBOARD
# ---------------------------------------------------------
echo "Memasang PHP Dashboard..."
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
    if ($o[0] == 'Start') {
        exec('killall -q limit');
        exec('chmod +x limit');
        exec('screen -d -m ./limit');
        exec('echo Stop > limitdir/st');
    } else {
        exec('killall -q limit');
        exec('echo "Auto Limit Client Stopped." > limitdir/log.txt');
        exec('tc qdisc del dev br-lan root handle 1: > /dev/null 2>&1');
        exec('echo Start > limitdir/st');
    }
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}
if (isset($_POST['simpan'])) {
    $iplist = $_POST['iplist'];
    $size = $_POST['size'];
    $use_ip = isset($_POST['use_ip']) ? "yes" : "no";
    file_put_contents('limitdir/ip.list', $iplist);
    file_put_contents('limitdir/sz', $size);
    file_put_contents('limitdir/useip', "use_ip=$use_ip");
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Xderm Limiter</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: sans-serif; background: #f4f7f6; color: #333; padding: 20px; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 400px; margin: auto; }
        .btn { padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; width: 100%; margin-top: 10px; }
        textarea { width: 100%; border-radius: 4px; border: 1px solid #ddd; padding: 5px; }
        .log { background: #222; color: #0f0; padding: 10px; font-family: monospace; font-size: 11px; height: 100px; overflow-y: scroll; margin-top: 10px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="card">
        <h2 style="text-align:center">Xderm Limiter</h2>
        <form method="post">
            <input type="submit" name="button1" class="btn" style="background:<?php echo ($sst[0] == 'Start') ? '#10b981' : '#ef4444'; ?>; color:white;" value="<?php echo ($sst[0] == 'Start') ? 'START ENGINE' : 'STOP ENGINE'; ?>" />
            <hr>
            <label>IP Pengecualian:</label>
            <textarea name="iplist" rows="4"><?php echo file_get_contents('limitdir/ip.list'); ?></textarea>
            <br><br>
            Limit: <input type="text" name="size" size="2" value="<?php echo trim(file_get_contents('limitdir/sz')); ?>"> Mbps
            <br>
            <input type="submit" name="simpan" class="btn" style="background:#2563eb; color:white;" value="SIMPAN SETTING" />
        </form>
        <div class="log">
            <?php echo nl2br(file_get_contents('limitdir/log.txt')); ?>
        </div>
    </div>
</body>
</html>
EOF

# ---------------------------------------------------------
# 5. DOWNLOAD ASSETS (IMAGE & JS)
# ---------------------------------------------------------
echo "Mengunduh assets pendukung..."
# Catatan: Sesuaikan URL ini jika ingin mengambil gambar dari repo Anda
wget -qO "$WWW_DIR/img/image.png" "https://raw.githubusercontent.com/roisulx-coder/RLX-WRT-TTL/main/xderm/img/image.png"
wget -qO "$WWW_DIR/js/jquery-2.1.3.min.js" "https://raw.githubusercontent.com/roisulx-coder/RLX-WRT-TTL/main/xderm/js/jquery-2.1.3.min.js"

# ---------------------------------------------------------
# 6. FINALISASI
# ---------------------------------------------------------
echo "Mengatur izin file & membersihkan cache..."
chmod -R 755 "$WWW_DIR"
chmod +x "$WWW_DIR/limit"
chmod 644 "$CTRL_PATH"
chmod 644 "$VIEW_PATH"

# Setup file default di limitdir jika belum ada
[ ! -f "$WWW_DIR/limitdir/st" ] && echo "Start" > "$WWW_DIR/limitdir/st"
[ ! -f "$WWW_DIR/limitdir/sz" ] && echo "3" > "$WWW_DIR/limitdir/sz"
[ ! -f "$WWW_DIR/limitdir/useip" ] && echo "use_ip=no" > "$WWW_DIR/limitdir/useip"
touch "$WWW_DIR/limitdir/log.txt"

rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/*
/etc/init.d/uhttpd restart
sync

echo "----------------------------------------------------"
echo "  INSTALASI XDERM LIMITER SELESAI!"
echo "  Akses di: Services -> Xderm Limiter"
echo "----------------------------------------------------"
