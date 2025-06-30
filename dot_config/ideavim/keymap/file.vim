""" File Keymap
let g:WhichKeyDesc_File = "<leader>f    +file"

 Find files
let g:WhichKeyDesc_File_GotoFileAlt = "<leader>fF goto file"
nnoremap <leader>fF    :action GotoFile<CR>
vnoremap <leader>fF    :action GotoFile<CR>
let g:WhichKeyDesc_File_GotoFile = "<leader>ff goto file"
nnoremap <leader>ff    :action GotoFile<CR>
vnoremap <leader>ff    :action GotoFile<CR>

" Rename file
let g:WhichKeyDesc_File_Rename = "<leader>fR rename"
nnoremap <leader>fR    :action RenameFile<CR>
vnoremap <leader>fR    :action RenameFile<CR>

" Recent files
let g:WhichKeyDesc_File_Recent = "<leader>fr recent"
nnoremap <leader>fr    :action RecentFiles<CR>
vnoremap <leader>fr    :action RecentFiles<CR>

" Save all files
let g:WhichKeyDesc_File_SaveAll = "<leader>fS save all"
nnoremap <leader>fS    :action SaveAll<CR>
vnoremap <leader>fS    :action SaveAll<CR>

" Save single file
let g:WhichKeyDesc_File_Save = "<leader>fs save"
nnoremap <leader>fs    :action SaveDocument<CR>
vnoremap <leader>fs    :action SaveDocument<CR>

" Close file
let g:WhichKeyDesc_File_Close = "<leader>fc close"
nnoremap <leader>fc    :action CloseContent<CR>
vnoremap <leader>fc    :action CloseContent<CR>

" Focus on project window.
" Sadly when you are inside the project window this key binding does not work
" anymore. You can use <A-1> if you want to close the window or <Esc> if you
" want to leave the window opened and focus on the code.
let g:WhichKeyDesc_File_FileTree = "<leader>ft file tree"
nnoremap <leader>ft    :action ActivateProjectToolWindow<CR>
vnoremap <leader>ft    :action ActivateProjectToolWindow<CR>

"""" IDE submenu
let g:WhichKeyDesc_File_IDE = "<leader>fe +ide"

" Show settings
let g:WhichKeyDesc_File_IDE_Settings = "<leader>fed settings"
nnoremap <leader>fed    :action ShowSettings<CR>
vnoremap <leader>fed    <Esc>:action ShowSettings<CR>

" Reload .ideavimrc
let g:WhichKeyDesc_File_IDE_ReloadIdeaVimRc = "<leader>feR reload ideavimrc"
nnoremap <leader>feR    :source ~/.ideavimrc<CR>
vnoremap <leader>feR    <Esc>:source ~/.ideavimrc<CR>

"""" Yank/Copy submenu
let g:WhichKeyDesc_File_YankCopy = "<leader>fy +Yank/Copy"

" Copy file path
let g:WhichKeyDesc_File_YankCopy_FilePath = "<leader>fyy file path"
nnoremap <leader>fyy    :action CopyAbsolutePath<CR>
vnoremap <leader>fyy    :action CopyAbsolutePath<CR>
