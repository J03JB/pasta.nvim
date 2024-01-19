---@class pasta

local pasta = {}

---@alias pasta_mode
---| '"insert"' # Insert the register's contents like when in insert mode and pressing <C-R>.
---| '"paste"' # Insert the register's contents by pretending a pasting action, similar to pressing "*reg*p, cannot be used in insert mode.
---| '"motion"' # Create a motion from the register, similar to pressing "*reg* (without pasting it yet).

---@private
function pasta._read_registers()
  pasta._register_values = {}
  pasta._empty_registers = {}

  local rs = '*+"-/_=#%.0123456789abcdefghijklmnopqrstuvwxyz:'

  for i = 1, #rs do
    local register = rs:sub(i, i)
    local reg_info = vim.fn.getreginfo(register)

    -- The register contents as a single line
    if reg_info and reg_info.regcontents then
      local line = table.concat(reg_info.regcontents, "\n")
      local hide = false
      hide = #(line:match("^%s*(.-)%s*$")) == 0

      if hide then
        -- Place it in the empty registers
        pasta._empty_registers[#pasta._empty_registers + 1] = register
      elseif line and type(line) == "string" then
        -- Trim the whitespace if applicable
        line = line:match("^%s*(.-)%s*$")

        line = line
          -- Replace newline characters (win)
          :gsub("\r\n", "⏎")
          -- Replace newline characters (unix)
          :gsub("\n", "⏎")
          -- Replace newline characters (mac)
          :gsub("\r", "⏎")
          -- Replace tab characters
          :gsub("\t", ".")
          -- Replace space characters
          :gsub(" ", " ")

        reg_info.line = line
        pasta._register_values[#pasta._register_values + 1] = reg_info
      end
    else
      -- Place it in the empty registers
      pasta._empty_registers[#pasta._empty_registers + 1] = register
    end
  end

  -- print(vim.inspect(pasta._register_values))
  -- print(vim.inspect(pasta._empty_registers))
end

--TODO: Go though function and remove/ update bits.
---@private
---Fill the window's buffer.
function pasta._fill_window()
  -- Don't allow the buffer to be modified
  vim.bo[pasta._buffer].modifiable = true

  -- create array of lines for the registers
  local lines = {}
  for i in ipairs(lines) do
    lines[i] = lines:gsub("\n", "")
  end
  for i = 1, #pasta._register_values do
    local register = pasta._register_values[i]

    lines[i] = register.line
  end

  -- Write the lines to the buffer
  vim.api.nvim_buf_set_lines(pasta._buffer, 0, -1, false, lines)

  -- Create signs and highlights for the register itself
  -- for i = 1, #pasta._register_values do
  --   local register = pasta._register_values[i]

  --   local sign_text = register.register
  --   -- Add the register type symbol if applicable
  --   if registers.options.show_register_types then
  --     sign_text = sign_text .. register.type_symbol
  --   end

  --   -- Create signs for the register itself, and highlight the line
  --   vim.api.nvim_buf_set_extmark(pasta._buffer, pasta._namespace, i - 1, 0, {
  --     id = i,
  --     sign_text = sign_text,
  --     sign_hl_group = pasta._highlight_for_sign(register.register),
  --     cursorline_hl_group = pasta.options.sign_highlights.cursorline,
  --   })
  -- end

  -- Don't allow the buffer to be modified
  vim.bo[pasta._buffer].modifiable = false
end

---@private
---Create the window and the buffer.
function pasta._create_window()
  -- Keep track of the buffer from which the window is called
  pasta._preview_buffer = vim.api.nvim_get_current_buf()
  pasta._preview_window = vim.api.nvim_get_current_win()

  -- Fill the registers
  pasta._read_registers()

  -- Create the buffer the registers will be written to
  pasta._buffer = vim.api.nvim_create_buf(false, true)

  -- Remove the buffer when the window is closed
  vim.bo[pasta._buffer].bufhidden = "wipe"

  -- Set the filetype
  vim.bo[pasta._buffer].filetype = "pasta"

  -- The width is based on the longest line, but it will be truncated if the max width is supplied and is longer
  -- local window_width
  -- There is no max width supplied so use the longest registers length as the window size
  -- window_width = math.min(pasta._longest_register_length())

  -- Height is based on the amount of available registers
  local window_height = #pasta._register_values

  -- Create the floating window
  local window_options = {
    -- Place the window next to the cursor
    relative = "cursor",
    -- Remove all window decorations
    style = "minimal",
    -- location to anchor the window to
    anchor = "NW",
    -- Width of the window
    -- width = window_width,
    width = 100,
    -- Height of the window
    height = window_height,
    -- height = 10,
    -- Place the new window just under the cursor
    row = 1,
    col = 0,
    -- How the edges are rendered
    border = "rounded",
  }
  -- Make the window active when the window is not a preview
  pasta._window = vim.api.nvim_open_win(pasta._buffer, true, window_options)

  -- Register an autocommand to close the window if focus is lost
  local group = vim.api.nvim_create_augroup("RegistersWindow", {})
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    pattern = "<buffer>",
    callback = pasta._close_window,
  })

  -- Register an autocommand to trigger events when the cursor moves
  -- if type(registers.options.events.on_register_highlighted) == "function" then
  -- 	registers._previous_cursor_line = nil
  -- 	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  -- 		group = group,
  -- 		buffer = registers._buffer,
  -- 		callback = registers._cursor_moved,
  -- 	})
  -- end

  -- Make the buffer content cut-off instead of starting on new line
  vim.wo[pasta._window].wrap = false

  -- Show a column on the left for the register names
  vim.wo[pasta._window].signcolumn = "yes:2"

  -- Highlight the cursor line
  vim.wo[pasta._window].cursorline = true

  -- Add the colors
  -- pasta._define_highlights()

  -- Update the buffer
  pasta._fill_window()

  -- Apply the key bindings to the buffer
  -- pasta._set_bindings()

  -- -- Stop when the window is interrupted/
  -- if registers._is_interrupted() then
  -- 	registers._close_window()
  -- 	return
  -- end

  -- -- The creation of the window can't be interrupted at this point because the keys are already bound
  -- registers._key_interrupt_timer:close()
  -- registers._key_interrupt_timer = nil

  -- Ensure the window shows up
  vim.cmd("redraw!")

  -- -- Put the window in normal mode when using a visual selection
  -- if registers._previous_mode_is_visual() then
  -- 	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true), "n", true)
  -- end
