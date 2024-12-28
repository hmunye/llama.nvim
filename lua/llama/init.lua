--[[
    Files in the `lua` directory are not immediately executed on startup of
    Neovim but are available to the user to `require`
--]]

local Health = require("llama.health")
local API = require("llama.api")

local Llama = {}

function Llama.setup(opts)
    if not opts.model then
        vim.notify(
            "ERROR: missing 'model' field in plugin setup configuration",
            vim.log.levels.ERROR,
            {}
        )
        return
    end

    local check_status = Health.check()

    if not check_status then
        vim.notify(
            "ERROR: failed llama.nvim healthcheck: run command ':checkhealth llama' for more information",
            vim.log.levels.ERROR,
            {}
        )
        return
    end

    local status, data = API.fetch_local_models()

    if not status then
        vim.notify(data, vim.log.levels.ERROR, {})
        return
    end

    local model_found = false

    for _, value in pairs(data.models) do
        if opts.model == value.model then
            model_found = true
            break
        end
    end

    if not model_found then
        vim.notify(
            "ERROR: failed to find model in list of local available models: provided "
                .. opts.model,
            vim.log.levels.ERROR,
            {}
        )
        return
    end
end

vim.keymap.set("n", "<leader>r", function()
    require("lazy.core.loader").reload("llama")
end)

return Llama
