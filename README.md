# 🚀 Xderm Limiter for OpenWrt

[![Status](https://img.shields.io/badge/Status-Stable-green.svg)]()
[![Platform](https://img.shields.io/badge/Platform-OpenWrt-blue.svg)]()
[![Engine](https://img.shields.io/badge/Engine-Traffic%20Control-orange.svg)]()

**Xderm Limiter** adalah alat manajemen bandwidth otomatis untuk OpenWrt yang dirancang untuk membatasi kecepatan internet klien secara dinamis. Menggunakan engine `tc` (Traffic Control), alat ini sangat efektif untuk menjaga stabilitas jaringan dari pengguna yang rakus bandwidth.

---

## ✨ Fitur Utama
* **Auto Limit Client**: Mendeteksi perangkat yang terhubung dan menerapkan limit secara otomatis.
* **Integrated LuCI Dashboard**: Terintegrasi langsung dengan antarmuka web OpenWrt (Menu Services).
* **IP Exception**: Fitur untuk mengecualikan perangkat tertentu agar tidak terkena limitasi.
* **Real-time Engine**: Menggunakan `screen` agar proses limit berjalan di latar belakang tanpa memutus sesi SSH.
* **Custom Speed**: Pengaturan kecepatan (Mbps) yang bisa diubah kapan saja melalui dashboard PHP.

---

## 📸 Cara Kerja Sistem


Sistem bekerja dengan memantau tabel DHCP di `/tmp/dhcp.leases`. Setiap kali klien aktif terdeteksi, skrip `limit` akan membuatkan jalur khusus (class) pada antarmuka `br-lan` menggunakan algoritma **HTB (Hierarchical Token Bucket)**.

---

## 📥 Instalasi Cepat

Cukup salin dan tempel perintah berikut di terminal SSH Anda:

```bash
wget -qO- [https://raw.githubusercontent.com/username-anda/repo-anda/main/install-xderm.sh](https://raw.githubusercontent.com/username-anda/repo-anda/main/install-xderm.sh) | sh
