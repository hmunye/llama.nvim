local M = {}

---@param buf integer
---@param start integer
---@param ending integer
---@param strict_indexing boolean
---@param replacement string[]
M.set_buf_lines = function(buf, start, ending, strict_indexing, replacement)
    local isModifiable =
        vim.api.nvim_get_option_value("modifiable", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, start, ending, strict_indexing, replacement)
    vim.api.nvim_set_option_value("modifiable", isModifiable, { buf = buf })
end

return M
