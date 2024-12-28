--[[
    Files in the `lua` directory are not immediately executed on startup of
    Neovim but are available to the user to `require`
--]]

local Llama = {}

local state = {
    model = "",
    loaded = false,
}

---@param opts LlamaConfigPartial
Llama.setup = function(opts)
    local merged_opts = require("llama.config").merge_config(opts)

    state.model = merged_opts.model

    -- Initial keymap to load plugin/toggle chat window
    vim.keymap.set(
        merged_opts.keymaps.LlamaChat.mode,
        merged_opts.keymaps.LlamaChat.lhs,
        "<cmd>LlamaChat<CR>",
        { noremap = true, silent = true }
    )

    vim.api.nvim_create_user_command("LlamaChat", function()
        if not state.loaded then
            if not Llama.load() then
                return
            end

            require("llama.ui").init(
                state.model,
                merged_opts.chat,
                merged_opts.prompt,
                merged_opts.include_current_buffer,
                merged_opts.keymaps
            )
            require("llama.api").init(merged_opts.model_options)
            require("llama.ui").toggle_chat_window()

            state.loaded = true

            return
        end

        require("llama.ui").toggle_chat_window()
    end, {})
end

Llama.load = function()
    if not state.model or state.model == "" then
        vim.notify(
            "ERROR: missing or invalid 'model' field in plugin setup configuration",
            vim.log.levels.ERROR,
            { title = "llama.nvim" }
        )
        return false
    end

    local check_status = require("llama.health").check()

    if not check_status then
        vim.notify(
            "ERROR: failed llama.nvim healthcheck: run command ':checkhealth llama' for more information",
            vim.log.levels.ERROR,
            {}
        )
        return false
    end

    local status, model_data = require("llama.api").fetch_local_models()

    if not status then
        vim.notify(model_data, vim.log.levels.ERROR, {})
        return false
    end

    local model_found = false

    for _, value in pairs(model_data.models) do
        if state.model == value.model then
            model_found = true
            break
        end
    end

    if not model_found then
        vim.notify(
            "ERROR: failed to find model in list of local available models: provided "
                .. state.model,
            vim.log.levels.ERROR,
            {}
        )
        return false
    end

    return true
end

-- TODO: Remove
vim.keymap.set("n", "<leader>r", function()
    require("lazy.core.loader").reload("llama")
end)

return Llama
