-- lua/autofilename/init.lua

local M = {}

-- プラグイン設定
local _config = {
    lang = "en", -- デフォルト言語を英語に設定
}

-- 翻訳メッセージを格納するテーブル
local _lang_messages = {}

-- 翻訳関数
local function _(key, ...)
    local message = _lang_messages[key] or key -- キーが見つからない場合はキー自体を返す
    return string.format(message, ...)
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
            vim.notify(string.format("翻訳ファイル '%s' の読み込みに失敗しました。英語を試します。", lang_file_path), vim.log.levels.WARN)
            lang_file_path = "autofilename.i18n.en"
            ok, messages = pcall(require, lang_file_path)
            if ok and type(messages) == "table" then
                _lang_messages = messages
            else
                vim.notify(string.format("デフォルトの英語翻訳ファイル '%s' の読み込みにも失敗しました。", lang_file_path), vim.log.levels.ERROR)
                _lang_messages = {} -- 最終的に空のテーブル
            end
        else
            vim.notify(string.format("デフォルトの英語翻訳ファイル '%s' の読み込みに失敗しました。", lang_file_path), vim.log.levels.ERROR)
            _lang_messages = {} -- 最終的に空のテーブル
        end
    end

	vim.api.nvim_create_user_command(
		"AutoSaveNote", -- コマンド名
		function(opts)
			-- ここにファイル名自動生成と保存のロジックを記述します
			-- print("AutoSaveNoteコマンドが実行されました！")
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
				vim.notify(_("file_saved_message", save_path), vim.log.levels.INFO)
			else
				vim.notify(_("file_save_failed_message", (result_or_err or _("unknown_error"))), vim.log.levels.ERROR)
			end
		end,
		{
			desc = _("autosavenote_command_desc"),
			nargs = 0,
		}
	)
end

return M
