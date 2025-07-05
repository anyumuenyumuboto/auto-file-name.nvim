-- lua/autofilename/init.lua

local M = {}

-- 自動保存コマンドを定義
function M.setup()
	vim.api.nvim_create_user_command(
		"AutoSaveNote", -- コマンド名
		function(opts)
			-- ここにファイル名自動生成と保存のロジックを記述します
			print("AutoSaveNoteコマンドが実行されました！")
			-- ファイル名を設定
			local filename = "untitled"
			local save_dir = vim.fn.getcwd()

			-- ファイルパスを結合
			local save_path = vim.fs.joinpath(save_dir, filename)

			-- 現在のバッファの内容を全行取得
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			-- ファイルへの書き込みを試みる
			local ok, result_or_err = pcall(vim.fn.writefile, lines, save_path)

			if ok and result_or_err == 0 then
				vim.api.nvim_buf_set_name(0, save_path)
				vim.api.nvim_buf_set_option(0, "modified", false)
				vim.notify("ファイルを " .. save_path .. "として保存しました", vim.log.levels.INFO)
			else
				vim.notify("ファイルの保存にしっぱいしました: " .. (result_or_err or "不明なエラー"), vim.log.levels.ERROR)
			end
		end,
		{
			desc = '現在のバッファを"untitled"という名前で保存',
			nargs = 0,
		}
	)
end

return M
