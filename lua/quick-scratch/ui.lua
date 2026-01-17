local M = {}

--- @alias PickerTypes 'snacks' | 'vim' | 'telescope' | 'mini'

local PICKER_TITLE = "Scratches"

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
--- @param on_confirm fun(item: string) The callback fired when the picker's options are selected
local function _spawn_snacks_picker(picker_entries, on_confirm)
	local snacks = require("snacks")
	snacks.picker({
		title = PICKER_TITLE,
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
		confirm = function(snacks_picker, selected_item)
			snacks_picker:close()
			on_confirm(selected_item.file)
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
					local user_choice = vim.fn.input("Delete file '" .. file_path .. "' from disk? [y/n] ")
					if user_choice == "y" then
						os.remove(file_path)
						-- Refresh the picker
						snacks_picker:find({ refresh = true })
					end
				else
					local user_choice =
						vim.fn.input("Delete the " .. item_count .. " selected files from disk? [y/n]")
					if user_choice == "y" then
						for _, removed_item in ipairs(selected_items) do
							os.remove(removed_item.file)
						end
						-- Refresh the picker
						snacks_picker:find({ refresh = true })
					end
				end
			end,
		},
	})
end

--- Spawn Telescope's picker
--- @param picker_entries string[] The entries to popualte the picker with
--- @param on_confirm fun(item: string) The callback fired when the picker's options are selected
local function _spawn_telescope_picker(picker_entries, on_confirm)
	local telescope_pickers = require("telescope.pickers")
	local telescope_finders = require("telescope.finders")
	local telescope_actions = require("telescope.actions")
	local telescope_previewer = require("telescope.previewers").vim_buffer_cat.new({})

	telescope_pickers
		.new({}, {
			prompt_title = PICKER_TITLE,
			finder = telescope_finders.new_table({
				results = picker_entries,
			}),
			previewer = telescope_previewer,
			attach_mappings = function(prompt_bufnr, _)
				-- Override telescope's default action to do the callback
				telescope_actions.select_default:replace(function()
					local selected_scratches = require("telescope.actions.state").get_selected_entry()
					telescope_actions.close(prompt_bufnr)
					-- Assuming 1, not supporting multi-select
					on_confirm(selected_scratches[1])
				end)
				return true
			end,
		})
		:find()
end

--- Spawn mini.nvim's picker
--- @param picker_entries string[] The entries to popualte the picker with
--- @param on_confirm fun(item: string) The callback fired when the picker's options are selected
local function _spawn_mini_picker(picker_entries, on_confirm)
	local mini_picker = require("mini.pick")
	mini_picker.start({
		source = {
			items = picker_entries,
			name = PICKER_TITLE,
			choose = function(scratch_filename)
				mini_picker.stop()
				-- Needed to allow mini time to properly shut down, otherwise
				-- the scratch window won't get focus
				vim.defer_fn(function()
					on_confirm(scratch_filename)
				end, 0.5)
			end,
		},
	})
end

--- Spawn the built in vim.ui.select picker
--- @param picker_entries string[] The entries to popualte the picker with
--- @param on_confirm fun(item: string) The callback fired when the picker's options are selected
local function _spawn_vim_select_picker(picker_entries, on_confirm)
	vim.ui.select(picker_entries, {
		prompt = PICKER_TITLE,
	}, on_confirm)
end

--- Spawn a picker of the specified type to the user
--- @param picker_type PickerTypes The picker type to spawn
--- @param picker_entries string[] The entries to populate in the picker
--- @param on_confirm fun(item: string) The callback fired when the picker's options are selected
function M.spawn_picker(picker_type, picker_entries, on_confirm)
	if picker_type == "snacks" then
		_spawn_snacks_picker(picker_entries, on_confirm)
	elseif picker_type == "vim" then
		_spawn_vim_select_picker(picker_entries, on_confirm)
	elseif picker_type == "telescope" then
		_spawn_telescope_picker(picker_entries, on_confirm)
	elseif picker_type == "mini" then
		_spawn_mini_picker(picker_entries, on_confirm)
	end
end

--- Spawn a floating window with the contents of the scratch path inside it
--- @param scratch_path string The path to the scratch path
--- @param window_opts vim.api.keyset.win_config The options to use when making the float window
--- @param buffer_pos? number[] The position to put the cursor for the buffer
--- @return ScratchWindowContext | nil buffer_id The scratch context, nil if the operation failed
function M.spawn_float_window(scratch_path, window_opts, buffer_pos)
	local file_lines = _read_scratch_path(scratch_path)

	if file_lines == nil then
		print("Error: Couldn't open file!")
		return nil
	end

	-- Create the buffer itself and put the lines in it
	local buf_id = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(buf_id, scratch_path)
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, file_lines)
	vim.api.nvim_buf_set_var(buf_id, "is_scratch_buffer", true)

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

	-- Restore the user's position
	if buffer_pos ~= nil then
		vim.api.nvim_win_set_cursor(window_id, buffer_pos)
	end

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
