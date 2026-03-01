local utils = require("nvim-ollama.utils")
local log = require("nvim-ollama.log")

M = {}

function M.stream_ollama(prompt, buffer, window)
	utils.append_to_buffer(buffer, { "Asisstant: " })

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
				return
			end

			-- Ollama sends ND-JSON (one JSON object per line)
			for line in data:gmatch("[^\r\n]+") do
				local ok, decoded = pcall(vim.json.decode, line)
				if ok and decoded.response then
					-- Schedule UI updates on the main Neovim loop
					utils.append_to_buffer_text(buffer, decoded.response)
				end
			end
		end,
		stderr = function(_, data)
			log.log_error("stderr callback")
			if data then
				log.log_error("stderr data: " .. data)
				return
				-- utils.append_to_buffer(buffer, { data })
			end
		end,
	}, function()
		utils.append_to_buffer(buffer, { "User: " })
		utils.move_cursor_to_end_of_buffer(window)
	end)
end

function M.ask_ollama_async(prompt, buffer, window)
	-- Let user know AI is running
	utils.append_to_buffer(buffer, { "Asisstant: " })
	utils.move_cursor_to_end_of_buffer(window)

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
			utils.append_to_buffer(buffer, { "Error: Ollama request failed." })
			return
		end

		local success, data = pcall(vim.json.decode, out.stdout)
		if success and data.response then
			-- Split response by newline for nvim_buf_set_lines
			local lines = vim.split(data.response, "\n")
			utils.append_to_buffer(buffer, lines)
		else
			utils.append_to_buffer(buffer, { "Error: Failed to parse JSON." })
		end
	end)
	utils.append_to_buffer(buffer, { "User: " })
	utils.move_cursor_to_end_of_buffer(window)
end

return M
