# Lubuntu Setup

Lubuntu環境をセットアップするためのスクリプト集です。

## 含まれるスクリプト

- `install-packages.sh` - packages.jsonに基づいてapt/snapパッケージをインストール
- `setup-git.sh` - Gitのグローバル設定を対話的に行う
- `setup-volta.sh` - Volta (Node.jsバージョンマネージャー) をインストール
- `setup-autofs.sh` - SMB共有をautofsでオンデマンド自動マウント
- `setup-chrome.sh` - chromeのダウンロードとインストール。GPU使用のメモ
- `setup-docker.sh` - dockerのインストール
- `setup-vnc.sh` - VNCサーバーのインストールとsystemd管理の設定
- `setup-kiosk-cursor.sh` - kiosk端末用カーソル非表示設定（アイドル時に自動非表示）

## 注意事項

- スクリプトは`sudo`権限を必要とします

## 使用方法

### 1. パッケージのインストール

`packages.json`に記述されたソフトウェアをインストールします。

```bash
./install-packages.sh
```

#### packages.jsonの編集

必要なパッケージを`packages.json`に追加・編集してください:

```json
{
  "apt": {
    "packages": [
      "jq",
      "fzf"
    ]
  },
  "snap": {
    "packages": [
      "your-snap-package"
    ]
  }
}
```

### 2. Gitのセットアップ

Git のを設定します。

```bash
./setup-git.sh
```

プロンプトに従って以下を入力してください:
- Gitユーザー名
- Gitメールアドレス
- デフォルトブランチ名(default: main)
- デフォルトエディタ(default: vim)

### 3. Google Chromeのセットアップ

Google Chrome Stable版をインストールします。

```bash
./setup-chrome.sh
```

このスクリプトは以下を実行します:
- Google Chrome Stable版の最新debパッケージをダウンロード
- dpkgを使用してインストール
- 不足している依存関係を自動的に解決

#### GPU加速の有効化

パフォーマンスを向上させるために、以下のフラグを有効化することをお勧めします:

1. Chrome を開き、アドレスバーに `chrome://flags` を入力
2. 以下のフラグを検索して「Enabled」に設定:
   - `#ignore-gpu-blocklist` - GPUブロックリストを無視
   - `#enable-gpu-rasterization` - GPUラスタライゼーションを有効化
   - `#enable-zero-copy` - ゼロコピーを有効化
3. Chrome を再起動

### 4. Dockerのセットアップ

Dockerをインストールします。

```bash
./setup-docker.sh
```

このスクリプトは以下を実行します:
- Docker公式のインストールスクリプトを使用してDockerをインストール
- Docker Engine、CLI、containerdなどの必要なコンポーネントをセットアップ

#### インストール後の設定

Dockerをsudo無しで実行できるようにする場合:

```bash
sudo usermod -aG docker $USER
```

**注意:** グループ変更を有効にするには、一度ログアウトして再ログインするか、システムを再起動してください。

#### 動作確認

```bash
# Dockerバージョンの確認
docker --version

# テストコンテナの実行
docker run hello-world
```

#### Docker Composeの使用

Docker Composeは最近のDockerに同梱されています:

```bash
docker compose version
```

### 5. Voltaのセットアップ

Volta (Node.jsバージョンマネージャー) をインストールします。

```bash
./setup-volta.sh
```

このスクリプトは以下を実行します:
- Voltaのインストール
- オプションでNode.js (最新LTSまたは指定バージョン) のインストール
- オプションでYarn (パッケージマネージャー) のインストール

**注意:** インストール後、変更を有効にするためにシェルを再起動するか、`source ~/.bashrc` を実行してください。

### 6. SMB共有の自動マウント (autofs)

WindowsやNAS上のSMB共有をautofsでオンデマンドにマウントします。mDNSが遅い場合はIPを使うこともできます。

```bash
sudo ./setup-autofs.sh
```

プロンプトに従って以下を入力します:
- ホスト名（例: `hostname.local`）またはIPの使用選択
- ユーザー名／パスワード
- 共有名の選択（例: `books`）
- マウント先のディレクトリ（例: `/Volumes/books`）

設定後の確認:

```bash
# マウントはディレクトリへアクセスしたときに自動で発生します
ls /Volumes/books
```

#### 生成されるファイル

- `/etc/auto.master.d/<MOUNT_PARENT>.autofs` - マスター設定（マウント親ディレクトリ単位、例: `/Volumes /etc/auto.cifs-volumes`）
- `/etc/auto.cifs-<MOUNT_PARENT>` - マップ設定（複数のマウント定義を管理）
- `/etc/creds/<HOST_ID>-<SHARE>` - 認証情報（権限600）

内部仕様:
- SMBバージョンは`vers=3.0`、文字コードは`iocharset=utf8`
- masterとmapはマウント親ディレクトリ単位で1つ管理され、複数の共有をマウントする場合はmapファイルに追記されます
- autofsのSUNマップではUNCに`://host/share`形式を使用します（`//host/share`だとデコードで1本スラッシュになるため）

#### トラブルシューティング

```bash
# autofsのデバッグ起動（一時）
sudo automount -f -v -d

# サービスログを確認
sudo journalctl -u autofs --no-pager -n 100

# カーネルメッセージの末尾
dmesg | tail -n 50
```

クリーンアップ（設定の削除）:

```bash
# 特定のマウント設定を削除する場合
# 例：/Volumes/books の CIFS マウントを削除
sudo sed -i "/^books /d" /etc/auto.cifs-volumes  # mapファイルからエントリを削除
sudo systemctl restart autofs

# 親ディレクトリ配下のすべてのマウント設定を削除する場合（例：/Volumes全体）
sudo rm /etc/auto.master.d/volumes.autofs \
  /etc/auto.cifs-volumes
sudo rm /etc/creds/hostname-books \
  /etc/creds/hostname-video
# 等（認証情報ファイルはすべて削除）
sudo systemctl restart autofs
```

