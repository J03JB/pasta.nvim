# Pasta.nvim

**Pasta.nvim** is a Neovim plugin that provides an enhanced visual interface for interacting with your editor registers. It allows you to easily view, select, and apply register contents in various modes.

![image](assets/pasta_nvim_screenshot.png)

## ✨ Features

- **Visual Register Listing:** Displays all populated registers in a floating window.
- **Intuitive Selection:** Easily navigate and select registers using standard Neovim motions (by default, or configure as needed).
- **Multiple Application Modes:**
  - **Insert Mode:** Pastes the register content directly, similar to `<C-R><reg>`.
  - **Paste Mode:** Applies the register content as a paste operation (e.g., `p`, `P`), suitable for normal or visual mode.
  - **Motion Mode:** Uses the selected register for a motion (e.g., `"<reg>d`, `"<reg>y`), useful when you want to specify the register before an operator.
- **Live Preview:** Shows a preview of the highlighted register's content as virtual text in the buffer where the plugin was invoked.
- **Customizable Keybindings:**
  - Define global keybindings to open the Pasta window.
  - Customize keybindings within the Pasta window for actions like applying a register, closing the window, etc.
- **Syntax Highlighting:**
  - Highlights special characters (newlines, tabs) within register previews for better readability.
  - Differentiates register types (e.g., selection, default, named, history) with distinct highlight groups, all configurable.
- **User Command:** `:Pasta` command to open the register window (defaults to "paste" mode).
- **Informative Footer:** Displays empty registers.

## ⚡️ Requirements

- Neovim (0.11+ recommended).

## 💾 Installation

You can install Pasta.nvim using your favorite plugin manager.

**lazy.nvim:**

```lua

{
  'J03JB/pasta.nvim',
  config = function()
    require('pasta').setup({})
  end,
}
```

🚀 Usage

Pasta.nvim aims to be intuitive. Once installed and set up, you can open the register window using the default keybindings (or your custom ones).

Default Global Keybindings:

    " in Normal Mode: Opens the Pasta window, configured to paste the selected register's content (like "<reg>p).
    " in Visual Mode: Opens the Pasta window, configured to use the selected register for a motion (e.g., to yank the visual selection into the chosen register "<reg>y).
    <C-R> in Insert Mode: Opens the Pasta window, configured to insert the selected register's content.

Command:

    :Pasta: Opens the Pasta window in "paste" mode.

Inside the Pasta Window:

    Navigation: Use j, k (or arrow keys) to move up and down the list of registers.
    Selection & Application:
        Pressing the key corresponding to a register (e.g., a, 0, *) will apply that register based on the mode Pasta was opened in.
        Pressing <CR> (Enter) on a highlighted register will apply it.
    Closing:
        Pressing <Esc> closes the Pasta window.

As you move the cursor in the Pasta window, a preview of the highlighted register's content will appear as virtual text at your cursor position in the original buffer.
⚙️ Configuration

You can customize Pasta.nvim by passing a configuration table to the setup() function.
Lua

