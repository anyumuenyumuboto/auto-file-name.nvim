-- lua/autofilename/init.lua

local M = {}

-- プラグイン設定
local _config = {
	lang = "en-US", -- デフォルト言語を英語に設定
	extension = ".md", -- デフォルトのファイル拡張子を.mdに設定
	filename_format = "{{first_line}}", -- ファイル名フォーマット (最初の行の内容のみ)
	max_filename_length = 255, -- 最大ファイル名長 (OSの制限に合わせる)
	save_directory = nil, -- デフォルトの保存ディレクトリ (nilの場合は現在の作業ディレクトリ)
	fs = nil, -- ファイルシステム操作のモック用
}

-- 翻訳メッセージを格納するテーブル
local _lang_messages = {}

-- AIサジェスト機能を提供するモジュールをロード
local ai_suggestions_module = require("autofilename.ai_suggestions")
local filename_sanitizer = require("autofilename.utils.filename_sanitizer") -- 新しいモジュールをインポート
local file_path_helpers = require("autofilename.utils.file_path_helpers") -- 新しいモジュールをインポート
-- AIサジェスト機能のインスタンスを保持する変数
local ai_suggester = nil

-- 翻訳関数
local function _(key, ...)
	local message = _lang_messages[key] or key -- キーが見つからない場合はキー自体を返す
	-- 可変引数を明示的にunpackしてstring.formatに渡す
	return string.format(message, unpack({ ... }))
end

-- ユーザーの環境言語を検出（例: "en", "ja", "zh-CN"など）
local function trim_system_lang(system_lang)
	if system_lang then
		-- 例: "ja_JP.UTF-8" から "ja_JP" を抽出し、"ja-JP" に変換
		local locale_with_underscore = system_lang:match("([^%.]+)") -- "en_US.UTF-8" -> "en_US"
		if locale_with_underscore then
			system_lang = string.gsub(locale_with_underscore, "_", "-") -- "en_US" -> "en-US"
		else
			system_lang = nil -- 環境変数が空、または不正な形式の場合はnil
		end
	end
	return system_lang
end


-- Neovim API操作のヘルパー関数を作成するファクトリ関数
local function _create_nvim_api_helpers(dependencies)
	dependencies = dependencies or {}

	return {
		get_buffer_content = dependencies.get_buffer_content or function()
			return vim.api.nvim_buf_get_lines(0, 0, -1, false)
		end,
		save_file_as = dependencies.save_file_as or function(path)
			vim.cmd("saveas " .. vim.fn.fnameescape(path))
		end,
		show_select_prompt = dependencies.show_select_prompt or function(items, options, on_choice)
			vim.ui.select(items, options, on_choice)
		end,
		show_notification = dependencies.show_notification or vim.notify,
		get_error_level = dependencies.get_error_level or function() return vim.log.levels.ERROR end,
		get_info_level = dependencies.get_info_level or function() return vim.log.levels.INFO end,
		get_warn_level = dependencies.get_warn_level or function() return vim.log.levels.WARN end,
		get_current_working_directory = dependencies.get_current_working_directory or vim.fn.getcwd,
		schedule_wrap = dependencies.schedule_wrap or vim.schedule,
	}
end

-- ファイルパス操作ヘルパーのインスタンスを保持する変数
local fs_helpers = nil
-- Neovim API操作ヘルパーのインスタンスを保持する変数
local nvim_api_helpers = nil

