" Pathogen
execute pathogen#infect()
syntax on
filetype plugin indent on

" Show line numbers
set number

colorscheme molokai
" molokai kellys jellybeans
highlight Normal ctermbg=None

" Treat .t files as Perl scripts
au BufNewFile,BufRead *.t set filetype=perl
au BufNewFile,BufRead *.rst set filetype=rst
au BufNewFile,BufRead *.less set filetype=css
au BufNewFile,BufRead Capfile set filetype=ruby
au BufNewFile,BufRead *.tache set filetype=mustache
au BufNewFile,BufRead Taskfile set filetype=php

" Set indents
set ts=4 sw=4 sts=4 expandtab
" Python
autocmd FileType python :setlocal ts=4 sw=4 sts=4
autocmd FileType python match ErrorMsg '\%>79v.\+'
" reStructuredText
autocmd FileType rst :setlocal ts=3 sw=3 sts=3 tw=79
" JSON
au BufNewFile,BufRead *.json :setlocal ts=4 sw=4 sts=4
" HTML
autocmd FileType html :setlocal ts=2 sw=2 sts=2
" YAML
autocmd FileType yaml :setlocal ts=2 sw=2 sts=2

" Disable arrow keys
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

" One character insert
nmap <Space> i_<Esc>r
nmap <S-Space> a_<Esc>r

" Switch tab
map <Left> gT
map <Right> gt
" Move tab
nnoremap <silent> <Down> :execute 'silent! tabmove ' . (tabpagenr()-2)<CR>
nnoremap <silent> <Up> :execute 'silent! tabmove ' . tabpagenr()<CR>

" Set tab label format
:set guitablabel=%t%m

" Enable folding for PHP
let php_folding=1

set nobackup

" Disable syntastic for HTML
let g:syntastic_mode_map = { 'mode': 'active', 'active_filetypes': [], 'passive_filetypes': ['html'] }
" Use PSR2 check for PHP with phpcs
let g:syntastic_php_phpcs_args = "--report=csv --standard=PSR2 --ignore=vendor/"

" Prevent mouse selection from including line numbers
:se mouse+=a

" Undo dir
set undodir^=~/.vim/undo
" Swp dir
set dir=~/.vim/.swp

" Colour scheme
" colorscheme charon

" command-t
map OA <Up>
map OB <Down>
map OD <Left>
map OC <Right>
let g:CommandTAcceptSelectionTabMap = '<CR>'


map <c-j> :s/(/(\r        /g<CR>:s/, /,\r        /g<CR>:s/)/)\r    /<CR>

let g:phpqa_codecoverage_file="tests/reports/clover.xml"
let g:phpqa_codecoverage_showcovered = 0
