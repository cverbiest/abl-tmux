-- VS Code files (settings.json, tasks.json, *.code-workspace): JSON with comments and
-- trailing commas, and the workspace's .code-workspace file.
local M = {}

-- vim.json.decode skips the comments; drop the trailing commas first.
function M.decode(s)
    -- Index of the next token after whitespace and comments
    local function next_token(i)
        while true do
            i = s:match("^%s*()", i)
            if s:sub(i, i + 1) == "//" then
                i = (s:find("\n", i, true) or #s) + 1
            elseif s:sub(i, i + 1) == "/*" then
                i = (select(2, s:find("*/", i + 2, true)) or #s) + 1
            else
                return i
            end
        end
    end
    local parts, start, i = {}, 1, 1
    while true do
        local j = s:find('[",/]', i)
        if not j then break end
        local c = s:sub(j, j)
        if c == '"' then
            local k = j + 1
            repeat
                k = s:find('[\\"]', k)
                local escape = k and s:sub(k, k) == "\\"
                if escape then k = k + 2 end
            until not escape
            i = (k or #s) + 1
        elseif c == "/" then
            local pair = s:sub(j, j + 1)
            i = (pair == "//" or pair == "/*") and next_token(j) or j + 1
        else
            if s:sub(next_token(j + 1)):match("^[%]}]") then
                parts[#parts + 1] = s:sub(start, j - 1)
                start = j + 1
            end
            i = j + 1
        end
    end
    parts[#parts + 1] = s:sub(start)
    return vim.json.decode(table.concat(parts), { skip_comments = true })
end

-- Decoded file, {} when missing or unreadable
function M.read(path)
    local f = io.open(path)
    if not f then return {} end
    local text = f:read("*a")
    f:close()
    local ok, data = pcall(M.decode, text)
    if not ok or type(data) ~= "table" then
        vim.notify("Can't read " .. path .. ": " .. tostring(data), vim.log.levels.WARN)
        return {}
    end
    return data
end

-- The workspace's .code-workspace: the only one in root, or the one named after it
function M.workspace_file(root)
    local files = vim.fn.glob(root .. "/*.code-workspace", false, true)
    if #files <= 1 then return files[1] end
    local own = root .. "/" .. vim.fs.basename(root) .. ".code-workspace"
    return vim.uv.fs_stat(own) and own or nil
end

return M
