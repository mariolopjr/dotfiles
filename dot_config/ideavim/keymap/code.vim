""" Code keymap
let g:WhichKeyDesc_Code = "<leader>c    +code"

nmap <leader>ca <Action>(ShowIntentionActions)
nmap <leader>ce <Action>(ShowErrorDescription)
nmap <leader>cf <Action>(ReformatCode)
nmap <leader>cF <Action>(ReformatWithPrettierAction)
nmap <leader>ch <Action>(CallHierarchy)
nmap <leader>ci <Action>(OptimizeImports)
nmap <leader>cm <Action>(MethodHierarchy)
nmap <leader>cp <Action>(ParameterInfo)
nmap <leader>cr <Action>(RenameElement)
nmap <leader>cs <Action>(FileStructurePopup)
nmap <leader>cS <Action>(GotoSymbol)
nmap <leader>ct <Action>(ExpressionTypeInfo)
nmap <leader>cu <Action>(ShowUsages)
nmap <leader>cU <Action>(ShowUmlDiagram)

let g:WhichKeyDesc_Code_Action = "<leader>ca action list"
let g:WhichKeyDesc_Code_ShowErrorDescr = "<leader>ce show error description"
let g:WhichKeyDesc_Code_FormatCode = "<leader>cf format code"
let g:WhichKeyDesc_Code_FormatCodeWithPrettier = "<leader>cF format code with prettier"
let g:WhichKeyDesc_Code_CallHierarchy = "<leader>ch call hierarchy"
let g:WhichKeyDesc_Code_OptimizeImports = "<leader>ci optimize imports"
let g:WhichKeyDesc_Code_MethodHierarchy = "<leader>cm method hierarchy"
let g:WhichKeyDesc_Code_ParamInfo = "<leader>cp parameter info"
let g:WhichKeyDesc_Code_RenameSymbol = "<leader>cr rename symbol"
let g:WhichKeyDesc_Code_SearchSymbols = "<leader>cs search symbols"
let g:WhichKeyDesc_Code_SearchSymbolsInProject = "<leader>cS search symbols (project)"
let g:WhichKeyDesc_Code_ExprTypeInfo = "<leader>ct expression type info"
let g:WhichKeyDesc_Code_ShowUsages = "<leader>cu show usages"
let g:WhichKeyDesc_Code_ShowUml = "<leader>cU show uml"

