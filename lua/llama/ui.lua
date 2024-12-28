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
    setup_complete = false,
}

--- @param model string
--- @param chat_opts ChatConfig
--- @param prompt_opts PromptConfig
--- @param include_current_buffer boolean
--- @param keymaps KeymapConfig
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
        -- Chat window will be on the left side
        col = 0
    else
        -- Chat window will be on the right side (Default)
        col = vim.api.nvim_win_get_width(0) - state.chat.width
    end

    if not vim.api.nvim_buf_is_valid(state.chat.bufnr) then
        state.chat.bufnr = vim.api.nvim_create_buf(false, true)
    end

    -- Chat window to top (Default)
    local row = 0

    if state.prompt.opts.position == "top" then
        -- Chat window to bottom
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

    if not state.setup_complete then
        M.setup_keymaps()
        M.setup_buf_commands()

        state.setup_complete = true
    end
end

---@param chat_col number
M.create_prompt_window = function(chat_col)
    if not vim.api.nvim_buf_is_valid(state.prompt.bufnr) then
        -- BUG: Unexpected behaviors when opening Oil file explorer within
        -- prompt buffer and toggling chat window
        state.prompt.bufnr = vim.api.nvim_create_buf(false, true)
    end

    local prompt_height = math.floor(state.chat.height * 0.10)

    -- Default to bottom
    local row = state.chat.height + 2

    if state.prompt.opts.position == "top" then
        -- Prompt window to top
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

M.submit_prompt = function()
    print("submitted")
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