require('pasta').setup({
-- Global keybindings to open the Pasta window
bind_keys = {
normal = function() require('pasta').show_window({ mode = "paste" }) end, -- Default: paste mode
visual = function() require('pasta').show_window({ mode = "motion" }) end,
insert = function() require('pasta').show_window({ mode = "insert" }) end,
-- Disable a binding
-- visual = false,

    -- Keybindings within the Pasta window
    registers = function(register, mode) require('pasta').apply_register() end, -- Action for pressing a register key (e.g., 'a', '0')
    ["<CR>"] = function(register, mode) require('pasta').apply_register() end,  -- Action for <CR>
    ["<Esc>"] = function(register, mode) require('pasta').close_window() end,   -- Action for <Esc>

    -- Add custom keybindings for the Pasta window
    -- ["<C-d>"] = function() print("Debug!") end,
    -- ["d"] = function(register, mode)
    --   -- Custom action for pressing 'd' in the pasta window
    --   -- For example, delete the register content (you'd need to implement P.delete_register)
    --   -- require('pasta').delete_register(nil, mode)
    --   -- then close
    --   require('pasta').close_window()
    -- end,

    -- Note: Deprecated keys like 'return_key', 'escape', 'ctrl_n', etc. are handled by
    -- directly mapping keys like "<CR>", "<Esc>" as shown above.
    -- The default bindings for <C-n>, <C-p>, <C-j>, <C-k>, <Del>, <BS> are commented out
    -- in the plugin's internal defaults but can be re-enabled here if desired,
    -- pointing them to appropriate functions (e.g., P.move_cursor_down(), P.clear_highlighted_register() -
    -- these specific functions would need to be exposed or re-implemented if you want them).

},

-- Customize highlight groups for register types in the Pasta window
sign*highlights = {
cursorline = "Visual", -- Highlight for the cursor line in Pasta window
selection = "Constant", -- For `*`, `+` registers
default = "Function", -- For `"` register
unnamed = "Statement", -- For `\` register (if used/shown, typically `"` is the unnamed)
read_only = "Type", -- For `:.%` registers
alternate_buffer = "Operator",-- For `#` register
expression = "Exception", -- For `=` register
black_hole = "Error", -- For `*`register
    last_search = "Tag",          -- For`/`register
    delete = "Special",           -- For`-`register (small delete)
    yank = "Delimiter",           -- For`0`register (yank register)
    history = "Number",           -- For`1-9`registers (numbered history)
    named = "Todo",               -- For`a-z` registers (named registers)

    -- Internal highlights (usually don't need changing unless your colorscheme has issues)
    cursorlinesign = "CursorLine",
    signcolumn = "SignColumn",

}
})

bind_keys Options

The bind_keys table allows you to customize how Pasta.nvim is invoked and how you interact with its window.

    normal: (Function | false) Function to map to " in normal mode. Set to false to disable.
        Default: require('pasta').show_window({ mode = "paste" })
    visual: (Function | false) Function to map to " in visual mode. Set to false to disable.
        Default: require('pasta').show_window({ mode = "motion" })
    insert: (Function | false) Function to map to <C-R> in insert mode. Set to false to disable.
        Default: require('pasta').show_window({ mode = "insert" })
    registers: (Function) Function to call when a register key (e.g., a, 0, *) is pressed in the Pasta window.
        Receives register: string, mode: P_mode as arguments.
        Default: require('pasta').apply_register()
    <key>: (Function | false) You can add any other key (e.g., "<CR>", "<Esc>", "<C-j>") and assign a function to it for custom behavior within the Pasta window.
        The function will receive register: string (the currently selected register symbol, or nil if none relevant) and mode: P_mode (the mode Pasta was opened with).
        Example: ["<Esc>"] = require('pasta').close_window()

sign_highlights Options

This table maps logical register categories to Neovim highlight groups. You can change these to better fit your colorscheme. Refer to :help highlight-groups for standard Neovim highlight groups.
P_mode (Pasta Modes)

When calling show_window or defining actions, you specify a P_mode:

    "insert": Inserts the register's contents directly, like <C-R><reg> in insert mode.
    "paste": Applies the register's contents as a paste operation (e.g., p or P). This is useful in normal or visual modes.
    "motion": Uses the selected register for a motion. For example, if you open Pasta in "motion" mode, select register a, then after Pasta closes, typing d would effectively be "ad.

🛠️ API

Pasta.nvim exposes a few functions that can be used in your custom keybindings or for more advanced integrations:

    require('pasta').show_window(options)
        Opens the Pasta window.
        options: A table, e.g., { mode = "insert" | "paste" | "motion" }.
    require('pasta').apply_register(options)
        Applies the currently selected register (or a specified one).
        options: A table, can include:
            mode: P_mode to override the mode Pasta was opened with.
            keep_open_until_keypress: boolean, if true and in "motion" mode, keeps the window open until another key is pressed (e.g., for "<reg>d the d would be the key).
        Typically used as a callback.
    require('pasta').close_window(options)
        Closes the Pasta window.
        options: (Optional) Can include after (a callback function) or if_mode (to only close if in a specific mode).
        Typically used as a callback.

Refer to the source code for detailed arguments and behaviors of these functions.

TODO
   -  User settings for window dimensions, position, border style.
   -  Option to show/hide empty registers or filter registers.
   -  More robust handling for clear_highlighted_register (if re-enabled by user).
   -  Consider if move_cursor_down/up functions should be part of the public API for custom keybindings.

📜 License

This plugin is licensed under the MIT License. See the LICENSE file for details.
