function! s:pushTag()
  " TODO: fallback implementation?
  if exists('*gettagstack') && exists('*settagstack')
    let l:winid = win_getid()
    let l:stack = gettagstack(l:winid)
    let l:item = {'bufnr': bufnr('%'), 'from': getpos('.'), 'tagname': expand('<cword>')}
    " Insert item into the stack at the current index
    call insert(l:stack['items'], l:item, l:stack['curidx']-1)
    " Truncate elements higher than the newly inserted element
    let l:stack['items'] = l:stack['items'][:l:stack['curidx']]
    let l:stack['curidx'] += 1
    call settagstack(l:winid, l:stack, 'r')
  endif
endfunction

function! gotodef#Jump()
  if exists('*LanguageClient#isServerRunning') && LanguageClient#isServerRunning()
    " This can be slow, especially if the language server is booting for the
    " first time
    echo "Using language server to find definition..."
    call s:pushTag()
    call LanguageClient#textDocument_definition()
  else
    call s:fzf_tag(expand('<cword>'))
  endif
endfunction

function! s:fzf_tag(identifier)
  let identifier = s:strip_leading_bangs(a:identifier)
  let source_lines = s:source_lines(identifier)

  if len(source_lines) == 0
    echohl WarningMsg
    echo 'Tag not found: ' . identifier
    echohl None
  elseif len(source_lines) == 1
    execute 'tag' identifier
  else
    let l:run_spec = fzf#vim#with_preview({
          \ 'source': source_lines,
          \ 'sink*': function('s:sink', [identifier]),
          \ 'window': { 'width': 0.9, 'height': 0.6 },
          \ 'placeholder': '--tag {2..}',
          \ })
    let l:run_spec['options'] = l:run_spec['options'] + [
          \ '--ansi',
          \ '--no-sort',
          \ '--tiebreak', 'index',
          \ '--prompt', 'tag> ',
          \ '--delimiter=:',
          \ ]
    " TODO: better rendering. Hide the tag preview spec as the last arg or
    " something

    call fzf#run(l:run_spec)
  endif
endfunction

function! s:strip_leading_bangs(identifier)
  if (a:identifier[0] !=# '!')
    return a:identifier
  else
    return s:strip_leading_bangs(a:identifier[1:])
  endif
endfunction

function! s:source_lines(identifier)
  let relevant_fields = map(
  \   taglist('^' . a:identifier . '$', expand('%:p')),
  \   function('s:tag_to_string')
  \ )
  return map(relevant_fields, 'join(v:val, ":")')
endfunction

function! s:tag_to_string(index, tag_dict)
  let components = [a:index + 1]
  call add(components, s:magenta(a:tag_dict['filename']))
  call add(components, '')
  call add(components, s:red(a:tag_dict['cmd']))
  return components
endfunction

function! s:sink(identifier, selection)
  let selected_text = a:selection[0]
  let l:count = split(selected_text, ':')[0]
  execute l:count . 'tag' a:identifier
endfunction

function! s:green(s)
  return "\033[32m" . a:s . "\033[m"
endfunction
function! s:magenta(s)
  return "\033[35m" . a:s . "\033[m"
endfunction
function! s:red(s)
  return "\033[31m" . a:s . "\033[m"
endfunction
