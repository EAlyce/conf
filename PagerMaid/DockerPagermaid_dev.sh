#!/usr/bin/env bash

install_docker_and_compose() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker and Docker Compose..."
        curl -fsSL https://get.docker.com | bash > /dev/null 2>&1
        apt-get install -y docker-compose > /dev/null
        echo "Docker and Docker Compose installation completed."
    else
        echo "Docker and Docker Compose are already installed."
    fi
}

services:
  pagermaid:
    image: teampgm/pagermaid_pyro
    container_name: "${CONTAINER_NAME:-PagerMaid-${RANDOM_NAME}}"
    hostname: "${CONTAINER_NAME:-PagerMaid-${RANDOM_NAME}}"
    volumes:
      - data:/pagermaid/workdir
    restart: always
    environment:
      # 在此添加任何必要的环境变量
    entrypoint: ["bash", "-c", "utils/docker-config.sh && tail -f /dev/null"]

  cron:
    image: alpine
    volumes:
      - data:/data
    entrypoint: ["sh", "-c", "echo '43 * * * * docker restart ${CONTAINER_NAME:-PagerMaid-${RANDOM_NAME}}' | crontab - && crond -f"]
    restart: always

volumes:
  data:
