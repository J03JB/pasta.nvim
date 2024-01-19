---@class ConfigModule
---@field defaults Config: default options
---@field options Config: config table extending defaults
local M = {}

M.defaults = {
  bind_keys = {
    -- Show the window when pressing " in normal mode, applying the selected register as part of a motion, which is the default behavior of Neovim
    -- normal = .show_window({ mode = "motion" }),
    -- Show the window when pressing " in visual mode, applying the selected register as part of a motion, which is the default behavior of Neovim
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

---@class Config
---@field bind_keys function: maps keys to aciton
M.options = {}

--- We will not generate documentation for this function
--- because it has `__` as prefix. This is the one exception
--- Setup options by extending defaults with the options proveded by the user
---@param options Config: config table
M.__setup = function(options)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, options or {})
end

---Format the defaults options table for documentation
---@return table
M.__format_keys = function()
  local tbl = vim.split(vim.inspect(M.defaults), "\n")
  table.insert(tbl, 1, "<pre>")
  table.insert(tbl, 2, "Defaults: ~")
  table.insert(tbl, #tbl, "</pre>")
  return tbl
end

-- M.registers = function ()
--     local registers = '*+"-/_=#%.0123456789abcdefghijklmnopqrstuvwxyz:',
--     for i = 1, #registers do
--         registers:sub(i, i)
--     end
-- end



return M
