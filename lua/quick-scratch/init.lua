local quick_scratch = require("quick-scratch.main")

local M = {}

--- Configuration for the module
--- @class ScratchBufferConfig
--- @field scratch_root string | nil Where all created scratch files should be stored. If this not overridden by the user, this will be the OS' 'temp' directory
--- @field default_file_extension string The file extension to assume when generating a scratch file on-the-fly. Defaults to "md" (markdown)
--- @field picker_provider PickerTypes Which picker to use. See PickerTypes alias
--- @field log_level logging_levels The logging level of the logger
--- @field float_window_style vim.api.keyset.win_config The arguments to pass to the float window
M.config = {
	scratch_root = nil,
	log_level = "OFF",
	default_file_extension = "md",
	picker_provider = "vim",
	float_window_style = {
		relative = "editor",
		width = 80,
		height = 24,
		style = "minimal",
		border = "rounded",
	},
}

---Initialize the plugin
---@param opts ScratchBufferConfig The configuration to use for the module.
function M.setup(opts)
	local self = setmetatable({}, { __index = M })
	local config = vim.tbl_deep_extend("force", M.config, opts or {})

	quick_scratch:new(config)

	return self
end

--- Open the most recent scratch file
--- @param scratch_file? string The path to the file to open. If not provided, will open the most recent scratch file
function M.open(scratch_file)
	quick_scratch:open(scratch_file)
end

--- Close the currently opened scratch window
function M.close()
	quick_scratch:close()
end

--- Toggle the scratch window
function M.toggle()
	quick_scratch:toggle()
end

--- Generate a new scratch file
--- @return string new_file_path The name of the generated file
function M.create()
	return quick_scratch:create()
end

--- List the scratch files
function M.list()
	quick_scratch:list()
end

return M
