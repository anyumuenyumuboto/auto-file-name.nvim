-- tests/minimal_init.lua
-- 最小限の設定：テスト対象のプラグインと plenary.nvim だけをロード

local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)  -- テスト対象のプラグイン（auto-file-name.nvim）を追加

-- plenary.nvim のパスを追加（通常は ~/.local/share/nvim/lazy/plenary.nvim など）
-- lazy.nvim 使用時の例:
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")

-- 必要に応じて packer/dein のパスも調整
-- 例: vim.opt.rtp:append("~/.local/share/nvim/site/pack/packer/start/plenary.nvim")

-- 余計な設定を一切読み込まない
