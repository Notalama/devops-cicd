#!/bin/bash

sudo apt-get update

is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Docker
if is_installed docker; then
    echo "Docker вже встановлено: $(docker --version)"
else
    echo "Встановлення Docker..."
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker встановлено: $(docker --version)"
fi

# 2. Docker Compose
if is_installed docker-compose; then
    echo "Docker Compose вже встановлено: $(docker-compose --version)"
else
    echo "Встановлення Docker Compose..."
    sudo apt-get install -y docker-compose
    echo "Docker Compose встановлено: $(docker-compose --version)"
fi

# 3. Python (3.9+)
if is_installed python3 && python3 -c "import sys; exit(0 if sys.version_info >= (3, 9) else 1)"; then
    echo "Python 3.9+ вже встановлено: $(python3 --version)"
else
    echo "Встановлення Python 3..."
    sudo apt-get install -y python3 python3-pip
    echo "Python встановлено: $(python3 --version)"
fi

# 4. Django
if python3 -m django --version >/dev/null 2>&1; then
    echo "Django вже встановлено: $(python3 -m django --version)"
else
    echo "Встановлення Django..."
    pip3 install django
    echo "Django встановлено: $(python3 -m django --version)"
fi

echo "--- Всі інструменти перевірено та встановлено! ---"
