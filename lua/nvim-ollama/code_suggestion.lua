local log = require("nvim-ollama.log")

M = {}

M.ns_id = 0
M.current_suggestion = ""

-- Function to show the shadow text
local function show_suggestion(text)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local col = cursor[2]
	M.current_suggestion = text
	log.log_info("Current suggestion = " .. M.current_suggestion)

	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" then
		return -- Abort: User left Insert mode
	end

	vim.api.nvim_buf_set_extmark(0, M.ns_id, line - 1, col, {
		virt_text = { { M.current_suggestion, "NvimOllamaCustomGhost" } },
		virt_text_pos = "inline",
		hl_mode = "replace",
	})
end

-- Function to clear the shadow text
local function clear_suggestion()
	vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
	M.current_suggestion = ""
end

local function accept_suggestion()
	if M.current_suggestion ~= "" then
		-- Insert the suggestion text into the line
		vim.api.nvim_put({ M.current_suggestion }, "c", false, true)
		clear_suggestion()
	end
end

local function setup_hl()
	local non_text_hl = vim.api.nvim_get_hl(0, { name = "NonText", link = false })
	-- vim.api.nvim_set_hl(0, "MyCustomGhost", { fg = non_text_hl.fg, italic = true })
	vim.api.nvim_set_hl(
		0,
		"NvimOllamaCustomGhost",
		{ fg = non_text_hl.fg or "gray", italic = true, blend = 30, force = true }
	)
end

local function should_suggest()
	-- 1. Check filetype blacklist
	local blacklist = { "TelescopePrompt", "NvimTree", "neo-tree", "notify", "packer", "lazy" }
	local ft = vim.bo.filetype
	for _, name in ipairs(blacklist) do
		if ft == name then
			return false
		end
	end

	-- 2. Check buftype (ignore terminals, help files, etc.)
	local bt = vim.bo.buftype
	if bt ~= "" then
		return false
	end -- "prompt", "terminal", "nofile" are caught here

	-- 3. Check if window is floating
	local config = vim.api.nvim_win_get_config(0)
	if config.relative ~= "" then
		return false
	end

	return true
end

function M.register_suggestions(func_generate_suggestion)
	M.ns_id = vim.api.nvim_create_namespace("no_ghost_text")

	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = setup_hl,
	})
	setup_hl()

	vim.api.nvim_create_autocmd("InsertLeave", {
		callback = function()
			-- Use the function we created earlier to wipe the namespace
			clear_suggestion()
		end,
	})

	-- Trigger suggestions automatically when text changes in Insert mode
	vim.api.nvim_create_autocmd("TextChangedI", {
		callback = function()
			if not should_suggest() then
				log.log_info("Shouldn't add suggestion in this window")
				return
			end
			clear_suggestion()
			vim.defer_fn(function()
				-- Logic to decide WHAT to suggest goes here
				clear_suggestion()
				utils.async(function()
					local suggestion = func_generate_suggestion()
					if suggestion then
						show_suggestion(suggestion)
					end
				end)
			end, 1000)
		end,
	})

	-- Map the "Accept" key
	vim.keymap.set("i", "`", accept_suggestion, { desc = "Accept ghost text" })

	-- Clear suggestion if user leaves Insert mode
	vim.api.nvim_create_autocmd("InsertLeave", { callback = clear_suggestion })
end

return M
