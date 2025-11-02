local M = {}

--- Get a filename from a path
--- For example, some/dir/file.md -> file.md
--- @param path string The path to the file to get the filename of
--- @return string filename The name of the file
local function _get_filename_from_path(path)
	return path:match("^.+/(.+)$") or path
end

--- Read a scratch path's contents
--- @param scratch_path string The path to the scratch path.
--- @return string[] | nil file_lines The contents of the scratch path. Nil if the operation failed.
local function _read_scratch_path(scratch_path)
	local file = io.open(scratch_path, "r")
	if not file then
		return nil
	end

	local lines = {}
	for line in file:lines() do
		table.insert(lines, line)
	end
	file:close()

	return lines
end

--- Deep copy a lua table
--- @generic T
--- @param original T The original table to copy
--- @return T copy The copied table
local function _deep_copy(original)
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = _deep_copy(v)
	end
	return copy
end

--- Spawn a snacks picker
--- @param picker_entries string[] The entries to popualte the picker with
local function _spawn_snacks_picker(picker_entries)
	local snacks = require("snacks")
	snacks.picker({
		title = "Scratches",
		finder = function()
			local file_entries = {}
			for _, file_path in ipairs(picker_entries) do
				local snacks_entry = {
					pos = { 1, 1 },
					file = file_path,
					text = _get_filename_from_path(file_path),
				}
				table.insert(file_entries, snacks_entry)
			end
			return file_entries
		end,
		win = {
			input = {
				keys = { ["dd"] = { "prompt_delete", mode = { "n", "x" } } },
			},
			list = {
				keys = { ["dd"] = { "prompt_delete", mode = { "n", "x" } } },
			},
		},
		actions = {
			prompt_delete = function(snacks_picker, _)
				local selected_items = snacks_picker:selected({ fallback = true })
				local item_count = #selected_items

				if item_count == 1 then
					local file_path = selected_items[1].file
					local user_choice = vim.fn.input("Delete file '" .. file_path .. "' from disk? [y/n]")
					if user_choice == "y" then
						os.remove(file_path)
					end
				else
					local user_choice =
						vim.fn.input("Delete the " .. item_count .. " selected files from disk? [y/n]")
					if user_choice == "y" then
						for _, removed_item in ipairs(selected_items) do
							os.remove(removed_item.file)
						end
					end
					-- Refresh the picker
					snacks_picker:find({ refresh = true })
				end
			end,
		},
	})
end

--- Spawn a picker of the specified type to the user
--- @param picker_type 'snacks' The picker type to spawn
--- @param picker_entries string[] The entries to populate in the picker
function M.spawn_picker(picker_type, picker_entries)
	if picker_type == "snacks" then
		_spawn_snacks_picker(picker_entries)
	end
end

--- Spawn a floating window with the contents of the scratch path inside it
--- @param scratch_path string The path to the scratch path
--- @param window_opts vim.api.keyset.win_config The options to use when making the float window
--- @return ScratchWindowContext | nil buffer_id The scratch context, nil if the operation failed
function M.spawn_float_window(scratch_path, window_opts)
	local file_lines = _read_scratch_path(scratch_path)

	if file_lines == nil then
		print("Error: Couldn't open file!")
		return nil
	end

	-- Create the buffer itself and put the lines in it
	local buf_id = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(buf_id, scratch_path)
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, file_lines)

	-- Trigger filetype detection on that buffer, so syntax highlighting works
	-- The view stuff is to get around other plugins intercepting the commands and attempting to
	-- restore the cursor position
	local view = vim.fn.winsaveview()
	vim.api.nvim_exec_autocmds("BufRead", { buffer = buf_id })
	vim.api.nvim_exec_autocmds("BufNewFile", { buffer = buf_id })
	vim.fn.winrestview(view)

	-- Add keybinds
	-- vim.api.nvim_buf_set_keymap(buf, "n", "w", ":w!<CR>", {})
	-- vim.api.nvim_buf_set_keymap(buf_id, "n", "q", ":silent wq!<CR>", { silent = true })

	-- Spawn the floating window
	local window_id = vim.api.nvim_open_win(buf_id, true, window_opts)

	-- This means nvim couldn't make the window properly
	if window_id == 0 then
		-- Clean up the useless buffer
		vim.api.nvim_buf_delete(buf_id, { force = true })
		return nil
	end

	return { buffer_id = buf_id, window_id = window_id }
end

--- Alter the provided window_opts to make it centered on the user's screen
--- @param window_opts vim.api.keyset.win_config The window options to base calcualations off
--- @return vim.api.keyset.win_config centered_window_opts The window options provided, centered
function M.center_floating_window(window_opts)
	local win_width = vim.api.nvim_win_get_width(0)
	local win_height = vim.api.nvim_win_get_height(0)
	local left_offset = math.floor((win_width - window_opts.width) / 2)
	local top_offset = math.floor((win_height - window_opts.height) / 2)

	local centered_window_opts = _deep_copy(window_opts)
	centered_window_opts.col = left_offset
	centered_window_opts.row = top_offset

	return centered_window_opts
end

return M
