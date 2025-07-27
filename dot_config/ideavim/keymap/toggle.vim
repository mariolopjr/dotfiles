""" Toggle settings Keymap
let g:WhichKeyDesc_Toggle = "<leader>T    +toggle"

" Toggle Gutter icons
let g:WhichKeyDesc_Toggle_GutterIcons = "<leader>Tg gutter icons"
nnoremap <leader>Tg    :action EditorToggleShowGutterIcons<CR>
vnoremap <leader>Tg    :action EditorToggleShowGutterIcons<CR>

" Hide all windows except the ones with code
let g:WhichKeyDesc_Toggle_HideAllWindows = "<leader>Tm hide all windows"
nnoremap <leader>Tm    :action HideAllWindows<CR>
vnoremap <leader>Tm    :action HideAllWindows<CR>

" Toggle presentation mode
let g:WhichKeyDesc_Toggle_PresentationMode = "<leader>Tp presentation mode"
nnoremap <leader>Tp    :action TogglePresentationMode<CR>
vnoremap <leader>Tp    :action TogglePresentationMode<CR>

" Toggle presentation or distraction free mode
let g:WhichKeyDesc_Toggle_ChooseViewMode = "<leader>Tv choose view mode"
nnoremap <leader>Tv    :action ChangeView<CR>
vnoremap <leader>Tv    :action ChangeView<CR>
