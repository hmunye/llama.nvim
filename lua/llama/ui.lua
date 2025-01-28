local API = require("llama.api")
local Utils = require("llama.utils")

local M = {}

local state = {
    -- current buffer with code
    current_buf = -1,
    -- context window for model (in tokens)
    ctx_win = -1,
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
    is_processing = false,
    -- https://github.com/jellydn/spinner.nvim
    spinner = {
        index = 1,
        timer = nil,
        bufnr = -1,
        winid = -1,
        frames = {
            "⠋",
            "⠙",
            "⠹",
            "⠸",
            "⠼",
            "⠴",
            "⠦",
            "⠧",
            "⠇",
            "⠏",
        },
    },
}

-- `commands` to enter in prompt
local commands = {
    clear_chat = "/clear",
    include_buffer = "/buf",
    no_current_buffer = "/no_buf",
    list_models = "/list",
    switch_model = "/switch",
    help = "/help",
}

--- @param model string -- initial model provided
--- @param chat_opts ChatOpts -- initial chat window opts
--- @param prompt_opts PromptOpts -- initial prompt window opts
--- @param keymaps KeymapOpts -- remaining keymaps that need to be buffer-scoped
--- @param ctx_win integer -- context window for model
M.init = function(model, chat_opts, prompt_opts, keymaps, ctx_win)
    state.model = model
    state.chat.opts = chat_opts
    state.prompt.opts = prompt_opts
    state.keymaps = keymaps
    state.ctx_win = ctx_win
end

M.start_spinner = function()
    if state.spinner.timer then
        return
    end

    local text_row = math.floor(state.chat.height / 2)
    local text_col = math.floor((state.chat.width - 1) / 2)

    local opts = {
        -- Relative to chat window
        relative = "win",
        win = state.chat.winid,
        width = 1,
        height = 1,
        col = text_col,
        row = text_row,
        style = "minimal",
    }

    -- Define highlight group for spinner
    vim.cmd(
        string.format(
            "highlight SpinnerHighlight guibg=NONE guifg=%s",
            state.chat.opts.spinner_color
        )
    )

    if not vim.api.nvim_buf_is_valid(state.spinner.bufnr) then
        state.spinner.bufnr = vim.api.nvim_create_buf(false, true)
    end

    if not vim.api.nvim_win_is_valid(state.spinner.winid) then
        state.spinner.winid =
            vim.api.nvim_open_win(state.spinner.bufnr, false, opts)
    end

    -- Start a timer to cycle through the spinner frames
    state.spinner.timer = vim.loop.new_timer()
    state.spinner.timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            if vim.api.nvim_buf_is_valid(state.spinner.bufnr) then
                Utils.set_buf_lines(
                    state.spinner.bufnr,
                    0,
                    -1,
                    false,
                    { state.spinner.frames[state.spinner.index] }
                )

                vim.api.nvim_buf_add_highlight(
                    state.spinner.bufnr,
                    -1,
                    "SpinnerHighlight",
                    0,
                    0,
                    -1
                )
            end

            state.spinner.index = (state.spinner.index % #state.spinner.frames)
                + 1
        end)
    )
end

M.stop_spinner = function()
    if state.spinner.timer then
        state.spinner.timer:stop()
        state.spinner.timer:close()
        state.spinner.timer = nil

        if state.spinner.winid then
            vim.api.nvim_win_close(state.spinner.winid, true)
        end

        if state.spinner.bufnr then
            vim.api.nvim_buf_delete(state.spinner.bufnr, { force = true })
        end
    end
end

--- get input value from prompt buffer
---@return string -- all lines in the buffer as a single string with newlines
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
        M.stop_spinner()

        return
    end

    -- store the current buffer for future use in including
    state.current_buf = vim.api.nvim_win_get_buf(0)

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

    -- resume the spinner if chat window is previously closed and model is still processing
    if state.is_processing then
        M.start_spinner()
    end

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

    M.toggle_prompt_window(col)

    if state.keymaps then
        M.setup_keymaps()
        M.setup_buf_commands()

        state.keymaps = nil
    end
end

