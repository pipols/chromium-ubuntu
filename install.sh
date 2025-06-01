#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Запустите скрипт с правами root (sudo $0)"
  exit 1
fi

install_chromium() {
  read -p "Введите имя пользователя для Chromium: " CUSTOM_USER
  read -sp "Введите пароль для Chromium: " PASSWORD
  echo ""
  read -p "Введите часовой пояс сервера (по умолчанию Europe/London): " TZ_INPUT
  TZ=${TZ_INPUT:-Europe/London}

  apt update -y && apt upgrade -y

  # Проверка установлен ли Docker
  if ! command -v docker &> /dev/null; then
    echo "Установка Docker..."
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
      apt-get remove -y "$pkg" 2>/dev/null
    done

    apt-get update
    apt-get install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    echo "Docker уже установлен, продолжаем..."
  fi

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
  echo "Установка завершена."
  echo "Доступ к приложению:"
  echo "  http://${SERVER_IP}:3010/"
  echo "  https://${SERVER_IP}:3011/"
}

uninstall_chromium() {
  echo "Остановка и удаление контейнера Chromium..."
  docker stop chromium 2>/dev/null
  docker rm chromium 2>/dev/null

  echo "Удаление директории Chromium..."
  rm -rf "$HOME/chromium"

  echo "Удаление образа Chromium..."
  docker rmi lscr.io/linuxserver/chromium:latest 2>/dev/null

  echo "Удаление завершено."
}

while true; do
  echo "Выберите действие:"
  echo "1) Установить Chromium"
  echo "2) Удалить Chromium"
  read -rp "Введите ваш выбор [1 или 2]: " choice
  choice=$(echo "$choice" | tr -d '[:space:]')
  if [ "$choice" = "1" ]; then
    install_chromium
    break
  elif [ "$choice" = "2" ]; then
    uninstall_chromium
    break
  else
    echo "Неверный выбор. Попробуйте снова."
  fi
done
