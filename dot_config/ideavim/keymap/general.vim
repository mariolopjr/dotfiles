""" General keymap

"""" Windowing
" Focus window left
let g:WhichKeyDesc_Windows_WindowLeft = "<C-h> window left"
nnoremap <C-h>         <C-w>h
vnoremap <C-h>         <Esc><C-w>h

" Focus window right
let g:WhichKeyDesc_Windows_WindowRight = "<C-l> window right"
nnoremap <C-l>         <C-w>l
vnoremap <C-l>         <Esc><C-w>l

" Focus window down
let g:WhichKeyDesc_Windows_WindowDown = "<C-j> window down"
nnoremap <C-j>         <C-w>j
vnoremap <C-j>         <Esc><C-w>j

" Focus window up
let g:WhichKeyDesc_Windows_WindowUp = "<C-k> window up"
nnoremap <C-k>         <C-w>k
vnoremap <C-k>         <Esc><C-w>k

"""" Diagnostics
nmap ]e <Action>(GotoNextError)
nmap [e <Action>(GotoPreviousError)
