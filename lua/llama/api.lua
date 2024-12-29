local M = {}

local state = {
    opts = {
        system_message = "",
        stream = false,
        model_options = {},
    },
    messages = {},
}

---@param system_message string
---@param stream boolean
---@param model_options ModelOpts
M.init = function(system_message, stream, model_options)
    state.opts.system_message = system_message
    state.opts.stream = stream
    state.opts.model_options = model_options
end

---@return boolean -- true if the request was successful, false otherwise
---@return string|table -- error message if failed, or a table of models if successful
M.fetch_local_models = function()
    local results = vim.system(
        { "curl", "http://localhost:11434/api/tags" },
        { text = true }
    ):wait()

    if results.code ~= 0 then
        local err_parts = vim.split(results.stderr, "\n")
        local err_msg = ""

        for _, value in pairs(err_parts) do
            if string.find(value, "curl") then
                err_msg = value
                break
            end
        end

        return false, "ERROR: failed to retrieve local models: " .. err_msg
    end

    local success, decoded_results =
        pcall(vim.fn.json_decode, { results.stdout })

    if not success then
        return false,
            "ERROR: failed to decode JSON response for local models: "
                .. decoded_results
    end

    return true, decoded_results
end

---@param model string -- model used in generating chat
---@param prompt string -- user prompt
---@param callback function -- callback returns true and the next token/response or false and error message
M.generate_chat_completion = function(model, prompt, callback)
    if state.opts.system_message then
        local system_message = {
            role = "system",
            content = state.opts.system_message,
        }

        -- update chat memory once with system message
        table.insert(state.messages, system_message)

        state.opts.system_message = nil
    end

    local user_message = {
        role = "user",
        content = prompt,
    }

    -- update chat memory with user prompt
    table.insert(state.messages, user_message)

    local request_body = vim.fn.json_encode({
        model = model,
        messages = state.messages,
        options = state.opts.model_options,
        stream = state.opts.stream,
    })

    local function streamed_response()
        local on_exit = function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    local err_parts = vim.split(obj.stderr, "\n")
                    local err_msg = ""

                    for _, value in pairs(err_parts) do
                        if string.find(value, "curl") then
                            err_msg = value
                            break
                        end
                    end

                    callback(
                        false,
                        "ERROR: failed to generate chat completion: " .. err_msg
                    )
                    return
                end

                -- split each returned response when streaming otherwise
                local response_parts = vim.split(obj.stdout, "\n")

                local accumulated_response = ""

                for i, part in ipairs(response_parts) do
                    local success, decoded_part =
                        pcall(vim.fn.json_decode, { part })

                    if not success then
                        callback(
                            false,
                            "ERROR: failed to decode JSON response for chat completion: "
                                .. decoded_part
                        )
                        break
                    end

                    if decoded_part.done then
                        local assistant_message = {
                            role = "assistant",
                            content = accumulated_response,
                        }

                        -- update chat memory with full assistant message (role and content)
                        table.insert(state.messages, assistant_message)

                        -- end of stream
                        callback(true, "")
                        break
                    end

                    accumulated_response = accumulated_response
                        .. decoded_part.message.content

                    -- defers the callback incrementally based on the amount of responses
                    vim.defer_fn(function()
                        callback(true, decoded_part.message.content)
                    end, 40 * i)
                end
            end)
        end

        -- asynchronous
        vim.system(
            { "curl", "http://localhost:11434/api/chat", "-d", request_body },
            { text = true },
            on_exit
        )
    end

    local function non_streamed_response()
        local on_exit = function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    local err_parts = vim.split(obj.stderr, "\n")
                    local err_msg = ""

                    for _, value in pairs(err_parts) do
                        if string.find(value, "curl") then
                            err_msg = value
                            break
                        end
                    end

                    callback(
                        false,
                        "ERROR: failed to generate chat completion: " .. err_msg
                    )
                    return
                end

                -- don't need to split responses since it will be generated all at once
                local success, decoded_response =
                    pcall(vim.fn.json_decode, { obj.stdout })

                if not success then
                    callback(
                        false,
                        "ERROR: failed to decode JSON response for chat completion: "
                            .. decoded_response
                    )
                    return
                end

                -- update chat memory with full assistant message (role and content)
                table.insert(state.messages, decoded_response.message)

                callback(true, decoded_response.message.content)
            end)
        end

        -- asynchronous
        vim.system(
            { "curl", "http://localhost:11434/api/chat", "-d", request_body },
            { text = true },
            on_exit
        )
    end

    if not state.opts.stream then
        non_streamed_response()
    else
        streamed_response()
    end
end

return M
