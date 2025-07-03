#!/bin/bash

# 設定ファイルの読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

# 設定ファイルが存在しない場合は親ディレクトリを確認
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$(dirname "$SCRIPT_DIR")/config.json"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config.json not found"
    exit 1
fi

# JSON設定から値を読み取る関数
get_config_value() {
    python3 -c "import json; config=json.load(open('$CONFIG_FILE')); print(config['$1']['$2'])" 2>/dev/null
}

# 設定値の読み込み
export OCI_CLI_KEY_FILE=$(get_config_value "oci" "key_file")
export OCI_CLI_PASSPHRASE=$(get_config_value "oci" "passphrase")
export PATH=/home/opc/.local/bin:$PATH

# A1インスタンス空き確認スクリプト
# OCI CLI を使用してA1.Flexインスタンスの空きをチェック

# 設定
SHAPE=$(get_config_value "a1_instance" "shape")
COMPARTMENT_ID=$(get_config_value "oci" "compartment_id")
AVAILABILITY_DOMAIN=$(get_config_value "oci" "availability_domain")
IMAGE_ID=$(get_config_value "oci" "image_id")
SUBNET_ID=$(get_config_value "oci" "subnet_id")
SSH_KEY=$(get_config_value "oci" "ssh_key")

# Pushover通知設定
PUSHOVER_USER_KEY=$(get_config_value "pushover" "user_key")
PUSHOVER_API_TOKEN=$(get_config_value "pushover" "api_token")

# ログファイル
LOG_FILE=$(get_config_value "logging" "a1_check_log")
LAST_CHECK_FILE=$(get_config_value "logging" "last_check_file")

