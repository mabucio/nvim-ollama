local utils = require("utils")

local M = {}

-- Variables to keep track of our persistent state
local persistent_buf = nil
local floating_win = nil
local i = 0

function M.move_cursor_below_last_match(pattern)
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
		-- print("Floating win exists")
		vim.api.nvim_set_current_win(floating_win)
	else
		-- print("Creating window again")
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
	M.move_cursor_below_last_match("<CR>")
end

function M.ask_ollama_async(prompt)
	-- Let user know AI is running
	utils.append_to_buffer({ "Asisstant: " })
	M.move_cursor_below_last_match("s")

	local obj = {
		model = "qwen2.5-coder:14b",
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
			utils.append_to_buffer({ "Error: Ollama request failed." })
			return
		end

		local success, data = pcall(vim.json.decode, out.stdout)
		if success and data.response then
			-- Split response by newline for nvim_buf_set_lines
			local lines = vim.split(data.response, "\n")
			utils.append_to_buffer(lines)
		else
			utils.append_to_buffer({ "Error: Failed to parse JSON." })
		end

		utils.append_to_buffer({ "User: " })

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
	utils.append_to_buffer({ "" })
	vim.keymap.set("n", "<CR>", function()
		local input = utils.buf_to_str(persistent_buf)

		-- Don't send empty lines
		if input ~= "" then
			M.ask_ollama_async(input)
		else
			utils.append_to_buffer({ "Empty input" })
		end
	end, { buffer = persistent_buf, desc = "Submit prompt to Ollama" })
	M.ask_ollama_async("Say some greettings to the user who is just starting to work with you.")
end

return M
