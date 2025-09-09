""" easymotion keymap to ensure shows up in which-key
let g:WhichKeyDesc_EasyMotion = "<leader><leader>    +easymotion"
map <leader><leader> <Plug>(easymotion)

let g:WhichKeyDesc_EasyMotion_w = "<leader><leader>w Beginning of word forward."
map <leader><leader>w <Plug>(easymotion-f)
