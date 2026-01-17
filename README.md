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
--- @field scratch_root string | nil Where all created scratch files should be stored. If this not overridden by the user, this will be the OS' 'temp' directory
--- @field default_file_extension string The file extension to assume when generating a scratch file on-the-fly. Defaults to "md" (markdown)
--- @field picker_provider PickerTypes Which picker to use. See PickerTypes alias
--- @field log_level logging_levels The logging level of the logger
--- @field float_window_style vim.api.keyset.win_config The arguments to pass to the float window
opts = {
    -- Use /tmp for storing scratches
    scratch_root = nil,
    -- Or, if you'd rather them be persistent
    -- scratch_root = os.getenv("HOME") .. "/notes-dir",
    log_level = "OFF",
    default_file_extension = "md",
    -- This can be "vim" | "snacks" | "mini" | "telescope", depending on what picker you use
    picker_provider = "vim",
    float_window_style = {
	relative = "editor",
	width = 80,
	height = 24,
	style = "minimal",
	border = "rounded",
    },
}
```

To override any of these, simply update your `opts` in your Lazy:
```lua
{
    "bramdelta/quick-scratch.nvim",
    ---@type ScratchBufferConfig
    opts = {
	-- This will use snacks as the picker instead, with the omitted options using the defaults above
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
## Determining Scratch Buffer Status Programmatically

Say you have a bit of code like this, that lints on buffer write:

```lua
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
 callback = function()
   require("lint").try_lint()
 end,
})
```

If your lint plugin tries to run on a scratch buffer, you'll run into problems since the buffer it's targeting no longer exists. This is due to the plugin firing a write on the buffer's content, followed by deleting the buffer.

All scratch buffers created by this plugin bear a buffer-scoped variable called `is_scratch_buffer` set to `true`. So, you can modify your callback to check for this prior to running your commands, provided they're not meant to run on the scratch buffer:

```lua
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
 callback = function(opts)
  -- Checking true directly since this returns "" otherwise
  local is_scratch_buffer = vim.fn.getbufvar(opts.buf, "is_scratch_buffer") == true
  if not is_scratch_buffer then
   require("lint").try_lint()
   vim.cmd(":FormatWrite")
  end
 end,
})
```

