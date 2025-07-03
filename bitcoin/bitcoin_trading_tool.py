#!/usr/bin/env python3
"""
Bitcoin自動売買ツール（メイン実行ファイル）
データ取得とチャート生成を統合実行
"""

import sys
import argparse
import logging
from bitcoin_tracker import BitcoinTracker, main as tracker_main
from bitcoin_chart import BitcoinChart, main as chart_main

def main():
    parser = argparse.ArgumentParser(description='Bitcoin自動売買ツール')
    parser.add_argument('--action', choices=['track', 'chart', 'both'], default='both',
                       help='実行するアクション (track: 価格取得, chart: チャート生成, both: 両方)')
    parser.add_argument('--days', type=int, default=7,
                       help='履歴データの日数 (デフォルト: 7日)')
    parser.add_argument('--chart-type', choices=['line', 'candlestick'], default='candlestick',
                       help='チャートタイプ (line: ライン, candlestick: ローソク足)')
    
    args = parser.parse_args()
    
    try:
        if args.action in ['track', 'both']:
            print("📊 Bitcoin価格データを取得中...")
            current_data, historical_data = tracker_main()
            print(f"✅ 現在価格: ${current_data['price']:,.2f}")
            print(f"✅ 24h変動: {current_data['change_24h']:+.2f}%")
        
        if args.action in ['chart', 'both']:
            print("📈 チャートを生成中...")
            summary = chart_main()
            print(f"✅ チャート生成完了")
            print(f"   期間変動: {summary['price_change_percent']:+.2f}%")
            print(f"   最高値: ${summary['max_price']:,.2f}")
            print(f"   最安値: ${summary['min_price']:,.2f}")
        
        print("\n🎉 処理完了！")
        
    except Exception as e:
        print(f"❌ エラーが発生しました: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()