#!/bin/bash

# A1インスタンス空き確認スクリプト
# OCI CLI を使用してA1.Flexインスタンスの空きをチェック

# 設定
SHAPE="VM.Standard.A1.Flex"
COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaay43gxqikyfgdogwellqrysliln22qigj7r5ro4wxvpjg75gm4bzq"
AVAILABILITY_DOMAIN="iTAA:AP-TOKYO-1-AD-1"
IMAGE_ID="ocid1.image.oc1.ap-tokyo-1.aaaaaaaayy2dcg4vje7vg2xjbnwz7t6n3c3vr3rsx2w7ut4ldaoc2akb5mqq"
SUBNET_ID="ocid1.subnet.oc1.ap-tokyo-1.aaaaaaaat4kzefmfjteea2xioabacu23q3alllj2imvi6gytepzgngquljdq"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDC14+EvJ3qaEmyn3vmVPXvfpbq8BkpKpzZjCTPkwAf54fkmQywpArswR+E3v16UbtcKsIOC4bQeTJjMr0Zsm3v6Urrpiqoufr6aB601AA9wtKmBSkw7h+6Ap5rBMd+oW59QMFgRObdymzqNCza1FWl6B5+sBdoJbxD7sthNDM4M1P8PQ4spriyKvlBI18SiUmG6sQLNkgQX4YKqeNkHMF6r8CqQszHxbzdRPEPochb1/GDMiB1y6ypVqKRpza3G+ohxFLlwJnk+zBb+actU44zMAWTcR5EU6Gy7J/4T/n+dNo5p9M8zNeZKeW+GBPBOQEaS+thiCC6JU93rWt1weP8dOKSBru0YPChbv53sO6seNXBF2wJqPFv+YxQ6gJf4RjQlN9Jwylo+VEV19Qv/Al+qNNmarSjcGuEHfEXv5X+sdGlmLEqhxOfJ6ZYCTTQAEBWR9Lvs6eUNKM3iQ0UEZn7RH9ae3KdVbQwyb0Z9mEzGK0w0+3bBCwP6dDwZfCJAh+Q+aFa1CSINKd8flV63GFLS38EjcE6QK+WosbTRPuTMCM/7owQ34uGHOJlkNrxg7KYIcUf3tBLyyhHWb8NvSzlDuVN35LTMfiaesGnU0gTcVaaL87PPJBW5jW2WJpOWacGGBUin7ijhRQMk/6pNi1r0sfT+84OkzPoKUByTuGtgQ== proce55ingpurser@gmail.com"

# ログファイル
LOG_FILE="/home/opc/a1_availability_check.log"
LAST_CHECK_FILE="/home/opc/last_a1_check.txt"

# 関数: ログメッセージ
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 関数: A1インスタンス作成を試行
try_launch_a1() {
    local instance_name="a1-instance-$(date +%Y%m%d-%H%M%S)"
    
    log_message "A1インスタンス作成を試行: $instance_name"
    
    # A1.Flexインスタンス作成コマンド（4 OCPU, 24GB RAM）
    result=$(python3 -m oci compute instance launch \
        --availability-domain "$AVAILABILITY_DOMAIN" \
        --compartment-id "$COMPARTMENT_ID" \
        --shape "$SHAPE" \
        --shape-config '{"ocpus": 4, "memory_in_gbs": 24}' \
        --display-name "$instance_name" \
        --image-id "$IMAGE_ID" \
        --subnet-id "$SUBNET_ID" \
        --assign-public-ip true \
        --metadata "{\"ssh_authorized_keys\": \"$SSH_KEY\"}" \
        2>&1)
    
    if echo "$result" | grep -q '"lifecycle-state": "PROVISIONING"'; then
        instance_id=$(echo "$result" | grep '"id":' | head -1 | sed 's/.*"id": "\([^"]*\)".*/\1/')
        log_message "A1インスタンス作成成功! Instance ID: $instance_id"
        
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
    log_message "A1インスタンス空き確認開始"
    
    # 前回のチェックから30分以内の場合はスキップ
    last_check=$(get_last_check)
    current_time=$(date +%s)
    time_diff=$((current_time - last_check))
    
    if [ $time_diff -lt 1800 ]; then  # 1800秒 = 30分
        log_message "前回のチェックから30分経過していません。スキップします。"
        exit 0
    fi
    
    # A1インスタンス作成を試行
    if try_launch_a1; then
        log_message "A1インスタンスが利用可能です！"
        # 成功時の通知処理をここに追加可能
    else
        log_message "A1インスタンスは現在利用できません"
    fi
    
    # 現在時刻を保存
    save_current_time
    
    log_message "A1インスタンス空き確認完了"
}

# スクリプト実行
main "$@"