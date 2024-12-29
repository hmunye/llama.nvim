local API = require("llama.api")
local Utils = require("llama.utils")

local M = {}

local state = {
    model = "",
    include_current_buffer = false,
    chat = {
        opts = {},
        bufnr = -1,
        winid = -1,
        width = -1,
        height = -1,
    },
    prompt = {
        opts = {},
        bufnr = -1,
        winid = -1,
    },
    keymaps = {},
}

--- @param model string -- initial model provided
--- @param chat_opts ChatOpts -- initial chat window opts
--- @param prompt_opts PromptOpts -- initial prompt window opts
--- @param include_current_buffer boolean
--- @param keymaps KeymapOpts -- remaining keymaps that need to be buffer-scoped
M.init = function(
    model,
    chat_opts,
    prompt_opts,
    include_current_buffer,
    keymaps
)
    state.model = model
    state.include_current_buffer = include_current_buffer
    state.chat.opts = chat_opts
    state.prompt.opts = prompt_opts
    state.keymaps = keymaps
end

--- get input value from prompt buffer
---@return string -- all lines in the buffer as a single string
M.get_input = function()
    if not vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
        return ""
    end

    local lines = vim.api.nvim_buf_get_lines(state.prompt.bufnr, 0, -1, false)
    return table.concat(lines, "\n")
end

M.toggle_chat_window = function()
    if vim.api.nvim_win_is_valid(state.chat.winid) then
        vim.api.nvim_win_hide(state.chat.winid)
        vim.api.nvim_win_hide(state.prompt.winid)

        return
    end

    state.chat.width = math.floor(
        vim.api.nvim_win_get_width(0) * (state.chat.opts.width / 100)
    )
    state.chat.height = math.floor(vim.api.nvim_win_get_height(0) * 0.85)

    local col
    if state.chat.opts.position == "left" then
        -- chat window will be on the left side
        col = 0
    else
        -- chat window will be on the right side (Default)
        col = vim.api.nvim_win_get_width(0) - state.chat.width
    end

    if not vim.api.nvim_buf_is_valid(state.chat.bufnr) then
        state.chat.bufnr = vim.api.nvim_create_buf(false, true)
    end

    -- chat window to top (Default)
    local row = 0

    if state.prompt.opts.position == "top" then
        -- chat window to bottom
        row = math.floor(state.chat.height * 0.15)
    end

    state.chat.winid = vim.api.nvim_open_win(state.chat.bufnr, true, {
        relative = "editor",
        width = state.chat.width,
        height = state.chat.height,
        row = row,
        col = col,
        border = state.chat.opts.border,
        style = "minimal",
        title = state.chat.opts.title,
        title_pos = state.chat.opts.title_position,
    })

    vim.api.nvim_set_option_value("wrap", true, { win = state.chat.winid })

    vim.api.nvim_set_option_value(
        "filetype",
        "markdown",
        { buf = state.chat.bufnr }
    )

    vim.api.nvim_set_option_value(
        "modifiable",
        false,
        { buf = state.chat.bufnr }
    )

    M.create_prompt_window(col)

    if state.keymaps then
        M.setup_keymaps()
        M.setup_buf_commands()

        state.keymaps = nil
    end
end

---@param chat_col number
M.create_prompt_window = function(chat_col)
    if not vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
        -- BUG: unexpected behaviors when opening `Oil` file explorer within
        -- prompt buffer and toggling chat window. can be useful though
        state.prompt.bufnr = vim.api.nvim_create_buf(false, true)
    end

    local prompt_height = math.floor(state.chat.height * 0.10)

    -- default to bottom
    local row = state.chat.height + 2

    if state.prompt.opts.position == "top" then
        -- prompt window to top
        row = 0
    end

    state.prompt.winid = vim.api.nvim_open_win(state.prompt.bufnr, true, {
        relative = "editor",
        width = state.chat.width,
        height = prompt_height,
        row = row,
        col = chat_col,
        border = state.prompt.opts.border,
        style = "minimal",
        title = state.model,
        title_pos = "left",
    })

    vim.api.nvim_set_option_value("wrap", true, { win = state.prompt.winid })
    vim.api.nvim_set_option_value(
        "modifiable",
        true,
        { buf = state.prompt.bufnr }
    )

    if state.prompt.opts.start_insert_mode then
        vim.cmd([[startinsert]])
    end
