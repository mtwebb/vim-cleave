vim9script

export def Cleave()
  const original_bufnr = bufnr('%')
  const original_bufname = bufname('%')
  const original_lines = getline(1, '$')
  const [_, _, cursor_col, _] = getpos('.')

  var left_lines: list<string> = []
  var right_lines: list<string> = []

  for line in original_lines
    if len(line) >= cursor_col
      add(left_lines, line[0 : cursor_col - 2])
      add(right_lines, line[cursor_col - 1 :])
    else
      add(left_lines, line)
      add(right_lines, '')
    endif
  endfor

  vnew
  setline(1, right_lines)
  execute 'file ' .. fnamemodify(original_bufname, ':t:r') .. '.right'

  wincmd p
  setline(1, left_lines)
  execute 'file ' .. fnamemodify(original_bufname, ':t:r') .. '.left'
enddef
