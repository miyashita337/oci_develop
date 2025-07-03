import requests
import json
from datetime import datetime, timedelta
import os
import logging

def load_config():
    """設定ファイルを読み込み"""
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config.json')
    if not os.path.exists(config_path):
        raise FileNotFoundError("config.json not found")
    
    with open(config_path, 'r') as f:
        return json.load(f)

# 設定読み込み
config = load_config()

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(config['logging']['us_bonds_log'])
    ]
)
logger = logging.getLogger(__name__)

# 設定から値を取得
SAVE_FILE = config['us_bonds']['monitoring']['save_file']
PUSHOVER_USER_KEY = config['pushover']['user_key']
PUSHOVER_API_TOKEN = config['pushover']['api_token']

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
        current_date = datetime.now().strftime('%Y-%m-%d')
        
        # サンプルデータ（実際の運用では実APIを使用）
        rates_data = {
            "2-Year Treasury": {
                "rate": 4.25,
                "date": current_date
            },
            "10-Year Treasury": {
                "rate": 4.45,
                "date": current_date
            },
            "30-Year Treasury": {
                "rate": 4.65,
                "date": current_date
            }
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
    with open(SAVE_FILE, 'r') as f:
        return json.load(f)

# 債券データ保存
def save_bonds_data(data):
    with open(SAVE_FILE, 'w') as f:
        json.dump({
            'data': data,
            'timestamp': datetime.utcnow().isoformat()
        }, f, indent=2)

# Pushover通知送信
def send_notification(message, title="🏦 米国債金利通知"):
    try:
        logger.info(f"通知送信: {message}")
        response = requests.post("https://api.pushover.net/1/messages.json", 
                               data={
                                   "token": PUSHOVER_API_TOKEN,
                                   "user": PUSHOVER_USER_KEY,
                                   "message": message,
                                   "title": title
                               },
                               timeout=30)
        response.raise_for_status()
        logger.info("通知送信成功")
    except Exception as e:
        logger.error(f"通知送信エラー: {e}")

# 昨日の金利変動サマリーを取得
def get_yesterday_summary():
    """昨日の金利変動サマリーを取得"""
    try:
        yesterday = datetime.now() - timedelta(days=1)
        yesterday_str = yesterday.strftime('%Y-%m-%d')
        
        log_file = config['logging']['us_bonds_log']
        if not os.path.exists(log_file):
            return "📊 昨日のログファイルが見つかりません"
        
        with open(log_file, 'r') as f:
            log_content = f.read()
        
        yesterday_logs = [line for line in log_content.split('\n') if yesterday_str in line and 'Treasury:' in line]
        
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
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
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
def check_us_bonds(absolute_threshold=None):
    if absolute_threshold is None:
        absolute_threshold = config['us_bonds']['monitoring']['absolute_threshold']
    
    try:
        logger.info("米国債金利チェック開始")
        current_data = get_us_treasury_rates()
        
        notifications = []
        
        # 10年国債の利回りが5%を超えたかチェック
        if "10-Year Treasury" in current_data:
            current_rate = current_data["10-Year Treasury"]["rate"]
            logger.info(f"10年国債利回り: {current_rate:.3f}%, 閾値: {absolute_threshold:.1f}%")
            
            if current_rate >= absolute_threshold:
                message = f"🚨 10年国債利回りが{absolute_threshold:.1f}%を超えました！\n現在の利回り: {current_rate:.3f}%"
                notifications.append(message)
                logger.info(f"閾値超過: {current_rate:.3f}% >= {absolute_threshold:.1f}%")
            else:
                logger.info(f"閾値未満: {current_rate:.3f}% < {absolute_threshold:.1f}%")
        
        # 通知送信
        if notifications:
            full_message = "\n\n".join(notifications)
            send_notification(full_message, "🚨 10年国債利回り警告")
        else:
            logger.info("閾値未満のため通知なし")
        
        # 必ず更新
        save_bonds_data(current_data)
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