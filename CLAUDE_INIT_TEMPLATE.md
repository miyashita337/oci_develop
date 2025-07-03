# CLAUDE CODE INIT: Oracle Free Tier 開発プロジェクト

## 概要

Oracle Cloud Free Tier（VM.Standard.E2.1.Micro）上で、以下のPython CLIツールを開発中です：

---

### 1. ドル円通知アプリ

- 5分ごとに為替レート（USD/JPY）を取得
- レート変動（初期は±5%、後で調整可）を検知したら **Pushover** で通知
- `rate-exchange.py` に初期実装済（API: `https://api.exchangerate.host/` 使用）

---

### 2. A1インスタンス空き確認スクリプト

- OracleのAPIを用いて `A1.Flex` の空き状況を確認
- 空きが出た場合、自動作成を試みる（要：安全な設計）
- Push通知（成功/失敗）は **Pushover** に送る
- 初期設定では **通知のみ** 実行し、後に自動作成へ段階的移行予定

---

### 3. 将来のタスク候補

- 為替変動しきい値・頻度の変更をCLI引数や設定ファイルで制御可能に
- Alfred/Mac通知との統合（後回しでOK）
- Bitcoin自動売買ツール（構想段階）
- Windows側でのStableDiffusion用画像処理・LoRA支援（別スコープ、今は除外）

---

## Claudeへの依頼テンプレ

```plaintext
/plan ドル円通知アプリに設定ファイル（JSONまたは.env）でパラメータ管理を追加したい
/debug rate-exchange.py のPushover通知が動かないので確認して
/implement A1空き確認スクリプト（oracle config未取得）を開始して
/implement config取得方法とテストスクリプトも欲しい
/expand 通知だけでなくログ保存機能（CSV）を追加したい
```

---

## 実行環境

- **OS**: Oracle Cloud Free Tier上のLinux（詳細未確認）
- **Python**: 未確認（必要ならインストール手順も含める）
- **通知手段**: [Pushover](https://pushover.net/)
- **為替API**: https://api.exchangerate.host/latest?base=USD&symbols=JPY

## 今後の進行フロー（例）

1. `/debug` や `/plan` で `rate-exchange.py` を整備
2. `/implement` で `a1_check.py` を新規作成
3. `/debug` でOracle API認証・実行テスト
4. `/plan` でAlfred統合やWindows側案件の分離管理を相談
