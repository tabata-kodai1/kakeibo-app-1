#!/bin/bash
# EC2 の初期化スクリプト（初回起動時に root で 1 回だけ実行される）。
# Rails のイメージを EC2 上でビルドできるようにする。ビルドと起動は deploy.sh が行う。
set -euxo pipefail

# --- スワップ ---
# 無料枠のインスタンスはメモリが 1GB 程度で、Rails のイメージビルド（bundle install や
# アセットのプリコンパイル）がメモリ不足で落ちやすい。ビルドの前にスワップを確保する。
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Docker ---
dnf install -y docker git
usermod -aG docker ec2-user

# ログでディスクを食い潰さないよう、ローテーションの上限を設ける（N-19）。
# docker logs で読めるのは標準出力に出したログで、json-file ドライバが EC2 上にファイルとして残す。
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

systemctl enable --now docker
