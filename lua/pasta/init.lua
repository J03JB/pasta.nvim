---@tag pasta.nvim
---@brief [[
---
---@brief ]]

---@class Pasta
---@field private _window? integer
---@field private _buf? integer
---@field private _preview_buffer? integer
---@field private _preview_win? integer
---@field setup function: setup the plugin
---@field main function: calculate the max or min of two numbers and round the result if specified by options

require('pasta.pasta').setup()
