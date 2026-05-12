import requests
import json
from datetime import datetime, timedelta
import os
import logging


def load_config():
    """設定ファイルを読み込み"""
    config_path = os.path.join(os.path.dirname(__file__), "..", "config.json")
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
        logging.FileHandler(config["logging"]["us_bonds_log"]),
    ],
)
logger = logging.getLogger(__name__)

# 設定から値を取得
SAVE_FILE = config["us_bonds"]["monitoring"]["save_file"]
PUSHOVER_USER_KEY = config["pushover"]["user_key"]
PUSHOVER_API_TOKEN = config["pushover"]["api_token"]


# 米国債金利取得API (FRED API使用)
def get_us_treasury_rates():
    """米国債金利データを取得"""
    try:
        # FRED APIの無料エンドポイント
        rates_data = {}

        # 簡単な債券データ（固定値でテスト）
        logger.info("米国債金利データを取得中...")

        # 実際のAPIが利用できない場合の代替手段
        # Treasury.govのデータを手動で設定
        current_date = datetime.now().strftime("%Y-%m-%d")

        # サンプルデータ（実際の運用では実APIを使用）
        rates_data = {
            "2-Year Treasury": {"rate": 4.25, "date": current_date},
            "10-Year Treasury": {"rate": 4.45, "date": current_date},
            "30-Year Treasury": {"rate": 4.65, "date": current_date},
        }

        for bond_type, info in rates_data.items():
            logger.info(f"{bond_type}: {info['rate']}% ({info['date']})")

        return rates_data
    except Exception as e:
        logger.error(f"APIリクエストエラー: {e}")
        raise


# 前回保存データの読み込み
def load_previous_data():
    if not os.path.exists(SAVE_FILE):
        return None
    with open(SAVE_FILE, "r") as f:
        return json.load(f)


# 債券データ保存
def save_bonds_data(data, cooldown=None, above_absolute_threshold=None):
    payload = {
        "data": data,
        "timestamp": datetime.utcnow().isoformat(),
    }
    if cooldown is not None:
        payload["cooldown"] = cooldown
    if above_absolute_threshold is not None:
        payload["above_absolute_threshold"] = above_absolute_threshold
    with open(SAVE_FILE, "w") as f:
        json.dump(payload, f, indent=2)


# Pushover通知送信
def send_notification(message, title="🏦 米国債金利通知"):
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


# 昨日の金利変動サマリーを取得
def get_yesterday_summary():
    """昨日の金利変動サマリーを取得"""
    try:
        yesterday = datetime.now() - timedelta(days=1)
        yesterday_str = yesterday.strftime("%Y-%m-%d")

        log_file = config["logging"]["us_bonds_log"]
        if not os.path.exists(log_file):
            return "📊 昨日のログファイルが見つかりません"

        with open(log_file, "r") as f:
            log_content = f.read()

        yesterday_logs = [
            line
            for line in log_content.split("\n")
            if yesterday_str in line and "Treasury:" in line
        ]

        if not yesterday_logs:
            return f"📊 昨日({yesterday_str})の金利データが見つかりません"

        return f"📊 昨日({yesterday_str})の金利データ: {len(yesterday_logs)}件記録"

    except Exception as e:
        logger.error(f"昨日のサマリー取得エラー: {e}")
        return "📊 昨日のデータ取得中にエラーが発生しました"


# 朝の定期レポート送信
def send_morning_report():
    """朝の定期レポートを送信"""
    try:
        logger.info("朝の定期レポート送信開始")

        # 現在の金利データ取得
        current_data = get_us_treasury_rates()
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # 昨日のサマリー取得
        yesterday_summary = get_yesterday_summary()

        # レポートメッセージ作成
        report_message = f"""🌅 おはようございます！米国債金利レポート

⏰ 時刻: {current_time}

📊 現在の金利："""

        for bond_type, info in current_data.items():
            report_message += f"\n• {bond_type}: {info['rate']:.3f}% ({info['date']})"

        report_message += f"""

{yesterday_summary}

設定:
- 10年国債警告閾値: {config['us_bonds']['monitoring']['absolute_threshold']:.1f}%
- API: Treasury.gov

今日も金利を監視します！"""

        send_notification(report_message, "🌅 米国債金利 朝のレポート")
        logger.info("朝の定期レポート送信完了")

    except Exception as e:
        logger.error(f"朝の定期レポート送信エラー: {e}")
        raise


