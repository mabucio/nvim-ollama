local utils = require("nvim-ollama.utils")
local code_sug = require("nvim-ollama.code_suggestion")
local ollama = require("nvim-ollama.ollama")
local log = require("nvim-ollama.log")

local M = {}
-- Variables to keep track of our persistent state
M.buffer = nil
M.window = nil

function M.open_floating_window()
	-- Create a new empty buffer (not listed, scratch buffer)
	if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then
		M.buffer = vim.api.nvim_create_buf(false, true)
	end

	-- 2. If window is already open, just focus it and stop
	if M.window and vim.api.nvim_win_is_valid(M.window) then
		vim.api.nvim_set_current_win(M.window)
	else
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
		M.window = vim.api.nvim_open_win(M.buffer, true, opts)

		vim.api.nvim_create_autocmd("BufLeave", {
			buffer = M.buffer,
			once = true,
			callback = function()
				if M.window and vim.api.nvim_win_is_valid(M.window) then
					vim.api.nvim_win_close(M.window, true)
					M.window = nil -- Reset handle so we can reopen it
				end
			end,
		})
	end
	utils.move_cursor_to_end_of_buffer(M.window)
end

function M.stream_ollama(prompt)
	utils.append_to_buffer(M.buffer, { "Asisstant: " })

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
		"-H",
		"Content-Type: application/json",
	}, {
		-- This callback runs every time stdout receives data
		stdout = function(_, data)
			-- log.log_info("Ollama stream stdout callback")
			if not data then
				log.log_info("No data")
				utils.append_to_buffer_text(M.buffer, "Failed to get ollama response. Is Ollama running?")
				return
			end

			-- Ollama sends ND-JSON (one JSON object per line)
			for line in data:gmatch("[^\r\n]+") do
				local ok, decoded = pcall(vim.json.decode, line)
				if ok and decoded.response then
					-- Schedule UI updates on the main Neovim loop
					utils.append_to_buffer_text(M.buffer, decoded.response)
				end
			end
		end,
		stderr = function(_, data)
			log.log_error("stderr callback")
			if data then
				log.log_error("stderr data: " .. data)
				return
				-- utils.append_to_buffer(M.buffer, { data })
			end
		end,
	}, function()
		utils.append_to_buffer(M.buffer, { "User: " })
		utils.move_cursor_to_end_of_buffer(M.window)
	end)
end

function M.ask_ollama_async(prompt)
	-- Let user know AI is running
	utils.append_to_buffer(M.buffer, { "Asisstant: " })
	utils.move_cursor_to_end_of_buffer(M.window)

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
		utils.append_to_buffer(M.buffer, { "TEST TEST" })
		if out.code ~= 0 then
			utils.append_to_buffer(M.buffer, { "Error: Ollama request failed." })
			return
		end

		local success, data = pcall(vim.json.decode, out.stdout)
		if success and data.response then
			-- Split response by newline for nvim_buf_set_lines
			local lines = vim.split(data.response, "\n")
			utils.append_to_buffer(M.buffer, lines)
		else
			utils.append_to_buffer(M.buffer, { "Error: Failed to parse JSON." })
		end
	end)
	utils.append_to_buffer(M.buffer, { "User: " })
	utils.move_cursor_to_end_of_buffer(M.window)
end

function M.setup()
	code_sug.register_suggestions(ollama.generate_code_suggestion)
	vim.api.nvim_create_user_command("LLM", M.open_floating_window, {
		desc = "Open Chat with LLM.",
	})

	vim.api.nvim_create_user_command("LOG", log.open_log, {
		desc = "Open plugin log file",
	})

	M.buffer = vim.api.nvim_create_buf(false, true)
	utils.append_to_buffer(M.buffer, { "Initialized the plugin:" })
	vim.keymap.set("n", "<CR>", function()
		local input = utils.buf_to_str(M.buffer)

		-- Don't send empty lines
		if input ~= "" then
			ollama.stream_ollama(input, M.buffer, M.window)
		else
			utils.append_to_buffer(M.buffer, { "Empty input" })
		end
	end, { buffer = M.buffer, desc = "Submit prompt to Ollama" })
	ollama.stream_ollama("Say some greettings to the user who is just starting to work with you.", M.buffer, M.window)
	utils.move_cursor_to_end_of_buffer(M.window)
end

return M
