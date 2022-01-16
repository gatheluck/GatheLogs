# GatheLogs

## ローカルでの開発

下記コマンドを実行後に `http://localhost:1313/` から確認可能.

```bash
$ cd gathelogs/environments/development/
$ sudo docker-compose up
```

## 備忘録

デフォルト機能以外で追加した点などを記載.

### コードブロックにタイトルを付与

Hugoの標準のハイライト設定ではコードブロックに対してタイトルを付与する機能が無いため, ショートコード `layouts/shortcodes/code-title.html` とCSS `static/css/code-title.css` を追加した. 下記のようにマークダウン中で使用可能.

```
{{< code-title lang="python" title="sample_python_code.py" >}}
# write your python code here.
{{< / code-title >}}
```

上記を使用するためには `config.toml` 中で下記の設定がなされている必要がある.

```
pygmentsUseClasses = false
pygmentsCodefences = true
```

**参考**
- [まくまくHugo/Goノート](https://maku77.github.io/hugo/shortcode/highlight.html)

### ヘッダー中の文字のスタイルを変更

標準ではヘッダーの文字はすべて大文字になっていたため, `static/css/header.css` によってスタイルを変更. Roboto Condensed フォントの URL は Google Fonts のページから取得.

**参考**
- [Google Fonts](https://fonts.google.com/)

### タグの文字のスタイルを変更

標準ではサイドバー及びフッター内のタグの文字のスタイルはすべて大文字になっていたため, `static/css/tag.css` によってスタイルを変更. 

### リンクのスタイルを変更

標準ではコンテンツや本文のリンクは強調色になっていたため, `static/css/link.css` によってスタイルを変更. 

### 本中のコードのスタイルを変更

標準では本文のコードは強調色になっていたため, `static/css/code.css` によってスタイルを変更. 