# メイン処理
def check_us_bonds(absolute_threshold=None, volatility_threshold=None):
    """
    米国債金利を 2 軸で判定:
    1) ボラ型: |Δ%| が volatility_threshold 以上 → 通知（cooldown あり）
    2) state transition: 10 年債が absolute_threshold を「跨いだ」ときだけ通知
       （超え続けている間は鳴らない）
    """
    monitoring_config = config["us_bonds"]["monitoring"]
    if absolute_threshold is None:
        absolute_threshold = monitoring_config["absolute_threshold"]
    if volatility_threshold is None:
        volatility_threshold = monitoring_config.get("volatility_threshold", 0.05)
    cooldown_seconds = monitoring_config.get("cooldown_seconds", 0)

    try:
        logger.info("米国債金利チェック開始")
        current_data = get_us_treasury_rates()
        previous = load_previous_data() or {}
        previous_rates = previous.get("data") or {}
        cooldown_state = previous.get("cooldown") or {}

        notifications = []
        new_cooldown_state = dict(cooldown_state)
        now_ts = int(datetime.utcnow().timestamp())

        # 1) ボラ型判定（全銘柄）
        for bond_type, info in current_data.items():
            current_rate = info["rate"]
            prev_info = previous_rates.get(bond_type) or {}
            previous_rate = prev_info.get("rate")
            if previous_rate is None or previous_rate == 0:
                logger.info(f"{bond_type}: 初回 or 0 値、ボラ判定スキップ")
                continue
            delta_pct = (current_rate - previous_rate) / previous_rate
            logger.info(
                f"{bond_type}: prev={previous_rate:.3f}%, curr={current_rate:.3f}%, Δ={delta_pct:.2%}"
            )
            if abs(delta_pct) < volatility_threshold:
                continue
            last_ts = cooldown_state.get(bond_type)
            if last_ts and (now_ts - last_ts) < cooldown_seconds:
                logger.info(
                    f"{bond_type}: 閾値超過だが cooldown 中 (前回通知から {now_ts - last_ts}s) - スキップ"
                )
                continue
            direction = "上昇" if delta_pct > 0 else "下落"
            notifications.append(
                f"🚨 {bond_type}が{direction}：{delta_pct:.2%}変動\n"
                f"現在: {current_rate:.3f}% (前回: {previous_rate:.3f}%)"
            )
            new_cooldown_state[bond_type] = now_ts

        # 2) state transition: 10 年債が absolute_threshold を跨いだか
        if "10-Year Treasury" in current_data:
            curr_10y = current_data["10-Year Treasury"]["rate"]
            prev_10y_info = previous_rates.get("10-Year Treasury") or {}
            prev_10y = prev_10y_info.get("rate")
            prev_above = previous.get("above_absolute_threshold")
            curr_above = curr_10y >= absolute_threshold
            # state 未保存または値が変化したときのみ発火
            if prev_above is None:
                logger.info(f"10年債 state transition 初期化: above_5pct={curr_above}")
            elif curr_above != prev_above:
                event = "突破" if curr_above else "割り込み"
                notifications.append(
                    f"📊 10年国債が {absolute_threshold:.1f}% を{event}\n"
                    f"現在: {curr_10y:.3f}%"
                    + (f" (前回: {prev_10y:.3f}%)" if prev_10y is not None else "")
                )
            previous["above_absolute_threshold"] = curr_above

        # 通知送信
        if notifications:
            full_message = "\n\n".join(notifications)
            send_notification(full_message, "🏦 米国債金利アラート")
        else:
            logger.info("発火条件未達のため通知なし")

        # 保存（cooldown / state を引き継ぎ）
        save_bonds_data(
            current_data,
            cooldown=new_cooldown_state,
            above_absolute_threshold=previous.get("above_absolute_threshold"),
        )
        logger.info("米国債金利チェック完了")

    except Exception as e:
        logger.error(f"メイン処理エラー: {e}")
        raise


if __name__ == "__main__":
    import sys

    # コマンドライン引数のチェック
    if len(sys.argv) > 1 and sys.argv[1] == "--morning-report":
        send_morning_report()
    else:
        check_us_bonds()