# 関数: ログメッセージ
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 関数: Pushover通知送信
send_pushover_notification() {
    local message="$1"
    local title="${2:-🚀 OCI A1インスタンス空き通知}"
    log_message "Pushover通知送信: $message"
    
    response=$(curl -s \
        --form-string "token=$PUSHOVER_API_TOKEN" \
        --form-string "user=$PUSHOVER_USER_KEY" \
        --form-string "message=$message" \
        --form-string "title=$title" \
        https://api.pushover.net/1/messages.json)
    
    if echo "$response" | grep -q '"status":1'; then
        log_message "Pushover通知送信成功"
    else
        log_message "Pushover通知送信失敗: $response"
    fi
}

# 関数: 昨日のログサマリーを取得
get_yesterday_log_summary() {
    local yesterday=$(date -d "yesterday" '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d' 2>/dev/null)
    
    if [ -f "$LOG_FILE" ]; then
        local check_count=$(grep "$yesterday" "$LOG_FILE" | grep -c "A1インスタンス空き確認開始" || echo "0")
        local success_count=$(grep "$yesterday" "$LOG_FILE" | grep -c "A1インスタンス作成成功" || echo "0")
        local fail_count=$(grep "$yesterday" "$LOG_FILE" | grep -c "A1インスタンス作成失敗" || echo "0")
        
        echo "📊 昨日($yesterday)のA1チェック結果：
チェック回数: ${check_count}回
作成成功: ${success_count}回
作成失敗: ${fail_count}回"
    else
        echo "📊 昨日のログファイルが見つかりません"
    fi
}

# 関数: 現在のイメージ情報を取得
get_current_image_info() {
    log_message "現在のイメージ情報を取得中..."
    
    # OCI CLIでイメージ情報を取得
    local image_info=$(python3 -m oci compute image get --image-id "$IMAGE_ID" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local display_name=$(echo "$image_info" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data['data']['display-name'])" 2>/dev/null || echo "Unknown")
        local size_gb=$(echo "$image_info" | python3 -c "import json, sys; data=json.load(sys.stdin); print(round(data['data']['size-in-mbs']/1024, 1))" 2>/dev/null || echo "Unknown")
        local lifecycle_state=$(echo "$image_info" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data['data']['lifecycle-state'])" 2>/dev/null || echo "Unknown")
        
        echo "🖥️ 使用イメージ情報：
名前: $display_name
サイズ: ${size_gb}GB
状態: $lifecycle_state
Image ID: $IMAGE_ID"
    else
        echo "🖥️ イメージ情報取得失敗（認証エラーの可能性）"
    fi
}

# 関数: 朝の定期レポート送信
send_morning_report() {
    log_message "朝の定期レポート送信開始"
    
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local yesterday_summary=$(get_yesterday_log_summary)
    local image_info=$(get_current_image_info)
    
    local report_message="🌅 おはようございます！A1インスタンス監視レポート

⏰ 時刻: $current_time

$yesterday_summary

$image_info

設定:
- Shape: $SHAPE
- Domain: $AVAILABILITY_DOMAIN
- チェック間隔: $(get_config_value "a1_instance" "check_interval_minutes")分

今日も監視を継続します！"

    send_pushover_notification "$report_message" "🌅 A1監視 朝のレポート"
    log_message "朝の定期レポート送信完了"
}

# 関数: A1インスタンス作成を試行
try_launch_a1() {
    local instance_name="a1-instance-$(date +%Y%m%d-%H%M%S)"
    
    log_message "A1インスタンス作成を試行: $instance_name"
    
    # A1.Flexインスタンス作成コマンド（設定から取得）
    OCPUS=$(get_config_value "a1_instance" "shape_config" | python3 -c "import json, sys; config=json.load(sys.stdin); print(config['ocpus'])" 2>/dev/null || echo "4")
    MEMORY=$(get_config_value "a1_instance" "shape_config" | python3 -c "import json, sys; config=json.load(sys.stdin); print(config['memory_in_gbs'])" 2>/dev/null || echo "24")
    
    result=$(python3 -m oci compute instance launch \
        --availability-domain "$AVAILABILITY_DOMAIN" \
        --compartment-id "$COMPARTMENT_ID" \
        --shape "$SHAPE" \
        --shape-config "{\"ocpus\": $OCPUS, \"memory_in_gbs\": $MEMORY}" \
        --display-name "$instance_name" \
        --image-id "$IMAGE_ID" \
        --subnet-id "$SUBNET_ID" \
        --assign-public-ip true \
        --metadata "{\"ssh_authorized_keys\": \"$SSH_KEY\"}" \
        2>&1)
    
    if echo "$result" | grep -q '"lifecycle-state": "PROVISIONING"'; then
        instance_id=$(echo "$result" | grep '"id":' | head -1 | sed 's/.*"id": "\([^"]*\)".*/\1/')
        log_message "A1インスタンス作成成功! Instance ID: $instance_id"
        
        # Pushover通知を送信
        send_pushover_notification "🎉 A1インスタンス作成成功！
Instance ID: $instance_id
時刻: $(date)
Shape: $SHAPE ($OCPUS OCPU, ${MEMORY}GB RAM)"
        
        # 成功時は即座に削除（テストのため）
        log_message "テスト用インスタンスを削除中..."
        python3 -m oci compute instance terminate --instance-id "$instance_id" --force
        log_message "テスト用インスタンス削除完了"
        
        return 0
    else
        log_message "A1インスタンス作成失敗: $result"
        return 1
    fi
}

# 関数: 前回のチェック時刻を取得
get_last_check() {
    if [ -f "$LAST_CHECK_FILE" ]; then
        cat "$LAST_CHECK_FILE"
    else
        echo "0"
    fi
}

# 関数: 現在時刻を保存
save_current_time() {
    date +%s > "$LAST_CHECK_FILE"
}

# メイン処理
main() {
    # コマンドライン引数のチェック
    if [ "$1" = "--morning-report" ]; then
        send_morning_report
        exit 0
    fi
    
    log_message "A1インスタンス空き確認開始"
    
    # 前回のチェックから30分以内の場合はスキップ
    last_check=$(get_last_check)
    current_time=$(date +%s)
    time_diff=$((current_time - last_check))
    
    CHECK_INTERVAL_SECONDS=$(($(get_config_value "a1_instance" "check_interval_minutes") * 60))
    if [ $time_diff -lt $CHECK_INTERVAL_SECONDS ]; then
        log_message "前回のチェックから$(($CHECK_INTERVAL_SECONDS/60))分経過していません。スキップします。"
        exit 0
    fi
    
    # A1インスタンス作成を試行
    if try_launch_a1; then
        log_message "A1インスタンスが利用可能です！"
    else
        log_message "A1インスタンスは現在利用できません"
    fi
    
    # 現在時刻を保存
    save_current_time
    
    log_message "A1インスタンス空き確認完了"
}

# スクリプト実行
main "$@"