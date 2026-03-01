M = {}

local log_path = vim.fn.stdpath("log") .. "/ollama_plugin.log"

function M.log_error(msg)
	local time = os.date("%Y-%m-%d %H:%M:%S")
	vim.schedule(function()
		local f = io.open(log_path, "a")
		if f then
			f:write(string.format("[%s] ERROR: %s\n", time, msg))
			f:close()
		end
	end)
end

function M.log_info(msg)
	local time = os.date("%Y-%m-%d %H:%M:%S")
	vim.schedule(function()
		local f = io.open(log_path, "a")
		if f then
			f:write(string.format("[%s] INFO: %s\n", time, msg))
			f:close()
		end
	end)
end

function M.open_log()
	vim.cmd("edit " .. log_path)
end

return M
