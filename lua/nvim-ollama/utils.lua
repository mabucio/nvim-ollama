utils = {}
function utils.append_to_buffer(buf, lines)
	vim.schedule(function()
		if buf and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
		end
	end)
end

function utils.buf_to_str(buf, separator)
	local sep = separator or ""
	local content = vim.api.nvim_buf_get_lines(buf, 0, vim.api.nvim_buf_line_count(0), false)
	return table.concat(content, sep)
end

return utils