end

---`require("registers").show_window({...})`
---@class show_window_options

---Popup the registers window.
---@param options? show_window_options Options for firing the callback.
---@return function callback Function that can be used to pass to configuration options with callbacks.
---@usage [[
----- Disable all key bindings
---require("registers").setup({ bind_keys = false })
---
----- Define a custom for opening the register window when pressing "r"
---vim.api.nvim_set_keymap("n", "r", "", {
---    -- The "paste" argument means that when a register is selected it will automatically be pasted
---    callback = require("registers").show_window({ mode = "paste" }),
---    -- This is required for the registers window to function
---    expr = true
---})
---@usage ]]
function pasta.show_window(options)
  options = vim.tbl_deep_extend("keep", options or {}, {
    mode = "motion",
  })

  return function()
    -- Mode before opening the popup window
    pasta._previous_mode = vim.api.nvim_get_mode().mode

    -- Store the mode which defaults to motion
    pasta._mode = options.mode

    -- Must be scheduled so the window can be created at the right moment
    pasta._create_window()
   end
end

---@private
---Handle the calling of the callback function based on the options, so things like delays can be added.
---@param options? callback_options Options to apply to the callback function.
---@param cb function Callback function to trigger.
---@return function callback Wrapped callback function applying the options.
---@nodiscard
function pasta._handle_callback_options(options, cb)
  -- Process the table arguments
  local if_mode = (options and options.if_mode) or { "paste", "insert", "motion" }
  -- Ensure it's always a table
  if type(if_mode) ~= "table" then
    if_mode = { if_mode }
  end
  local after = (options and options.after) or function() end

  -- Create the callback that's called with all checks and events
  local full_cb = function(...)
    -- Do nothing if we are not in the proper mode
    if not vim.tbl_contains(if_mode, pasta._mode) then
      return
    end

    -- Call the original callback
    cb(...)

    -- If we need to call a function after the callback also call that
    after()
  end

  return full_cb
end

---@private
function pasta._close_window()
  if pasta._window then
    vim.api.nvim_win_close(pasta._window, true)
    pasta._window = nil
  end
end

---Close the window.
---@param options? callback_options Options for firing the callback.
---@return function callback Function that can be used to pass to configuration options with callbacks.
function pasta.close_window(options)
  return pasta._handle_callback_options(options, pasta._close_window)
end

-- pasta._read_registers()
-- vim.api.nvim_set_keymap("n", "r", "", { callback = pasta.show_window({ mode = "motion" }), noremap = true, expr = true })
-- vim.api.nvim_set_keymap("i", "<C-u>", "", { callback = pasta.show_window(), noremap = true, expr = true })

pasta.show_window()


return pasta
