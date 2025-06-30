" enable which-key extension
set which-key

" disable which-key timeout
set notimeout

" show the menu also for default Vim actions like `gg` or `zz`.
let g:WhichKey_ShowVimActions = "true"

" sort commands after prefixes
let g:WhichKey_SortOrder = "by_key_prefix_first"

" ensure sort 'a' before 'A'
let g:WhichKey_SortCaseSensitive = "false"
