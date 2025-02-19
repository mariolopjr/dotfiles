""" General keymaps

" cycle through errors
let g:WhichKeyDesc_General_GotoNextError = "goto next error"
nmap ]e <Action>(GotoNextError)
let g:WhichKeyDesc_General_GotoPreviousError = "goto previous error"
nmap [e <Action>(GotoPreviousError)
