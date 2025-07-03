#!/bin/bash

# OCI Full Deployment Script
# すべての監視スクリプトをOCIインスタンスにデプロイし、cronを設定
# 新しいディレクトリ構造に対応

# 設定
OCI_USER="opc"
OCI_HOST="${1:-138.2.28.222}"  # コマンドライン引数でIPを指定可能
SSH_KEY="~/.ssh/id_rsa"

if [ -z "$1" ]; then
    echo "Usage: $0 <OCI_IP_ADDRESS>"
    echo "Example: $0 140.238.48.195"
    echo ""
    echo "既知のOCI IP addresses:"
    echo "- 138.2.28.222"
    echo "- 155.248.175.40" 
    echo "- 140.238.48.195"
    exit 1
fi

echo "=== Full OCI Deployment Script ==="
echo "Target: $OCI_USER@$OCI_HOST"
echo "新しいディレクトリ構造でデプロイ中..."
echo ""

# Step 1: 接続テスト
echo "1. Testing SSH connection..."
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$OCI_USER@$OCI_HOST" 'echo "Connection successful"'; then
    echo "ERROR: Cannot connect to $OCI_HOST"
    exit 1
fi

# Step 2: 設定ファイルのアップロード
echo "2. Uploading configuration files..."
scp -i "$SSH_KEY" config.json "$OCI_USER@$OCI_HOST:/home/opc/"

# Step 3: 各プロジェクトディレクトリを作成
echo "3. Creating project directories on OCI..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" '
mkdir -p /home/opc/rate-exchange
mkdir -p /home/opc/bitcoin  
mkdir -p /home/opc/check_a1
mkdir -p /home/opc/us_bonds
'

# Step 4: 各プロジェクトのスクリプトをアップロード
echo "4. Uploading project scripts..."

# Rate Exchange
echo "   Uploading rate-exchange files..."
scp -i "$SSH_KEY" rate-exchange/rate-exchange.py "$OCI_USER@$OCI_HOST:/home/opc/rate-exchange/"
scp -i "$SSH_KEY" rate-exchange/requirements.txt "$OCI_USER@$OCI_HOST:/home/opc/rate-exchange/"

# Bitcoin
echo "   Uploading bitcoin files..."
scp -i "$SSH_KEY" bitcoin/bitcoin_tracker.py "$OCI_USER@$OCI_HOST:/home/opc/bitcoin/"
scp -i "$SSH_KEY" bitcoin/bitcoin_chart.py "$OCI_USER@$OCI_HOST:/home/opc/bitcoin/"
scp -i "$SSH_KEY" bitcoin/bitcoin_trading_tool.py "$OCI_USER@$OCI_HOST:/home/opc/bitcoin/"

# Check A1
echo "   Uploading check_a1 files..."
scp -i "$SSH_KEY" check_a1/check_a1_availability.sh "$OCI_USER@$OCI_HOST:/home/opc/check_a1/"
scp -i "$SSH_KEY" check_a1/check_a1_availability_with_pushover.sh "$OCI_USER@$OCI_HOST:/home/opc/check_a1/"

# US Bonds
echo "   Uploading us_bonds files..."
scp -i "$SSH_KEY" us_bonds/us_bond_checker.py "$OCI_USER@$OCI_HOST:/home/opc/us_bonds/"
scp -i "$SSH_KEY" us_bonds/us_bonds_data.json "$OCI_USER@$OCI_HOST:/home/opc/us_bonds/"

# Step 5: 実行権限設定
echo "5. Setting execute permissions..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" '
chmod +x /home/opc/rate-exchange/rate-exchange.py
chmod +x /home/opc/bitcoin/bitcoin_tracker.py
chmod +x /home/opc/bitcoin/bitcoin_chart.py
chmod +x /home/opc/bitcoin/bitcoin_trading_tool.py
chmod +x /home/opc/check_a1/check_a1_availability.sh
chmod +x /home/opc/check_a1/check_a1_availability_with_pushover.sh
chmod +x /home/opc/us_bonds/us_bond_checker.py
'

# Step 6: 依存関係確認
echo "6. Checking dependencies..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" '
python3 -c "import requests" 2>/dev/null || pip3 install --user requests
python3 -c "import matplotlib" 2>/dev/null || pip3 install --user matplotlib
python3 -c "import pandas" 2>/dev/null || pip3 install --user pandas
python3 -c "import numpy" 2>/dev/null || pip3 install --user numpy
'

# Step 7: 各スクリプトのテスト実行
echo "7. Testing scripts..."
echo "   Testing rate-exchange.py..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" 'cd /home/opc/rate-exchange && python3 rate-exchange.py' || echo "   Warning: rate-exchange test failed"

echo "   Testing bitcoin_tracker.py..."  
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" 'cd /home/opc/bitcoin && python3 bitcoin_tracker.py' || echo "   Warning: bitcoin_tracker test failed"

