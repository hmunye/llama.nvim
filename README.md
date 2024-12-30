<div align="center">
  
<img src="https://github.com/user-attachments/assets/d5d38206-7c72-48d4-9ebb-0ce5ac82c7b4#gh-light-mode-only" width="400px" alt="llama.nvim logo"/>
<img src="https://github.com/user-attachments/assets/77c9a2b8-923a-4160-acd2-95e934f270e8#gh-dark-mode-only"  width="400px" alt="llama.nvim logo"/>

##### AI in your terminal, powered locally

[![Neovim](https://img.shields.io/static/v1?&style=for-the-badge&label=Neovim&message=v0.10%2b&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
</div>

## TOC
* [Overview](#overview)
* [Features](#features)
* [Installation](#installation)
* [Usage](#usage)

## Overview
**llama.nvim** is a Neovim plugin that provides local AI in your terminal via Ollama. 
A private experience integrated into your workflow, giving you full control.

## Features
- [x] Option to include or exclude the current buffer content as context for model
- [x] Enable switching between locally available models
- [x] Configuration of model options (e.g., temperature, system prompt, seed)
- [x] Enable/disable streaming of generated responses into the chat buffer

## Installation

### Prerequisites:
- **Neovim 0.10.0+**
- [**Ollama**](https://ollama.com/download)
- **curl**

### Start Ollama Server: 
You must run the Ollama server to interact with models. Start the server with the 
following command:

```bash
ollama serve
```
### Pull Model: 
You need to download a model to use with Ollama. For example, to pull the 
`llama3.2:3b` model, run the following command:

```bash
ollama pull llama3.2:3b
```
### Plugin Setup:

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

> Note: All options in setup are optional except for the `model` field

```lua
return {
    "hmunye/llama.nvim",
    dependencies = {},
    config = function()
        require("llama").setup({
            model = "llama3.2:3b", -- REQUIRED
            model_options = {
                -- (int) Controls whether Mirostat sampling is used. Mirostat is
                -- a method for controlling perplexity. 0 means it's disabled, 
                -- 1 enables Mirostat, and 2 enables Mirostat 2.0. (Default: 0)
                mirostat = 0, 

                -- (float) Affects how quickly the Mirostat algorithm responds 
                -- to feedback from the generated text. Lower values result in 
                -- slower adjustments, higher values make the model more responsive. 
                -- (Default: 0.1)
                mirostat_eta = 0.1, 

                -- (float) Controls the trade-off between coherence and diversity.
                -- Lower values make text more focused and coherent. Higher values 
                -- increase diversity. (Default: 5.0)
                mirostat_tau = 5.0, 

                -- (int) The size of the context window, which determines how many
                -- tokens the model considers at once when generating new tokens. 
                -- Larger values allow the model to maintain context over a larger 
                -- range of tokens. (Default: 2048)
                num_ctx = 2048, 

                -- (int) Determines how far back the model looks to prevent repeating 
                -- the same phrases. If set to 0, repetition is disabled. Setting it to 
                -- -1 uses the entire context window. (Default: 64)
                repeat_last_n = 64, 

                -- (float) Controls how strongly the model penalizes repetition. 
                -- A higher value makes the model less likely to repeat itself.
                -- (Default: 1.1)
                repeat_penalty = 1.1, 

                -- (float) Controls the creativity of the model's responses. A 
                -- higher value results in more creative (and possibly more random) text.
                -- A lower value makes the text more focused and predictable. 
                -- (Default: 0.8)
                temperature = 0.8, 

                -- (int) Sets the random number seed for text generation. 
                -- A fixed seed ensures repeatable outputs for the same input. 
                -- (Default: 0)
                seed = 0, 

                -- (string[]|nil) Defines one or more stop sequences that will halt the 
                -- text generation when encountered. (Default: nil)
                stop = nil, 

                -- (int) Defines the maximum number of tokens to generate in a response. 
                -- Setting it to -1 means the generation is unlimited. A positive integer 
                -- will limit the output to the specified number of tokens.
                -- (Default: -1)
                num_predict = -1, 

                -- (int) This setting reduces the likelihood of generating nonsensical 
                -- text by limiting the possible next token choices. A higher value 
                -- allows more diversity, while a lower value makes the text more focused.
                -- (Default: 40)
                top_k = 40, 

                -- (float) This works together with `top_k`. It defines the cumulative 
                -- probability of the most likely tokens to consider for the next token. 
                -- A value of 0.9 means that the top 90% of token probabilities will 
                -- be considered, increasing diversity. (Default: 0.9)
                top_p = 0.9, 

                -- (float) This is an alternative to `top_p`, filtering out tokens 
                -- with probabilities lower than a minimum threshold. For example, with 
                -- `min_p = 0.05`, any token with less than 5% of the probability of 
                -- the most likely token is ignored. (Default: 0.0)
                min_p = 0.0,
            },
            -- (string) A system prompt used to initialize or guide the AI model's behavior.
            system_message = "",
            -- (bool) Whether to stream the output as it is generated or wait until 
            -- the entire response is ready. (Default: true)
            stream = true,
            -- (bool) Indicates whether to include the current buffer's content 
            -- initially as context for the model. (Default: false)
            include_current_buffer = false,
            chat = {
                -- (string) Specifies the position of the chat interface. Options are 
                -- "left" and "right". (Default: "right")
                position = "right",
                -- (float) The width of the chat window as a percentage of current 
                -- window width. (Default: 30.0)
                width = 30.0,
                -- (string) Title of the chat window. (Default: "Llama")
                title = "Llama",
                -- (string) The position of the title. Options are "left", "center", 
                -- and "right". (Default: "center")
                title_position = "center",
                -- (string|string[]) Defines the style of the border for the chat window. 
                -- Options are "none", "single", "double", "rounded", "solid", "shadow",
                -- or array. (Default: "rounded")
                border = "rounded",
                -- (string) Defines the color of the loading spinner, using a hex 
                -- color code. (Default: "#FFFFFF")
                spinner_color = "#FFFFFF",
            },
            prompt = {
                -- (string) Defines the position of the prompt input window
                -- relative to the chat window. Options are "top" and "bottom". 
                -- (Default: "bottom")
                position = "bottom",
                -- (string|string[]) Defines the style of the border for the chat window. 
                -- Options are "none", "single", "double", "rounded", "solid", "shadow",
                -- or array. (Default: "rounded")
                border = "rounded",
                -- (bool) Whether the prompt starts in insert mode. (Default: true)
                start_insert_mode = true,
                -- (string) Defines the color of the background highlight of user 
                -- prompts within the chat window, using a hex color code. 
                -- (Default: "#303030")
                highlight_color = "#303030",
            },
            keymaps = {
                -- Keymap for toggling the chat
                LlamaChat = {
                    -- (table) Specifies the modes in which this keymap is active (e.g., "n", "v", "i", "t", etc.) (Default: { "n" })
                    mode = { "n" },
                    -- (string) The key combination that triggers the action. (Default: Ctrl + L)
                    lhs = "<C-l>",
                },
                -- Keymap for submitting a prompt (scoped to prompt buffer)
                LlamaSubmitPrompt = {
                    -- (table) (Default: { "n", "i" })
                    mode = { "n", "i" },
                    -- (string) (Default: Enter/Return)
                    lhs = "<CR>",
                },
            },
        })
    end,
}
```

## Usage

### User Commands

#### `LlamaChat`
- **Command**: `:LlamaChat`
- **Action**: Initializes the state for the plugin with user options if they haven't already been applied, 
then toggles the visibility of the chat window, otherwise just toggles the chat window

#### `LlamaSubmitPrompt`
- **Command**: `:LlamaSubmitPrompt`
- **Action**: Submits the contents of the prompt buffer to the currently selected model. 
If `commands` are provided, they will be processed independently. This command also uses
the `include_current_buffer` option to include the contents of the current buffer, 
if configured. The `LlamaSubmitPrompt` command and its associated keymap are scoped 
specifically to the prompt buffer.

### Prompt Commands

Within the prompt buffer, the following commands can be submitted:

  - **Command**: `/c`  
  **Action**: Clears the chat buffer

  - **Command**: `/buf`  
  **Action**: Sets the `include_current_buffer` option to true

  - **Command**: `/no_buf`  
  **Action**: Sets the `include_current_buffer` option to false

  - **Command**: `/l`  
  **Action**: Lists the locally available models on the host system

  - **Command**: `/switch`  
  **Action**: Provides a list of available to switch to, resetting the chat buffer and chat history

> Note: These commands should be entered just as regular prompts are
