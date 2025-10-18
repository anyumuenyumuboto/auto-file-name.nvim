-- vim.test に依存しない、plenary.busted の最小限のテスト
local busted = require("plenary.busted")

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
