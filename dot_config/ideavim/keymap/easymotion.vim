""" easymotion keymap to ensure shows up in which-key
let g:WhichKeyDesc_EasyMotion = "<leader><leader>    +easymotion"
map <leader><leader> <Plug>(easymotion)

map <leader><leader>f <Plug>(easymotion-f)
map <leader><leader>F <Plug>(easymotion-F)
map <leader><leader>t <Plug>(easymotion-t)
map <leader><leader>T <Plug>(easymotion-T)

map <leader><leader>w <Plug>(easymotion-w)
map <leader><leader>W <Plug>(easymotion-W)
map <leader><leader>b <Plug>(easymotion-b)
map <leader><leader>B <Plug>(easymotion-B)
map <leader><leader>e <Plug>(easymotion-e)
map <leader><leader>E <Plug>(easymotion-E)
map <leader><leader>ge <Plug>(easymotion-ge)
map <leader><leader>gE <Plug>(easymotion-gE)
map <leader><leader>j <Plug>(easymotion-j)
map <leader><leader>k <Plug>(easymotion-k)
map <leader><leader>n <Plug>(easymotion-n)
map <leader><leader>N <Plug>(easymotion-N)
map <leader><leader>s <Plug>(easymotion-s)

let g:WhichKeyDesc_EasyMotion_f = "<leader><leader>f find {char} to right"
let g:WhichKeyDesc_EasyMotion_F = "<leader><leader>F find {char} to left"
let g:WhichKeyDesc_EasyMotion_t = "<leader><leader>t till before {char} to right"
let g:WhichKeyDesc_EasyMotion_T = "<leader><leader>T till after {char} to left"

let g:WhichKeyDesc_EasyMotion_w = "<leader><leader>w beginning of word forward"
let g:WhichKeyDesc_EasyMotion_W = "<leader><leader>W beginning of WORD forward"
let g:WhichKeyDesc_EasyMotion_b = "<leader><leader>b beginning of word backward"
let g:WhichKeyDesc_EasyMotion_B = "<leader><leader>B beginning of WORD backward"
let g:WhichKeyDesc_EasyMotion_e = "<leader><leader>e end of word forward"
let g:WhichKeyDesc_EasyMotion_E = "<leader><leader>E end of WORD forward"
let g:WhichKeyDesc_EasyMotion_ge = "<leader><leader>ge end of word backward"
let g:WhichKeyDesc_EasyMotion_gE = "<leader><leader>gE end of WORD backward"
let g:WhichKeyDesc_EasyMotion_j = "<leader><leader>j line downward"
let g:WhichKeyDesc_EasyMotion_k = "<leader><leader>k line upward"
let g:WhichKeyDesc_EasyMotion_n = "<leader><leader>n jump to latest / or ? forward"
let g:WhichKeyDesc_EasyMotion_N = "<leader><leader>N jump to latest / or ? backward"
let g:WhichKeyDesc_EasyMotion_s = "<leader><leader>f find(search) {char} forward and backward"

