# Lubuntu Setup

Lubuntu環境をセットアップするためのスクリプト集です。

## 含まれるスクリプト

- `install-packages.sh` - packages.jsonに基づいてapt/snapパッケージをインストール
- `setup-git.sh` - Gitのグローバル設定を対話的に行う
- `setup-volta.sh` - Volta (Node.jsバージョンマネージャー) をインストール
- `setup-autofs.sh` - SMB共有をautofsでオンデマンド自動マウント

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

### 3. Voltaのセットアップ

Volta (Node.jsバージョンマネージャー) をインストールします。

```bash
./setup-volta.sh
```

このスクリプトは以下を実行します:
- Voltaのインストール
- オプションでNode.js (最新LTSまたは指定バージョン) のインストール
- オプションでYarn (パッケージマネージャー) のインストール

**注意:** インストール後、変更を有効にするためにシェルを再起動するか、`source ~/.bashrc` を実行してください。

### 4. SMB共有の自動マウント (autofs)

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

- `/etc/auto.master.d/<HOST_ID>-<SHARE>.autofs` - マスター設定（例: `/Volumes /etc/auto.cifs-<HOST_ID>-<SHARE>`）
- `/etc/auto.cifs-<HOST_ID>-<SHARE>` - マップ設定（`books`キーを`://host/share`でCIFSに割り当て）
- `/etc/creds/<HOST_ID>-<SHARE>` - 認証情報（権限600）

内部仕様:
- SMBバージョンは`vers=3.0`、文字コードは`iocharset=utf8`
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
sudo rm /etc/auto.master.d/<HOST_ID>-<SHARE>.autofs \
  /etc/auto.cifs-<HOST_ID>-<SHARE> \
  /etc/creds/<HOST_ID>-<SHARE>
sudo systemctl restart autofs
```

