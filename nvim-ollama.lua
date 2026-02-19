local M = {}

-- Variables to keep track of our persistent state
local persistent_buf = nil
local floating_win = nil
local i = 0

local function append_to_buffer(lines)
	vim.schedule(function()
		if persistent_buf and vim.api.nvim_buf_is_valid(persistent_buf) then
			vim.api.nvim_buf_set_lines(persistent_buf, -1, -1, false, lines)
		end
	end)
end

-- 1. Function to create a centered floating window
function M.open_floating_window()
	i = i + 1
	-- Create a new empty buffer (not listed, scratch buffer)
	if not persistent_buf or not vim.api.nvim_buf_is_valid(persistent_buf) then
		persistent_buf = vim.api.nvim_create_buf(false, true)
		-- vim.api.nvim_buf_set_lines(persistent_buf, 0, -1, false, { "Background logic running..." })
	end

	-- 2. If window is already open, just focus it and stop
	if floating_win and vim.api.nvim_win_is_valid(floating_win) then
		vim.api.nvim_set_current_win(floating_win)
	else
		-- local ui = vim.api.nvim_list_uis()[0] -- Get UI dimensions
		local ui_width = vim.o.columns
		local ui_height = vim.o.lines
		local opts = {
			relative = "editor",
			width = math.ceil(0.8 * ui_width),
			height = math.ceil(0.8 * ui_height),
			col = math.ceil(0.1 * ui_width),
			row = math.ceil(0.05 * ui_height),
			style = "minimal", -- No numbers or status line
			border = "rounded", -- Clean rounded border
		}

		-- Open the window and focus it
		floating_win = vim.api.nvim_open_win(persistent_buf, true, opts)

		vim.api.nvim_create_autocmd("BufLeave", {
			buffer = persistent_buf,
			once = true,
			callback = function()
				if floating_win and vim.api.nvim_win_is_valid(floating_win) then
					vim.api.nvim_win_close(floating_win, true)
					floating_win = nil -- Reset handle so we can reopen it
				end
			end,
		})
	end
end

function M.ask_ollama_async(prompt)
	-- Let user know AI is running
	append_to_buffer({ "--- AI is thinking ---" })

	local obj = {
		model = "qwen3:14b",
		prompt = prompt,
		stream = false,
	}

	-- Use vim.system (Non-blocking)
	vim.system({
		"curl",
		"-s",
		"-X",
		"POST",
		"http://localhost:11434/api/generate",
		"-d",
		vim.json.encode(obj),
	}, { text = true }, function(out)
		-- This callback runs when the process finishes
		if out.code ~= 0 then
			append_to_buffer({ "Error: Ollama request failed." })
			return
		end

		local success, data = pcall(vim.json.decode, out.stdout)
		if success and data.response then
			-- Split response by newline for nvim_buf_set_lines
			local lines = vim.split(data.response, "\n")
			append_to_buffer(lines)
		else
			append_to_buffer({ "Error: Failed to parse JSON." })
		end

		vim.schedule(function()
			-- If the buffer is empty, line_count is 1.
			-- nvim_win_set_cursor takes {row, col}, row is 1-indexed.
			if floating_win and vim.api.nvim_win_is_valid(floating_win) then
				local line_count = vim.api.nvim_buf_line_count(persistent_buf)
				vim.api.nvim_win_set_cursor(floating_win, { line_count, 0 })
			end
		end)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("LLM", M.open_floating_window, {
		desc = "My custom command to open a window",
	})

	persistent_buf = vim.api.nvim_create_buf(false, true)
	vim.keymap.set("n", "<CR>", function()
		local input = vim.api.nvim_get_current_line()

		-- Don't send empty lines
		if input ~= "" then
			-- 1. Trigger your function
			M.ask_ollama_async(input)

			-- 2. Move cursor to the end of the buffer for the next input
			local line_count = vim.api.nvim_buf_line_count(persistent_buf)
			-- Add a new empty line at the bottom
			vim.api.nvim_buf_set_lines(persistent_buf, -1, -1, false, { "" })
			-- Set cursor to that new line
			vim.api.nvim_win_set_cursor(0, { line_count + 1, 0 })
		else
			append_to_buffer({ "Empty input" })
		end
	end, { buffer = persistent_buf, desc = "Submit prompt to Ollama" })
	M.ask_ollama_async("Say some greettings to the user who is just starting to work with you.")
end

return M
