--[[
    Files in the `lua` directory are not immediately executed on startup of
    Neovim but are available to the user to `require`
--]]

local Utils = require("llama.health")

local Llama = {}

function Llama.setup()
    local check_status = Utils.check()

    if not check_status then
        vim.notify(
            "error occured during plugin healthcheck. run command ':checkhealth llama' for more information",
            vim.log.levels.ERROR,
            {
                title = "llama.nvim",
            }
        )
        return
    end

    print("success")
end

vim.keymap.set("n", "<leader>r", function()
    require("lazy.core.loader").reload("llama")
end)

return Llama
