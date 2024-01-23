---@class P
---@field private _register_values { regcontents: string, line: string, register: string, type_symbol?: string, regtype: string }[]
--@field private _namespace string
---@field private _empty_registers string[]
---@field private _window? integer
---@field private _buffer? integer
---@field private _preview_buffer? integer
---@field private _preview_window? integer
---@field private _previous_mode string
local P = {}

---@class bind_keys_options
---@field normal fun()|false Function to map to " in normal mode to display the registers window, `false` to disable the binding. Default is `registers.show_window({ mode = "motion" })`.
---@field visual fun()|false Function to map to " in visual mode to display the registers window, `false` to disable the binding. Default is `registers.show_window({ mode = "motion" })`.
---@field insert fun()|false Function to map to <C-R> in insert mode to display the registers window, `false` to disable the binding. Default is `registers.show_window({ mode = "insert" })`.
---@field registers fun(register:string,mode:P_mode) Function to map to the register selected by pressing it's key. Default is `registers.apply_register()`.
---@field [string] fun()|false Function to map to the custom key binding in the registers window.
---@field return_key fun(register:string,mode:P_mode) Deprecated, function to map to <CR> in the registers window. Default is `registers.apply_register()`.
---@field escape fun(register:string,mode:P_mode) Deprecated, function to map to <ESC> in the registers window. Default is `registers.close_window()`.
---@field ctrl_n fun()|false Deprecated, function to map <C-N> in the registers window. Default is `registers.move_cursor_down()`.
---@field ctrl_p fun()|false Deprecated, function to map <C-P> in the registers window. Default is `registers.move_cursor_up()`.
---@field ctrl_j fun()|false Deprecated, function to map <C-J> in the registers window. Default is `registers.move_cursor_down()`.
---@field ctrl_k fun()|false Deprecated, function to map <C-K> in the registers window. Default is `registers.move_cursor_up()`.
---@field delete fun()|false Deprecated, function to map <DEL> in the registers window. Default is `registers.clear_highlighted_register()`.
---@field backspace fun()|false Deprecated, function to map <BS> in the registers window. Default is `registers.clear_highlighted_register()`.

---@alias P_mode
---| '"insert"' # Insert the register's contents like when in insert mode and pressing <C-R>.
---| '"paste"' # Insert the register's contents by pretending a pasting action, similar to pressing "*reg*p, cannot be used in insert mode.
---| '"motion"' # Create a motion from the register, similar to pressing "*reg* (without pasting it yet).

---@class sign_highlights_options
---@field cursorline? string Highlight group for when the cursor is over the line. Default is `"Visual"`.
---@field selection? string Highlight group for the selection registers, `*+`. Default is `"Constant"`.
---@field default? string Highlight group for the default register, `"`. Default is `"Function"`.
---@field unnamed? string Highlight group for the unnamed register, `\\`. Default is `"Statement"`.
---@field read_only? string Highlight group for the read only registers, `:.%`. Default is `"Type"`.
---@field alternate_buffer? string Highlight group for the alternate buffer register, `#`. Default is `"Type"`.
---@field expression? string Highlight group for the expression register, `=`. Default is `"Exception"`.
---@field black_hole? string Highlight group for the black hole register, `_`. Default is `"Error"`.
---@field last_search? string Highlight group for the last search register, `/`. Default is `"Operator"`.
---@field delete? string Highlight group for the delete register, `-`. Default is `"Special"`.
---@field yank? string Highlight group for the yank register, `0`. Default is `"Delimiter"`.
---@field history? string Highlight group for the history registers, `1-9`. Default is `"Number"`.
---@field named? string Highlight group for the named registers, `a-z`. Default is `"Todo"`.

P.sign_highlights = {
    cursorlinesign = "CursorLine",
    signcolumn = "SignColumn",
    cursorline = "Visual",
    selection = "Constant",
    default = "Function",
    unnamed = "Statement",
    read_only = "Type",
    expression = "Exception",
    black_hole = "Error",
    alternate_buffer = "Operator",
    last_search = "Tag",
    delete = "Special",
    yank = "Delimiter",
    history = "Number",
    named = "Todo",
}
---@usage 'require("Pasta").setup({})'
function P.setup()
    vim.api.nvim_create_user_command("Pasta", P.show_window({ mode = "paste" }), {})
    -- Pre-fill the key mappings
    -- THESE DONT WORK
    P._fill_mappings()

    -- these work!!
    P._bind_global_key("normal", '"', "n")
    P._bind_global_key("visual", '"', "x")
    P._bind_global_key("insert", "<C-R>", "i")

    -- create namespace for highlighting and signs
    P._namespace = vim.api.nvim_create_namespace("registers")
