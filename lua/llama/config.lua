local M = {}

--- @class LlamaOpts
--- @field model string
--- @field model_options ModelOpts
--- @field system_message string
--- @field stream boolean
--- @field chat ChatOpts
--- @field prompt PromptOpts
--- @field keymaps KeymapOpts

--- @class ModelOpts
--- @field mirostat number
--- @field mirostat_eta number
--- @field mirostat_tau number
--- @field num_ctx number
--- @field repeat_last_n number
--- @field repeat_penalty number
--- @field temperature number
--- @field seed number
--- @field stop string[]|nil
--- @field num_predict number
--- @field top_k number
--- @field top_p number
--- @field min_p number

--- @class ChatOpts
--- @field position string
--- @field width number
--- @field title string
--- @field title_position string
--- @field border string|string[]
--- @field spinner_color string

--- @class PromptOpts
--- @field position string
--- @field border string|string[]
--- @field start_insert_mode boolean
--- @field highlight_color string

--- @class KeymapOpts
--- @field LlamaChat Keymap
--- @field LlamaSubmitPrompt Keymap

--- @class Keymap
--- @field mode string[]
--- @field lhs string

--- @return LlamaOpts
local function get_default_config()
    return {
        model = "",
        model_options = {
            mirostat = 0,
            mirostat_eta = 0.1,
            mirostat_tau = 5.0,
            num_ctx = 2048,
            repeat_last_n = 64,
            repeat_penalty = 1.1,
            temperature = 0.8,
            seed = 0,
            stop = nil,
            num_predict = -1,
            top_k = 40,
            top_p = 0.9,
            min_p = 0.0,
        },
        system_message = "",
        stream = true,
        chat = {
            position = "right",
            width = 30.0,
            title = "LLAMA",
            title_position = "center",
            border = "rounded",
            spinner_color = "#FFFFFF",
        },
        prompt = {
            position = "bottom",
            border = "rounded",
            start_insert_mode = true,
            highlight_color = "#303030",
        },
        keymaps = {
            LlamaChat = {
                mode = { "n" },
                lhs = "<C-l>",
            },
            -- scoped to prompt buffer
            LlamaSubmitPrompt = {
                mode = { "n", "i" },
                lhs = "<CR>",
            },
        },
    }
end

--- @class LlamaOptsPartial
--- @field model string
--- @field model_options ModelOpts?
--- @field system_message string?
--- @field stream boolean?
--- @field chat ChatOpts?
--- @field prompt PromptOpts?
--- @field keymaps KeymapOpts?

--- @class ModelOptsPartial
--- @field mirostat number?
--- @field mirostat_eta number?
--- @field mirostat_tau number?
--- @field num_ctx number?
--- @field repeat_last_n number?
--- @field repeat_penalty number?
--- @field temperature number?
--- @field seed number?
--- @field stop string[]|nil
--- @field num_predict number?
--- @field top_k number?
--- @field top_p number?
--- @field min_p number?

--- @class ChatOptsPartial
--- @field position string?
--- @field width number?
--- @field title string?
--- @field title_position string?
--- @field border string|string[]?
--- @field spinner_color string?

--- @class PromptOptsPartial
--- @field position string?
--- @field border string|string[]?
--- @field start_insert_mode boolean?
--- @field highlight_color string?

--- @class KeymapOptsPartial
--- @field LlamaChat Keymap?
--- @field LlamaSubmitPrompt Keymap?

--- @class KeymapPartial
--- @field mode string[]?
--- @field lhs string?

--- merge users opts with the default config.
--- prefer a user's option when conflict occurs
---
--- @param partial_opts LlamaOptsPartial
--- @return LlamaOpts -- non-nil configuration
function M.merge_config(partial_opts)
    local default_config = get_default_config()

    return vim.tbl_extend("force", {}, default_config, partial_opts or {})
end

return M
