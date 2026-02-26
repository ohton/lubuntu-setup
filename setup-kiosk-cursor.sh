#!/bin/bash

# Lubuntu Kiosk端末用カーソル非表示セットアップ
# 一定時間操作がない場合、カーソルを自動的に非表示にします

set -e

echo "=== Lubuntu Kiosk Cursor Setup ==="

# unclutterのインストール (カーソルを自動非表示にするツール)
echo "📦 Installing unclutter..."
sudo apt-get update
sudo apt-get install -y unclutter

# LXDEの自動起動設定ディレクトリを作成
AUTOSTART_DIR="$HOME/.config/lxsession/Lubuntu"
mkdir -p "$AUTOSTART_DIR"

# autostartファイルが存在しない場合は作成
if [ ! -f "$AUTOSTART_DIR/autostart" ]; then
    echo "📝 Creating autostart file..."
    cat > "$AUTOSTART_DIR/autostart" << 'EOF'
@lxpanel --profile Lubuntu
@pcmanfm -d --desktop --profile desktop
@xscreensaver -no-splash
EOF
else
    # 既存のautostart内容を確認
    if ! grep -q "unclutter" "$AUTOSTART_DIR/autostart"; then
        # autostart ファイルがあり、unclutterの設定がない場合は追加
        echo "unclutter既存のautostart ファイルに追加中..."
    fi
fi

# unclutterの設定を追加 (既に存在しない場合)
if ! grep -q "^@unclutter" "$AUTOSTART_DIR/autostart"; then
    echo "🖱️  Adding unclutter to autostart..."
    echo "" >> "$AUTOSTART_DIR/autostart"
    echo "# Kiosk cursor hiding - 5秒間のアイドル後カーソルを非表示にする" >> "$AUTOSTART_DIR/autostart"
    echo "@unclutter -idle 5 -root" >> "$AUTOSTART_DIR/autostart"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 設定内容:"
echo "   - unclutter がインストールされました"
echo "   - 5秒間の無操作後にカーソルが非表示になります"
echo "   - 設定ファイル: $AUTOSTART_DIR/autostart"
echo ""
echo "🔧 カスタマイズ方法:"
echo "   - カーソル非表示の発動時間を変更する場合:"
echo "     sed -i 's/idle 5/idle N/' $AUTOSTART_DIR/autostart"
echo "     (Nは秒数。例: idle 3 は3秒)"
echo ""
echo "   - カーソルの再表示:"
echo "     キーボードまたはマウスを操作するとカーソルが表示されます"
echo ""
echo "💡 その他のkiosk設定:"
echo "   - スクリーンセーバーを有効にする場合は xscreensaver-demo を実行"
echo "   - 自動ログインを有効にする場合は LightDM設定を修正してください"