end

---@param prompt string
M.append_model_response = function(prompt)
    API.generate_chat_completion(state.model, prompt, function(status, response)
        if not status then
            vim.notify(response, vim.log.levels.ERROR, { title = "llama.nvim" })
            return
        end

        -- finished streaming response (should not affect non-streamed responses)
        if response == "" then
            return
        end

        -- handle newlines in response
        if string.find(response, "\n") then
            local response_lines = vim.split(response, "\n")

            local lines =
                vim.api.nvim_buf_get_lines(state.chat.bufnr, 0, -1, false)

            -- if no lines exist in the buffer, add the response lines directly
            if #lines == 0 then
                Utils.set_buf_lines(
                    state.chat.bufnr,
                    0,
                    0,
                    false,
                    response_lines
                )
            else
                -- get the last line in the buffer and append the first part of the new response
                local last_line = lines[#lines] or ""
                local first_line = response_lines[1] or ""
                local updated_line = last_line .. first_line

                -- replace the last line with the updated line
                Utils.set_buf_lines(
                    state.chat.bufnr,
                    #lines - 1,
                    #lines,
                    false,
                    { updated_line }
                )

                -- add the remaining response lines
                if #response_lines > 1 then
                    local remaining_lines =
                        vim.list_slice(response_lines, 2, #response_lines)
                    Utils.set_buf_lines(
                        state.chat.bufnr,
                        #lines,
                        #lines,
                        false,
                        remaining_lines
                    )
                end
            end
        else
            -- no newlines present in response
            local lines =
                vim.api.nvim_buf_get_lines(state.chat.bufnr, 0, -1, false)

            if #lines == 0 then
                Utils.set_buf_lines(state.chat.bufnr, 0, 0, false, { response })
            else
                local last_line = lines[#lines] or ""
                local updated_line = last_line .. response

                Utils.set_buf_lines(
                    state.chat.bufnr,
                    #lines - 1,
                    #lines,
                    false,
                    { updated_line }
                )
            end
        end
    end)
end

M.submit_prompt = function()
    local input = M.get_input()

    if input == "" then
        return
    end

    M.append_model_response(input)

    if vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
        -- Clear the prompt after submitting
        Utils.set_buf_lines(state.prompt.bufnr, 0, -1, false, {})
    end
end

M.clear_chat_window = function()
    print("cleared")
end

M.setup_keymaps = function()
    -- Scoped only to prompt buffer
    vim.keymap.set(
        state.keymaps.LlamaSubmitPrompt.mode,
        state.keymaps.LlamaSubmitPrompt.lhs,
        "<cmd>LlamaSubmitPrompt<CR>",
        { buffer = state.prompt.bufnr, noremap = true, silent = true }
    )

    -- Scoped only to chat buffer
    vim.keymap.set(
        state.keymaps.LlamaClearChat.mode,
        state.keymaps.LlamaClearChat.lhs,
        "<cmd>LlamaClearChat<CR>",
        { buffer = state.chat.bufnr, noremap = true, silent = true }
    )
end

M.setup_buf_commands = function()
    -- Scoped only to prompt buffer
    vim.api.nvim_buf_create_user_command(
        state.prompt.bufnr,
        "LlamaSubmitPrompt",
        function()
            require("llama.ui").submit_prompt()
        end,
        {}
    )

    -- Scoped only to chat buffer
    vim.api.nvim_buf_create_user_command(
        state.chat.bufnr,
        "LlamaClearChat",
        function()
            require("llama.ui").clear_chat_window()
        end,
        {}
    )
end

return M
