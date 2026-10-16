-- OpenEdge ABL buffers.
-- Highlighting is in syntax/abl.lua: nvim's regex syntax for Progress. tree-sitter-abl
-- doesn't parse enough real-world ABL yet, and the language server sends no semantic tokens.
vim.bo.commentstring = "/* %s */"
vim.bo.comments = "s1:/*,mb:*,ex:*/,://"
-- Identifiers contain hyphens (NO-UNDO, cust-num), so w, * and completion treat them as one word
vim.opt_local.iskeyword:append("-")
