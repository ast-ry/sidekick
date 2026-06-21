# Sidekick

[English README](README.md)

`Sidekick` は、あなたが Mac で見ている画面に合わせて、短いアドバイスやリアクションを返すデスクトップアシスタントです。作業中にエラーが見えたら次の一手を提案し、動画やゲームを見ているときは一緒に見ている相手のようにコメントします。気になった返答は、そのままチャットで詳しく聞けます。

画面の理解には、LM Studio などで動かすローカル LLM を利用します。

## ダウンロード

最新版の DMG は [GitHub Releases](https://github.com/ast-ry/sidekick/releases/latest) からダウンロードできます。直接ダウンロードする場合はこちらです。

[Sidekick.dmg をダウンロード](https://github.com/ast-ry/sidekick/releases/latest/download/Sidekick.dmg)

DMG を開き、`Sidekick.app` を `Applications` にドラッグしてインストールしてください。現在は ad-hoc signing のため、初回起動時に macOS のセキュリティ警告が出る場合があります。

## デモ

![Sidekick demo animation](docs/assets/sidekick-demo.gif)

画面のすみで待機し、状況に合った短いひとことを返し、必要ならその話題をチャットで続けるまでのイメージです。

## 動作イメージ

```mermaid
flowchart LR
    screen["Mac で作業・視聴する"]
    capture["Sidekick が<br/>画面の状況を見る"]
    lmstudio["ローカル LLM が<br/>状況に合う返答を考える"]
    feedback["画面のすみに<br/>短いひとことを表示"]
    chat["気になったら<br/>そのままチャット"]

    screen --> capture --> lmstudio --> feedback
    feedback --> chat
    chat --> lmstudio
```

既定構成では、画面の情報は同じ Mac 上で動いている LM Studio に送られます。設定を変更して外部の API を使う場合は、画面情報がデバイス外へ送信される可能性があります。

## できること

たとえば、次のような使い方ができます。

- **作業で困ったとき:** コードのエラー、設定画面、操作中の詰まりなどを画面から読み取り、次に確認できそうなことを短く提案します。
- **動画やゲームを楽しむとき:** 一緒に見ている相手のようなリアクション、背景知識、小ネタを画面のすみに表示します。
- **集中しているとき:** 変化が小さい場面では静かに待機し、必要そうな場面だけ反応するよう調整できます。
- **もう少し聞きたいとき:** 表示されたひとことから、その画面や話題を引き継いでチャットできます。
- **あとで話題に戻りたいとき:** 直近5件のフィードバックをさかのぼり、選んだ話題から会話を再開できます。

使い方に合わせて、反応の方針を `Auto` / `Assist` / `Companion` / `Silent` から選べます。口調、コメント量、キャプチャ範囲、画像と OCR の使い分け、返答言語なども設定できます。

## 必要なもの

- macOS 14 以降
- Xcode の実行環境
- 実行ファイルに対する `画面収録` 権限
- LM Studio などの OpenAI 互換 chat completions API
  - 例: `http://127.0.0.1:1234/v1/chat/completions`
- 動作確認済みの LM Studio バージョン: `0.4.16+2 (0.4.16+2)`
- 動作確認済みのローカルモデル: LM Studio 経由の `Gemma4-26b-a4b`

## LM Studio のセットアップ例

確認済み構成では、LM Studio `0.4.16+2 (0.4.16+2)` で `Gemma4-26b-a4b` を読み込み、OpenAI 互換 API サーバーを localhost で起動します。

1. LM Studio を起動し、`Gemma4-26b-a4b` をダウンロードまたは選択します。
2. LM Studio のローカルサーバー画面でモデルを読み込みます。
3. OpenAI 互換 API サーバーを起動します。
4. サーバー URL が `http://127.0.0.1:1234/v1` であることを確認します。
5. 画像入力に対応したモデルとして応答できることを確認します。うまくいかない場合は、下の「LM Studio の切り分け」のスクリプトで `Responses` と `Chat Completions` のどちらが通るか確認してください。

Sidekick の既定 endpoint は `http://127.0.0.1:1234/v1/chat/completions` です。LM Studio 側でポートやホストを変えた場合は、Sidekick 側の `Base URL` も同じ値に変更してください。

## Sidekick 起動後の設定

アプリを起動したら、メニューバーの Sidekick から `設定を開く`、またはダッシュボードを開いて設定します。

1. `接続と言語` を開きます。
2. `Base URL` に LM Studio の endpoint を入力します。通常は `http://127.0.0.1:1234/v1/chat/completions` です。
3. `モデル` に LM Studio で読み込んだモデル名を入力します。確認済み構成では `Gemma4-26b-a4b` です。
4. `API形式` はまず `Chat` を選びます。LM Studio の切り分けで `Responses` だけが通る場合は `Responses` に変更します。
5. `UI言語` と `出力言語` を必要に応じて `日本語` または `English` にします。
6. `ふるまい` を開き、`解析モード` を `画像のみ` または `OCR+画像` にします。Gemma 系の VLM ではこのどちらかが向いています。
7. `キャプチャ範囲` は、まず `ディスプレイ全体` のままで試します。特定のアプリだけを見せたい場合は `前面ウィンドウ` に切り替えます。
8. `診断` を開き、`画面をキャプチャ` でプレビューが出るか確認します。
9. 続けて `Sidekickに聞く` を押し、LM Studio から返答が戻るか確認します。
10. 問題なければ `モニタリングを開始` を押します。

初回キャプチャ時に macOS の `画面収録` 権限が必要です。許可した後は Sidekick を再起動してから、もう一度 `画面をキャプチャ` または `Sidekickに聞く` を試してください。

## プライバシーとデータの扱い

Sidekick は画面内容を扱うアプリです。画面共有と同じくらい慎重に使ってください。

- キャプチャ画像と OCR テキストは、アプリに設定した API endpoint に送信されます。
- 既定 endpoint は LM Studio 用の localhost ですが、外部 endpoint に変えると画面内容がデバイス外へ送信される可能性があります。
- endpoint が localhost の場合でも、LM Studio や選択したモデル実行環境がツール、プラグイン、MCP サーバー、その他の連携を呼び出す設定になっていると、プロンプト、OCR テキスト、スクリーンショット、またはそこから派生した文脈の一部が外部サービスへ送信される可能性があります。
- 機密性の高い画面で Sidekick を使う前に、LM Studio 側のツール / MCP / プラグイン設定を確認し、信頼できる構成であることを確かめてください。
- キャプチャ画像は現在セッションと直近のアプリ内会話履歴のためにメモリ上で保持します。スクリーンショットのアーカイブとしてファイル保存はしません。
- 直近のフィードバックやチャット履歴はメモリ上のみで、アプリ終了時に消えます。
- 設定値と編集したプロンプトは `UserDefaults` に保存されます。
- ログは `~/Library/Logs/Sidekick/sidekick.log` と `/tmp/sidekick.log` に書き込まれます。
- 秘密情報、認証情報、個人的なメッセージ、顧客データなどが画面にある状態では、設定 endpoint を完全に信頼できる場合にだけ使ってください。

## 起動方法

```bash
swift run
```

最初のキャプチャ時に macOS から `画面収録` 権限の許可が求められます。許可後はアプリを再起動してから `Capture Screen`、`Ask Sidekick`、または `Start Monitoring` を実行してください。

## 簡易 .app / インストール用 DMG の作成

通知を使うには `swift run` ではなく `.app` バンドルとして起動する必要があります。簡易バンドルは次で作れます。

```bash
zsh Scripts/build_app.sh
open dist/Sidekick.app
```

`.app` 版で起動すると、通知まわりが有効になります。

ビルドスクリプトはリポジトリ内に `dist/Sidekick.app` を作り、ローカルで ad-hoc signing します。`/Applications` には自動インストールしません。必要なら手動で移動してください。

ドラッグ&ドロップでインストールできる DMG は次で作れます。

```bash
zsh Scripts/build_dmg.sh
open dist/Sidekick.dmg
```

DMG の中には `Sidekick.app` と `Applications` へのショートカットが入ります。一般的な macOS アプリと同じように、`Sidekick.app` を `Applications` へドラッグしてインストールできます。

## LM Studio の切り分け

画像入力で失敗する場合は、まず LM Studio 単体で API が通るか確認してください。

```bash
zsh Scripts/test_lmstudio_vision.sh <model-id> <image-path> [base-url]
```

例:

```bash
zsh Scripts/test_lmstudio_vision.sh google/gemma-3-4b-it ~/Desktop/capture.png http://127.0.0.1:1234/v1
```

このスクリプトは `GET /models`、`POST /v1/responses`、`POST /v1/chat/completions` を順に試します。どちらかだけ通る場合は、アプリ側の `API Format` をそれに合わせてください。

## 補足

- 起動するとまずオーバーレイが開き、`モニタリングを開始` で見守りを始められます。
- `モニタリングを開始` を押すと、指定間隔で定期キャプチャしてフィードバックします。
- オーバーレイでは、`チャットする` の右側にある矢印から直近5件のフィードバック履歴をたどれます。
- 履歴を見ている状態で `チャットする` を押すと、その時点の会話を再開します。
- 監視中のフィードバックは `通知` または `オーバーレイ` のどちらかに流せます。現在の主導線はオーバーレイです。
- ダッシュボードを閉じてもアプリは終了せず、メニューバーから再表示したりチャットを開いたりできます。
- オーバーレイ右上の `×` はオーバーレイを隠すのではなく、Sidekick 自体を終了します。
- 監視中は前回との差分を見て、変化が大きいときに具体的支援を増やし、変化が小さいときは短い伴走コメントや状況共有に寄せます。
- `Agent Mode` が `Auto` のときは、画面から `State` `Intent` `Response` を推定し、必要に応じて `assist` `companion` `celebrate` `silent` を切り替えます。
- `commentary` や `fun_fact` が選ばれると、一緒に画面を見ているような軽いコメントや短い背景知識・小ネタを返します。
- `Agent Mode` を `Assist` `Companion` `Silent` に固定すると、分類をスキップしてその反応方針を優先します。
- `Tone = 砕けた感じ` と `Companion Style = 小ネタあり` を使うと、友達っぽい軽いコメントや背景知識を出しやすくなります。
- 入力モードは `OCRのみ` `画像のみ` `OCR+画像` から選べます。Gemma 系の VLM を使う場合は `画像のみ` か `OCR+画像` が向いています。
- キャプチャ対象は `前面ウィンドウ` と `ディスプレイ全体` を切り替えられます。既定は `ディスプレイ全体` です。
- `API Format` は `Chat` と `Responses` を切り替えられます。LM Studio やモデルによって相性が違う場合の切り分けに使えます。
- 現在はメニューバー常駐も入っているので、ダッシュボードを閉じてもバックグラウンド監視を継続できます。
- 返答中にモデルが出した `---` のような Markdown 区切り線は、表示前に簡易的に除去しています。

## 開発

ローカルビルド:

```bash
swift build
```

GitHub Actions でも push と pull request に対して同じビルドを macOS 上で実行します。

## ライセンス

MIT。詳細は [LICENSE](LICENSE) を参照してください。
