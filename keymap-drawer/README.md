# keymap-drawer

キーマップを SVG で可視化するための設定です。

## 自動生成（GitHub Actions）

`config/*` または `keymap-drawer/config.yaml` をpushすると、GitHub Actions が自動的に SVG を生成してコミットします。  
通常はこちらを使用してください。

---

## ローカルでの実行（Mac）

ローカルで SVG を確認したい場合の手順です。  
コマンドはすべて **`zmk-config-LisM` フォルダ直下で実行**してください。

### インストール

#### pipx のインストール

```bash
brew install pipx
```

#### keymap-drawer のインストール

```bash
pipx install keymap-drawer
pipx ensurepath
source ~/.zshrc
```

### ファイル構成

```
keymap-drawer/
├── config.yaml   # keymap-drawer の設定（ラベル変換・描画設定）
└── lism.yaml     # parse済みのキーマップ（自動生成）

config/
├── lism.keymap   # ZMK キーマップファイル
└── lism.json     # キーボードの物理レイアウト定義
```

### コマンド

#### parse（.keymap → .yaml）

```bash
keymap -c keymap-drawer/config.yaml parse -z config/lism.keymap -o keymap-drawer/lism.yaml
```

#### draw（.yaml → .svg）

```bash
keymap -c keymap-drawer/config.yaml draw keymap-drawer/lism.yaml -j config/lism.json -o keymap-drawer/lism.svg
```

#### まとめて実行

```bash
keymap -c keymap-drawer/config.yaml parse -z config/lism.keymap -o keymap-drawer/lism.yaml && \
keymap -c keymap-drawer/config.yaml draw keymap-drawer/lism.yaml -j config/lism.json -o keymap-drawer/lism.svg
```
