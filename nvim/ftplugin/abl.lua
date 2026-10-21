-- OpenEdge ABL buffers.
-- Highlighting is in syntax/abl.lua: nvim's regex syntax for Progress. tree-sitter-abl
-- doesn't parse enough real-world ABL yet, and the language server sends no semantic tokens.
vim.bo.commentstring = "/* %s */"
vim.bo.comments = "s1:/*,mb:*,ex:*/,://"
-- Identifiers contain hyphens (NO-UNDO, cust-num), so w, * and completion treat them as one word
vim.opt_local.iskeyword:append("-")
-- gf / Ctrl+click on RUN x, {inc}, class names: try the ABL suffixes, and A.B.C as A/B/C(.cls)
vim.bo.suffixesadd = ".p,.w,.i,.cls"
vim.bo.includeexpr = [[v:fname =~ '^\h[[:alnum:]_-]*\(\.\h[[:alnum:]_-]*\)\+$' && v:fname !~ '\.\(p\|w\|i\|cls\)$' ? substitute(v:fname, '\.', '/', 'g') : v:fname]]