echo "   Testing us_bond_checker.py..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" 'cd /home/opc/us_bonds && python3 us_bond_checker.py' || echo "   Warning: us_bond_checker test failed"

echo "   Testing check_a1_availability_with_pushover.sh..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" 'cd /home/opc/check_a1 && ./check_a1_availability_with_pushover.sh' || echo "   Warning: check_a1 test failed"

# Step 8: cronジョブの完全設定（新しいディレクトリ構造対応）
echo "8. Setting up comprehensive cron jobs..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" '
# 既存のcronをバックアップ
crontab -l > /home/opc/crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || true

# 新しいcron設定（15分間隔に最適化）
(echo "# PATH for cron jobs"
 echo "PATH=/home/opc/.local/bin:/usr/local/bin:/usr/bin:/bin"
 echo ""
 echo "# A1 availability monitoring (every 15 minutes)"
 echo "*/15 * * * * cd /home/opc/check_a1 && ./check_a1_availability_with_pushover.sh >> /home/opc/a1_availability.log 2>&1"
 echo ""
 echo "# Exchange rate monitoring (every 15 minutes)"  
 echo "*/15 * * * * cd /home/opc/rate-exchange && python3 rate-exchange.py >> /home/opc/rate-exchange.log 2>&1"
 echo ""
 echo "# Bitcoin price monitoring (every 15 minutes)"
 echo "*/15 * * * * cd /home/opc/bitcoin && python3 bitcoin_tracker.py >> /home/opc/bitcoin-tracker.log 2>&1"
 echo ""
 echo "# US Bond monitoring (every 15 minutes - 10年国債5%超え警告)"
 echo "*/15 * * * * cd /home/opc/us_bonds && python3 us_bond_checker.py >> /home/opc/us-bonds.log 2>&1"
 echo ""
 echo "# Morning reports (10:00 AM daily)"
 echo "0 10 * * * cd /home/opc/check_a1 && ./check_a1_availability_with_pushover.sh --morning-report >> /home/opc/a1_morning_report.log 2>&1"
 echo "0 10 * * * cd /home/opc/rate-exchange && python3 rate-exchange.py --morning-report >> /home/opc/rate_morning_report.log 2>&1" 
 echo "0 10 * * * cd /home/opc/bitcoin && python3 bitcoin_tracker.py --morning-report >> /home/opc/bitcoin_morning_report.log 2>&1"
 echo "0 10 * * * cd /home/opc/us_bonds && python3 us_bond_checker.py --morning-report >> /home/opc/us_bonds_morning_report.log 2>&1") | crontab -
'

# Step 9: 設定確認
echo "9. Verifying deployment..."
ssh -i "$SSH_KEY" "$OCI_USER@$OCI_HOST" '
echo "=== Cron Jobs ==="
crontab -l
echo ""
echo "=== Project Directory Structure ==="
ls -la /home/opc/*/
echo ""
echo "=== Configuration Files ==="
ls -la /home/opc/*.json 2>/dev/null
echo ""
echo "=== Test morning reports ==="
echo "Testing Bitcoin morning report..."
cd /home/opc/bitcoin && python3 bitcoin_tracker.py --morning-report || echo "Bitcoin morning report failed"
echo ""
echo "Testing Exchange rate morning report..."
cd /home/opc/rate-exchange && python3 rate-exchange.py --morning-report || echo "Rate exchange morning report failed"
echo ""
echo "Testing US Bond morning report..."
cd /home/opc/us_bonds && python3 us_bond_checker.py --morning-report || echo "US bonds morning report failed"
echo ""
echo "Testing A1 availability morning report..."
cd /home/opc/check_a1 && ./check_a1_availability_with_pushover.sh --morning-report || echo "A1 morning report failed"
'

echo ""
echo "=== Deployment Complete ==="
echo "✓ Rate exchange monitoring: Every 15 minutes + 10:00 AM report"
echo "✓ Bitcoin price monitoring: Every 15 minutes + 10:00 AM report"  
echo "✓ US Bond monitoring: Every 15 minutes (10年国債5%超え警告) + 10:00 AM report"
echo "✓ A1 availability monitoring: Every 15 minutes + 10:00 AM report"
echo ""
echo "Project directories:"
echo "- /home/opc/rate-exchange/"
echo "- /home/opc/bitcoin/"
echo "- /home/opc/check_a1/"
echo "- /home/opc/us_bonds/"
echo ""
echo "Log files locations:"
echo "- /home/opc/rate-exchange.log"
echo "- /home/opc/bitcoin-tracker.log"
echo "- /home/opc/us-bonds.log"
echo "- /home/opc/a1_availability.log"
echo "- /home/opc/*_morning_report.log"
echo ""
echo "To monitor: ssh -i ~/.ssh/id_rsa opc@$OCI_HOST"
echo ""
echo "🎉 新しいディレクトリ構造でのデプロイが完了しました！"