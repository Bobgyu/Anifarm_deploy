#!/bin/bash
set -e  # 오류 발생시 스크립트 중단

# 디스크 공간 정리 강화
echo "Cleaning up disk space..."
sudo apt-get clean
sudo apt-get autoremove -y
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /tmp/*
sudo rm -rf ~/.cache/pip
sudo rm -rf /var/cache/pip
sudo rm -rf /var/cache/apt
sudo rm -rf /var/cache/apt/archives
sudo rm -rf /var/cache/apt/archives/*
sudo rm -rf /var/cache/apt/*.bin
sudo rm -rf /var/cache/apt/partial/*
sudo rm -rf /var/cache/apt/apt-file
sudo rm -rf /var/cache/apt/apt-file/*
sudo rm -rf /var/cache/apt/apt-file/partial/*
sudo rm -rf /var/cache/apt/apt-file/archives/*
sudo rm -rf /var/cache/apt/apt-file/archives/*/*
sudo rm -rf /var/cache/apt/apt-file/archives/*/*/*

# 기존 conda 환경 및 캐시 정리
echo "Cleaning up conda environments..."
if [ -d "/home/ubuntu/miniconda" ]; then
    export PATH="/home/ubuntu/miniconda/bin:$PATH"
    conda clean -a -y
    rm -rf ~/.conda/pkgs/*
    rm -rf ~/.conda/envs/*
fi

# 기존 배포 파일 정리
echo "Cleaning up old deployments..."
sudo rm -rf /var/www/back

echo "Current disk space usage:"
df -h

# Conda 환경 설정
echo "Setting up conda environment..."
if [ ! -d "/home/ubuntu/miniconda" ]; then
    echo "Installing Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p /home/ubuntu/miniconda
    rm /tmp/miniconda.sh
fi

# Conda 초기화
export PATH="/home/ubuntu/miniconda/bin:$PATH"
source /home/ubuntu/miniconda/bin/activate

echo "creating app folder"
sudo mkdir -p /var/www/back

echo "moving files to app folder"
sudo cp -r * /var/www/back/

# Navigate to the app directory and handle .env file
cd /var/www/back/
echo "Setting up .env file..."
if [ -f env ]; then
    sudo mv env .env
    sudo chown ubuntu:ubuntu .env
    echo ".env file created from env file"
elif [ -f .env ]; then
    sudo chown ubuntu:ubuntu .env
    echo ".env file already exists"
fi

# .env 파일 확인
echo "Checking .env file..."
if [ -f .env ]; then
    echo ".env file exists"
    ls -la .env
else
    echo "Warning: .env file not found"
fi

# 기존 환경 제거 및 새로운 환경 생성
echo "Creating conda environment..."
conda env remove -n fastapi-env --yes || true
conda create -n fastapi-env python=3.12 -y
conda activate fastapi-env

# Nginx 설치 및 설정
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx"
    sudo apt-get update
    sudo apt-get install -y nginx
fi

# Nginx 설정
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF'

# Nginx 설정 심볼릭 링크 생성
sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 로그 파일 설정
sudo mkdir -p /var/log/fastapi
sudo touch /var/log/fastapi/uvicorn.log
sudo chown -R ubuntu:ubuntu /var/log/fastapi

# 기존 프로세스 정리
echo "Cleaning up existing processes..."
sudo pkill uvicorn || true
sudo systemctl stop nginx || true

# 애플리케이션 디렉토리 권한 설정
sudo chown -R ubuntu:ubuntu /var/www/back

# 의존성 설치 (pip 캐시 사용하지 않음)
echo "Installing dependencies..."
pip install --no-cache-dir -r requirements.txt

# Nginx 설정 테스트 및 재시작
echo "Testing and restarting Nginx..."
sudo nginx -t
sudo systemctl restart nginx

# 애플리케이션 시작
echo "Starting FastAPI application..."
cd /var/www/back
nohup /home/ubuntu/miniconda/envs/fastapi-env/bin/uvicorn app:app --host 0.0.0.0 --port 8000 --workers 3 > /var/log/fastapi/uvicorn.log 2>&1 &

# 애플리케이션 시작 확인을 위한 대기
sleep 5

# 로그 확인
echo "Recent application logs:"
tail -n 20 /var/log/fastapi/uvicorn.log || true

echo "Deployment completed successfully! 🚀"

# 상태 확인
echo "Checking service status..."
ps aux | grep uvicorn
sudo systemctl status nginx



