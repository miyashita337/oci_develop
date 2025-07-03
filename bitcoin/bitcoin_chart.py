#!/usr/bin/env python3
"""
Bitcoin チャート表示ツール
取得したBitcoin価格データをチャートで可視化
"""

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.patches import Rectangle
import pandas as pd
import numpy as np
import json
import os
from datetime import datetime
import logging
from bitcoin_tracker import load_config, BitcoinTracker

# 設定読み込み
config = load_config()

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class BitcoinChart:
    def __init__(self):
        self.config = config['bitcoin']['chart']
        self.trading_config = config['bitcoin']['trading']
        
        # フィギュアサイズ設定
        plt.rcParams['figure.figsize'] = (self.config['width'], self.config['height'])
        
        # スタイル設定
        if self.config['style'] in plt.style.available:
            plt.style.use(self.config['style'])
        else:
            plt.style.use('default')
    
    def load_historical_data(self):
        """履歴データを読み込み"""
        try:
            filepath = '/tmp/bitcoin_historical_data.json'
            if not os.path.exists(filepath):
                logger.warning("履歴データファイルが見つかりません。データを取得中...")
                tracker = BitcoinTracker()
                data = tracker.get_historical_data()
                tracker.save_data(data, 'bitcoin_historical_data.json')
            else:
                with open(filepath, 'r') as f:
                    data = json.load(f)
            
            # DataFrameに変換
            df = pd.DataFrame(data)
            df['datetime'] = pd.to_datetime(df['timestamp'], unit='ms')
            df.set_index('datetime', inplace=True)
            
            logger.info(f"履歴データ読み込み完了: {len(df)}件")
            return df
            
        except Exception as e:
            logger.error(f"履歴データ読み込みエラー: {e}")
            raise
    
    def calculate_moving_averages(self, df, periods=[7, 25, 50]):
        """移動平均線を計算"""
        for period in periods:
            if len(df) >= period:
                df[f'MA{period}'] = df['price'].rolling(window=period).mean()
        return df
    
    def create_price_chart(self, df, save_path=None):
        """価格チャートを作成"""
        try:
            fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(self.config['width'], self.config['height']), 
                                         gridspec_kw={'height_ratios': [3, 1]})
            
            # 価格チャート
            ax1.plot(df.index, df['price'], label='Bitcoin価格', linewidth=2, color='#f7931a')
            
            # 移動平均線
            df = self.calculate_moving_averages(df)
            if 'MA7' in df.columns:
                ax1.plot(df.index, df['MA7'], label='7日移動平均', alpha=0.7, color='blue')
            if 'MA25' in df.columns:
                ax1.plot(df.index, df['MA25'], label='25日移動平均', alpha=0.7, color='red')
            
            ax1.set_title(f'Bitcoin (BTC/{self.trading_config["vs_currency"].upper()}) 価格チャート', 
                         fontsize=16, fontweight='bold')
            ax1.set_ylabel('価格 (USD)', fontsize=12)
            ax1.legend()
            ax1.grid(True, alpha=0.3)
            
            # 価格フォーマット
            ax1.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))
            
            # ボリュームチャート（表示設定が有効な場合）
            if self.config.get('show_volume', False):
                ax2.bar(df.index, df['volume'], alpha=0.6, color='gray', label='取引量')
                ax2.set_ylabel('取引量', fontsize=12)
                ax2.legend()
                ax2.grid(True, alpha=0.3)
                
                # ボリュームフォーマット
                ax2.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'{x/1e9:.1f}B'))
            
            # X軸の日付フォーマット
            days = len(df)
            if days <= 7:
                ax1.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d %H:%M'))
                ax1.xaxis.set_major_locator(mdates.HourLocator(interval=6))
            elif days <= 30:
                ax1.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))
                ax1.xaxis.set_major_locator(mdates.DayLocator(interval=2))
            else:
                ax1.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))
                ax1.xaxis.set_major_locator(mdates.WeekdayLocator())
            
            if self.config.get('show_volume', False):
                ax2.xaxis.set_major_formatter(ax1.xaxis.get_major_formatter())
                ax2.xaxis.set_major_locator(ax1.xaxis.get_major_locator())
            
            plt.xticks(rotation=45)
            plt.tight_layout()
            
            # 現在の価格を表示
            current_price = df['price'].iloc[-1]
            ax1.axhline(y=current_price, color='red', linestyle='--', alpha=0.7)
            ax1.text(0.02, 0.98, f'現在価格: ${current_price:,.2f}', 
                    transform=ax1.transAxes, fontsize=12, fontweight='bold',
                    bbox=dict(boxstyle='round', facecolor='white', alpha=0.8),
                    verticalalignment='top')
            
            # 統計情報を表示
            price_change = ((df['price'].iloc[-1] - df['price'].iloc[0]) / df['price'].iloc[0]) * 100
            max_price = df['price'].max()
            min_price = df['price'].min()
            
            stats_text = f'期間変動: {price_change:+.2f}%\n最高値: ${max_price:,.2f}\n最安値: ${min_price:,.2f}'
            ax1.text(0.98, 0.98, stats_text, 
                    transform=ax1.transAxes, fontsize=10,
                    bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.8),
                    verticalalignment='top', horizontalalignment='right')
            
            # 保存
            if save_path is None:
                save_path = self.config['save_path']
            
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            logger.info(f"チャート保存完了: {save_path}")
            
            return fig, (ax1, ax2) if self.config.get('show_volume', False) else (ax1,)
            
        except Exception as e:
            logger.error(f"チャート作成エラー: {e}")
            raise
    
    def create_candlestick_chart(self, df, save_path=None):
        """ローソク足チャートを作成（簡易版）"""
        try:
            # 1時間足のデータを作成（簡易的にOHLCを生成）
            hourly_df = df.resample('1H').agg({
                'price': ['first', 'max', 'min', 'last'],
                'volume': 'sum'
            }).dropna()
            
            hourly_df.columns = ['open', 'high', 'low', 'close', 'volume']
            
            fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(self.config['width'], self.config['height']),
                                         gridspec_kw={'height_ratios': [3, 1]})
            
            # ローソク足を描画
            for idx, (timestamp, row) in enumerate(hourly_df.iterrows()):
                color = '#00ff00' if row['close'] >= row['open'] else '#ff0000'  # 緑=上昇、赤=下降
                
                # ローソク足の実体
                height = abs(row['close'] - row['open'])
                bottom = min(row['open'], row['close'])
                
                ax1.add_patch(Rectangle((idx - 0.3, bottom), 0.6, height, 
                                      facecolor=color, alpha=0.8))
                
                # ひげ
                ax1.plot([idx, idx], [row['low'], row['high']], color='black', linewidth=1)
            
            ax1.set_title(f'Bitcoin ローソク足チャート (1時間足)', fontsize=16, fontweight='bold')
            ax1.set_ylabel('価格 (USD)', fontsize=12)
            ax1.grid(True, alpha=0.3)
            
            # X軸のラベル設定
            tick_positions = range(0, len(hourly_df), max(1, len(hourly_df) // 10))
            ax1.set_xticks(tick_positions)
            ax1.set_xticklabels([hourly_df.index[i].strftime('%m/%d %H:%M') 
                               for i in tick_positions], rotation=45)
            
            # ボリュームチャート
            if self.config.get('show_volume', False):
                ax2.bar(range(len(hourly_df)), hourly_df['volume'], alpha=0.6, color='gray')
                ax2.set_ylabel('取引量', fontsize=12)
                ax2.set_xticks(tick_positions)
                ax2.set_xticklabels([hourly_df.index[i].strftime('%m/%d %H:%M') 
                                   for i in tick_positions], rotation=45)
                ax2.grid(True, alpha=0.3)
            
            plt.tight_layout()
            
            # 保存
            if save_path is None:
                save_path = self.config['save_path'].replace('.png', '_candlestick.png')
            
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            logger.info(f"ローソク足チャート保存完了: {save_path}")
            
            return fig, (ax1, ax2) if self.config.get('show_volume', False) else (ax1,)
            
        except Exception as e:
            logger.error(f"ローソク足チャート作成エラー: {e}")
            raise
    
    def show_chart(self):
        """チャートを表示"""
        plt.show()
    
    def generate_summary(self, df):
        """価格サマリーを生成"""
        try:
            current_price = df['price'].iloc[-1]
            previous_price = df['price'].iloc[0]
            price_change = ((current_price - previous_price) / previous_price) * 100
            
            max_price = df['price'].max()
            min_price = df['price'].min()
            avg_price = df['price'].mean()
            
            summary = {
                'current_price': current_price,
                'price_change_percent': price_change,
                'max_price': max_price,
                'min_price': min_price,
                'average_price': avg_price,
                'total_volume': df['volume'].sum(),
                'data_points': len(df),
                'period_start': df.index[0].isoformat(),
                'period_end': df.index[-1].isoformat()
            }
            
            logger.info(f"価格サマリー生成完了")
            return summary
            
        except Exception as e:
            logger.error(f"サマリー生成エラー: {e}")
            raise

def main():
    """メイン処理"""
    try:
        logger.info("Bitcoinチャート作成開始")
        
        chart = BitcoinChart()
        df = chart.load_historical_data()
        
        # チャートタイプに応じて作成
        chart_type = chart.config.get('chart_type', 'line')
        
        if chart_type == 'candlestick':
            fig, axes = chart.create_candlestick_chart(df)
        else:
            fig, axes = chart.create_price_chart(df)
        
        # サマリー生成
        summary = chart.generate_summary(df)
        
        logger.info("チャート作成完了")
        logger.info(f"現在価格: ${summary['current_price']:,.2f}")
        logger.info(f"期間変動: {summary['price_change_percent']:+.2f}%")
        
        # チャート表示（オプション）
        # chart.show_chart()
        
        return summary
        
    except Exception as e:
        logger.error(f"メイン処理エラー: {e}")
        raise

if __name__ == "__main__":
    main()