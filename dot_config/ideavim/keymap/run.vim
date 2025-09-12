""" Run keymap
let g:WhichKeyDesc_Run = "<leader>r    +run"

" Compile
let g:WhichKeyDesc_Run_Build = "<leader>rb build"
map <leader>rb <Action>(BuildSolutionAction)

" Run
let g:WhichKeyDesc_Run_Run = "<leader>rr run"
map <leader>rr <Action>(Run)

" Terminal
let g:WhichKeyDesc_Run_Terminal = "<leader>rt terminal"
map <leader>rt <Action>(ActivateTerminalToolWindow)
