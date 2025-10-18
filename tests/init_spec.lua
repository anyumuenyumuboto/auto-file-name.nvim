-- vim.test が利用可能かを確認するための最小限のテスト
local busted = require("plenary.busted")

describe("vim.test availability", function()
	it("should have vim.test available", function()
		assert.is_not_nil(vim.test)
	end)

	it("should have vim.test.fn available", function()
		assert.is_not_nil(vim.test.fn)
	end)

	it("should have vim.test.stub available", function()
		assert.is_not_nil(vim.test.stub)
	end)
end)
