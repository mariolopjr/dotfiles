""" Code keymap
let g:WhichKeyDesc_Code = "<leader>c    +code"

let g:WhichKeyDesc_Code_Action = "<leader>ca action list"
nmap <leader>ca    <Action>(ShowIntentionActions)

let g:WhichKeyDesc_Code_SearchSymbols = "<leader>cs search symbols"
nmap <leader>cs    <Action>(FileStructurePopup)
vmap <leader>cs    <Action>(FileStructurePopup)

let g:WhichKeyDesc_Code_SearchSymbolsInProject = "<leader>cS search symbols (project)"
nmap <leader>cS    <Action>(GotoSymbol)
vmap <leader>cS    <Action>(GotoSymbol)
