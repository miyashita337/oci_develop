# USD/JPY Exchange Rate Monitor

Oracle Cloud Free Tier (VM.Standard.E2.1.Micro) 上で動作する為替レート監視システム

## 機能

- USD/JPY為替レートの定期監視
- 5%以上の変動時にPushover通知
- 前回レートとの比較・変動率計算
- ログ出力機能

## デプロイ方法

### 前提条件
- Oracle Cloud Free Tierアカウント
- VM.Standard.E2.1.Microインスタンス作成済み
- SSH鍵ペア設定済み

### デプロイ手順

1. **Pushover設定**
   ```bash
   # rate-exchange.py のPushoverキーを自分のキーに変更
   PUSHOVER_USER_KEY = 'your_user_key'
   PUSHOVER_API_TOKEN = 'your_app_token'
   ```

2. **デプロイ実行**
   ```bash
   ./deploy-to-oci.sh <VM_IP_ADDRESS> <SSH_KEY_PATH>
   ```
   
   例:
   ```bash
   ./deploy-to-oci.sh 192.168.1.100 ~/.ssh/oci_private_key
   ```

### 手動操作

- **ログ確認**
  ```bash
  ssh -i ~/.ssh/oci_private_key opc@<VM_IP> 'tail -f /tmp/rate-exchange.log'
  ```

- **手動実行**
  ```bash
  ssh -i ~/.ssh/oci_private_key opc@<VM_IP> 'cd /home/opc/rate-exchange && python3 rate-exchange.py'
  ```

- **cron設定確認**
  ```bash
  ssh -i ~/.ssh/oci_private_key opc@<VM_IP> 'crontab -l'
  ```

## 動作仕様

- **実行頻度**: 毎時0分（cron設定）
- **通知閾値**: 5%以上の変動
- **API**: exchangerate-api.com（無料・認証不要）
- **ログ**: `/tmp/rate-exchange.log`
- **データ保存**: `usd_jpy_rate.json`

## システム要件

- Python 3.6+
- requests ライブラリ
- インターネット接続