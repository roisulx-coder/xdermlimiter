# 🚀 Xderm Limiter - Auto Bandwidth Manager

[![Status](https://img.shields.io/badge/Status-Stable-green.svg)]()
[![Platform](https://img.shields.io/badge/Platform-OpenWrt-blue.svg)]()
[![Engine](https://img.shields.io/badge/Engine-Traffic%20Control-orange.svg)]()

**Xderm Limiter** adalah alat manajemen bandwidth otomatis untuk OpenWrt yang menggunakan engine `tc` (Traffic Control). Alat ini membantu membatasi kecepatan internet klien secara dinamis untuk mencegah penggunaan bandwidth berlebih oleh satu perangkat.

---

## ✨ Fitur Utama
* **Auto Limit**: Otomatis membatasi setiap klien yang terhubung ke WiFi/LAN.
* **Integrated LuCI**: Akses pengaturan langsung lewat menu Services di OpenWrt.
* **IP Exception**: Kecualikan IP tertentu (seperti IP Admin) dari pembatasan.
* **Background Process**: Engine berjalan di latar belakang menggunakan `screen`.

---

## 📸 Cara Kerja Teknis


Sistem memantau perangkat yang aktif melalui tabel DHCP dan menerapkan aturan **HTB (Hierarchical Token Bucket)** pada antarmuka jaringan router untuk memastikan pembagian bandwidth yang adil.

---

## 📥 Instalasi Satu Baris

Buka terminal SSH Anda (Putty/Termius) dan jalankan perintah berikut:

```bash
wget -qO- https://raw.githubusercontent.com/roisulx-coder/xdermlimiter/main/install-xderm.sh | sh
