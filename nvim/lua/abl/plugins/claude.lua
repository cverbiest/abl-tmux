-- Claude Code IDE integration. claude runs in its own tmux pane, so nvim only runs
-- the server claude connects to (type /ide in claude).
return {
    "coder/claudecode.nvim",
    lazy = false, -- start the server right away so claude can find it
    opts = {
        terminal = { provider = "none" },
    },
    keys = {
        { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add buffer to Claude" },
        { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "x", desc = "Send selection to Claude" },
        { "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
        { "<leader>cn", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Reject Claude diff" },
    },
}
