-- 開発中のプラグインのルートディレクトリの絶対パスを指定します。      
local plugin_dev_path = vim.fn.fnamemodify(vim.fn.expand('<sfile>:p'), ':h:h')
-- runtimepathの先頭にプラグインのパスを追加します。                   
-- `prepend`を使うことで、他のプラグインより優先して読み込まれるようになります。
vim.opt.runtimepath:prepend(plugin_dev_path)                           
-- 開発中のプラグインのセットアップ関数を呼び出します
-- AutoFileName.nvim/lua/autofilename/init.lua が'autofilename' モジュールとしてロードされます               
require('autofilename').setup({
	extension = ".txt",
	filename_format = "untitled_{{strftime:%Y%m%dT%H%M%SZ}}",
	save_directory = "./tmp/note/"
})
