---@class FileStatObject
---@field filename string The name of the file
---@field mtime number When the file was last edited, in seconds since the unix epoch

---@class ScratchWindowContext
---@field buffer_id number The ID of the created buffer
---@field window_id number The ID of the created window

local Logger = require("quick-scratch.logger")
local logger = Logger:new()
local M = { ui = require("quick-scratch.ui"), fs = require("quick-scratch.fs") }

--- Configuration for the module
--- @class ScratchBufferConfig
--- @field scratch_root string Where all created scratch files should be stored. If this not overridden by the user, this will be the OS' 'temp' directory
--- @field default_file_extension string The file extension to assume when generating a scratch file on-the-fly. Defaults to "md" (markdown)
--- @field log_level logging_levels The logging level of the logger
--- @field float_window_style vim.api.keyset.win_config The arguments to pass to the float window
M.config = {
	scratch_root = M.fs.get_tmpdir(),
	-- TODO: Implement this, likely via passing it down to private funcs
	log_level = "OFF",
	default_file_extension = "md",
	float_window_style = M.ui.center_floating_window({
		relative = "editor",
		width = 80,
		height = 24,
		row = 5,
		col = 10,
		style = "minimal",
		border = "rounded",
	}),
}

--- Internal module state
--- @class ScratchBufferState
--- @field scratch_window_context ScratchWindowContext | nil The current context of the windows
--- @field last_buffer_pos number[] | nil The cursor position of the buffer. Used to restore it on toggle
M._state = {
	scratch_window_context = nil,
	last_buffer_pos = nil,
}

---Initialize the plugin
---@param opts ScratchBufferConfig The configuration to use for the module.
function M.setup(opts)
	local self = setmetatable({}, { __index = M })

	-- Merge user options on top of defaults for this instance
	self.config = vim.tbl_deep_extend("force", M.config, opts or {})

	logger:set_level(self.config.log_level)

	return self
end

--- Open the most recent scratch file
--- @param scratch_file? string The path to the file to open. If not provided, will open the most recent scratch file
function M.open(scratch_file)
	if scratch_file == nil then
		scratch_file =
			M.fs.get_latest_scratch_file(M.config.scratch_root, M.config.default_file_extension)
	end

	logger:log("Opening scratch file: " .. scratch_file)
	local scratch_window_context =
		M.ui.spawn_float_window(scratch_file, M.config.float_window_style, M._state.last_buffer_pos)

	if scratch_window_context ~= nil then
		logger:log(
			"Generated window context with buffer ID '"
				.. scratch_window_context.buffer_id
				.. "' and window ID '"
				.. scratch_window_context.window_id
				.. "'"
		)
		M._state.scratch_window_context = scratch_window_context
	end
end

--- Close the currently opened scratch window
function M.close()
	logger:log("Closing scratch window/buffer")
	local scratch_window_context = M._state.scratch_window_context

	if scratch_window_context ~= nil then
		-- Save the buffer
		vim.api.nvim_buf_call(scratch_window_context.buffer_id, function()
			vim.cmd("silent write!")
		end)
		-- Store the user's cursor position in state, for when they re-open it
		M._state.last_buffer_pos = vim.api.nvim_win_get_cursor(scratch_window_context.window_id)

		-- Close the window
		vim.api.nvim_win_close(scratch_window_context.window_id, true)
		logger:log("Deleted window ID '" .. scratch_window_context.window_id .. "'")
		-- Close the buffer
		vim.api.nvim_buf_delete(scratch_window_context.buffer_id, { force = true })
		logger:log("Deleted buffer ID '" .. scratch_window_context.buffer_id .. "'")
		M._state.scratch_window_context = nil
	end
end

--- Toggle the scratch window
function M.toggle()
	logger:log("Toggling scratch window/buffer")
	if M._state.scratch_window_context == nil then
		M.open()
	else
		M.close()
	end
end

--- Generate a new scratch file
--- @return string new_file_path The name of the generated file
function M.create()
	local user_chosen_name = vim.fn.input("Name for the new scratch file (leave blank for default): ")
	local new_scratch_filename

	if user_chosen_name == "" then
		new_scratch_filename = nil
	else
		new_scratch_filename = user_chosen_name
	end

	local scratch_dir = M.fs.get_scratch_dir(M.config.scratch_root)
	local scratch_file_path =
		M.fs.make_scratch_file(scratch_dir, M.config.default_file_extension, new_scratch_filename)

	return scratch_file_path
end

--- List the scratch files
function M.list()
	local scratch_dir = M.fs.get_scratch_dir(M.config.scratch_root)
	local file_list = M.fs.get_files_sorted_by_mtime(scratch_dir)

	M.ui.spawn_picker("telescope", file_list, M.open)
end

return M
