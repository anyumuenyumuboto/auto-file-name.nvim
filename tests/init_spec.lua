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
end)