-- 自動保存コマンドを定義
function M.setup(user_config)
	-- ユーザー設定をマージ
	_config = vim.tbl_deep_extend("force", _config, user_config or {})

	-- Neovim APIヘルパーを初期化
	nvim_api_helpers = _create_nvim_api_helpers(_config.nvim_api)

	-- 設定からファイルシステムヘルパーを初期化。Neovim APIヘルパーを注入
	fs_helpers = file_path_helpers.create(_config.fs, nvim_api_helpers)

	-- ユーザーの環境言語を検出（例: "en", "ja", "zh-CN"など）
	local system_lang = trim_system_lang(vim.env.LANG)

	-- 設定で言語が指定されていない場合、または無効な言語が指定されている場合、システム言語を使用
	if
		not _config.lang
		-- or not _lang_messages[_config.lang]
	then
		_config.lang = system_lang
		-- or "en-US" -- システム言語も不明な場合はデフォルトの英語
	end

	-- 言語ファイルを読み込む
	local lang_file_path = "autofilename.i18n." .. _config.lang
	local ok, messages = pcall(require, lang_file_path)
	if ok and type(messages) == "table" then
		_lang_messages = messages
	else
		-- 翻訳ファイルの読み込みに失敗した場合、デフォルトの英語を試みる
		if _config.lang ~= "en" then
			nvim_api_helpers.show_notification(
				string.format(
					"翻訳ファイル '%s' の読み込みに失敗しました。英語を試します。",
					lang_file_path
				),
				nvim_api_helpers.get_warn_level()
			)
			lang_file_path = "autofilename.i18n.en"
			ok, messages = pcall(require, lang_file_path)
			if ok and type(messages) == "table" then
				_lang_messages = messages
			else
				nvim_api_helpers.show_notification(
					string.format(
						"デフォルトの英語翻訳ファイル '%s' の読み込みにも失敗しました。",
						lang_file_path
					),
					nvim_api_helpers.get_error_level()
				)
				_lang_messages = {} -- 最終的に空のテーブル
			end
		else
			nvim_api_helpers.show_notification(
				string.format(
					"デフォルトの英語翻訳ファイル '%s' の読み込みに失敗しました。",
					lang_file_path
				),
				nvim_api_helpers.get_error_level()
			)
			_lang_messages = {} -- 最終的に空のテーブル
		end
	end

	-- AIサジェスト機能を初期化
	ai_suggester = ai_suggestions_module.setup(_config, _, nvim_api_helpers)

	vim.api.nvim_create_user_command(
		"AutoSaveNote", -- コマンド名
		function(opts)
			-- 現在のバッファの内容を全行取得
			local lines = nvim_api_helpers.get_buffer_content()
			local title = ""
			-- 最初の空でない行をタイトルとして取得
			for _, line in ipairs(lines) do
				-- 行をトリムし、空でないかチェック
				local trimmed_line = line:match("^%s*(.-)%s*$")
				if trimmed_line ~= "" then
					title = trimmed_line
					break
				end
			end
			title = filename_sanitizer.sanitize_filename_part(title)

			-- ファイル名フォーマットを処理
			local filename_format_str = _config.filename_format
			-- {{first_line}} プレースホルダーを置換
			filename_format_str = string.gsub(filename_format_str, "{{%s*first_line%s*}}", title)

			-- 最終的なファイル名ベースは、全てのプレースホルダーが置換された文字列となる
			local filename_base = filename_format_str

			-- ファイル名の長さを制限 (拡張子と最悪の連番(-XXXXX)の長さを考慮)
			local max_base_len = _config.max_filename_length - #_config.extension - 5
			if #filename_base > max_base_len then
				filename_base = string.sub(filename_base, 1, max_base_len)
			end

			local file_extension = _config.extension
			local save_dir = _config.save_directory or nvim_api_helpers.get_current_working_directory()

			-- 保存ディレクトリの存在を確認し、必要なら作成
			local dir_ok, dir_err = fs_helpers.ensure_save_directory(save_dir, _)
			if not dir_ok then
				-- エラー通知は ensure_save_directory 内で行われる
				return -- ディレクトリ作成失敗時は処理を中断
			end

			local final_save_path = fs_helpers.get_unique_save_path(filename_base, file_extension, save_dir)

			nvim_api_helpers.save_file_as(final_save_path)
		end,
		{
			desc = _("autosavenote_command_desc"),
			nargs = 0,
		}
	)

	-- 新しいコマンド: AIによるファイル名提案と保存
	vim.api.nvim_create_user_command(
		"AutoSuggestNote", -- コマンド名
		function(opts)
			local lines = nvim_api_helpers.get_buffer_content()

			-- AIサジェスト関数を呼び出し、結果を待機
			ai_suggester.get_ai_suggestions(lines, function(suggestions)
				nvim_api_helpers.schedule_wrap(function() -- UI操作はメインスレッドで実行する必要がある
					if #suggestions > 0 then
						-- vim.ui.select を使用してユーザーに選択させる
						nvim_api_helpers.show_select_prompt(suggestions, {
							prompt = _("ai_select_prompt"),
							format_item = function(item)
								-- 提案の形式に応じて表示を調整 (例: { name = "ファイル名", score = 0.9 } )
								-- fileNameCandidateフィールドを優先し、なければnameフィールドを使用
								local display_name = item.fileNameCandidate or item.name or ""
								return display_name
									.. (item.score and string.format(" (スコア: %.2f)", item.score) or "")
							end,
						}, function(selected_suggestion)
							if selected_suggestion then
								-- ユーザーが選択したファイル名を使用して保存処理を続行
								-- fileNameCandidateフィールドを優先し、なければnameフィールドを使用
								local filename_base = filename_sanitizer.sanitize_filename_part(
									selected_suggestion.fileNameCandidate or selected_suggestion.name
								)
								-- ファイル名の長さを制限 (拡張子と最悪の連番(-XXXXX)の長さを考慮)
								local max_base_len = _config.max_filename_length - #_config.extension - 5
								if #filename_base > max_base_len then
									filename_base = string.sub(filename_base, 1, max_base_len)
								end

								local file_extension = _config.extension
								local save_dir = _config.save_directory or nvim_api_helpers.get_current_working_directory()

								-- 保存ディレクトリの存在を確認し、必要なら作成
								local dir_ok, dir_err = fs_helpers.ensure_save_directory(save_dir, _)
								if not dir_ok then
									-- エラー通知は ensure_save_directory 内で行われる
									return -- ディレクトリ作成失敗時は処理を中断
								end

								-- 最終的な保存パスを決定
								local final_save_path =
									fs_helpers.get_unique_save_path(filename_base, file_extension, save_dir)

								nvim_api_helpers.save_file_as(final_save_path)
							else
								nvim_api_helpers.show_notification(_("ai_selection_canceled"), nvim_api_helpers.get_info_level())
							end
						end)
					else
						nvim_api_helpers.show_notification(_("ai_no_suggestions"), nvim_api_helpers.get_info_level())
					end
				end)
			end)
		end,
		{
			desc = _("autosuggestnote_command_desc"),
			nargs = 0,
		}
	)
end

-- テストのために内部関数と変数を公開 (本番コードでは通常行わない)
M._config_for_test_only = _config
M._lang_messages_for_test_only = _lang_messages
M._create_file_path_helpers = file_path_helpers.create
M._create_nvim_api_helpers = _create_nvim_api_helpers
M.trim_system_lang_for_test_only = trim_system_lang -- テスト用に公開

return M
