-- 開発中のプラグインのルートディレクトリの絶対パスを指定します。
local plugin_dev_path = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
-- runtimepathの先頭にプラグインのパスを追加します。
-- `prepend`を使うことで、他のプラグインより優先して読み込まれるようになります。
vim.opt.runtimepath:prepend(plugin_dev_path)
-- 開発中のプラグインのセットアップ関数を呼び出します
-- AutoFileName.nvim/lua/autofilename/init.lua が'autofilename' モジュールとしてロードされます
require("autofilename").setup({
	-- example
	-- extension = ".txt",
	-- filename_format = "{{first_line}}_" .. os.date("%Y%m%dT%H%M%S"), -- ファイル名フォーマット (最初の行の内容とISO 8601形式のタイムスタンプ)
	-- save_directory = "./tmp/note/",
	ai_server_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
	ai_api_key = vim.env.API_KEY,
})
