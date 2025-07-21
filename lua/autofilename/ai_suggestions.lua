local M = {}

-- init.lua から渡される設定と翻訳関数を保持するローカル変数
local _config_internal
local _translate_func_internal

-- AIサーバーからファイル名の提案を取得する関数
-- callback: 提案のリスト (例: { { name = "suggestion1.md" }, { name = "suggestion2.md" } } ) を引数に取る関数
local function get_ai_suggestions(buffer_content, callback)
	local ai_server_url = _config_internal.ai_server_url
	local ai_api_key = _config_internal.ai_api_key

	if not ai_server_url or not ai_api_key then
		vim.notify(_translate_func_internal("ai_config_missing_error"), vim.log.levels.ERROR)
		callback({})
		return
	end

	-- バッファの内容をAIに送信するためのJSONペイロードを作成
	-- local payload = vim.json.encode({ content = table.concat(buffer_content, "\n") })
	local payload = vim.json.encode({
		contents = {
			{
				parts = {
					{
						-- text = "Explain how AI works in a few words",
						text = table.concat(buffer_content, "\n"),
					},
				},
			},
		},
		-- ref [Structured output  |  Gemini API  |  Google AI for Developers](https://ai.google.dev/gemini-api/docs/structured-output)
		generationConfig = {
			responseMimeType = "application/json",
			responseSchema = {
				type = "ARRAY",
				minItems = 3,
				maxItems = 5,
				description = "この内容のテキストファイルのファイル名として適切な命名の候補を挙げていただけますか? なお、拡張子は付けなくてよいです",
				items = {
					type = "OBJECT",
					properties = {
						fileNameCandidate = { type = "STRING" },
					},
					propertyOrdering = { "fileNameCandidate" },
				},
			},
		},
	})
	local cmd = {
		"curl",
		"-X",
		"POST",
		"-H",
		"Content-Type: application/json",
		"-H",
		-- "Authorization: Bearer " .. ai_api_key, -- APIキーをヘッダーに含める
		"x-goog-api-key: " .. ai_api_key, -- APIキーをヘッダーに含める
		"-d",
		payload,
		ai_server_url,
	}

	local output_lines = {}
	local stderr_lines = {}

	-- curlコマンドを非同期で実行
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data, _)
			for _, line in ipairs(data) do
				table.insert(output_lines, line)
			end
		end,
		on_stderr = function(_, data, _)
			for _, line in ipairs(data) do
				table.insert(stderr_lines, line)
			end
		end,
		on_exit = function(_, retcode, _)
			if retcode == 0 then
				local response_str = table.concat(output_lines, "\n")
				local ok, result = pcall(vim.json.decode, response_str)
				if ok and result and result.candidates and type(result.candidates) == "table" then
					local suggestions = {}
					-- AI応答のcandidates配列をループし、提案されたテキストを抽出
					for _, candidate in ipairs(result.candidates) do
						if
							candidate.content
							and candidate.content.parts
							and #candidate.content.parts > 0
							and candidate.content.parts[1].text
						then
							-- 提案リストに追加 (例: { name = "提案ファイル名" } )
							-- table.insert(suggestions, { fileNameCandidate = candidate.content.parts[1].text })
							file_name_candidate_list = vim.json.decode(candidate.content.parts[1].text)
							for _, item in ipairs(file_name_candidate_list) do
								file_name_candidate = item.fileNameCandidate
								table.insert(suggestions, { fileNameCandidate = file_name_candidate })
							end
						end
					end
					callback(suggestions)
				else
					vim.notify(_translate_func_internal("ai_response_parse_error", response_str), vim.log.levels.ERROR)
					callback({})
				end
			else
				vim.notify(
					_translate_func_internal("ai_call_failed_error", retcode, table.concat(stderr_lines, "\n")),
					vim.log.levels.ERROR
				)
				callback({})
			end
		end,
	})

	if job_id == 0 then
		vim.notify(_translate_func_internal("ai_job_start_error"), vim.log.levels.ERROR)
		callback({})
	end
end

-- 外部から呼び出されるセットアップ関数
function M.setup(config, translate_func)
	_config_internal = config
	_translate_func_internal = translate_func
	return {
		get_ai_suggestions = get_ai_suggestions,
	}
end

return M
