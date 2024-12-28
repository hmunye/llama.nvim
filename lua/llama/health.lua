local M = {}

M.check = function()
    vim.health.start("llama.nvim report")

    if vim.fn.executable("curl") == 0 then
        vim.health.error("curl is not installed or not in the PATH")
        return false
    end

    vim.health.ok("curl installed and found in PATH")

    if vim.fn.executable("ollama") == 0 then
        vim.health.error("ollama is not installed or not in the PATH")
        return false
    end

    vim.health.ok("ollama installed and found in PATH")

    -- synchronous
    local results = vim.system({ "curl", "--version" }, { text = true }):wait()

    if results.code ~= 0 then
        vim.health.error("failed to retrieve curl version: ", results.stderr)
        return false
    end

    local version = vim.version.parse(vim.split(results.stdout or "", " ")[2])

    if not version then
        vim.health.error("invalid curl version output: ", results.stdout)
        return false
    end

    -- Require curl 8.x.x or higher
    if version.major < 8 then
        vim.health.error(
            "curl must be version 8.x.x or higher. found version "
                .. tostring(version)
        )
        return false
    end

    vim.health.ok("curl " .. tostring(version) .. " is an acceptable version")

    -- synchronous
    results = vim.system({ "ollama", "-v" }, { text = true }):wait()

    if results.code ~= 0 then
        vim.health.error("failed to retrieve ollama version: ", results.stderr)
        return false
    end

    -- Don't need to split ollama version stdout
    version = vim.version.parse(results.stdout or "")

    if not version then
        vim.health.error("invalid ollama version output: ", results.stdout)
        return false
    end

    -- Require ollama 0.5.x or higher
    if version.minor < 5 then
        vim.health.error(
            "ollama must be version 0.5.x or higher. found version "
                .. tostring(version)
        )
        return false
    end

    vim.health.ok("ollama " .. tostring(version) .. " is an acceptable version")

    return true
end

return M