### 7. VNCサーバーのセットアップ

VNCサーバーをインストールしてsystemdで管理できるようにします。

```bash
./setup-vnc.sh
```

#### VNCサーバーの選択

プロンプトに従って以下を選択・入力します:

1. **VNCサーバーの種類:**
   - `1` TigerVNC Standalone - 独立した仮想セッションを作成（物理ディスプレイと別）
   - `2` TigerVNC Scraping - 既存のディスプレイ（:0）を共有（**kiosk端末のメンテナンス推奨**）
     - 自動的にlingerが有効化され、ログアウト後も動作
   - `3` x11vnc - 既存のディスプレイ（:0）を共有
     - 自動的にlingerが有効化され、ログアウト後も動作

2. **ディスプレイ番号** (TigerVNC Standaloneのみ、デフォルト: 1)
   - `:1`はポート`5901`、`:2`はポート`5902`に対応

3. **画面解像度** (TigerVNC Standaloneのみ、デフォルト: 1920x1080)

4. **VNCパスワード**
   - 接続時に使用するパスワードを設定
   - TigerVNC Scrapingは既存パスワード（`~/.vnc/passwd`）を再利用可能

#### 接続方法

設定完了後、以下の方法でVNC接続できます:

**TigerVNC Standaloneの場合:**
```
<ホスト名またはIP>:1
または
<ホスト名またはIP>:5901
```

**TigerVNC Scraping / x11vncの場合:**
```
<ホスト名またはIP>:0
または
<ホスト名またはIP>:5900
```

#### サービス管理

**TigerVNC Standalone:**
```bash
# サービスの起動
systemctl --user start vncserver@1.service

# サービスの停止
systemctl --user stop vncserver@1.service

# サービスの再起動
systemctl --user restart vncserver@1.service

# サービスの状態確認
systemctl --user status vncserver@1.service
```

**TigerVNC Scraping:**
```bash
# サービスの起動
systemctl --user start x0vncserver.service

# サービスの停止
systemctl --user stop x0vncserver.service

# サービスの再起動
systemctl --user restart x0vncserver.service

# サービスの状態確認
systemctl --user status x0vncserver.service
```

**x11vnc:**
```bash
# サービスの起動
systemctl --user start x11vnc.service

# サービスの停止
systemctl --user stop x11vnc.service

# サービスの再起動
systemctl --user restart x11vnc.service

# サービスの状態確認
systemctl --user status x11vnc.service
```

#### ログイン時の自動起動

**TigerVNC Scraping / x11vnc:**
- セットアップ時に自動的にlingerが有効化されます
- **再起動後、ログインしなくてもVNCサービスが起動**します（kiosk端末に最適）

**TigerVNC Standalone:**
- デフォルトではユーザーログイン時のみ起動
- ログアウト後も起動したい場合は以下を実行:

```bash
sudo loginctl enable-linger $USER
```

lingerの状態確認:
```bash
loginctl show-user $USER | grep Linger
# Linger=yes なら有効、Linger=no なら無効
```

#### ファイアウォールの設定

VNC接続を許可するためにファイアウォールルールを追加:

**TigerVNC (ディスプレイ:1の場合):**
```bash
sudo ufw allow 5901/tcp
```

**TigerVNC Scraping / x11vnc:**
```bash
sudo ufw allow 5900/tcp
```

#### トラブルシューティング

**TigerVNC Standalone:**
```bash
# VNCサーバーのログを確認
cat ~/.vnc/*.log

# 手動でVNCサーバーを起動してテスト
vncserver :1 -geometry 1920x1080
vncserver -kill :1
```

**TigerVNC Scraping:**
```bash
# サービスログを確認
journalctl --user -u x0vncserver.service -n 50

# 手動でx0vncserverを起動してテスト
x0vncserver -display :0 -rfbport 5900 -PasswordFile ~/.vnc/passwd -localhost=0 -fg

# VNCポートが使用中か確認
ss -tlnp | grep 5900
```

**x11vnc:**
```bash
# サービスログを確認
journalctl --user -u x11vnc.service -n 50

# 手動でx11vncを起動してテスト
x11vnc -display :0 -auth guess -rfbauth ~/.x11vnc/passwd
```

### 8. Kiosk端末用カーソル非表示設定

kiosk端末として使用する場合、アイドル時にマウスカーソルを自動的に非表示にすることができます。

```bash
./setup-kiosk-cursor.sh
```

#### 動作

- **unclutter** がインストールされます
- 5秒間操作がない場合、マウスカーソルが自動的に非表示になります
- キーボードまたはマウスを操作するとカーソルが再度表示されます

#### カスタマイズ

カーソルが非表示になるまでの時間を変更したい場合:

```bash
# ~/.config/lxsession/Lubuntu/autostart を編集
sed -i 's/idle 5/idle N/' ~/.config/lxsession/Lubuntu/autostart
# N を希望の秒数に置き換えてください（例: idle 3 は3秒）
```

完全にカーソルを非表示にしたい場合（非表示にしない場合は以下を実行）:

```bash
sed -i 's/@unclutter.*//' ~/.config/lxsession/Lubuntu/autostart
```

#### 関連設定

- スクリーンセーバーを有効にしたい場合: `xscreensaver-demo` を実行
- 自動ログインを有効にする場合: LightDM設定（`/etc/lightdm/lightdm.conf`）を修正