---@param chat_col number
M.toggle_prompt_window = function(chat_col)
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
M.append_user_prompt = function(prompt)
    local lines = vim.api.nvim_buf_get_lines(state.chat.bufnr, 0, -1, false)

    local wrap_width = math.floor(state.chat.width * 0.4)

    local wrapped_prompt = {}

    -- check if the prompt contains any newline characters
    if prompt:find("\n") then
        for line in prompt:gmatch("([^\n]+)") do
            local wrapped_line = Utils.wrap_text(line, wrap_width)

            for _, wrapped_subline in ipairs(wrapped_line) do
                table.insert(wrapped_prompt, wrapped_subline)
            end
        end
    else
        -- manually split it into multiple chunks if there are now newlines
        local line_start = 1
        while line_start <= #prompt do
            local line_end = math.min(line_start + wrap_width - 1, #prompt)

            local wrapped_line = prompt:sub(line_start, line_end)

            table.insert(wrapped_prompt, wrapped_line)

            line_start = line_end + 1
        end
    end

    local bg_color = state.prompt.opts.highlight_color

    -- Define highlight group for user prompt
    vim.cmd(
        string.format("highlight PromptHighlight guibg=%s guifg=NONE", bg_color)
    )

    -- add padding between each prompt
    local padding_lines = 2

    for i = 1, padding_lines do
        Utils.set_buf_lines(
            state.chat.bufnr,
            #lines + i,
            #lines + i,
            false,
            { "" }
        )
    end

    local last_row = #lines + padding_lines

    for _, line in ipairs(wrapped_prompt) do
        Utils.set_buf_lines(state.chat.bufnr, last_row, last_row + 1, false, {
            " " .. line .. " " .. string.rep(" ", wrap_width - #line),
        })

        vim.api.nvim_buf_add_highlight(
            state.chat.bufnr,
            -1,
            "PromptHighlight",
            last_row,
            0,
            state.chat.width
        )

        last_row = last_row + 1
    end
end

---@param prompt string
M.append_model_response = function(prompt)
    M.start_spinner()
    state.is_processing = true

    local lines = vim.api.nvim_buf_get_lines(state.chat.bufnr, 0, -1, false)

    local winid = vim.fn.bufwinid(state.current_buf)
    vim.api.nvim_set_current_win(winid)

    -- add padding between each response
    local padding_lines = 4

    for i = 1, padding_lines do
        Utils.set_buf_lines(
            state.chat.bufnr,
            #lines + 1 + i - 1,
            #lines + 1 + i,
            false,
            { "" }
        )
    end

    local callback_count = 0

    API.generate_chat_completion(
        state.model,
        prompt,
        function(status, response, response_count)
            if not status then
                vim.notify(
                    response,
                    vim.log.levels.ERROR,
                    { title = "llama.nvim" }
                )
                vim.api.nvim_set_option_value(
                    "modifiable",
                    true,
                    { buf = state.prompt.bufnr }
                )
                return
            end

            -- handle newlines in response
            if string.find(response, "\n") then
                local response_lines = vim.split(response, "\n")

                lines =
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
                lines =
                    vim.api.nvim_buf_get_lines(state.chat.bufnr, 0, -1, false)

                if #lines == 0 then
                    Utils.set_buf_lines(
                        state.chat.bufnr,
                        0,
                        0,
                        false,
                        { response }
                    )
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

            M.stop_spinner()
            state.is_processing = false

            callback_count = callback_count + 1
            if callback_count == response_count - 2 then
                vim.api.nvim_set_option_value(
                    "modifiable",
                    true,
                    { buf = state.prompt.bufnr }
                )
            end
        end
    )
end

---@param mes string -- command message to display
M.append_command_message = function(mes)
    local lines = vim.api.nvim_buf_get_lines(state.chat.bufnr, 0, -1, false)

    if #lines <= 1 then
        -- if there is 1 or fewer lines, directly append the message
        Utils.set_buf_lines(
            state.chat.bufnr,
            #lines,
            #lines + 1,
            false,
            { mes }
        )
    else
        local padding_lines = 4

        for i = 1, padding_lines do
            Utils.set_buf_lines(
                state.chat.bufnr,
                #lines + i,
                #lines + i + 1,
                false,
                { "" }
            )
        end

        Utils.set_buf_lines(
            state.chat.bufnr,
            #lines + padding_lines,
            #lines + padding_lines + 1,
            false,
            { mes }
        )
    end
end

---@param command string
M.process_command = function(command)
    if command == "/clear" then
        M.clear_chat_window()
    elseif command == "/buf" then
        state.include_current_buffer = true

        M.append_command_message("[LLAMA] include current buffer: enabled")
    elseif command == "/no_buf" then
        state.include_current_buffer = false

        M.append_command_message("[LLAMA] include current buffer: disabled")
    elseif command == "/list" then
        local status, model_data = API.fetch_local_models()

        if not status then
            -- should be a string since an error occurred, using tostring to hide warning
            vim.notify(tostring(model_data), vim.log.levels.ERROR, {})
            return
        end

        local available_models = {}

        for _, value in pairs(model_data.models) do
            table.insert(available_models, "`" .. value.model .. "`")
        end

        M.append_command_message(
            "[LLAMA] local models: " .. table.concat(available_models, ", ")
        )
    elseif command == "/switch" then
        local status, model_data = API.fetch_local_models()

        if not status then
            -- should be a string since an error occurred, using tostring to hide warning
            vim.notify(tostring(model_data), vim.log.levels.ERROR, {})
            return
        end

        local available_models = {}

        for idx, value in pairs(model_data.models) do
            table.insert(available_models, idx .. ". " .. value.model)
        end

        local model_choice = vim.fn.inputlist(available_models)

        if
            model_choice
            and model_choice > 0
            and model_choice <= #available_models
        then
            local model_name = string.sub(available_models[model_choice], 4)

            state.model = model_name

            -- update prompt window title
            vim.api.nvim_win_set_config(
                state.prompt.winid,
                { title = model_name }
            )

            -- reset
            M.clear_chat_window()
            API.clear_chat_history()

            M.append_command_message(
                "[LLAMA] switched model to `" .. model_name .. "`"
            )
        else
            M.append_command_message("[LLAMA] model switch canceled")
        end
    elseif command == "/help" then
        local available_cmds = {}

        for _, value in pairs(commands) do
            table.insert(available_cmds, "`" .. value .. "`")
        end

        M.append_command_message(
            "[LLAMA] prompt commands: " .. table.concat(available_cmds, ", ")
        )
    end
end

M.submit_prompt = function()
    local input = M.get_input()

    if input == "" then
        return
    end

    -- check for any commands
    for _, value in pairs(commands) do
        if input == value then
            M.process_command(value)

            if vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
                -- Clear the prompt after submitting
                Utils.set_buf_lines(state.prompt.bufnr, 0, -1, false, {})
            end

            return
        end
    end

    if state.include_current_buffer then
        -- get the stats of current buffer
        local ok, stats = pcall(
            vim.loop.fs_stat,
            vim.api.nvim_buf_get_name(state.current_buf)
        )

        -- checked ollama server messages for truncated prompts that were larger than `num_ctx`
        -- ex. "msg="truncating input prompt" limit=4096 prompt=4881 keep=4 new=4096"
        --
        -- appx tokens in file = math.floor(file size in bytes * 0.286).
        if ok and stats and math.floor(stats.size * 0.286) > state.ctx_win then
            -- print("approximate tokens: " .. math.floor(stats.size * 0.286))

            vim.notify(
                "file larger than configured context window. current buffer was not included",
                vim.log.levels.WARN,
                { title = "llama.nvim" }
            )

            if vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
                -- Clear the prompt after submitting
                Utils.set_buf_lines(state.prompt.bufnr, 0, -1, false, {})
                vim.api.nvim_set_option_value(
                    "modifiable",
                    false,
                    { buf = state.prompt.bufnr }
                )
            end

            -- use original prompt
            M.append_user_prompt(input)
            M.append_model_response(input)

            return
        else
            -- save original prompt
            local user_prompt = input

            input = input .. "\n[CONTEXT]: "

            -- get lines from main buffer
            local lines =
                vim.api.nvim_buf_get_lines(state.current_buf, 0, -1, false)

            for _, line in ipairs(lines) do
                input = input .. line
            end

            user_prompt = user_prompt .. "\n [BUFFER INCLUDED]"

            if vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
                -- Clear the prompt after submitting
                Utils.set_buf_lines(state.prompt.bufnr, 0, -1, false, {})
                vim.api.nvim_set_option_value(
                    "modifiable",
                    false,
                    { buf = state.prompt.bufnr }
                )
            end

            -- use original prompt with indicator for which buffer was included
            M.append_user_prompt(user_prompt)

            -- use modified prompt
            M.append_model_response(input)

            return
        end
    end

    if vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
        -- Clear the prompt after submitting
        Utils.set_buf_lines(state.prompt.bufnr, 0, -1, false, {})
        vim.api.nvim_set_option_value(
            "modifiable",
            false,
            { buf = state.prompt.bufnr }
        )
    end

    -- use original prompt
    M.append_user_prompt(input)
    M.append_model_response(input)
end

M.clear_chat_window = function()
    Utils.set_buf_lines(state.chat.bufnr, 0, -1, false, {})
end

M.setup_keymaps = function()
    -- Scoped only to prompt buffer
    vim.keymap.set(
        state.keymaps.LlamaSubmitPrompt.mode,
        state.keymaps.LlamaSubmitPrompt.lhs,
        "<cmd>LlamaSubmitPrompt<CR>",
        { buffer = state.prompt.bufnr, noremap = true, silent = true }
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
end

return M
