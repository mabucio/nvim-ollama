cs = {}

cs.ns_id = vim.api.nvim_create_namespace("my_ghost_text")
cs.current_suggestion = ""

-- Function to show the shadow text
local function show_suggestion(text)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local col = cursor[2]
	cs.current_suggestion = text

	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" then
		return -- Abort: User left Insert mode
	end

	vim.api.nvim_buf_set_extmark(0, cs.ns_id, line - 1, col, {
		virt_text = { { cs.current_suggestion, "NvimOllamaCustomGhost" } },
		virt_text_pos = "inline",
		hl_mode = "replace",
	})
end

-- Function to clear the shadow text
local function clear_suggestion()
	vim.api.nvim_buf_clear_namespace(0, cs.ns_id, 0, -1)
	cs.current_suggestion = ""
end

local function accept_suggestion()
	if cs.current_suggestion ~= "" then
		-- Insert the suggestion text into the line
		vim.api.nvim_put({ cs.current_suggestion }, "c", false, true)
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

function cs.register_suggestions()
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
			clear_suggestion()
			vim.defer_fn(function()
				-- Logic to decide WHAT to suggest goes here
				clear_suggestion()
				local suggestion = "suggestion"
				show_suggestion(suggestion)
			end, 1000)
		end,
	})

	-- Map the "Accept" key
	vim.keymap.set("i", "`", accept_suggestion, { desc = "Accept ghost text" })

	-- Clear suggestion if user leaves Insert mode
	vim.api.nvim_create_autocmd("InsertLeave", { callback = clear_suggestion })
end

return cs
