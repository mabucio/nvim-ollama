local utils = require("nvim-ollama.utils")
local log = require("nvim-ollama.log")

M = {}

-- Used to track code suggestion handles
M.active_handle = nil
M.request_id = 0

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

function M.ask_ollama_async(prompt)
	-- Let user know AI is running
	-- utils.append_to_buffer(buffer, { "Asisstant: " })
	-- utils.move_cursor_to_end_of_buffer(window)

	local obj = {
		model = "qwen2.5-coder:14b",
		prompt = prompt,
		stream = false,
	}

	if M.active_handle then
		M.active_handle:kill(9)
		M.active_handle = nil
	end
	local co = coroutine.running()

	M.request_id = M.request_id + 1
	local my_id = M.request_id
	-- Use vim.system (Non-blocking)
	local handle = vim.system({
		"curl",
		"-s",
		"-X",
		"POST",
		"http://localhost:11434/api/generate",
		"-d",
		vim.json.encode(obj),
	}, { text = true }, function(out)
		vim.schedule(function()
			if my_id ~= M.request_id then
				log.log_info("request_id " .. my_id .. " ignored")
				return ""
			end
			log.log_info("MACIEKTEST")
			-- This callback runs when the process finishes
			if out.code ~= 0 then
				log.log_error("ask_ollama_async: Ollama request failed.")
				return ""
			end

			local success, data = pcall(vim.json.decode, out.stdout)
			if success and data.response then
				log.log_info("Suggestion: " .. data.response)
				coroutine.resume(co, data.response)
			else
				log.log_error("ask_ollama_async: Failed to parse JSON")
				coroutine.resume(co, "")
			end
		end)
	end)
	M.active_handle = handle
	return coroutine.yield()
	-- utils.append_to_buffer(buffer, { "User: " })
	-- utils.move_cursor_to_end_of_buffer(window)
end

function M.generate_code_suggestion()
	log.log_info("generate_code_suggestion")
	local prompt =
		"Your job is to generate code suggestion for current or next line code based on the file name and last lines of code shared in this prompt. Your output should be in json format where you put your thinking process in the _thinking field and code in output. Example: {'_thinking': 'This file is called init.lua and code snippet in prompt resembles Lua programming language so I should suggest lua code. Last line of code snippet is a comment saying 'this function should add two numbers' so I'm going to generate code adding two numbers', 'output': 'function add_numbers(a, b) return a+b end'''"

	prompt = prompt .. "\n<file_name>\n" .. utils.get_filename() .. "\n</file_name>"
	prompt = prompt .. "\n<code_snippet>\n" .. utils.get_lines_above_cursor(10) .. "\n</code_snippet>"
	prompt = prompt .. "<rules>\n"
	prompt = prompt .. "1. You have to generate json in proper format with two fields only: thinking and output.\n"
	prompt = prompt
		.. "2. When outputting JSON, return ONLY raw JSON as the entire response body. Do NOT wrap it in Markdown code fences, backticks. Do NOT add any surrounding keys or wrapers.\n"
	prompt = prompt .. "3. The first non-whitespace character of the response must be { and last must be }.\n"
	prompt = prompt .. "\n</rules>"

	local co = coroutine.running()
	local jsonString = M.ask_ollama_async(prompt)
	log.log_info("jsonString: " .. jsonString)

	vim.schedule(function()
		local success, data = pcall(vim.json.decode, jsonString)
		if not success then
			log.log_error("Failed to parse JSON: " .. data)
			coroutine.resume(co, "")
			return ""
		else
			-- Extract the 'output' field as a string
			-- log.log_info("data[0]:\n" .. data[0] .. "\ndata[1]:\n" .. data[1])
			log.log_info("data.output: " .. data.output)
			coroutine.resume(co, data.output)
		end
	end)

	return coroutine.yield()
end

return M
