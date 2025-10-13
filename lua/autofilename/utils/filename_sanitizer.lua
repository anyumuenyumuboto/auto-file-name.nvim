local M = {}

function M.sanitize_filename_part(s)
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

return M
