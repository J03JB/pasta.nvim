--@class ConfigModule
--@field defaults Config: default options
--@field options Config: config table extending defaults

---`require("registers").setup({...})`
---@class options
---@field show string Which registers to show and in what order. Default is `"*+\"-/_=#%.0123456789abcdefghijklmnopqrstuvwxyz:"`.
---@field bind_keys bind_keys_options|boolean Which keys to bind, `true` maps all keys and `false` maps no keys.
---@field symbols symbols_options Symbols used to replace text in the previous buffer.
---@field sign_highlights sign_highlights_options Highlights for the sign section of the window
local M = {}

---@return options options
local Defaults = {
  bind_keys = {
    -- Show the window when pressing " in normal mode, applying the selected register as part of a motion, which is the default behavior of Neovim
    -- normal = .show_window({ mode = "motion" }),
    -- Show the window when pressing " in visual mode, applying the selected register as part of a motion, which is the default behavior of Neovi
    visual = show_window({ mode = "motion" }),
    -- Show the window when pressing <C-R> in insert mode, inserting the selected register, which is the default behavior of Neovim
    insert = show_window({ mode = "insert" }),

    -- Immediately apply the selected register line when pressing the return key
    ["<CR>"] = apply_register(),
    -- Close the  window when pressing the Esc key
    ["<Esc>"] = close_window(),
    -- Move the cursor in the  window down when pressing <C-n>
    ["<C-n>"] = move_cursor_down(),
    -- Move the cursor in the  window up when pressing <C-p>
    ["<C-p>"] = move_cursor_up(),
    -- Move the cursor in the  window down when pressing <C-j>
    ["<C-j>"] = move_cursor_down(),
    -- Move the cursor in the  window up when pressing <C-k>
    ["<C-k>"] = move_cursor_up(),
    -- Clear the register of the highlighted line when pressing <DeL>
    ["<Del>"] = clear_highlighted_register(),
    -- Clear the register of the highlighted line when pressing <BS>
    ["<BS>"] = clear_highlighted_register(),
  },
}

M.options = {}


function Defaults:set(options)
    if options then
        self.options = vim.tbl_extend("keep", options, self.options)
    end
    return self
end
---Get the config
--@return CommentConfig
---@usage `require('Comment.config'):get()`
function Defaults:get()
    return self.options
end

---Format the defaults options table for documentation
---@return table
M.__format_keys = function()
  local tbl = vim.split(vim.inspect(Defaults), "\n")
  table.insert(tbl, 1, "<pre>")
  table.insert(tbl, 2, "Defaults: ~")
  table.insert(tbl, #tbl, "</pre>")
  return tbl
end

return Defaults
