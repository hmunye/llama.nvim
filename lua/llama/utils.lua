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
---@return table
M.wrap_text = function(text, width)
    local lines = {}
    local current_line = ""

    -- split the text by spaces to get individual words
    for word in text:gmatch("%S+") do
        -- check if adding the next word would exceed the width
        if #current_line + #word + (current_line == "" and 0 or 1) > width then
            -- push the current line and start a new one with the current word
            table.insert(lines, current_line)
            current_line = word
        else
            -- add the word to the current line
            if current_line == "" then
                current_line = word
            else
                current_line = current_line .. " " .. word
            end
        end
    end

    -- add remaining text
    if #current_line > 0 then
        table.insert(lines, current_line)
    end

    return lines
end

return M
