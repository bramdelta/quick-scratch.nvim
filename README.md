# Quick Scratch
A NeoVim plugin to provide a simple way to quickly jot down ideas in a scratch buffer.

## Installation (via Lazy)
Simply add this to your lazy plugins list to install it:
```lua
{
    "bramdelta/quick-scratch.nvim",
    opts = {}
}
```

## Default Configuration
By default, Quick Scratch assumes the following options:
```lua
--- Configuration for the module
--- @class ScratchBufferConfig
--- @field scratch_root string Where all created scratch files should be stored. If this not overridden by the user, this will be the OS' 'temp' directory
--- @field default_file_extension string The file extension to assume when generating a scratch file on-the-fly. Defaults to "md" (markdown)
--- @field picker_provider PickerTypes Which picker to use. See PickerTypes alias
--- @field log_level logging_levels The logging level of the logger
--- @field float_window_style vim.api.keyset.win_config The arguments to pass to the float window
opts = {
    -- This is like /tmp, if you don't care about your scratch buffers being persistent
    -- You could instead set this to a specific folder
	scratch_root = M.fs.get_tmpdir(),
	log_level = "OFF",
	default_file_extension = "md",
    -- This can be 'vim' | 'snacks' | 'mini' | 'telescope', depending on what picker you use
	picker_provider = "vim",
	float_window_style = M.ui.center_floating_window({
		relative = "editor",
		width = 80,
		height = 24,
		style = "minimal",
		border = "rounded",
	}),
}
```

To override any of these, simply update your `opts` in your Lazy:
```lua
{
    "bramdelta/quick-scratch.nvim",
    opts = {
        picker_provider = "snacks"
    }
}
```

## Example Usage
You can do something like this to map the plugin's functionality to specific keybinds:
```lua
-- st, Scratch toggle
vim.keymap.set("n", "<leader>st", scratch.toggle, { noremap = true, silent = true })
-- sl, Scratch list
vim.keymap.set("n", "<leader>sl", scratch.list, { noremap = true, silent = true })
-- sn, Scratch new
vim.keymap.set("n", "<leader>sn", scratch.create, { noremap = true, silent = true })
```
