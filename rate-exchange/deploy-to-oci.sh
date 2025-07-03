#!/bin/bash

# Oracle Cloud Free Tier VM.Standard.E2.1.Microへのデプロイスクリプト
# 使用方法: ./deploy-to-oci.sh <VM_IP_ADDRESS> <SSH_KEY_PATH>

set -e

if [ $# -ne 2 ]; then
    echo "使用方法: $0 <VM_IP_ADDRESS> <SSH_KEY_PATH>"
    echo "例: $0 192.168.1.100 ~/.ssh/oci_private_key"
    exit 1
fi

VM_IP=$1
SSH_KEY=$2
REMOTE_USER="opc"  # OCI default user
REMOTE_DIR="/home/opc/rate-exchange"

echo "=== Oracle Cloud VM への rate-exchange デプロイ開始 ==="
echo "VM IP: $VM_IP"
echo "SSH Key: $SSH_KEY"

# SSH接続テスト
echo "1. SSH接続テスト..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$REMOTE_USER@$VM_IP" "echo 'SSH接続成功'"

# リモートディレクトリ作成
echo "2. リモートディレクトリ作成..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$VM_IP" "mkdir -p $REMOTE_DIR"

# ファイル転送
echo "3. ファイル転送..."
scp -i "$SSH_KEY" rate-exchange.py "$REMOTE_USER@$VM_IP:$REMOTE_DIR/"
scp -i "$SSH_KEY" requirements.txt "$REMOTE_USER@$VM_IP:$REMOTE_DIR/"

# リモートでのセットアップ実行
echo "4. リモート環境セットアップ..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$VM_IP" << 'EOF'
    set -e
    cd /home/opc/rate-exchange
    
    # Python3とpipの確認・インストール
    echo "Python3とpipの確認..."
    if ! command -v python3 &> /dev/null; then
        echo "Python3をインストール中..."
        sudo dnf install -y python3 python3-pip
    fi
    
    # 依存関係インストール
    echo "依存関係をインストール中..."
    python3 -m pip install --user -r requirements.txt
    
    # 実行権限設定
    chmod +x rate-exchange.py
    
    # テスト実行
    echo "テスト実行..."
    python3 rate-exchange.py
    
    echo "セットアップ完了!"
EOF

echo "5. cron設定（毎時実行）..."
ssh -i "$SSH_KEY" "$REMOTE_USER@$VM_IP" << 'EOF'
    # 既存のcronエントリを削除
    crontab -l 2>/dev/null | grep -v "rate-exchange" | crontab - 2>/dev/null || true
    
    # 新しいcronエントリを追加（毎時0分に実行）
    (crontab -l 2>/dev/null; echo "0 * * * * cd /home/opc/rate-exchange && /usr/bin/python3 rate-exchange.py >> /tmp/rate-exchange.log 2>&1") | crontab -
    
    echo "cron設定完了 - 毎時実行"
    crontab -l
EOF

echo ""
echo "=== デプロイ完了! ==="
echo "- スクリプトは毎時0分に自動実行されます"
echo "- ログ確認: ssh -i $SSH_KEY $REMOTE_USER@$VM_IP 'tail -f /tmp/rate-exchange.log'"
echo "- 手動実行: ssh -i $SSH_KEY $REMOTE_USER@$VM_IP 'cd /home/opc/rate-exchange && python3 rate-exchange.py'"