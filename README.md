# 🚀 Xderm Limiter - Auto Installer

[![OpenWrt Support](https://img.shields.io/badge/OpenWrt-21.02%20%7C%2022.03%20%7C%2023.05-blue?logo=openwrt)](https://openwrt.org)
[![PHP Version](https://img.shields.io/badge/PHP-7.4%20%7C%208.x-777bb4?logo=php)](https://www.php.net)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Xderm Limiter** adalah alat manajemen *bandwidth* otomatis berbasis web untuk router OpenWrt. Dirancang untuk membatasi kecepatan internet klien secara adil menggunakan `TC` (Traffic Control) dengan antarmuka PHP yang ringan.

---

## ✨ Fitur Utama
- 🛠 **Auto-Config PHP:** Memperbaiki masalah *Bad Gateway* secara otomatis pada `uhttpd`.
- ⚡ **Dual Engine:** Mendukung PHP7 dan PHP8 secara mulus.
- 📊 **Real-time Logging:** Pantau klien yang terbatasi langsung dari dashboard.
- 🛡 **Smart Limit:** Menggunakan antrian HTB (Hierarchical Token Bucket) untuk efisiensi tinggi.
- 🖥 **LuCI Integration:** Terintegrasi langsung dalam menu *Services* OpenWrt.

---

## 🛠 Prasyarat
Sebelum menginstal, pastikan router Anda terhubung ke internet untuk mengunduh paket berikut:
* `php7-cgi` atau `php8-cgi`
* `tc-full`
* `screen`

---

## 🚀 Cara Instalasi

Hubungkan ke terminal router Anda (SSH) dan jalankan perintah sakti berikut:

```bash
wget -qO install.sh "[https://raw.githubusercontent.com/username/repo/main/install.sh](https://raw.githubusercontent.com/username/repo/main/install.sh)" && chmod +x install.sh && ./install.sh
