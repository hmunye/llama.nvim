--[[
    Files in the `lua` directory are not immediately executed on startup of
    Neovim but are available to the user to `require`
--]]

local Llama = {}

local state = {
    opts = {},
    loaded = false,
}

---@param opts LlamaConfigPartial
Llama.setup = function(opts)
    state.opts = require("llama.config").merge_config(opts)

    for action, keymap in pairs(state.opts.keymaps) do
        vim.keymap.set(
            keymap.mode,
            keymap.lhs,
            "<cmd>" .. action .. "<CR>",
            { noremap = true, silent = true }
        )
    end

    vim.api.nvim_create_user_command("LlamaChat", function()
        if not state.loaded then
            Llama.load()
        end
    end, {})

    vim.api.nvim_create_user_command("LlamaSubmitPrompt", function() end, {})

    vim.api.nvim_create_user_command("LlamaClearChat", function() end, {})
end

Llama.load = function()
    if not state.opts.model or state.opts.model == "" then
        vim.notify(
            "ERROR: missing or invalid 'model' field in plugin setup configuration",
            vim.log.levels.ERROR,
            { title = "llama.nvim" }
        )
        return
    end

    local check_status = require("llama.health").check()

    if not check_status then
        vim.notify(
            "ERROR: failed llama.nvim healthcheck: run command ':checkhealth llama' for more information",
            vim.log.levels.ERROR,
            {}
        )
        return
    end

    local status, data = require("llama.api").fetch_local_models()

    if not status then
        vim.notify(data, vim.log.levels.ERROR, {})
        return
    end

    local model_found = false

    for _, value in pairs(data.models) do
        if state.opts.model == value.model then
            model_found = true
            break
        end
    end

    if not model_found then
        vim.notify(
            "ERROR: failed to find model in list of local available models: provided "
            .. state.opts.model,
            vim.log.levels.ERROR,
            {}
        )
        return
    end

    print("loaded")
end

vim.keymap.set("n", "<leader>r", function()
    require("lazy.core.loader").reload("llama")
end)

return Llama
