" Pathogen
execute pathogen#infect()
syntax on
filetype plugin indent on

" Show line numbers
set number

" Use 256 colours
set t_Co=256

" Treat .t files as Perl scripts
au BufNewFile,BufRead *.t set filetype=perl
au BufNewFile,BufRead *.rst set filetype=rst
au BufNewFile,BufRead *.less set filetype=css
au BufNewFile,BufRead Capfile set filetype=ruby

" Set indents
set ts=4 sw=4 sts=4 expandtab
" Python
autocmd FileType python :setlocal ts=4 sw=4 sts=4
autocmd FileType python match ErrorMsg '\%>79v.\+'
" reStructuredText
autocmd FileType rst :setlocal ts=3 sw=3 sts=3 tw=79
" JSON
au BufNewFile,BufRead *.json :setlocal ts=2 sw=2 sts=2
" HTML
autocmd FileType html :setlocal ts=2 sw=2 sts=2
" YAML
autocmd FileType yaml :setlocal ts=2 sw=2 sts=2

" NERDTree shortcut
:nmap \e :NERDTreeToggle<CR>

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

" Move tab
function TabLeft()
  let tab_number = tabpagenr() - 1
  if tab_number == 0
    execute "tabm" tabpagenr('$') - 1
  else
    execute "tabm" tab_number - 1
  endif
endfunction

function TabRight()
  let tab_number = tabpagenr() - 1
  let last_tab_number = tabpagenr('$') - 1
  if tab_number == last_tab_number
    execute "tabm" 0
  else
    execute "tabm" tab_number + 1
  endif
endfunction

map <Up> :execute TabRight()<CR>
map <Down> :execute TabLeft()<CR>

" Swtich tab
map <Left> gT
map <Right> gt

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
set background=dark
colorscheme solarized

" command-t
let g:CommandTAcceptSelectionTabMap = '<CR>'
