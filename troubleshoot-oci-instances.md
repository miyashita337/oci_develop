# OCI インスタンス復旧ガイド

## 現在の状況
- すべての既知のOCIインスタンス（138.2.28.222, 155.248.175.40, 140.238.48.195）への SSH接続が失敗
- OCI CLI認証エラー（APIキーまたはパスフレーズに問題の可能性）

## 復旧手順

### 1. OCI Web コンソールでの確認
1. https://cloud.oracle.com にアクセス
2. テナンシー: `ocid1.tenancy.oc1..aaaaaaaay43gxqikyfgdogwellqrysliln22qigj7r5ro4wxvpjg75gm4bzq`
3. リージョン: `ap-tokyo-1` (Asia Pacific Tokyo)
4. Compute > Instances でインスタンス状態を確認

### 2. インスタンス起動（Web コンソール）
停止状態のインスタンスがある場合：
1. インスタンス名をクリック
2. "Start" ボタンをクリック
3. 起動完了後、パブリックIPアドレスを確認

### 3. 新しいインスタンス作成（必要な場合）
```bash
# SSH キー確認
cat ~/.ssh/id_rsa.pub

# インスタンス作成設定:
# - Shape: VM.Standard.E2.1.Micro (Always Free)
# - Image: Oracle Linux 8
# - Network: 既存のVCN/サブネット
# - SSH Key: 上記で確認した公開キー
```

### 4. SSH接続確認
```bash
ssh -i ~/.ssh/id_rsa opc@<NEW_PUBLIC_IP>
```

### 5. 既存設定の復元
インスタンスが新規の場合、以下のファイルを再アップロード：
```bash
scp -i ~/.ssh/id_rsa /Users/harieshokunin/oci_develop/config.json opc@<IP>:/home/opc/
scp -i ~/.ssh/id_rsa /Users/harieshokunin/oci_develop/rate-exchange/rate-exchange.py opc@<IP>:/home/opc/
scp -i ~/.ssh/id_rsa /Users/harieshokunin/oci_develop/rate-exchange/bitcoin-trading.py opc@<IP>:/home/opc/
scp -i ~/.ssh/id_rsa /home/opc/check_a1_availability.sh opc@<IP>:/home/opc/
```

### 6. cronジョブの再設定
```bash
ssh -i ~/.ssh/id_rsa opc@<IP> '
# PATH設定付きでcronを設定
(echo "PATH=/home/opc/.local/bin:/usr/local/bin:/usr/bin:/bin"; 
 echo "*/5 * * * * /home/opc/check_a1_availability.sh >> /home/opc/cron.log 2>&1";
 echo "*/5 * * * * python3 /home/opc/rate-exchange.py >> /home/opc/rate-exchange.log 2>&1";
 echo "*/5 * * * * python3 /home/opc/bitcoin-trading.py >> /home/opc/bitcoin-trading.log 2>&1";
 echo "0 10 * * * /home/opc/check_a1_availability.sh --morning-report >> /home/opc/a1_morning_report.log 2>&1";
 echo "0 10 * * * python3 /home/opc/rate-exchange.py --morning-report >> /home/opc/rate_morning_report.log 2>&1";
 echo "0 10 * * * python3 /home/opc/bitcoin-trading.py --morning-report >> /home/opc/bitcoin_morning_report.log 2>&1") | crontab -
'
```

## トラブルシューティング

### OCI CLI認証修復
```bash
# 1. 新しいAPIキー生成
openssl genrsa -out ~/.oci/oci_api_key_new.pem 2048
openssl rsa -pubout -in ~/.oci/oci_api_key_new.pem -out ~/.oci/oci_api_key_public_new.pem

# 2. OCI Web コンソールでAPIキーを更新
# Identity > Users > <your_user> > API Keys > Add API Key

# 3. フィンガープリントを更新
# ~/.oci/config ファイルの fingerprint を新しい値に更新
```

### 緊急時の手動実行
```bash
# Bitcoin価格チェック
python3 /home/opc/bitcoin-trading.py

# 為替レートチェック  
python3 /home/opc/rate-exchange.py

# A1空きチェック
/home/opc/check_a1_availability.sh

# 朝のレポート
python3 /home/opc/bitcoin-trading.py --morning-report
python3 /home/opc/rate-exchange.py --morning-report
/home/opc/check_a1_availability.sh --morning-report
```