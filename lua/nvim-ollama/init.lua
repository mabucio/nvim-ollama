local utils = require("nvim-ollama.utils")

local M = {}

-- Variables to keep track of our persistent state
local persistent_buf = nil
local floating_win = nil

function M.open_floating_window()
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
	utils.move_cursor_to_end_of_buffer()
end

function M.stream_ollama(prompt)
	utils.append_to_buffer(persistent_buf, { "Asisstant: " })

	local model = "qwen2.5-coder:14b"
	local url = "http://localhost:11434/api/generate"
	-- Prepare the JSON payload
	local body = vim.json.encode({
		model = model,
		prompt = prompt,
		stream = true,
	})

	-- Use vim.system to run curl asynchronously
	vim.system({
		"curl",
		"-s",
		"-N",
		"-X",
		"POST",
		url,
		"-d",
		body,
		"Content-Type: application/json",
		-- "curl",
		-- "-N",
		-- "-X",
		-- "POST",
		-- url,
		-- "-d",
		-- body,
		-- "-H",
		-- "Content-Type: application/json",
	}, {
		-- This callback runs every time stdout receives data
		stdout = function(_, data)
			utils.print("MACIEK something worked")
			if not data then
				utils.print("Not data")
				return
			end

			-- Ollama sends ND-JSON (one JSON object per line)
			for line in data:gmatch("[^\r\n]+") do
				local ok, decoded = pcall(vim.json.decode, line)
				if ok and decoded.response then
					-- Schedule UI updates on the main Neovim loop
					utils.append_to_buffer_text(persistent_buf, decoded.response)
				end
			end
		end,
		stderr = function(_, data)
			utils.print("MACIEK something doesn't work")
			if data then
				utils.print("MACIEK Error: " .. data)
				return
				-- utils.append_to_buffer(persistent_buf, { data })
			end
		end,
	}, function()
		utils.append_to_buffer(persistent_buf, { "User: " })
		utils.move_cursor_to_end_of_buffer()
	end)
end

function M.ask_ollama_async(prompt)
	-- Let user know AI is running
	utils.append_to_buffer(persistent_buf, { "Asisstant: " })
	utils.move_cursor_to_end_of_buffer()

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
			utils.append_to_buffer(persistent_buf, { "Error: Ollama request failed." })
			return
		end

		local success, data = pcall(vim.json.decode, out.stdout)
		if success and data.response then
			-- Split response by newline for nvim_buf_set_lines
			local lines = vim.split(data.response, "\n")
			utils.append_to_buffer(persistent_buf, lines)
		else
			utils.append_to_buffer(persistent_buf, { "Error: Failed to parse JSON." })
		end
	end)
	utils.append_to_buffer(persistent_buf, { "User: " })
	utils.move_cursor_to_end_of_buffer()
end

function M.setup()
	vim.api.nvim_create_user_command("LLM", M.open_floating_window, {
		desc = "My custom command to open a window",
	})

	persistent_buf = vim.api.nvim_create_buf(false, true)
	utils.append_to_buffer(persistent_buf, { "Initialized the plugin:" })
	vim.keymap.set("n", "<CR>", function()
		local input = utils.buf_to_str(persistent_buf)

		-- Don't send empty lines
		if input ~= "" then
			M.stream_ollama(input)
		else
			utils.append_to_buffer(persistent_buf, { "Empty input" })
		end
	end, { buffer = persistent_buf, desc = "Submit prompt to Ollama" })
	M.stream_ollama("Say some greettings to the user who is just starting to work with you.")
	utils.move_cursor_to_end_of_buffer()
end

return M
