""" AI Assistant keymaps

" AI chat assistant
let g:WhichKeyDesc_AI_Chat = "<leader>ac chat assistant"
map <leader>ac <Action>(AIAssistant.ToolWindow.ShowOrFocus)

" AI inline chat
let g:WhichKeyDesc_AI_Inline = "<leader>ai inline assistant"
map <leader>ai <Action>(AIAssistant.Editor.AskAiAssistantInEditor)
