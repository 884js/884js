# README テンプレート - 構成ガイド

<!--
このファイルは README.md の構成指針です。
Claude Code はこの構成に従って、収集データからREADME.mdを動的に生成します。
プレースホルダーではなく、各セクションの「何を含めるべきか」を定義しています。
-->

## セクション構成

### 1. ヘッダー
- ユーザー名を大きく表示
- 短い自己紹介テキスト（GitHubプロフィールのbioから）
- ソーシャルリンクバッジ（GitHub, ポートフォリオサイト等）

### 2. About Me
- キャリアの成長ストーリーを簡潔に（2-3文）
  - career.yml から経歴の変遷を読み取り、成長を示す
  - 例: インフラ → フロントエンド → リードエンジニア
- 現在の専門領域と得意なこと

### 3. Skills & Technologies
- カテゴリごとに shields.io バッジで表示
- カテゴリ:
  - **Languages**: language_stats + org_language_stats からバイト数上位を抽出
  - **Frameworks & Libraries**: リポジトリの repositoryTopics から抽出
  - **Tools & Infrastructure**: CI/CD, クラウド, DB等

### 4. Stats
- GitHub での活動実績を数字で表示
- 総コミット数（personal_repos + org_repos の my_commits を合算）
- リポジトリ数（personal + org 合計）
- GitHub 活動年数（profile.created_at から算出）
- 個別リポジトリの一覧は載せない

### 5. フッター
- ポートフォリオサイトへのリンク
- 自動生成であることの注記と最終更新日
