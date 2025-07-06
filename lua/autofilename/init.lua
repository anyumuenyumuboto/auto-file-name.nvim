-- lua/autofilename/init.lua

local M = {}

-- プラグイン設定
local _config = {
    lang = "en",      -- デフォルト言語を英語に設定
    extension = ".md", -- デフォルトのファイル拡張子を.mdに設定
    filename_format = "%Y%m%dT%H%M%S_%title%", -- ファイル名フォーマット (ISO 8601形式のタイムスタンプとタイトル)
    max_filename_length = 255, -- 最大ファイル名長 (OSの制限に合わせる)
}

-- 翻訳メッセージを格納するテーブル
local _lang_messages = {}

-- 翻訳関数
local function _(key, ...)
    local message = _lang_messages[key] or key -- キーが見つからない場合はキー自体を返す
    return string.format(message, ...)
end

local function sanitize_filename_part(s)
    if not s then return "" end
    -- 空白文字をアンダースコアに置換
    s = string.gsub(s, "%s+", "_")
    -- ファイル名に使えない文字を削除 (/, \, :, *, ?, ", <, >, |)
    s = string.gsub(s, "[/\\%*:?\"<>|]", "")
    -- 制御文字を削除
    s = string.gsub(s, "[%c]", "")
    -- 先頭・末尾のアンダースコアを削除
    s = string.gsub(s, "^_+", "")
    s = string.gsub(s, "_+$", "")
    -- 連続するアンダースコアを一つにまとめる
    s = string.gsub(s, "__+", "_")
    return s
end

-- Luaプレースホルダーを処理し、安全なファイル名の一部を返す関数
local function process_lua_placeholder(lua_code_str)
    local func, err = load("return " .. lua_code_str)
    if not func then
        vim.notify(string.format("AutoFileName: Luaコードのパースに失敗しました: %s (コード: '%s')", err, lua_code_str), vim.log.levels.ERROR)
        return "" -- エラーの場合は空文字列を返す
    end

    local ok, result = pcall(func)
    if not ok then
        vim.notify(string.format("AutoFileName: Luaコードの実行に失敗しました: %s (コード: '%s')", result, lua_code_str), vim.log.levels.ERROR)
        return "" -- エラーの場合は空文字列を返す
    end

    -- 結果を文字列に変換し、ファイル名としてサニタイズ
    return sanitize_filename_part(tostring(result))
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
            -- %title% プレースホルダーを置換
            filename_format_str = string.gsub(filename_format_str, "%%title%%", title)

            -- {{ lua: ... }} プレースホルダーを置換
            filename_format_str = string.gsub(filename_format_str, "{{%s*lua:%s*(.-)%s*}}", function(lua_code)
                return process_lua_placeholder(lua_code)
            end)

            -- os.dateでタイムスタンプと残りのフォーマットを処理
			local filename_base = os.date(filename_format_str)

            -- ファイル名の長さを制限 (拡張子と最悪の連番(-XXXXX)の長さを考慮)
            local max_base_len = _config.max_filename_length - #_config.extension - 5
            if #filename_base > max_base_len then
                filename_base = string.sub(filename_base, 1, max_base_len)
            end

			local file_extension = _config.extension
			local save_dir = vim.fn.getcwd()
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
end

return M
