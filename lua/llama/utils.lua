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

---@param str string
function M.trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

---@param text string
---@param width number
---@return table -- lines split by the provided width for each line
M.wrap_text = function(text, width)
    local lines = {}

    text = text:gsub("\t", "    ")
    text = text:gsub("[\r\n]+", " ")
    text = text:gsub("%s+", " ")

    local start_pos = 1

    while #text > 0 do
        if #text <= width then
            table.insert(lines, text)
            break
        else
            local split_pos = text:find(" ", start_pos + width - 1) or #text + 1

            if split_pos > #text then
                split_pos = #text
            end

            local line_end = (split_pos == #text and #text + 1) or split_pos
            local line = text:sub(start_pos, line_end)

            while #line > width do
                line = line:sub(1, -2)
                line_end = line_end - 1
                line = text:sub(start_pos, line_end)
            end

            table.insert(lines, line)

            start_pos = line_end + 1
            text = text:sub(start_pos):gsub("^%s+", "")
        end
    end

    return lines
end

return M
