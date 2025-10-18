local M = {}

--- ヘルパー関数: ファイルパス操作、テスト用に依存性を注入可能にする
--- @param dependencies table モック用依存性 (例: vim.fn.getcwdの代替)
--- @param nvim_api table Neovim APIヘルパーのインスタンス
--- @return table ファイルパス操作ヘルパー関数群
function M.create(dependencies, nvim_api)
	dependencies = dependencies or {}
	nvim_api = nvim_api or {} -- Neovim APIヘルパーを注入

	local vim_fn_getcwd = dependencies.vim_fn_getcwd or nvim_api.get_current_working_directory or vim.fn.getcwd
	local vim_fn_isdirectory = dependencies.vim_fn_isdirectory or vim.fn.isdirectory
	local vim_fn_mkdir = dependencies.vim_fn_mkdir or vim.fn.mkdir
	local vim_fn_filereadable = dependencies.vim_fn_filereadable or vim.fn.filereadable
	local vim_fs_joinpath = dependencies.vim_fs_joinpath or vim.fs.joinpath
	local show_notification = nvim_api.show_notification or vim.notify
	local get_error_level = nvim_api.get_error_level or function()
		return vim.log.levels.ERROR
	end

	--- 保存ディレクトリが有効かチェックし、必要なら作成する
	--- @param save_dir string 保存先ディレクトリパス
	--- @param translate_func function 翻訳関数
	--- @return boolean, string|nil 成功した場合は true, そうでない場合は false とエラーメッセージ
	local function ensure_save_directory(save_dir, translate_func)
		if vim_fn_isdirectory(save_dir) == 0 then
			local mkdir_ok, mkdir_err = pcall(vim_fn_mkdir, save_dir, "p")
			if not mkdir_ok then
				show_notification(
					string.format(
						translate_func("file_save_failed_message"),
						"ディレクトリの作成に失敗しました: "
							.. (mkdir_err or translate_func("unknown_error"))
					),
					get_error_level()
				)
				return false, mkdir_err
			end
		end
		return true
	end

	--- ユニークな保存パスを決定する
	--- @param base_filename string 基本となるファイル名 (拡張子なし)
	--- @param extension string 拡張子 (例: ".md")
	--- @param save_dir string 保存先ディレクトリパス
	--- @return string 最終的なユニークなファイルパス
	local function get_unique_save_path(base_filename, extension, save_dir)
		local save_path_candidate = vim_fs_joinpath(save_dir, base_filename .. extension)
		local counter = 0

		-- ファイル名が既に存在する場合、連番を付与してユニークなファイル名を見つける
		while vim_fn_filereadable(save_path_candidate) == 1 do
			counter = counter + 1
			save_path_candidate = vim_fs_joinpath(save_dir, base_filename .. "-" .. counter .. extension)
		end
		return save_path_candidate
	end

	return {
		ensure_save_directory = ensure_save_directory,
		get_unique_save_path = get_unique_save_path,
		get_current_working_directory = vim_fn_getcwd,
	}
end

return M
