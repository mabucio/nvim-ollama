utils = {}
-- Define the log path: ~/.local/state/nvim/my_ollama_plugin.log
function utils.print(text)
	vim.schedule(function()
		print(text)
	end)
end

function utils.append_to_buffer_text(buf, text)
	vim.schedule(function()
		local line_count = vim.api.nvim_buf_line_count(buf)
		local last_line_idx = line_count - 1
		local last_line_content = vim.api.nvim_buf_get_lines(buf, last_line_idx, last_line_idx + 1, false)[1]
		local last_col = #last_line_content

		-- 2. Split the incoming text by newlines to handle multi-line chunks
		-- Using vim.split keeps trailing empty strings if the text ends in \n
		local lines = vim.split(text, "\n", { plain = true })

		-- 3. Use set_text to append
		-- Arguments: buffer, start_row, start_col, end_row, end_col, replacement_lines
		vim.api.nvim_buf_set_text(buf, last_line_idx, last_col, last_line_idx, last_col, lines)
	end)
end

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
	local line_number = vim.fn.search(pattern, "W")

	if line_number == 0 then
		print("Pattern not found.")
		return
	end

	local line_content = vim.fn.getline(line_number)
	local _, end_col = string.find(line_content, pattern)
	if not end_col then
		print("Pattern not found in the line.")
		return
	end

	local target_col = math.min(end_col + 2, vim.fn.col({ line_number, "$" }))
	vim.schedule(function()
		vim.fn.cursor(line_number, target_col)
	end)
end

function utils.move_cursor_to_end_of_buffer()
	vim.schedule(function()
		-- Get the total number of lines in the buffer
		local line_count = vim.fn.line("$")

		-- Move the cursor to the last line and the end of that line
		vim.fn.cursor(line_count, 0)
		vim.cmd("normal! $")
	end)
end
return utils
