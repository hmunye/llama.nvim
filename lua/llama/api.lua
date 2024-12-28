local M = {}

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

return M