end

---@mod callbacks Bindable functions

---Handle the calling of the callback function based on the options, so things like delays can be added.
---@param options? callback_options Options to apply to the callback function.
---@param cb function Callback function to trigger.
---@return function callback Wrapped callback function applying the options.
---@nodiscard
function P._handle_callback_options(options, cb)
    local if_mode = (options and options.if_mode) or { "paste", "insert", "motion" }
    -- Process the table arguments
    -- Ensure it's always a table
    if type(if_mode) ~= "table" then
        if_mode = { if_mode }
    end
    local after = (options and options.after) or function() end

    -- Create the callback that's called with all checks and events
    local full_cb = function(...)
        -- Do nothing if we are not in the proper mode
        if not vim.tbl_contains(if_mode, P._mode) then
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
function P._read_registers()
    P._register_values = {}
    P._empty_registers = {}

    local registers = '*+"-/_=#%.0123456789abcdefghijklmnopqrstuvwxyz:'

    for i = 1, #registers do
        local register = registers:sub(i, i)
        local register_info = vim.fn.getreginfo(register)

        -- The register contents as a single line
        if register_info and register_info.regcontents then
            local line = table.concat(register_info.regcontents, "\n")
            local hide = false
            hide = #(line:match("^%s*(.-)%s*$")) == 0

            if hide then
                -- Place it in the empty registers
                P._empty_registers[#P._empty_registers + 1] = register
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
                -- Convert the sign types
                if register_info.regtype == "v" then
                    register_info.type_symbol = "ᶜ"
                elseif register_info.regtype == "V" then
                    register_info.type_symbol = "ˡ"
                else
                    register_info.type_symbol = "ᵇ"
                end

                register_info.line = line

                -- Add register field for sign_text in sign_highlights
                register_info.register = register

                P._register_values[#P._register_values + 1] = register_info
            end
        else
            -- Place it in the empty registers
            P._empty_registers[#P._empty_registers + 1] = register
        end
    end
end

---@private
---Fill the window's buffer.
function P._fill_window()
    -- Don't allow the buffer to be modified
    vim.bo[P._buffer].modifiable = true

    -- create array of lines for the registers
    local lines = {}
    for i in ipairs(lines) do
        lines[i] = lines:gsub("\n", "")
    end
    for i = 1, #P._register_values do
        local register = P._register_values[i]

        lines[i] = register.line
    end
    -- Add the empty line
    -- lines[#lines + 1] = "Empty: " .. table.concat(P._empty_registers, " ")
    -- Write the lines to the buffer
    vim.api.nvim_buf_set_lines(P._buffer, 0, -1, false, lines)

    -- Create signs and highlights for the register itself
    for i = 1, #P._register_values do
        local register = P._register_values[i]
        local sign_text = register.register

        -- add type symbol to sign_text
        sign_text = sign_text .. register.type_symbol

        local ns = vim.api.nvim_create_namespace("registers")
        -- Create signs for the register itself, and highlight the line
        vim.api.nvim_buf_set_extmark(P._buffer, ns, i - 1, 0, {
            id = i,
            sign_text = sign_text,
            sign_hl_group = P._highlight_for_sign(register.register),
            cursorline_hl_group = P.sign_highlights.cursorline,
        })
    end

    -- Don't allow the buffer to be modified
    vim.bo[P._buffer].modifiable = true
end

---@private
---Create the window and the buffer.
function P._create_window()
    -- Keep track of the buffer from which the window is called
    P._preview_buffer = vim.api.nvim_get_current_buf()
    P._preview_window = vim.api.nvim_get_current_win()

    -- Fill the registers
    P._read_registers()

    -- Create the buffer the registers will be written to
    P._buffer = vim.api.nvim_create_buf(false, true)

    -- Remove the buffer when the window is closed
    vim.bo[P._buffer].bufhidden = "wipe"

    -- Set the filetype
    vim.bo[P._buffer].filetype = "Pasta"

    -- Height is based on the amount of available registers
    local window_height = #P._register_values

    -- Create the floating window
    local window_options = {
        relative = "cursor",
        style = "minimal",
        anchor = "NW",
        -- width = window_width,
        width = 100,
        height = window_height,
        row = 1,
        col = 0,
        border = "rounded",
        title = "Pasta.nvim",
        title_pos = "center",
        footer = "Empty: " .. table.concat(P._empty_registers, " "),
        footer_pos = "center",
    }
    -- Make the window active when the window is not a preview
    P._window = vim.api.nvim_open_win(P._buffer, true, window_options)

    -- Register an autocommand to close the window if focus is lost
    local group = vim.api.nvim_create_augroup("RegistersWindow", {})
    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        pattern = "<buffer>",
        callback = P._close_window,
    })

    -- -- Register an autocommand to trigger events when the cursor moves
    -- if type(P.events.on_register_highlighted) == "function" then
    -- 	P._previous_cursor_line = nil
    -- 	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    -- 		group = group,
    -- 		buffer = P._buffer,
    -- 		callback = P._cursor_moved,
    -- 	})
    -- end

    -- Make the buffer content cut-off instead of starting on new line
    vim.wo[P._window].wrap = false

    -- Show a column on the left for the register names
    vim.wo[P._window].signcolumn = "yes"

    -- Highlight the cursor line
    vim.wo[P._window].cursorline = true

    -- Add the colors
    P._define_highlights()

    -- Update the buffer
    P._fill_window()

    -- Apply the key bindings to the buffer
    P._set_bindings()

    -- Ensure the window shows up
    vim.cmd("redraw!")

    -- -- Put the window in normal mode when using a visual selection
    if P._previous_mode_is_visual() then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true), "n", true)
    end
