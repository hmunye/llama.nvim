local M = {}

local loaded = false

--- initialize the user's config and set up the keymap/command for loading
--- the plugin and toggling the chat window
---
---@param opts LlamaOptsPartial -- user provided options
M.setup = function(opts)
    -- user-provided opts may be partial, so they are merged with default config
    local merged_opts = require("llama.config").merge_config(opts)

    vim.keymap.set(
        merged_opts.keymaps.LlamaChat.mode,
        merged_opts.keymaps.LlamaChat.lhs,
        "<cmd>LlamaChat<CR>",
        { noremap = true, silent = true }
    )

    -- delay loading most modules on start by requiring them inline
    vim.api.nvim_create_user_command("LlamaChat", function()
        if not loaded then
            if not M.load(merged_opts.model) then
                return
            end

            require("llama.ui").init(
                merged_opts.model,
                merged_opts.chat,
                merged_opts.prompt,
                merged_opts.keymaps,
                merged_opts.model_options.num_ctx
            )
            require("llama.ui").toggle_chat_window()

            require("llama.api").init(
                merged_opts.system_message,
                merged_opts.stream,
                merged_opts.model_options
            )

            loaded = true
        else
            require("llama.ui").toggle_chat_window()
        end
    end, {})
end

--- perform health check to verify if the plugin can function correctly
--- and ensure model is provided and available locally to use
---
---@param model string -- initial model provided
---@return boolean -- true if all checks pass, false otherwise
M.load = function(model)
    if not model or model == "" then
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
        -- should be a string since an error occurred, using tostring to satisfy warning
        vim.notify(tostring(model_data), vim.log.levels.ERROR, {})
        return false
    end

    local model_found = false

    for _, value in pairs(model_data.models) do
        if model == value.model then
            model_found = true
            break
        end
    end

    if not model_found then
        local available_models = {}

        for _, value in pairs(model_data.models) do
            table.insert(available_models, value.model)
        end

        vim.notify(
            "ERROR: failed to find model in list of local available models: provided '"
                .. model
                .. "'\navailable models: "
                .. table.concat(available_models, ", "),
            vim.log.levels.ERROR,
            {}
        )
        return false
    end

    return true
end

return M
