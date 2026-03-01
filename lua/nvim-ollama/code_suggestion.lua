cs = {}

cs.ns_id = vim.api.nvim_create_namespace("my_ghost_text")
cs.current_suggestion = ""
-- Function to show the shadow text
local function show_suggestion(text)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local col = cursor[2]
	cs.current_suggestion = text

	vim.api.nvim_buf_set_extmark(0, cs.ns_id, line - 1, col, {
		virt_text = { { text, "Comment" } }, -- Use "Comment" hl group for grey text
		virt_text_pos = "inline",
		hl_mode = "combine",
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

function cs.register_suggestions()
	-- Trigger suggestions automatically when text changes in Insert mode
	vim.api.nvim_create_autocmd("TextChangedI", {
		callback = function()
			clear_suggestion()
			-- Logic to decide WHAT to suggest goes here
			local suggestion = "suggestion"
			show_suggestion(suggestion)
		end,
	})

	-- Map the "Accept" key
	vim.keymap.set("i", "`", accept_suggestion, { desc = "Accept ghost text" })

	-- Clear suggestion if user leaves Insert mode
	vim.api.nvim_create_autocmd("InsertLeave", { callback = clear_suggestion })
end

return cs
-- code_sug = {}
--
-- code_sug.last_insert_time = nil
-- -- Function to show the code suggestion
-- local function show_code_suggestion()
-- 	local bufnr = vim.api.nvim_get_current_buf()
-- 	local cursor_pos = vim.api.nvim_win_get_cursor(0)
--
-- 	-- Create a floating window for the suggestion
-- 	local win_id = vim.api.nvim_open_win(bufnr, false, {
-- 		relative = "cursor",
-- 		row = 1,
-- 		col = 0,
-- 		width = 10,
-- 		height = 1,
-- 		style = "minimal",
-- 		border = "single",
-- 	})
--
-- 	-- Display the suggestion
-- 	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "TEST TEST" })
--
-- 	-- Function to handle key press for accepting the suggestion
-- 	local function on_keypress(char)
-- 		if char == "`" then
-- 			-- Insert the suggestion at the cursor position
-- 			vim.api.nvim_win_close(win_id, true)
-- 			vim.fn.setline(
-- 				cursor_pos[1],
-- 				vim.fn.getline(cursor_pos[1]):sub(1, cursor_pos[2] - 1)
-- 					.. "TEST TEST"
-- 					.. vim.fn.getline(cursor_pos[1]):sub(cursor_pos[2])
-- 			)
-- 		end
-- 	end
--
-- 	-- Start listening for key presses in the suggestion window
-- 	vim.api.nvim_create_autocmd("TextChanged", {
-- 		buffer = bufnr,
-- 		callback = function()
-- 			local char = vim.fn.getcharstr()
-- 			on_keypress(char)
-- 		end,
-- 	})
-- end
--
-- function code_sug.register_code_suggestions()
-- 	-- Function to track user typing and show suggestion after delay
-- 	code_sug.last_insert_time = os.time()
-- 	vim.api.nvim_create_autocmd("TextChangedI", {
-- 		callback = function()
-- 			current_time = os.time()
-- 			vim.defer_fn(function()
-- 				if os.difftime(current_time, code_sug.last_insert_time) > 1 then
-- 					show_code_suggestion()
-- 				end
-- 			end, 1000)
-- 		end,
-- 	})
-- end
--
-- return code_sug
