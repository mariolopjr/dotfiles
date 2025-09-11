""" Settings

" <SPC> as the leader key
let mapleader = " "

" ensure relative line numbers are used
set relativenumber number

" show current vim mode
set showmode

" use the clipboard register '*' for all yank, delete, change and put operations
" which would normally go to the unnamed register.
set clipboard+=unnamed

" search as characters are entered
set incsearch

" highlight search results
set hlsearch

" if a pattern contains an uppercase letter, searching is case sensitive,
" otherwise, it is not.
set ignorecase
set smartcase

" enable modeline support
set modelines=1

" enable joining lines
set ideajoin

" The ":substitute" flag 'g' is by default
set gdefault

