import requests
import json
from datetime import datetime, timedelta
import os
import logging


def load_config():
    """設定ファイルを読み込み"""
    config_path = os.path.join(os.path.dirname(__file__), "config.json")
    if not os.path.exists(config_path):
        # フォールバック: 親ディレクトリも確認
        config_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)), "config.json"
        )

    if not os.path.exists(config_path):
        raise FileNotFoundError("config.json not found")

    with open(config_path, "r") as f:
        return json.load(f)


# 設定読み込み
config = load_config()

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(config["logging"]["rate_exchange_log"]),
    ],
)
logger = logging.getLogger(__name__)

# 設定から値を取得
SAVE_FILE = config["exchange_rate"]["save_file"]
PUSHOVER_USER_KEY = config["pushover"]["user_key"]
PUSHOVER_API_TOKEN = config["pushover"]["api_token"]


# 取得API（為替レート：USD/JPY）
def get_usdjpy():
    try:
        url = config["exchange_rate"]["api_url"]
        logger.info(f"APIリクエスト: {url}")
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        rate = data["rates"]["JPY"]
        logger.info(f"現在のUSD/JPYレート: {rate}")
        return rate
    except Exception as e:
        logger.error(f"APIリクエストエラー: {e}")
        raise


# 前回保存データの読み込み
def load_previous_rate():
    if not os.path.exists(SAVE_FILE):
        return None
    with open(SAVE_FILE, "r") as f:
        return json.load(f)


# レート記録保存
def save_rate(rate, last_notif_ts=None):
    payload = {"rate": rate, "timestamp": datetime.utcnow().isoformat()}
    if last_notif_ts is not None:
        payload["last_notif_ts"] = last_notif_ts
    with open(SAVE_FILE, "w") as f:
        json.dump(payload, f)


# Pushover通知送信
def send_notification(message, title="💱 USD/JPY為替レート通知"):
    try:
        logger.info(f"通知送信: {message}")
        response = requests.post(
            "https://api.pushover.net/1/messages.json",
            data={
                "token": PUSHOVER_API_TOKEN,
                "user": PUSHOVER_USER_KEY,
                "message": message,
                "title": title,
            },
            timeout=30,
        )
        response.raise_for_status()
        logger.info("通知送信成功")
    except Exception as e:
        logger.error(f"通知送信エラー: {e}")


# 昨日のレート変動サマリーを取得
def get_yesterday_rate_summary():
    """昨日の為替レート変動サマリーを取得"""
    try:
        yesterday = datetime.now() - timedelta(days=1)
        yesterday_str = yesterday.strftime("%Y-%m-%d")

        # ログファイルから昨日のデータを検索
        log_file = config["logging"]["rate_exchange_log"]
        if not os.path.exists(log_file):
            return "📊 昨日のログファイルが見つかりません"

        with open(log_file, "r") as f:
            log_content = f.read()

        # 昨日のレート情報を抽出
        yesterday_logs = [
            line
            for line in log_content.split("\n")
            if yesterday_str in line and "Current:" in line
        ]

        if not yesterday_logs:
            return f"📊 昨日({yesterday_str})のレートデータが見つかりません"

        # 最初と最後のレートを取得
        rates = []
        for log in yesterday_logs:
            try:
                # "Current: 146.3400" のような形式から数値を抽出
                if "Current:" in log:
                    rate_str = log.split("Current:")[1].split(",")[0].strip()
                    rates.append(float(rate_str))
            except:
                continue

        if len(rates) < 2:
            return f"📊 昨日({yesterday_str})のレートデータが不十分です"

        start_rate = rates[0]
        end_rate = rates[-1]
        min_rate = min(rates)
        max_rate = max(rates)
        change_percent = ((end_rate - start_rate) / start_rate) * 100

        return f"""📊 昨日({yesterday_str})のUSD/JPY変動：
開始: ${start_rate:.2f}
終了: ${end_rate:.2f}
最高: ${max_rate:.2f}
最安: ${min_rate:.2f}
変動: {change_percent:+.2f}%
データポイント: {len(rates)}件"""

    except Exception as e:
        logger.error(f"昨日のサマリー取得エラー: {e}")
        return "📊 昨日のデータ取得中にエラーが発生しました"


# 朝の定期レポート送信
def send_morning_report():
    """朝の定期レポートを送信"""
    try:
        logger.info("朝の定期レポート送信開始")

        # 現在のレート取得
        current_rate = get_usdjpy()
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # 昨日のサマリー取得
        yesterday_summary = get_yesterday_rate_summary()

        # 24時間変動を計算（前回データとの比較）
        data = load_previous_rate()
        change_24h = 0
        if data:
            previous_rate = data["rate"]
            change_24h = ((current_rate - previous_rate) / previous_rate) * 100

        report_message = f"""🌅 おはようございます！USD/JPY為替レポート

⏰ 時刻: {current_time}

💰 現在レート: ${current_rate:.2f}
📈 24h変動: {change_24h:+.2f}%

{yesterday_summary}

設定:
- 通知閾値: {config['exchange_rate']['threshold']*100:.1f}%
- API: ExchangeRate.com

今日も相場を監視します！"""

        send_notification(report_message, "🌅 USD/JPY 朝のレポート")
        logger.info("朝の定期レポート送信完了")

    except Exception as e:
        logger.error(f"朝の定期レポート送信エラー: {e}")
        raise


# メイン処理
def check_usdjpy(threshold=None):
    if threshold is None:
        threshold = config["exchange_rate"]["threshold"]
    cooldown_seconds = config["exchange_rate"].get("cooldown_seconds", 0)
    try:
        logger.info("為替レートチェック開始")
        current_rate = get_usdjpy()
        data = load_previous_rate()

        notified_ts = None
        carry_last_notif_ts = None

        if data:
            previous_rate = data["rate"]
            carry_last_notif_ts = data.get("last_notif_ts")
            rate_change = (current_rate - previous_rate) / previous_rate

            logger.info(
                f"Previous: {previous_rate:.4f}, Current: {current_rate:.4f}, Change: {rate_change:.2%}"
            )

            if abs(rate_change) >= threshold:
                now_ts = int(datetime.utcnow().timestamp())
                if (
                    carry_last_notif_ts
                    and (now_ts - carry_last_notif_ts) < cooldown_seconds
                ):
                    elapsed = now_ts - carry_last_notif_ts
                    logger.info(
                        f"閾値超過だが cooldown 中 (前回通知から {elapsed}s < {cooldown_seconds}s) - 通知スキップ"
                    )
                else:
                    direction = "上昇" if rate_change > 0 else "下落"
                    message = f"USD/JPYが{direction}：{rate_change:.2%}変動\n現在のレート: {current_rate:.2f}"
                    send_notification(message)
                    notified_ts = now_ts
            else:
                logger.info("閾値未満のため通知なし")
        else:
            logger.info("初回実行 - ベースラインを設定")

        # 必ず更新（cooldown 履歴は通知発火時のみ更新、それ以外は前回値を引き継ぐ）
        save_rate(current_rate, notified_ts or carry_last_notif_ts)
        logger.info("為替レートチェック完了")

    except Exception as e:
        logger.error(f"メイン処理エラー: {e}")
        raise


if __name__ == "__main__":
    import sys

    # コマンドライン引数のチェック
    if len(sys.argv) > 1 and sys.argv[1] == "--morning-report":
        send_morning_report()
    else:
        check_usdjpy()
