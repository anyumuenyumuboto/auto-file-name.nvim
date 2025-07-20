-- lua/autofilename/init.lua

local M = {}

-- プラグイン設定
local _config = {
	lang = "en", -- デフォルト言語を英語に設定
	extension = ".md", -- デフォルトのファイル拡張子を.mdに設定
	filename_format = "{{first_line}}_" .. os.date("%Y%m%dT%H%M%S"), -- ファイル名フォーマット (最初の行の内容とISO 8601形式のタイムスタンプ)
	max_filename_length = 255, -- 最大ファイル名長 (OSの制限に合わせる)
	save_directory = nil, -- デフォルトの保存ディレクトリ (nilの場合は現在の作業ディレクトリ)
}

-- 翻訳メッセージを格納するテーブル
local _lang_messages = {}

-- AIサジェスト機能を提供するモジュールをロード
local ai_suggestions_module = require("autofilename.ai_suggestions")
-- AIサジェスト機能のインスタンスを保持する変数
local ai_suggester = nil

-- 翻訳関数
local function _(key, ...)
	local message = _lang_messages[key] or key -- キーが見つからない場合はキー自体を返す
	-- 可変引数を明示的にunpackしてstring.formatに渡す
	return string.format(message, unpack({ ... }))
end

local function sanitize_filename_part(s)
	if not s then
		return ""
	end
	-- 空白文字をアンダースコアに置換
	s = string.gsub(s, "%s+", "_")
	-- ファイル名に使えない文字を削除 (/, \, :, *, ?, ", <, >, |)
	s = string.gsub(s, '[/\\%*:?"<>|]', "")
	-- 制御文字を削除
	s = string.gsub(s, "[%c]", "")
	-- 先頭・末尾のアンダースコアを削除
	s = string.gsub(s, "^_+", "")
	s = string.gsub(s, "_+$", "")
	-- 連続するアンダースコアを一つにまとめる
	s = string.gsub(s, "__+", "_")
	return s
end

-- 自動保存コマンドを定義
function M.setup(user_config)
	-- ユーザー設定をマージ
	_config = vim.tbl_deep_extend("force", _config, user_config or {})

	-- ユーザーの環境言語を検出（例: "en", "ja", "zh-CN"など）
	-- Neovimのv:langまたはLANG環境変数を使用
	local system_lang = vim.env.LANG
	if system_lang then
		-- 例: "ja_JP.UTF-8" から "ja_JP" を抽出し、"ja-JP" に変換
		local locale_with_underscore = system_lang:match("([^%.]+)") -- "en_US.UTF-8" -> "en_US"
		if locale_with_underscore then
			system_lang = string.gsub(locale_with_underscore, "_", "-") -- "en_US" -> "en-US"
		else
			system_lang = nil -- 環境変数が空、または不正な形式の場合はnil
		end
	end

	-- 設定で言語が指定されていない場合、または無効な言語が指定されている場合、システム言語を使用
	if not _config.lang or not _lang_messages[_config.lang] then
		_config.lang = system_lang or "en" -- システム言語も不明な場合はデフォルトの英語
	end

	-- 言語ファイルを読み込む
	local lang_file_path = "autofilename.i18n." .. _config.lang
	local ok, messages = pcall(require, lang_file_path)
	if ok and type(messages) == "table" then
		_lang_messages = messages
	else
		-- 翻訳ファイルの読み込みに失敗した場合、デフォルトの英語を試みる
		if _config.lang ~= "en" then
			vim.notify(
				string.format(
					"翻訳ファイル '%s' の読み込みに失敗しました。英語を試します。",
					lang_file_path
				),
				vim.log.levels.WARN
			)
			lang_file_path = "autofilename.i18n.en"
			ok, messages = pcall(require, lang_file_path)
			if ok and type(messages) == "table" then
				_lang_messages = messages
			else
				vim.notify(
					string.format(
						"デフォルトの英語翻訳ファイル '%s' の読み込みにも失敗しました。",
						lang_file_path
					),
					vim.log.levels.ERROR
				)
				_lang_messages = {} -- 最終的に空のテーブル
			end
		else
			vim.notify(
				string.format(
					"デフォルトの英語翻訳ファイル '%s' の読み込みに失敗しました。",
					lang_file_path
				),
				vim.log.levels.ERROR
			)
			_lang_messages = {} -- 最終的に空のテーブル
		end
	end

	-- AIサジェスト機能を初期化
	ai_suggester = ai_suggestions_module.setup(_config, _)

	vim.api.nvim_create_user_command(
		"AutoSaveNote", -- コマンド名
		function(opts)
			-- 現在のバッファの内容を全行取得
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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
			title = sanitize_filename_part(title)

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
			local save_dir = _config.save_directory or vim.fn.getcwd()

			-- 保存ディレクトリが存在しない場合は作成
			if vim.fn.isdirectory(save_dir) == 0 then
				local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, save_dir, "p")
				if not mkdir_ok then
					vim.notify(
						string.format(
							_("file_save_failed_message"),
							"ディレクトリの作成に失敗しました: " .. (mkdir_err or _("unknown_error"))
						),
						vim.log.levels.ERROR
					)
					return -- ディレクトリ作成失敗時は処理を中断
				end
			end

			local save_path_candidate = vim.fs.joinpath(save_dir, filename_base .. file_extension)
			local counter = 0

			-- ファイル名が既に存在する場合、連番を付与してユニークなファイル名を見つける
			while vim.fn.filereadable(save_path_candidate) == 1 do
				counter = counter + 1
				save_path_candidate = vim.fs.joinpath(save_dir, filename_base .. "-" .. counter .. file_extension)
			end

			-- 最終的な保存パスを決定
			local final_save_path = save_path_candidate

			-- ファイルへの書き込みを試みる
			local ok, result_or_err = pcall(vim.fn.writefile, lines, final_save_path)

			if ok and result_or_err == 0 then
				vim.api.nvim_buf_set_name(0, final_save_path)
				vim.api.nvim_buf_set_option(0, "modified", false)
				vim.notify(_("file_saved_message", final_save_path), vim.log.levels.INFO)
			else
				vim.notify(_("file_save_failed_message", (result_or_err or _("unknown_error"))), vim.log.levels.ERROR)
			end
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
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

			-- AIサジェスト関数を呼び出し、結果を待機
			ai_suggester.get_ai_suggestions(lines, function(suggestions)
				vim.schedule(function() -- UI操作はメインスレッドで実行する必要がある
					if #suggestions > 0 then
						-- vim.ui.select を使用してユーザーに選択させる
						vim.ui.select(suggestions, {
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
								local filename_base = sanitize_filename_part(
									selected_suggestion.fileNameCandidate or selected_suggestion.name
								)
								-- ファイル名の長さを制限 (拡張子と最悪の連番(-XXXXX)の長さを考慮)
								local max_base_len = _config.max_filename_length - #_config.extension - 5
								if #filename_base > max_base_len then
									filename_base = string.sub(filename_base, 1, max_base_len)
								end

								local file_extension = _config.extension
								local save_dir = _config.save_directory or vim.fn.getcwd()

								-- 保存ディレクトリが存在しない場合は作成
								if vim.fn.isdirectory(save_dir) == 0 then
									local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, save_dir, "p")
									if not mkdir_ok then
										vim.notify(
											string.format(
												_("file_save_failed_message"),
												"ディレクトリの作成に失敗しました: "
													.. (mkdir_err or _("unknown_error"))
											),
											vim.log.levels.ERROR
										)
										return -- ディレクトリ作成失敗時は処理を中断
									end
								end

								local save_path_candidate = vim.fs.joinpath(save_dir, filename_base .. file_extension)
								local counter = 0

								-- ファイル名が既に存在する場合、連番を付与してユニークなファイル名を見つける
								while vim.fn.filereadable(save_path_candidate) == 1 do
									counter = counter + 1
									save_path_candidate =
										vim.fs.joinpath(save_dir, filename_base .. "-" .. counter .. file_extension)
								end

								-- 最終的な保存パスを決定
								local final_save_path = save_path_candidate

								-- ファイルへの書き込みを試みる
								local ok, result_or_err = pcall(vim.fn.writefile, lines, final_save_path)

								if ok and result_or_err == 0 then
									vim.api.nvim_buf_set_name(0, final_save_path)
									vim.api.nvim_buf_set_option(0, "modified", false)
									vim.notify(_("file_saved_message", final_save_path), vim.log.levels.INFO)
								else
									vim.notify(
										_("file_save_failed_message", (result_or_err or _("unknown_error"))),
										vim.log.levels.ERROR
									)
								end
							else
								vim.notify(_("ai_selection_canceled"), vim.log.levels.INFO)
							end
						end)
					else
						vim.notify(_("ai_no_suggestions"), vim.log.levels.INFO)
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

return M