end

---@private
---Register the highlights.
function P._define_highlights()
    -- Set the namespace for the highlights on the window, if we're running an older neovim version make it global
    ---@type integer
    -- local namespace = 0
    local namespace = P._namespace
    vim.api.nvim_win_set_hl_ns(P._window, namespace)

    -- Define the matches and link them
    vim.cmd([[syntax match RegistersNumber "[-+]\?\d\+\.\?\d*"]])
    vim.api.nvim_set_hl(namespace, "RegistersNumber", { link = "Number" })

    vim.cmd([[syntax region RegistersString start=+"+ skip=+\\"+ end=+"+ oneline]])
    vim.cmd([[syntax region RegistersString start=+'+ skip=+\\'+ end=+'+ oneline]])
    vim.api.nvim_set_hl(namespace, "RegistersString", { link = "String" })

    -- space between register symbol and contents
    vim.api.nvim_set_hl(namespace, "RegistersSignColumn", { link = "SignColumn" })
    -- space between register symbol and contents but for only current line
    vim.api.nvim_set_hl(namespace, "RegistersStringCursorLineSign", { link = "CursorLine" })

    -- ⏎
    vim.cmd([[syntax match RegistersWhitespace "\%u23CE"]])
    -- ⎵
    vim.cmd([[syntax match RegistersWhitespace "\%u23B5"]])
    -- ·
    vim.cmd([[syntax match RegistersWhitespace "\%u00B7"]])
    vim.cmd([[syntax match RegistersWhitespace " "]])
    vim.api.nvim_set_hl(namespace, "RegistersWhitespace", { link = "Comment" })
    vim.cmd([[syntax match RegistersEscaped "\\\w"]])
    vim.cmd([[syntax keyword RegistersEscaped \.]])
    vim.api.nvim_set_hl(namespace, "RegistersEscaped", { link = "Special" })

    -- Empty region
    local function hl_symbol(type, symbols, group)
        local name = "RegistersSymbol_" .. group
        if type == "match" then
            vim.cmd(("syntax match %s %q contained"):format(name, symbols))
        else
            vim.cmd(("syntax %s %s %s contained"):format(type, name, symbols))
        end
        vim.api.nvim_set_hl(namespace, name, { link = P.sign_highlights[group] })
    end

    vim.api.nvim_set_hl(namespace, "SignColumn", { link = P.sign_highlights["Signcolumn"] })
    vim.api.nvim_set_hl(namespace, "CursorLineSign", { link = P.sign_highlights["Cursorlinesign"] })

    hl_symbol("match", "[*+]", "selection")
    hl_symbol("match", '\\"', "default")
    hl_symbol("match", "\\\\", "unnamed")
    hl_symbol("match", "[:.%]", "read_only")
    hl_symbol("match", "_", "black_hole")
    hl_symbol("match", "=", "expression")
    hl_symbol("match", "#", "alternate_buffer")
    hl_symbol("match", "\\/", "last_search")
    hl_symbol("match", "-", "delete")
    hl_symbol("keyword", "0", "yank")
    hl_symbol("keyword", "1 2 3 4 5 6 7 8 9", "history")
    hl_symbol("keyword", "a b c d e f g h i j k l m n o p q r s t u v w x y z", "named")

    vim.cmd([[syntax match RegistersEmptyString "Empty: " contained]])

    vim.cmd([[syntax region RegistersEmpty start="^Empty: " end="$" contains=RegistersSymbol.*,RegistersEmptyString]])
end

---`require("registers").show_window({...})`
---@class show_window_options
---@field mode? P_mode How the registers window should handle the selection of registers. Default is `"motion"`.

---Popup the registers window.
---@param options? show_window_options Options for firing the callback.
---@return function callback Function that can be used to pass to configuration options with callbacks.
function P.show_window(options)
    options = vim.tbl_deep_extend("keep", options or {}, {
        mode = "motion",
    })
    return function()
        -- Mode before opening the popup window
        P._previous_mode = vim.api.nvim_get_mode().mode
        P._mode = options.mode
        vim.print("pmode: " .. P._mode)
        vim.print("options: " .. options.mode)
        vim.schedule(function()
            P._create_window()
        end)
    end
end

---@private
-- Close the window.
function P._close_window()
    if P._window then
        vim.api.nvim_win_close(P._window, true)
        P._window = nil
    end
    -- clear the namespace
    if P._preview_buffer then
        vim.api.nvim_buf_clear_namespace(P._preview_buffer, P._namespace, 0, -1)
    end
end

---@private
---Handle the CursorMoved autocmd.
function P._cursor_moved()
    local cursor = unpack(vim.api.nvim_win_get_cursor(P._window))

    -- Skip horizontal movement
    if P._previous_cursor_line == cursor then
        return
    end
    P._previous_cursor_line = cursor

    -- Trigger the highlight change event
    -- P.preview_highlighted_register({ if_mode = { "insert", "paste" } })
end

---@private
---Get the register information matching the register.
---@param register? string Register to look up, if nothing is passed the current line will be used
---@return? table Register information from `registers._register_values`
function P._register_info(register)
    if register == nil then
        -- A register is selected by the cursor, get it based on the current line
        local cursor = unpack(vim.api.nvim_win_get_cursor(P._window))

        return P._register_values[cursor]
    else
        -- Otherwise find it by looking up the register in the list
        for i = 1, #P._register_values do
            if P._register_values[i].register == register then
                return P._register_values[i]
            end
        end
    end

    return nil
end

---Show a preview of the highlighted register in the target buffer.
---Currently this overlays the text, waiting for https://github.com/neovim/neovim/pull/9496 to merge.
--@param options callback_options Options for firing the callback.
--@return function callback Function that can be used to pass to configuration options with callbacks.
-- function P.preview_highlighted_register(options)
--     return P._handle_callback_options(options --[[@as callback_options]], function()
--         -- Get the register contents for the current line as a table
--         local register_info = P._register_info()

--         -- Do nothing when an invalid line is selected
--         if type(register_info) ~= "table" then
--             return
--         end

--         local register_lines = register_info.regcontents

--         -- Add the highlight to the lines
--         local lines = {}
--         for i, line in ipairs(register_lines) do
--             lines[i] = {
--                 line, "Normal"
--             }
--             vim.inspect(lines)
--         end

--         -- Clear the previous extmarks
--         vim.api.nvim_buf_clear_namespace(P._preview_buffer, P._namespace, 0, -1)

--         -- Get the cursor position of the main buffer
--         local line, col = unpack(vim.api.nvim_win_get_cursor(P._preview_window))

--         -- Display the register content
--         vim.api.nvim_buf_set_extmark(P._preview_buffer, P._namespace, line - 1, col, {
--             virt_text = lines,
--             virt_text_win_col = col,
--             virt_text_pos = "inline",
--         })
--     end)
-- end

---@class callback_options
---@field after? function Callback function that can be chained after the current one.
---@field if_mode P_mode|[register_mode] Will only be triggered when the registers mode matches it. Default: `{ "paste", "insert", "motion" }`.
---Close the window.
---@param options? callback_options Options for firing the callback.
---@return function callback Function that can be used to pass to configuration options with callbacks.
function P.close_window(options)
    return P._handle_callback_options(options, function()
        P._close_window()
    end)
end

---@class apply_register_options
---@field mode? P_mode How the register should be applied. If `nil` then the mode in which the window is opened is used.
---@field keep_open_until_keypress? boolean If `true`, keep the window open until another key is pressed, only applicable when the mode is `"motion"`.

---Apply the specified register.
---@param options? callback_options|apply_register_options Options for firing the callback.
---@return function callback Function that can be used to pass to configuration options with callbacks.
---@usage [[
---@usage ]]
function P.apply_register(options)
    return P._handle_callback_options(options --[[@as callback_options]], function(register, mode)
        -- When the current line needs to be selected a window also needs to be open
        if register == nil and P._window == nil then
            vim.api.nvim_err_writeln("registers window isn't open, can't apply register")
            return
        end

        -- Overwrite the mode
        if options and options.mode then
            P._mode = options.mode --[[@as P_mode]]
            print("mode overwritten to " .. P._mode)
        elseif mode then
            P._mode = mode
            print(P._mode)
        end

        P._apply_register(register, options and options.keep_open_until_keypress)
    end)
end

function P._apply_register(register, keep_open_until_keypress)
    register = P._register_symbol(register)
    print(vim.inspect(register))
    if not register then
        return
    end

    local action
    if P._mode == "paste" then
        action = "p"
    elseif keep_open_until_keypress and P._mode == "motion" then
        -- Handle the special case when the window needs to be open until a key is pressed
        action = vim.fn.getcharstr()
    end

    P._close_window()

    if P._mode == "insert" then
        local key = vim.api.nvim_replace_termcodes("<C-R>", true, true, true)
        if register == "=" then
            vim.api.nvim_feedkeys(key .. "=", "n", true)
        else
            -- Insert the other keys

            -- Capture the contents of the "=" register so it can be reset later
            local old_expr_content = vim.fn.getreg("=", 1)

            -- <CR> key
            local submit = vim.api.nvim_replace_termcodes("<CR>", true, true, true)

            -- Execute the selected register content using "=" register and insert the result
            vim.api.nvim_feedkeys(key .. register .. submit, "n", true)

            -- Recover the "=" register with a delay otherwise it doesn't get applied
            vim.schedule(function()
                vim.fn.setreg("=", old_expr_content)
            end)
        end
    elseif P._previous_mode == "n" or P._previous_mode_is_visual() then
        -- Simulate the keypresses require to perform the next actions
        vim.schedule(function()
            local keys = ""

            -- Go to previous visual selection if applicable
            if P._previous_mode_is_visual() then
                keys = keys .. "gv"
            end

            -- Select the register if applicable
            if P._mode == "motion" or P._mode == "paste" then
                -- Push the operator count back if applicable
                -- if P._operator_count > 0 then
                --   keys = keys .. P._operator_count
                -- end

                keys = keys .. '"' .. register
            end

            -- Handle the key that might needs to be pressed
            if action then
                keys = keys .. action
                vim.inspect(keys)
                vim.inspect(action)
            end

            vim.api.nvim_feedkeys(keys, "n", true)
        end)
    end
    if vim.fn.has("clipboard") == 1 then
        vim.cmd("let @+=@" .. register)
    else
        vim.api.nvim_err_writeln("No clipboard available")
    end
end

---@private
---Get the register or when it's `nil` the selected register from the cursor.
---@param register? string Register to look up, if nothing is passed the current line will be used
---@return? string The register or the current line, if applicable
---@nodiscard
function P._register_symbol(register)
    if register == nil then
        -- A register is selected by the cursor, get it based on the current line
        local cursor = unpack(vim.api.nvim_win_get_cursor(P._window))

        if #P._register_values < cursor then
            -- The empty section has been chosen, it doesn't select anything
            return nil
        end

        return P._register_values[cursor].register
    else
        -- Use the already set value
        return register
    end
end

---@private
---The highlight group from the options for the sign.
---@param register string Which register to get the highlight group for
---@return string Highlight group
---@nodiscard
function P._highlight_for_sign(register)
    local hl = P.sign_highlights

    return ({
        ["*"] = hl.selection,
        ["+"] = hl.selection,
        ['"'] = hl.default,
        ["\\"] = hl.unnamed,
        [":"] = hl.read_only,
        ["."] = hl.read_only,
        ["%"] = hl.read_only,
        ["/"] = hl.last_search,
        ["-"] = hl.delete,
        ["_"] = hl.black_hole,
        ["="] = hl.expression,
        ["#"] = hl.alternate_buffer,
        ["0"] = hl.yank,
        ["1"] = hl.history,
        ["2"] = hl.history,
        ["3"] = hl.history,
        ["4"] = hl.history,
        ["5"] = hl.history,
        ["6"] = hl.history,
        ["7"] = hl.history,
        ["8"] = hl.history,
        ["9"] = hl.history,
        a = hl.named,
        b = hl.named,
        c = hl.named,
        d = hl.named,
        e = hl.named,
        f = hl.named,
        g = hl.named,
        h = hl.named,
        i = hl.named,
        j = hl.named,
        k = hl.named,
        l = hl.named,
        m = hl.named,
        n = hl.named,
        o = hl.named,
        p = hl.named,
        q = hl.named,
        r = hl.named,
        s = hl.named,
        t = hl.named,
        u = hl.named,
        v = hl.named,
        w = hl.named,
        x = hl.named,
        y = hl.named,
        z = hl.named,
    })[register]
end

P.bind_keys = {
    -- Show the window when pressing " in normal mode, applying the selected register as part of a motion, which is the default behavior of Neovim
    normal = P.show_window({ mode = "paste" }),
    -- Show the window when pressing " in visual mode, applying the selected register as part of a motion, which is the default behavior of Neovim
    visual = P.show_window({ mode = "motion" }),
    -- Show the window when pressing <C-R> in insert mode, inserting the selected register, which is the default behavior of Neovim
    insert = P.show_window({ mode = "insert" }),

    -- When pressing the key of a register, apply it with a very small delay, which will also highlight the selected register
    registers = P.apply_register(),
    -- Immediately apply the selected register line when pressing the return key
    ["<CR>"] = P.apply_register(),
    -- Close the registers window when pressing the Esc key
    ["<Esc>"] = P.close_window(),

    -- -- Move the cursor in the registers window down when pressing <C-n>
    -- ["<C-n>"] = P.move_cursor_down(),
    -- -- Move the cursor in the registers window up when pressing <C-p>
    -- ["<C-p>"] = P.move_cursor_up(),
    -- -- Move the cursor in the registers window down when pressing <C-j>
    -- ["<C-j>"] = P.move_cursor_down(),
    -- -- Move the cursor in the registers window up when pressing <C-k>
    -- ["<C-k>"] = P.move_cursor_up(),
    -- -- Clear the register of the highlighted line when pressing <DeL>
    -- ["<Del>"] = P.clear_highlighted_register(),
    -- -- Clear the register of the highlighted line when pressing <BS>
    -- ["<BS>"]  = P.clear_highlighted_register(),
}

---@private
---Pre-fill the key mappings.
function P._fill_mappings()
    --  Don't map the keys when `false` is passed to bind_keys
    if not P.bind_keys then
        vim.inspect(P.bind_keys)
        return
    end

    -- Add the other user-defined keys to the map
    -- local reserved_keys = {
    --     normal = true,
    --     visual = true,
    --     insert = true,
    --     registers = true,
    --     return_key = true,
    --     escape = true,
    --     ctrl_n = true,
    --     ctrl_p = true,
    --     ctrl_j = true,
    --     ctrl_k = true,
    --     delete = true,
    --     backspace = true,
    -- }

    -- -- Create the mappings to call the function specified in the options
    P._mappings = {}
    for key, func in pairs(P.bind_keys) do
        -- Don't bind the reserved keys, that doesn't make any sense
        P._mappings[key] = function()
            func(nil, P._mode)
        end
    end

    -- Create mappings for the register keys
    for _, register in ipairs(P._all_registers) do
        -- Pressing the character of a register will also apply it
        P._mappings[register] = function()
            -- Always move the cursor to the selected line in case there's a delay, unfortunately there's no way to know if that's the case at this time so it's quite inefficient when there's no delay
            P._move_cursor_to_register(register)

            -- Apply the mapping
            P.bind_keys.registers(register, P._mode)
        end

        -- Also map uppercase registers if applicable
        if register:upper() ~= register then
            P._mappings[register:upper()] = function()
                -- Always move the cursor to the selected line in case there's a delay, unfortunately there's no way to know if that's the case at this time so it's quite inefficient when there's no delay
                P._move_cursor_to_register(register)

                -- Apply the mapping
                P.bind_keys.registers(register:upper(), P._mode)
            end
        end
    end
end

---@private
---Move the cursor to the specified register.
---@param register string The register to move to, if it can't be found nothing is done.
function P._move_cursor_to_register(register)
    if P._window == nil then
        vim.api.nvim_err_writeln("registers window isn't open, can't move cursor")
        return
    end

    -- Find the matching register so we know where to put the cursor
    for i = 1, #P._register_values do
        local register_info = P._register_values[i]
        if register_info.register == register then
            -- Move the cursor
            vim.api.nvim_win_set_cursor(P._window, { i, 0 })

            -- Redraw the line so it gets highlighted
            vim.api.nvim_command("silent! redraw")

            return
        end
    end
end

---@private
---Set the key bindings for the window.
function P._set_bindings()
    -- Helper function for setting the keymap for all buffer modes
    local set_keymap_all_modes = function(key, callback)
        local map_options = {
            nowait = true,
            noremap = true,
            silent = true,
            callback = callback,
        }

        vim.api.nvim_buf_set_keymap(P._buffer, "n", key, "", map_options)
        vim.api.nvim_buf_set_keymap(P._buffer, "i", key, "", map_options)
        vim.api.nvim_buf_set_keymap(P._buffer, "x", key, "", map_options)
    end

    -- Map all register keys
    if P._all_registers then
        for key, callback in pairs(P._mappings) do
            set_keymap_all_modes(key, callback)
        end
    end

    -- -- Map the keys for moving up and down
    -- if P._key_should_be_bound("ctrl_k") then
    --     set_keymap_all_modes("<c-k>", P.options.bind_keys.ctrl_k)
    -- end
    -- if P._key_should_be_bound("ctrl_j") then
    --     set_keymap_all_modes("<c-j>", P.options.bind_keys.ctrl_j)
    -- end
    -- if P._key_should_be_bound("ctrl_p") then
    --     set_keymap_all_modes("<c-p>", P.options.bind_keys.ctrl_p)
    -- end
    -- if P._key_should_be_bound("ctrl_n") then
    --     set_keymap_all_modes("<c-n>", P.options.bind_keys.ctrl_n)
    -- end
end

---@private
---Whether a key should be bound.
---@param option string Which item from bind_keys should be checked
---@return boolean Whether the key should be bound
---@nodiscard
function P._key_should_be_bound(option)
    if type(P.bind_keys) == "boolean" then
        vim.print(P.bind_keys)
        return P.bind_keys --[[@as boolean]]
    else
        return P.bind_keys[option]
    end
end

---@private
---Create a map for global key binding with a callback function.
---@param index string Key of the function in the `bind_keys` table.
---@param key string Which key to press.
---@param mode P_mode Which mode to register the key.
function P._bind_global_key(index, key, mode)
    if P._key_should_be_bound(index) then
        vim.api.nvim_set_keymap(mode, key, "", {
            callback = function()
                -- Don't open the registers window in a telescope prompt or in a non-modifiable buffer
                if
                    not vim.bo.modifiable
                    or vim.bo.filetype == "TelescopePrompt"
                    or vim.bo.filetype == "DressingInput"
                then
                    return vim.api.nvim_replace_termcodes(key, true, true, true)
                else
                    -- Call the callback function passed to the options
                    return P.bind_keys[index]()
                end
            end,
            expr = true,
        })
    end
end

---@private
---All available registers.
P._all_registers = {
    "*",
    "+",
    '"',
    "-",
    "/",
    "_",
    "=",
    "#",
    "%",
    ".",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    ":",
}
---Whether the previous mode is any of the visual selections.
---@return boolean is_visual Whether the previous mode is a visual selection.
function P._previous_mode_is_visual()
    return P._previous_mode == "v" or P._previous_mode == "^V" or P._previous_mode == "V" or P._previous_mode == "\22"
end

return P
