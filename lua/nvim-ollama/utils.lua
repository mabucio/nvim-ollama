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

function utils.move_cursor_below_last_match(pattern)
	-- Step 2: Find the text pattern
	local line_number = vim.fn.search(pattern, "W")

	if line_number == 0 then
		print("Pattern not found.")
		return
	end

	-- Step 3: Move cursor to the line below the matched line
	local next_line_number = line_number + 1
	local buffer = vim.api.nvim_get_current_buf()
	vim.fn.cursor(next_line_number, 0)
end

return utils
