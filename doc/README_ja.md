# AutoFileName.nvim

[English](../README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md)

AutoFileName.nvimは、Neovimで新しいメモファイルを作成・保存する際に、自動的に日付や内容に基づいた適切なファイル名を付与するプラグインです。手動でファイル名を考える手間を省き、効率的なメモ管理をサポートします。

## 機能

*   **ファイル名自動生成**: ユーザーが設定可能なフォーマット文字列（例: `{{strftime:%Y%m%dT%H%M%S}}_{{first_line}}`）に基づき、ファイル名を自動生成します。
    *   `{{strftime:...}}`: 日時を様々なフォーマットで挿入します (例: `{{strftime:%Y%m%d}}` は `20230706` のようになります)。
    *   `{{first_line}}`: バッファの最初の空でない行の内容をファイル名に含めます。ファイル名として不適切な文字は自動的にサニタイズされます。
    *   `{{lua:...}}`: 任意のLuaコードを実行し、その戻り値をファイル名に含めます。結果は自動的にサニタイズされます。
*   **自動保存コマンド**: 自動生成されたファイル名で、現在のバッファの内容を保存するコマンド `:AutoSaveNote` を提供します。
*   **ファイル拡張子設定**: 保存するファイルの拡張子（例: `.md`, `.txt`）を設定可能です。
*   **ファイル名衝突解決**: 同じファイル名が存在する場合、自動的に連番（例: `filename-1.md`）を付与して衝突を回避します。
*   **ファイル名長制限**: OSのファイル名制限（通常255文字）に準拠するため、生成されるファイル名を自動的に切り詰めます。
*   **多言語対応 (i18n)**: 英語、日本語、中国語 (簡体字) に対応しています。

## インストール

[lazy.nvim](https://github.com/folke/lazy.nvim) を使用する場合の例:

```lua
-- init.lua または plugins.lua
{
  'anyumuenyumuboto/AutoFileName.nvim', -- 実際のGitHubリポジトリパスに置き換えてください
  config = function()
    require('autofilename').setup({
      -- ここにオプションを設定
      -- 例:
      -- extension = ".txt",
      -- filename_format = "{{strftime:%Y-%m-%d}}_{{first_line}}",
      -- lang = "ja", -- 'en', 'ja', 'zh-CN'
    })
  end
}
```

## 使い方

1.  新しいNeovimバッファを開きます。
2.  メモの内容を記述します。最初の空でない行が `{{first_line}}` プレースホルダーとして使用されます。
3.  コマンドモードで `:AutoSaveNote` を実行します。
4.  設定されたフォーマットと拡張子に基づき、ファイルが現在の作業ディレクトリに保存されます。

## 設定

`require('autofilename').setup({})` 関数にテーブルを渡すことで、プラグインの挙動をカスタマイズできます。

利用可能なオプション:

*   `lang` (string, デフォルト: `"en"`): プラグインのメッセージ表示言語を設定します。`"en"` (英語), `"ja"` (日本語), `"zh-CN"` (簡体字中国語) が利用可能です。設定されていない場合、システムの環境変数 `LANG` から自動検出を試みます。
*   `extension` (string, デフォルト: `".md"`): 保存するファイルのデフォルト拡張子を指定します。
*   `filename_format` (string, デフォルト: `{{strftime:%Y%m%dT%H%M%S}}_{{first_line}}`): ファイル名の生成フォーマットを指定します。以下のプレースホルダーが利用可能です:
    *   `{{strftime:format}}`: `os.date` 関数と同じstrftime形式のフォーマット文字列を受け取り、日時を挿入します。(例: `{{strftime:%Y-%m-%d_%H%M}}`)
    *   `{{first_line}}`: 現在のバッファの最初の空でない行の内容を挿入します。ファイル名として不適切な文字は自動的に安全なものに変換されます。
    *   `{{lua:code}}`: 指定されたLuaコードを実行し、その結果を挿入します。結果は自動的にファイル名として安全なものに変換されます。(例: `{{lua:vim.fn.hostname()}}` でホスト名を挿入)
*   `save_directory` (string, デフォルト: `nil`): メモを保存するデフォルトのディレクトリを指定します。`nil` の場合、現在の作業ディレクトリに保存されます。
*   `max_filename_length` (number, デフォルト: `255`): 生成されるファイル名の最大長（拡張子を含む）。OSの制限を超えることを防ぎます。

### 設定例

```lua
require('autofilename').setup({
  extension = ".txt", -- .txtファイルとして保存
  filename_format = "{{strftime:%Y%m%d-%H%M%S}}_{{lua:os.getenv('USER')}}_{{first_line}}",
  lang = "ja", -- 日本語メッセージを使用
  save_directory = "~/notes", -- ~/notes ディレクトリに保存
  max_filename_length = 150, -- ファイル名を150文字に制限
})
```

## 開発

### 開発環境のセットアップ

1.  リポジトリをクローンします:
    ```bash
    git clone https://github.com/your_github_username/AutoFileName.nvim.git
    cd AutoFileName.nvim
    ```
2.  `nvim_dev` タスクを実行して開発環境を起動します (Taskfileが必要です):
    ```bash
    task nvim_dev
    ```
    これにより、`dev_config/init.lua` を設定ファイルとしてNeovimがクリーンな状態で起動します。

## 貢献

バグ報告、機能リクエスト、プルリクエストを歓迎します。

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細については`LICENSE`ファイルを参照してください。
