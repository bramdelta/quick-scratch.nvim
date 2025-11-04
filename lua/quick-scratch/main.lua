---@class FileStatObject
---@field filename string The name of the file
---@field mtime number When the file was last edited, in seconds since the unix epoch

---@class ScratchWindowContext
---@field buffer_id number The ID of the created buffer
---@field window_id number The ID of the created window

local Logger = require("quick-scratch.logger")
local logger = Logger:new()
local M = { ui = require("quick-scratch.ui"), fs = require("quick-scratch.fs") }

--- Internal module state
--- @class ScratchBufferState
--- @field scratch_window_context ScratchWindowContext | nil The current context of the windows
--- @field last_buffer_pos number[] | nil The cursor position of the buffer. Used to restore it on toggle
M._state = {
	scratch_window_context = nil,
	last_buffer_pos = nil,
}

function M:new(opts)
	-- Merge user options on top of defaults for this instance
	-- self.config = vim.tbl_deep_extend("force", M.config, opts or {})
	self.config = opts
	self._state = M._state

	-- Recenter the window, so if the user changed it, it'll be centered
	self.config.float_window_style = self.ui.center_floating_window(self.config.float_window_style)

	if self.config.scratch_root == nil then
		self.config.scratch_root = self.fs.get_tmpdir()
	end

	logger:set_level(self.config.log_level)
end

--- Open the most recent scratch file
--- @param scratch_file? string The path to the file to open. If not provided, will open the most recent scratch file
function M:open(scratch_file)
	if scratch_file == nil then
		scratch_file =
			self.fs.get_latest_scratch_file(self.config.scratch_root, self.config.default_file_extension)
	end

	logger:log("Opening scratch file: " .. scratch_file)
	local scratch_window_context = self.ui.spawn_float_window(
		scratch_file,
		self.config.float_window_style,
		self._state.last_buffer_pos
	)

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
function M:close()
	logger:log("Closing scratch window/buffer")
	local scratch_window_context = self._state.scratch_window_context

	if scratch_window_context ~= nil then
		-- Save the buffer
		vim.api.nvim_buf_call(scratch_window_context.buffer_id, function()
			vim.cmd("silent write!")
		end)
		-- Store the user's cursor position in state, for when they re-open it
		self._state.last_buffer_pos = vim.api.nvim_win_get_cursor(scratch_window_context.window_id)

		-- Close the window
		vim.api.nvim_win_close(scratch_window_context.window_id, true)
		logger:log("Deleted window ID '" .. scratch_window_context.window_id .. "'")
		-- Close the buffer
		vim.api.nvim_buf_delete(scratch_window_context.buffer_id, { force = true })
		logger:log("Deleted buffer ID '" .. scratch_window_context.buffer_id .. "'")
		self._state.scratch_window_context = nil
	end
end

--- Toggle the scratch window
function M:toggle()
	logger:log("Toggling scratch window/buffer")
	if self._state.scratch_window_context == nil then
		self:open()
	else
		self:close()
	end
end

--- Generate a new scratch file
--- @return string new_file_path The name of the generated file
function M:create()
	local user_chosen_name = vim.fn.input("Name for the new scratch file (leave blank for default): ")
	local new_scratch_filename

	if user_chosen_name == "" then
		new_scratch_filename = nil
	else
		new_scratch_filename = user_chosen_name
	end

	local scratch_dir = self.fs.get_scratch_dir(self.config.scratch_root)
	local scratch_file_path =
		self.fs.make_scratch_file(scratch_dir, self.config.default_file_extension, new_scratch_filename)

	return scratch_file_path
end

--- List the scratch files
function M:list()
	local scratch_dir = self.fs.get_scratch_dir(self.config.scratch_root)
	local file_list = self.fs.get_files_sorted_by_mtime(scratch_dir)

	self:close()
	self.ui.spawn_picker(self.config.picker_provider, file_list, self.open)
end

return M
