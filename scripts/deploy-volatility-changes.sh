#!/usr/bin/env bash
# OCI 実機への 19:00 ノイズ対策デプロイスクリプト
# Issue: morning-report 4 種が UTC 10:00 = JST 19:00 に同時着弾するノイズ
# 対策: (a) crontab から morning-report 系を全削除 (b) */15 → 0 * * * * に変更
#       (c) config.json に cooldown / volatility_threshold を反映
# 実行: bash scripts/deploy-volatility-changes.sh [OCI_HOST]
set -euo pipefail

OCI_HOST="${1:-138.2.28.222}"
OCI_USER="${OCI_USER:-opc}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
LOCAL_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> OCI ${OCI_USER}@${OCI_HOST} に接続テスト"
ssh -i "$SSH_KEY" -o ConnectTimeout=10 "${OCI_USER}@${OCI_HOST}" 'date'

echo
echo "==> 現在の crontab をバックアップ"
ssh -i "$SSH_KEY" "${OCI_USER}@${OCI_HOST}" \
  'BACKUP="/tmp/crontab.bak.$(date +%Y%m%d-%H%M%S)" && crontab -l > "$BACKUP" && echo "backup: $BACKUP"'

echo
echo "==> crontab から morning-report 系 4 行を削除 + 15 分間隔 → 毎時 0 分に変更"
ssh -i "$SSH_KEY" "${OCI_USER}@${OCI_HOST}" \
  'crontab -l | grep -v "morning-report" | sed "s|\*/15 \* \* \* \*|0 \* \* \* \*|g" | crontab -'

echo
echo "==> 新しい crontab"
ssh -i "$SSH_KEY" "${OCI_USER}@${OCI_HOST}" 'crontab -l | grep -v "^#"'

echo
echo "==> config.json を OCI に転送"
scp -i "$SSH_KEY" "$LOCAL_REPO/config.json" "${OCI_USER}@${OCI_HOST}:/home/opc/config.json"

echo
echo "==> 各 tracker ディレクトリ配下にも config.json を配置 (load_config の ../config.json フォールバック対応)"
ssh -i "$SSH_KEY" "${OCI_USER}@${OCI_HOST}" \
  'for dir in rate-exchange bitcoin us_bonds altcoin_portfolio; do
     [ -d "/home/opc/$dir" ] && cp /home/opc/config.json "/home/opc/$dir/config.json" && echo "  copied: /home/opc/$dir/config.json"
   done'

echo
echo "==> Python スクリプト 3 本を OCI に転送"
scp -i "$SSH_KEY" \
  "$LOCAL_REPO/rate-exchange/rate-exchange.py" \
  "${OCI_USER}@${OCI_HOST}:/home/opc/rate-exchange/rate-exchange.py"
scp -i "$SSH_KEY" \
  "$LOCAL_REPO/bitcoin/bitcoin_tracker.py" \
  "${OCI_USER}@${OCI_HOST}:/home/opc/bitcoin/bitcoin_tracker.py"
scp -i "$SSH_KEY" \
  "$LOCAL_REPO/us_bonds/us_bond_checker.py" \
  "${OCI_USER}@${OCI_HOST}:/home/opc/us_bonds/us_bond_checker.py"

echo
echo "==> 1 サイクル動作確認 (rate-exchange を即実行)"
ssh -i "$SSH_KEY" "${OCI_USER}@${OCI_HOST}" \
  'cd /home/opc/rate-exchange && python3 rate-exchange.py 2>&1 | tail -10'

echo
echo "✅ デプロイ完了"
echo
echo "確認:"
echo "  - 次の毎時 :00 UTC (= JST :00) から実行"
echo "  - morning-report は廃止されたので 10:00 UTC (JST 19:00) の同時着弾は止まる"
echo "  - ボラ閾値超 + cooldown 解除時のみ通知"
echo
echo "ロールバック:"
echo "  ssh -i $SSH_KEY ${OCI_USER}@${OCI_HOST} 'crontab /tmp/crontab.bak.<TIMESTAMP>'"
