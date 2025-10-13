-- plenary.nvim は busted をラップしているため、busted のグローバル assert が利用可能です。
-- vim.test.fn や vim.test.stub でモックやスパイを使います。
-- vim.loader を有効にして、lazy.nvim がプラグインを適切にロードできるようにする
vim.loader.enable()

local busted = require("plenary.busted")
local test_harness = require("plenary.test_harness") -- vim.test を初期化する主要モジュール
local M = require("autofilename.init")
local ai_suggestions_module = require("autofilename.ai_suggestions")
local filename_sanitizer = require("autofilename.utils.filename_sanitizer") -- 新しいモジュールをインポート

describe("autofilename.init", function()
	local original_env_lang

	-- 各テストケースの前に実行されるセットアップ
	before_each(function()
		-- Neovimのグローバル変数をモックする必要がある場合はここで行う
		-- 例: vim.env.LANG の値をテスト用に設定
		original_env_lang = vim.env.LANG
		vim.env.LANG = "en_US.UTF-8"

		-- setup関数が内部状態をクリア/初期化する前提で、常にsetupを呼び出す
		-- テスト時に使用するモックを注入
		M.setup({
			lang = "en-US", -- デフォルト言語を英語に設定
			fs = {
				-- テスト用のデフォルトのファイルシステムヘルパーモック
				vim_fn_getcwd = function() return "/mock/cwd" end,
				vim_fn_isdirectory = function(path)
					return path == "/mock/exists_dir" or path == "/mock/test_dir" and 1 or 0
				end,
				vim_fn_mkdir = function(path, p)
					if path == "/mock/fail_dir" then
						error("mkdir failed intentionally")
					end
					-- 成功したと見せかける
				end,
				vim_fn_filereadable = vim.test.fn(function(path)
					return path == "/mock/test_dir/existing.md" or path == "/mock/test_dir/base.md" or
							path == "/mock/test_dir/base-1.md" and 1 or 0
				end),
				vim_fs_joinpath = vim.fs.joinpath, -- joinpathはNeovimの実装をそのまま使う
			},
			nvim_api = {
				show_notification = vim.test.fn(), -- 通知をモック
				get_error_level = function() return "ERROR" end, -- エラーレベルをモック
				get_info_level = function() return "INFO" end,
				get_warn_level = function() return "WARN" end,
				get_current_working_directory = function() return "/mock/cwd" end,
				save_file_as = vim.test.fn(), -- saveasコマンドをモック
				get_buffer_content = vim.test.fn(function() return { "Test Content" } end), -- バッファ内容をモック
				show_select_prompt = vim.test.fn(function(items, options, on_choice)
					on_choice(items[1]) -- 常に最初の項目を選択したことにする
				end),
				schedule_wrap = function(func) func() end, -- スケジュールラップを同期的に実行
			},
		})
	end)

	-- 各テストケースの後に実行されるティアダウン
	after_each(function()
		-- モックしたNeovimグローバル変数を元に戻す
		vim.env.LANG = original_env_lang
		-- mock.clear_all_stubs() -- 必要に応じてstubをクリア
	end)

	describe("filename_sanitizer.sanitize_filename_part", function()
		it("should remove leading/trailing spaces and replace spaces with underscores", function()
			local sanitized = filename_sanitizer.sanitize_filename_part("  My File Name  ")
			assert.equals(sanitized, "My_File_Name")
		end)

		it("should remove invalid characters for filenames", function()
			local sanitized = filename_sanitizer.sanitize_filename_part("My/File:Name*?\"<>|")
			assert.equals(sanitized, "MyFileName")
		end)

		it("should remove control characters", function()
			local sanitized = filename_sanitizer.sanitize_filename_part("My\nFile\tName")
			assert.equals(sanitized, "MyFileName")
		end)

		it("should remove leading/trailing underscores", function()
			local sanitized = filename_sanitizer.sanitize_filename_part("__My_File_Name__")
			assert.equals(sanitized, "My_File_Name")
		end)

		it("should collapse multiple underscores into one", function()
			local sanitized = filename_sanitizer.sanitize_filename_part("My__File___Name")
			assert.equals(sanitized, "My_File_Name")
		end)

		it("should handle mixed invalid characters and spaces", function()
			local sanitized = filename_sanitizer.sanitize_filename_part(" / My-File.Name \\? ")
			assert.equals(sanitized, "My-File.Name")
		end)

		it("should return an empty string for nil input", function()
			local sanitized = filename_sanitizer.sanitize_filename_part(nil)
			assert.equals(sanitized, "")
		end)

		it("should return an empty string for empty input", function()
			local sanitized = filename_sanitizer.sanitize_filename_part("")
			assert.equals(sanitized, "")
		end)
	end)

	describe("trim_system_lang", function()
		it("should correctly trim and format a full locale string", function()
			assert.equals(M.trim_system_lang("ja_JP.UTF-8"), "ja-JP")
			assert.equals(M.trim_system_lang("en_US.UTF-8"), "en-US")
			assert.equals(M.trim_system_lang("zh_CN.GBK"), "zh-CN")
		end)

		it("should return nil if system_lang is nil", function()
			assert.equals(M.trim_system_lang(nil), nil)
		end)

		it("should return nil if system_lang is empty", function()
			assert.equals(M.trim_system_lang(""), nil)
		end)

		it("should handle locale strings without encoding", function()
			assert.equals(M.trim_system_lang("fr_FR"), "fr-FR")
		end)

		it("should handle locale strings with only language code", function()
			assert.equals(M.trim_system_lang("es"), "es")
		end)

		it("should handle unexpected formats gracefully", function()
			assert.equals(M.trim_system_lang("invalid-format"), "invalid-format")
			assert.equals(M.trim_system_lang("._UTF-8"), nil) -- match fails, returns nil
		end)
	end)

	describe("fs_helpers (mocked file system operations)", function()
		local mocked_file_api

		before_each(function()
			-- M.setup を呼び出すことで fs_helpers と nvim_api_helpers が更新される
			local mock_fs_dependencies = {
				vim_fn_getcwd = function() return "/mock/test_cwd" end,
				vim_fn_isdirectory = function(path)
					return path == "/mock/existing_dir" and 1 or 0
				end,
				vim_fn_mkdir = vim.test.fn(function(path, p)
					if path == "/mock/fail_create_dir" then
						error("Mock mkdir failed intentionally!")
					end
					-- 成功をシミュレート
				end),
				vim_fn_filereadable = vim.test.fn(function(path)
					return path == "/mock/test_cwd/existing_file.md" or
							path == "/mock/test_cwd/test-1.md" and 1 or 0
				end), -- M._create_file_path_helpers のテストではここも vim.test.fn でモック可能
				vim_fs_joinpath = vim.fs.joinpath,
			}
			local mock_nvim_api_dependencies = {
				show_notification = vim.test.fn(),
				get_error_level = function() return "ERROR" end,
				get_info_level = function() return "INFO" end,
				get_warn_level = function() return "WARN" end,
				get_current_working_directory = function() return "/mock/test_cwd" end,
				save_file_as = vim.test.fn(),
				get_buffer_content = vim.test.fn(function() return { "Test Content" } end),
				show_select_prompt = vim.test.fn(function(items, options, on_choice)
					on_choice(items[1])
				end),
				schedule_wrap = function(func) func() end,
			}

			M.setup({
				fs = mock_fs_dependencies,
				nvim_api = mock_nvim_api_dependencies,
			})
			mocked_file_api = mock_nvim_api_dependencies -- setupに渡したnvim_apiモックを参照
		end)

		it("should use the mocked get_current_working_directory via AutoSaveNote command", function()
			M.AutoSaveNote({}) -- コマンドを実行
			-- M._config_for_test_only.nvim_api.save_file_as.assert_called_with("/mock/test_cwd/Test_Content.md")
			-- 上記は直接的なモックアクセスを必要とするため、もう少し工夫が必要
			-- ここでは、`M.setup` に渡した `nvim_api` モックの `save_file_as` が呼ばれることを確認する
			assert.spy(mocked_file_api.save_file_as).called_with("/mock/test_cwd/Test_Content.md")
		end)

		-- get_unique_save_path のテスト
		it("should return a unique path when file does not exist", function()
			-- _create_file_path_helpers を直接呼び出すことで、fs_helpers インスタンスを取得し、テストする
			local helpers = M._create_file_path_helpers({
				vim_fn_filereadable = vim.test.fn(function() return 0 end), -- ファイルは存在しない
				vim_fs_joinpath = vim.fs.joinpath,
			})
			local path = helpers.get_unique_save_path("new_file", ".md", "/path/to/dir")
			assert.equals(path, "/path/to/dir/new_file.md")
		end)

		it("should return a unique path with counter when file exists", function()
			local helpers = M._create_file_path_helpers({
				vim_fn_filereadable = vim.test.fn(function(path)
					return path == "/path/to/dir/existing.md" or path == "/path/to/dir/existing-1.md" and 1 or 0
				end),
				vim_fs_joinpath = vim.fs.joinpath,
			})
			local path = helpers.get_unique_save_path("existing", ".md", "/path/to/dir")
			assert.equals(path, "/path/to/dir/existing-2.md")
		end)

		it("should ensure directory exists when it already does", function()
			local nvim_api_mock = M._create_nvim_api_helpers({
				show_notification = vim.test.fn(),
				get_error_level = function() return "ERROR" end,
			})
			local helpers = M._create_file_path_helpers(
				{
					vim_fn_isdirectory = vim.test.fn(function(path) return 1 end), -- ディレクトリは存在する
					vim_fn_mkdir = vim.test.fn(),
				},
				nvim_api_mock
			)

			local ok, err = helpers.ensure_save_directory("/path/to/dir", function(key) return key end)
			assert.is_true(ok)
			assert.is_nil(err) -- 成功時はerrはnil
			assert.spy(nvim_api_mock.show_notification).was_not_called()
			assert.spy(helpers.vim_fn_mkdir).was_not_called() -- mkdirは呼ばれない
		end)

		it("should create directory when it does not exist", function()
			local nvim_api_mock = M._create_nvim_api_helpers({ -- create_nvim_api_helpersに渡すモックもvim.test.fnを使う
				show_notification = vim.test.fn(),
				get_error_level = function() return "ERROR" end,
			})
			local helpers = M._create_file_path_helpers(
				{
					vim_fn_isdirectory = vim.test.fn(function(path) return 0 end), -- ディレクトリは存在しない
					vim_fn_mkdir = vim.test.fn(),
				},
				nvim_api_mock
			)

			local ok, err = helpers.ensure_save_directory("/path/to/new_dir", function(key) return key end)
			assert.is_true(ok)
			assert.is_nil(err) -- 成功時はerrはnil
			assert.spy(nvim_api_mock.show_notification).was_not_called()
			assert.spy(helpers.vim_fn_mkdir).called_with("/path/to/new_dir", "p") -- mkdirが呼ばれる
		end)

		it("should handle mkdir failure", function()
			local nvim_api_mock = M._create_nvim_api_helpers({ -- create_nvim_api_helpersに渡すモックもvim.test.fnを使う
				show_notification = vim.test.fn(),
				get_error_level = function() return "ERROR" end,
			})
			local helpers = M._create_file_path_helpers(
				{
					vim_fn_isdirectory = vim.test.fn(function(path) return 0 end), -- ディレクトリは存在しない
					vim_fn_mkdir = vim.test.fn(function() error("permission denied") end), -- mkdirが失敗
				},
				nvim_api_mock
			)

			local ok, err = helpers.ensure_save_directory("/path/to/fail_dir", function(key) return key end)
			assert.is_false(ok)
			assert.equals(err, "permission denied")
			assert.spy(nvim_api_mock.show_notification).called_with(
				"file_save_failed_message",
				"ERROR"
			) -- エラー通知が呼ばれる
			assert.spy(helpers.vim_fn_mkdir).called_with("/path/to/fail_dir", "p")
		end)
	end)

	-- `_create_nvim_api_helpers` とそれらの使用に関するテスト (M.AutoSaveNote, M.AutoSuggestNote)
	describe("Neovim API helpers and commands", function()
		local mocked_nvim_api_helpers -- _create_nvim_api_helpers が返すモックされたヘルパーを保持

		before_each(function()
			-- M.setup を呼び出し、その際に使用される _create_nvim_api_helpers に渡すモックを設定
			local mock_dependencies = {
				get_buffer_content = vim.test.fn(function() return { "Line 1", "Line 2" } end),
				save_file_as = vim.test.fn(),
				show_select_prompt = vim.test.fn(function(items, options, on_choice) on_choice(items[1]) end),
				show_notification = vim.test.fn(),
				get_error_level = function() return "ERROR" end,
				get_info_level = function() return "INFO" end,
				get_warn_level = function() return "WARN" end,
				get_current_working_directory = function() return "/mock/test_cwd" end,
				schedule_wrap = function(func) func() end, -- 同期的に実行
			}

			M.setup({
				fs = {
					vim_fn_getcwd = function() return "/mock/test_cwd" end,
					vim_fn_isdirectory = function(path) return 1 end, -- ディレクトリは常に存在する
					vim_fn_mkdir = vim.test.fn(),
					vim_fn_filereadable = vim.test.fn(function(path) return 0 end), -- ファイルは常に存在しない
					vim_fs_joinpath = vim.fs.joinpath,
				},
				nvim_api = mock_dependencies, -- ここでモックした依存性を渡す
			})

			-- M.setup 内部で設定された nvim_api_helpers はローカル変数なので直接アクセスできない。
			-- そのため、M.setup に渡した `mock_dependencies` を参照し続ける
			mocked_nvim_api_helpers = mock_dependencies
		end)

		describe("AutoSaveNote command", function()
			it("should get buffer content and save file using helpers", function()
				M.AutoSaveNote({})

				-- `get_buffer_content` が呼ばれたことを確認
				assert.spy(mocked_nvim_api_helpers.get_buffer_content).called()
				-- `save_file_as` が適切なパスで呼ばれたことを確認
				-- 最初の行 "Line 1" がファイル名になり、拡張子 ".md" が付与される
				assert.spy(mocked_nvim_api_helpers.save_file_as).called_with("/mock/test_cwd/Line_1.md")
			end)

			it("should use save_directory from config if provided", function()
				-- M.setupを再度呼び出す前に、既存のモックのspyをリセット (vim.test.fnは自動的にリセットされない)
				mocked_nvim_api_helpers.get_buffer_content.clear_calls()
				mocked_nvim_api_helpers.save_file_as.clear_calls()

				M.setup({
					save_directory = "/custom/save/path", -- setup時に設定が更新される
					fs = {
						vim_fn_getcwd = function() return "/mock/test_cwd" end,
						vim_fn_isdirectory = function(path) return 1 end,
						vim_fn_mkdir = vim.test.fn(),
						vim_fn_filereadable = vim.test.fn(function(path) return 0 end),
						vim_fs_joinpath = vim.fs.joinpath,
					},
					nvim_api = mocked_nvim_api_helpers, -- 前のモックを再利用
				}) -- setupは_configを更新する
				mocked_nvim_api_helpers.get_buffer_content.returns({ "Another Line" })


				M.AutoSaveNote({})

				assert.spy(mocked_nvim_api_helpers.save_file_as).called_with("/custom/save/path/Another_Line.md")
			end)
		end)

		describe("AutoSuggestNote command", function()
			local ai_suggester_mock

			before_each(function()
				-- ai_suggestions_module.setup をモックして、get_ai_suggestions を制御できるようにする
				-- ai_suggestions_module.setup をモックして、get_ai_suggestions を制御できるようにする
				-- M.setup が呼び出される前にモックする必要がある
				local original_ai_setup = ai_suggestions_module.setup
				ai_suggester_mock = {
					get_ai_suggestions = vim.test.fn(function(buffer_content, callback, opts)
						callback({ -- AIからの応答をシミュレート
							{ fileNameCandidate = "AI_Suggested_Name_1" },
							{ fileNameCandidate = "AI_Suggested_Name_2" },
						})
					end),
				}
				vim.test.stub(ai_suggestions_module, "setup", function(...)
					return ai_suggester_mock -- モックされたサジェスターを返す
				end)

				-- M.setup を再呼び出し、ai_suggester_mock が使われるようにする
				local mock_dependencies = {
					get_buffer_content = vim.test.fn(function() return { "AI Test Content" } end),
					save_file_as = vim.test.fn(),
					show_select_prompt = vim.test.fn(function(items, options, on_choice)
						-- 常に最初の提案を選択する
						on_choice(items[1])
					end),
					show_notification = vim.test.fn(),
					get_error_level = function() return "ERROR" end,
					get_info_level = function() return "INFO" end,
					get_warn_level = function() return "WARN" end,
					get_current_working_directory = function() return "/mock/test_cwd" end,
					schedule_wrap = function(func) func() end,
				}
				M.setup({
					lang = "en-US",
					fs = {
						vim_fn_getcwd = function() return "/mock/test_cwd" end,
						vim_fn_isdirectory = function(path) return 1 end,
						vim_fn_mkdir = vim.test.fn(),
						vim_fn_filereadable = vim.test.fn(function(path) return 0 end),
						vim_fs_joinpath = vim.fs.joinpath,
					},
					nvim_api = mock_dependencies,
				})
				mocked_nvim_api_helpers = mock_dependencies -- 更新されたモック参照
			end)

			after_each(function()
				vim.test.revert_stub(ai_suggestions_module, "setup")
			end)

			it("should get buffer content, call AI suggester, show select prompt, and save file", function()
				M.AutoSuggestNote({})

				-- `get_buffer_content` が呼ばれたことを確認
				assert.spy(mocked_nvim_api_helpers.get_buffer_content).called()
				-- `ai_suggester.get_ai_suggestions` が呼ばれたことを確認
				assert.spy(ai_suggester_mock.get_ai_suggestions).called_with({ "AI Test Content" }, vim.mock_fn(), nil)
				-- `show_select_prompt` が提案リストで呼ばれたことを確認
				assert.spy(mocked_nvim_api_helpers.show_select_prompt).called_with(
					{
						{ fileNameCandidate = "AI_Suggested_Name_1" },
						{ fileNameCandidate = "AI_Suggested_Name_2" },
					},
					vim.mock_tbl(), -- オプションテーブルは任意のテーブルとしてチェック
					vim.test.fn() -- コールバック関数は任意の関数としてチェック
				)
				-- `save_file_as` が選択された提案で呼ばれたことを確認
				assert.spy(mocked_nvim_api_helpers.save_file_as).called_with("/mock/test_cwd/AI_Suggested_Name_1.md")
			end)

			it("should show a notification if no suggestions are returned", function()
				ai_suggester_mock.get_ai_suggestions.clear_calls() -- spyのリセット
				ai_suggester_mock.get_ai_suggestions.stub(vim.test.fn(function(buffer_content, callback, opts)
					callback({}) -- 提案なし
				end))

				M.AutoSuggestNote({})

				assert.spy(mocked_nvim_api_helpers.show_notification).called_with("ai_no_suggestions", "INFO")
				assert.spy(mocked_nvim_api_helpers.save_file_as).was_not_called()
			end)

			it("should show a notification if user cancels selection", function()
				mocked_nvim_api_helpers.show_select_prompt.clear_calls() -- spyのリセット
				mocked_nvim_api_helpers.show_select_prompt.stub(vim.test.fn(function(items, options, on_choice)
					on_choice(nil) -- ユーザーがキャンセル
				end))

				M.AutoSuggestNote({})

				assert.spy(mocked_nvim_api_helpers.show_notification).called_with("ai_selection_canceled", "INFO")
				assert.spy(mocked_nvim_api_helpers.save_file_as).was_not_called()
			end)
		end)
	end)
end)
