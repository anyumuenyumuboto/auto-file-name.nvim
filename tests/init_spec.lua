-- vim.test に依存しない、plenary.busted の最小限のテスト
-- local busted = require("plenary.busted")

local filename_sanitizer = require("autofilename.utils.filename_sanitizer")

describe("plenary.busted functionality", function()
	it("should run a basic assertion successfully", function()
		assert.are.equal(1 + 1, 2)
	end)

	it("should recognize true as true", function()
		assert.is_true(true)
	end)

	it("should recognize nil as nil", function()
		assert.is_nil(nil)
	end)
end)

describe("filename_sanitizer.sanitize_filename_part", function()
	it("should replace spaces with underscores and remove invalid characters", function()
		assert.are.equal(
			filename_sanitizer.sanitize_filename_part("My new file/name?"),
			"My_new_filename"
		)
	end)

	it("should handle Japanese characters and remove invalid characters", function()
		assert.are.equal(
			filename_sanitizer.sanitize_filename_part("新しいファイル名/テスト?。md"),
			"新しいファイル名テスト。md"
		)
	end)

	it("should retain allowed special characters like hyphens, underscores, and dots", function()
		assert.are.equal(
			filename_sanitizer.sanitize_filename_part("my-document_v1.0.txt"),
			"my-document_v1.0.txt"
		)
	end)
end)

describe("autofilename.init.trim_system_lang", function()
	local trim_system_lang

	before_each(function()
		-- テスト用に公開された関数を取得
		trim_system_lang = autofilename_init.trim_system_lang_for_test_only
	end)

	it("should correctly trim and format a full locale string", function()
		assert.are.equal(trim_system_lang("en_US.UTF-8"), "en-US")
		assert.are.equal(trim_system_lang("ja_JP.UTF-8"), "ja-JP")
		assert.are.equal(trim_system_lang("zh_CN.GBK"), "zh-CN")
	end)

	it("should handle locale strings without encoding", function()
		assert.are.equal(trim_system_lang("en_US"), "en-US")
		assert.are.equal(trim_system_lang("fr_FR"), "fr-FR")
	end)

	it("should return nil for empty or invalid input", function()
		assert.is_nil(trim_system_lang(""))
		assert.is_nil(trim_system_lang(nil))
		assert.is_nil(trim_system_lang("  "))
		assert.is_nil(trim_system_lang(".UTF-8")) -- ロケール部分がない場合
	end)

	it("should handle single language codes", function()
		assert.are.equal(trim_system_lang("en"), "en")
		assert.are.equal(trim_system_lang("ja"), "ja")
	end)

	it("should handle mixed case input", function()
		assert.are.equal(trim_system_lang("en_us.utf-8"), "en-us")
		assert.are.equal(trim_system_lang("JA_jp.UTF8"), "JA-jp")
	end)
end)
