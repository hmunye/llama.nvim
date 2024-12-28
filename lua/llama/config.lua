local M = {}

--- @class LlamaConfig
--- @field model string
--- @field model_options ModelConfig
--- @field include_current_buffer boolean
--- @field chat ChatConfig
--- @field prompt PromptConfig
--- @field keymaps KeymapConfig

--- @class ModelConfig
--- @field mirostat number
--- @field mirostat_eta number
--- @field mirostat_tau number
--- @field num_ctx number
--- @field repeat_last_n number
--- @field repeat_penalty number
--- @field temperature number
--- @field seed number
--- @field stop string
--- @field tfs_z number
--- @field num_predict number
--- @field top_k number
--- @field top_p number
--- @field min_p number
--- @field system_message string
--- @field stream boolean

--- @class ChatConfig
--- @field position string
--- @field width number
--- @field title string
--- @field title_position string
--- @field border string|string[]
--- @field spinner_color string

--- @class PromptConfig
--- @field position string
--- @field border string|string[]
--- @field start_insert_mode boolean
--- @field highlight_color string

--- @class KeymapConfig
--- @field toggle_chat Keymap
--- @field submit_prompt Keymap
--- @field clear_chat Keymap

--- @class Keymap
--- @field mode string[]
--- @field lhs string

--- @return LlamaConfig
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
            stop = "",
            tfs_z = 1,
            num_predict = -1,
            top_k = 40,
            top_p = 0.9,
            min_p = 0.0,
            system_message = "",
            stream = true,
        },
        include_current_buffer = false,
        chat = {
            position = "right",
            width = 30.0,
            title = "Llama",
            title_position = "center",
            border = "rounded",
            spinner_color = "#FFFFFF",
        },
        prompt = {
            position = "bottom",
            border = "rounded",
            start_insert_mode = true,
            highlight_color = "#404040",
        },
        keymaps = {
            toggle_chat = {
                mode = { "n" },
                lhs = "<C-c>",
            },
            submit_prompt = {
                mode = { "n", "i" },
                lhs = "<CR>",
            },
            clear_chat = {
                mode = { "n" },
                lhs = "<leader>c",
            },
        },
    }
end

--- @class LlamaConfigPartial
--- @field model string
--- @field model_options ModelConfig?
--- @field include_current_buffer boolean?
--- @field chat ChatConfig?
--- @field prompt PromptConfig?
--- @field keymaps KeymapConfig?

--- @class ModelConfigPartial
--- @field mirostat number?
--- @field mirostat_eta number?
--- @field mirostat_tau number?
--- @field num_ctx number?
--- @field repeat_last_n number?
--- @field repeat_penalty number?
--- @field temperature number?
--- @field seed number?
--- @field stop string?
--- @field tfs_z number?
--- @field num_predict number?
--- @field top_k number?
--- @field top_p number?
--- @field min_p number?
--- @field system_message string?
--- @field stream boolean?

--- @class ChatConfigPartial
--- @field position string?
--- @field width number?
--- @field title string?
--- @field title_position string?
--- @field border string|string[]?
--- @field spinner_color string?

--- @class PromptConfigPartial
--- @field position string?
--- @field border string|string[]?
--- @field start_insert_mode boolean?
--- @field highlight_color string?

--- @class KeymapConfigPartial
--- @field toggle_chat Keymap?
--- @field submit_prompt Keymap?
--- @field clear_chat Keymap?

--- @class KeymapPartial
--- @field mode string[]?
--- @field lhs string?

--- @param partial_opts LlamaConfigPartial
--- @return LlamaConfig
function M.merge_config(partial_opts)
    local default_config = get_default_config()

    return vim.tbl_extend("force", {}, default_config, partial_config or {})
end

return M
