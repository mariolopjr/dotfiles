""" Debug keymap
let g:WhichKeyDesc_Debug = "<leader>d    +debug"

nmap <Leader>db <Action>(ToggleLineBreakpoint)
nmap <Leader>dd <Action>(ActivateDebugToolWindow)
nmap <Leader>de <Action>(EvaluateExpression)
vmap <Leader>de <Action>(EvaluateExpression)
nmap <Leader>dr <Action>(Debug)
nmap <Leader>dc <Action>(Resume)
nmap <Leader>ds <Action>(Stop)
nmap <Leader>dj <Action>(StepOver)
nmap <Leader>dk <Action>(StepOut)

let g:WhichKeyDesc_Debug_ToggleBreakpoint = "<leader>db toggle breakpoint"
let g:WhichKeyDesc_Debug_ActivateDebugTool = "<leader>dd debug tool"
let g:WhichKeyDesc_Debug_EvaluateExpr = "<leader>de evaluate expression"
let g:WhichKeyDesc_Debug_Debug = "<leader>dr debug run"
let g:WhichKeyDesc_Debug_Resume = "<leader>dc debug resume"
let g:WhichKeyDesc_Debug_Stop = "<leader>ds debug stop"
let g:WhichKeyDesc_Debug_StepOver = "<leader>dj debug step over"
let g:WhichKeyDesc_Debug_StepOut = "<leader>dk debug step out"

