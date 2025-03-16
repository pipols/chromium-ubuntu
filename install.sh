#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Jalankan script ini dengan hak akses root (sudo $0)"
  exit 1
fi

display_ascii() {
cat <<'EOF'
# ··············································
# : :::===  :::  === :::====  :::====  :::=====:
# : :::     :::  === :::  === :::  === :::     :
# :  =====  ======== ======== =======  ======  :
# :     === ===  === ===  === === ===  ===     :
# : ======  ===  === ===  === ===  === ========:
# :                                            :
# : ::: :::====      :::  === :::  === :::==== :
# : ::: :::====      :::  === :::  === :::  ===:
# : ===   ===        ======== ===  === ======= :
# : ===   ===        ===  === ===  === ===  ===:
# : ===   ===        ===  ===  ======  ======= :
# :                                            :
# ··············································
EOF
}

install_chromium() {
  display_ascii
  read -p "Masukkan username untuk Chromium: " CUSTOM_USER
  read -sp "Masukkan password untuk Chromium: " PASSWORD
  echo ""
  read -p "Masukkan timezone server (default Europe/London): " TZ_INPUT
  TZ=${TZ_INPUT:-Europe/London}

  apt update -y && apt upgrade -y

  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg"
  done

  apt-get update
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update -y && apt upgrade -y

  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  docker --version
  realpath --relative-to /usr/share/zoneinfo /etc/localtime

  mkdir -p "$HOME/chromium"
  cat > "$HOME/chromium/docker-compose.yaml" <<EOF
---
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=${CUSTOM_USER}
      - PASSWORD=${PASSWORD}
      - PUID=1000
      - PGID=1000
      - TZ=${TZ}
      - CHROME_CLI=https://www.youtube.com/@SHAREITHUB_COM
    volumes:
      - /root/chromium/config:/config
    ports:
      - "3010:3000"
      - "3011:3001"
    shm_size: "1gb"
    restart: unless-stopped
EOF

  cd "$HOME/chromium" || exit
  docker compose up -d

  SERVER_IP=$(hostname -I | awk '{print $1}')
  echo "Instalasi selesai."
  echo "Akses aplikasi melalui:"
  echo "  http://${SERVER_IP}:3010/"
  echo "  https://${SERVER_IP}:3011/"
}

uninstall_chromium() {
  echo "Menghentikan dan menghapus container Chromium..."
  docker stop chromium 2>/dev/null
  docker rm chromium 2>/dev/null

  echo "Menghapus direktori Chromium..."
  rm -rf "$HOME/chromium"

  echo "Menghapus image Chromium..."
  docker rmi lscr.io/linuxserver/chromium:latest 2>/dev/null

  echo "Menghapus paket Docker..."
  apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "Menghapus file konfigurasi Docker..."
  rm -f /etc/apt/sources.list.d/docker.list
  rm -rf /etc/apt/keyrings

  echo "Menghapus sisa-sisa Docker..."
  apt-get autoremove -y
  docker system prune -f

  echo "Uninstall selesai."
}

while true; do
  echo "Pilih opsi:"
  echo "1) Install Chromium"
  echo "2) Uninstall Chromium"
  read -rp "Masukkan pilihan Anda [1 atau 2]: " choice
  choice=$(echo "$choice" | tr -d '[:space:]')
  if [ "$choice" = "1" ]; then
    install_chromium
    break
  elif [ "$choice" = "2" ]; then
    uninstall_chromium
    break
  else
    echo "Pilihan tidak valid. Silakan coba lagi."
  fi
done
