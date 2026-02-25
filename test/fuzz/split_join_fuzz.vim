" Property-based fuzz tests for split/join lifecycle invariants.

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

let s:rng_state = 1
let s:word_bank = [
    \ 'alpha', 'beta', 'gamma', 'delta', 'layout', 'margin',
    \ 'notes', 'anchor', 'buffer', 'window', 'paragraph',
    \ 'document', 'cursor', 'stable', 'iteration',
    \ 'coverage',
    \ ]
let s:prefix_bank = ['', '  ', '- ', '* ', '1. ']

function! s:rng_seed(seed) abort
    let s:rng_state = (a:seed % 2147483647)
    if s:rng_state <= 0
        let s:rng_state = 1
    endif
endfunction

function! s:rng_next() abort
    let s:rng_state = (s:rng_state * 48271) % 2147483647
    return s:rng_state
endfunction

function! s:rng_int(max) abort
    if a:max <= 0
        return 0
    endif
    return s:rng_next() % a:max
endfunction

function! s:rng_range(min_value, max_value) abort
    if a:max_value <= a:min_value
        return a:min_value
    endif
    return a:min_value + s:rng_int(a:max_value - a:min_value + 1)
endfunction

function! s:rng_choice(items) abort
    if empty(a:items)
        return ''
    endif
    return a:items[s:rng_int(len(a:items))]
endfunction

function! s:random_word() abort
    let word = s:rng_choice(s:word_bank)
    if s:rng_int(8) == 0
        let word .= s:rng_choice(['.', ',', ';', ':'])
    endif
    return word
endfunction

function! s:random_sentence(min_words, max_words) abort
    let word_count = s:rng_range(a:min_words, a:max_words)
    let words = []
    for _idx in range(1, word_count)
        call add(words, s:random_word())
    endfor
    return join(words, ' ')
endfunction

function! s:merge_columns(left_text, right_text, cleave_col) abort
    let left_text = a:left_text

    if strdisplaywidth(left_text) >= a:cleave_col
        let left_text = cleave#VirtualStrpart(left_text, 1, a:cleave_col)
    endif

    let padding = a:cleave_col - 1 - strdisplaywidth(left_text)
    if padding < 1
        let padding = 1
    endif

    return left_text . repeat(' ', padding) . a:right_text
endfunction

function! s:generate_case() abort
    let case_data = {}
    let case_data.cleave_col = s:rng_range(20, 90)

    let line_count = s:rng_range(3, 40)
    let lines = []
    let has_non_empty = 0

    for _idx in range(1, line_count)
        if s:rng_int(9) == 0
            call add(lines, '')
            continue
        endif

        let left_text = s:rng_choice(s:prefix_bank) .
            \ s:random_sentence(1, 8)
        let right_text = ''
        if s:rng_int(4) != 0
            let right_text = s:rng_choice(s:prefix_bank) .
                \ s:random_sentence(1, 10)
        endif

        if empty(right_text)
            call add(lines, left_text)
        else
            call add(lines,
                \ s:merge_columns(left_text, right_text,
                \ case_data.cleave_col))
        endif

        if !empty(trim(lines[-1]))
            let has_non_empty = 1
        endif
    endfor

    if !has_non_empty
        let lines = ['fallback split join line']
    endif

    let case_data.lines = lines
    return case_data
endfunction

function! s:trim_trailing_empty(lines) abort
    let normalized = copy(a:lines)
    while !empty(normalized) && normalized[-1] ==# ''
        call remove(normalized, -1)
    endwhile
    return normalized
endfunction

function! s:to_number(value, default_value) abort
    if type(a:value) == v:t_number
        return a:value
    endif
    if type(a:value) == v:t_string && a:value =~# '^\d\+$'
        return str2nr(a:value)
    endif
    return a:default_value
endfunction

function! s:read_meta_file(path) abort
    let meta = {}
    if empty(a:path) || !filereadable(a:path)
        return meta
    endif

    for line in readfile(a:path)
        let match = matchlist(line, '^\([^=]\+\)=\(.*\)$')
        if len(match) < 3
            continue
        endif
        let meta[match[1]] = match[2]
    endfor

    return meta
endfunction

function! s:replay_case() abort
    let replay_file = get(g:, 'cleave_fuzz_replay_file', '')
    let lines = filereadable(replay_file) ? readfile(replay_file) : []
    if empty(lines)
        let lines = ['fallback split join line']
    endif

    let meta_file = get(g:, 'cleave_fuzz_replay_meta', replay_file . '.meta')
    let meta = s:read_meta_file(meta_file)

    return {
        \ 'lines': lines,
        \ 'cleave_col': s:to_number(
        \     get(g:, 'cleave_fuzz_replay_cleave_col',
        \         get(meta, 'cleave_col', 40)), 40),
        \ }
endfunction

function! s:wipe_case_buffers() abort
    silent! only
    enew!
    let keep_buf = bufnr('%')

    for buffer_id in range(1, bufnr('$'))
        if buffer_id == keep_buf || !bufexists(buffer_id)
            continue
        endif
        execute 'silent! bwipeout!' buffer_id
    endfor
endfunction

function! s:failure(reason, detail, ...) abort
    let result = {'ok': 0, 'reason': a:reason, 'detail': a:detail}
    if a:0 > 0 && type(a:1) == v:t_dict
        call extend(result, a:1)
    endif
    return result
endfunction

function! s:first_mismatch(expected, actual) abort
    let max_len = max([len(a:expected), len(a:actual)])
    for idx in range(0, max_len - 1)
        let expected_line = idx < len(a:expected)
            \ ? a:expected[idx]
            \ : '<missing>'
        let actual_line = idx < len(a:actual)
            \ ? a:actual[idx]
            \ : '<missing>'
        if expected_line !=# actual_line
            return {
                \ 'line_number': idx + 1,
                \ 'expected_line': expected_line,
                \ 'actual_line': actual_line,
                \ }
        endif
    endfor

    return {'line_number': -1}
endfunction

function! s:run_case(case_data, iteration) abort
    let saved_modeline = get(g:, 'cleave_modeline', 'read')

    try
        let g:cleave_modeline = 'ignore'

        call s:wipe_case_buffers()
        call setline(1, a:case_data.lines)
        setlocal nomodified

        let original_lines = getline(1, '$')
        let original_trimmed = s:trim_trailing_empty(original_lines)

        call cleave#SplitBuffer(bufnr('%'), a:case_data.cleave_col)

        let state = getbufvar(bufnr('%'), 'cleave', {})
        if get(state, 'side', '') !=# 'left'
            wincmd h
            let state = getbufvar(bufnr('%'), 'cleave', {})
        endif

        if get(state, 'side', '') !=# 'left'
            return s:failure('split', 'missing left buffer state')
        endif

        let left_bufnr = bufnr('%')
        let right_bufnr = get(state, 'peer', -1)
        if right_bufnr == -1 || !bufexists(right_bufnr)
            return s:failure('split', 'missing right buffer')
        endif

        let split_parts = cleave#SplitContent(original_lines,
            \ a:case_data.cleave_col)
        let expected_left = split_parts[0]
        let expected_right = split_parts[1]

        let actual_left = getbufline(left_bufnr, 1, '$')
        let actual_right = getbufline(right_bufnr, 1, '$')
        if string(expected_left) !=# string(actual_left)
            let mismatch = s:first_mismatch(expected_left, actual_left)
            return s:failure('split_left',
                \ 'left split output mismatch', mismatch)
        endif
        if string(expected_right) !=# string(actual_right)
            let mismatch = s:first_mismatch(expected_right, actual_right)
            return s:failure('split_right',
                \ 'right split output mismatch', mismatch)
        endif

        call cleave#UndoCleave()
        let after_undo = s:trim_trailing_empty(getline(1, '$'))
        if string(after_undo) !=# string(original_trimmed)
            return s:failure('undo', 'undo did not restore original text')
        endif

        call cleave#RecleaveLast()
        let recleave_state = getbufvar(bufnr('%'), 'cleave', {})
        if get(recleave_state, 'side', '') !=# 'left'
            wincmd h
            let recleave_state = getbufvar(bufnr('%'), 'cleave', {})
        endif
        if get(recleave_state, 'side', '') !=# 'left'
            return s:failure('recleave', 'failed to re-cleave')
        endif

        call cleave#JoinBuffers()
        let after_join = s:trim_trailing_empty(getline(1, '$'))
        if string(after_join) !=# string(original_trimmed)
            return s:failure('join_roundtrip',
                \ 'join did not preserve original text')
        endif

        call cleave#RecleaveLast()
        let second_state = getbufvar(bufnr('%'), 'cleave', {})
        if index(['left', 'right'], get(second_state, 'side', '')) == -1
            return s:failure('recleave_second',
                \ 'second recleave failed')
        endif

        call cleave#JoinBuffers()
        let after_join_again = s:trim_trailing_empty(getline(1, '$'))
        if string(after_join_again) !=# string(after_join)
            return s:failure('join_idempotence',
                \ 'join+recleave drifted content')
        endif
    catch /.*/
        return s:failure('exception', v:exception,
            \ {'throwpoint': v:throwpoint})
    finally
        let g:cleave_modeline = saved_modeline
        call s:wipe_case_buffers()
    endtry

    return {'ok': 1}
endfunction

function! s:write_failure_case(case_data, result, seed, iteration) abort
    let fail_dir = get(g:, 'cleave_fuzz_fail_dir', 'test/fixtures/failures')
    call mkdir(fail_dir, 'p')

    let stamp = strftime('%Y%m%d_%H%M%S')
    let base_name = printf('split_join_failure_%s_seed%d_iter%d',
        \ stamp, a:seed, a:iteration)
    let case_file = fail_dir . '/' . base_name . '.txt'
    let meta_file = fail_dir . '/' . base_name . '.meta'

    call writefile(a:case_data.lines, case_file)

    let detail = substitute(get(a:result, 'detail', ''), '\n', ' ', 'g')
    call writefile([
        \ 'seed=' . a:seed,
        \ 'iteration=' . a:iteration,
        \ 'cleave_col=' . a:case_data.cleave_col,
        \ 'reason=' . get(a:result, 'reason', 'unknown'),
        \ 'detail=' . detail,
        \ ], meta_file)

    return {'case_file': case_file, 'meta_file': meta_file}
endfunction

function! s:report_failure(seed, iteration, result, artifacts) abort
    echomsg 'FAIL: split/join fuzz invariant violated.'
    echomsg '  seed=' . a:seed . ' iteration=' . a:iteration
    echomsg '  reason=' . get(a:result, 'reason', 'unknown')
    echomsg '  detail=' . get(a:result, 'detail', '')
    if has_key(a:result, 'line_number')
        echomsg '  line_number=' . a:result.line_number
    endif
    if has_key(a:result, 'expected_line')
        echomsg '  expected=' . a:result.expected_line
    endif
    if has_key(a:result, 'actual_line')
        echomsg '  actual=' . a:result.actual_line
    endif
    echomsg '  case=' . a:artifacts.case_file
    echomsg '  meta=' . a:artifacts.meta_file
endfunction

function! RunSplitJoinFuzz() abort
    let iterations = s:to_number(get(g:, 'cleave_fuzz_iterations', 250), 250)
    if iterations < 1
        let iterations = 1
    endif

    let seed = s:to_number(get(g:, 'cleave_fuzz_seed', localtime()),
        \ localtime())
    let replay_file = get(g:, 'cleave_fuzz_replay_file', '')

    if !empty(replay_file)
        let case_data = s:replay_case()
        let result = s:run_case(case_data, 1)
        if get(result, 'ok', 0)
            echomsg 'PASS: split/join replay case satisfies invariants.'
            return 0
        endif
        let artifacts = s:write_failure_case(case_data, result, seed, 1)
        call s:report_failure(seed, 1, result, artifacts)
        return 1
    endif

    call s:rng_seed(seed)

    for iteration in range(1, iterations)
        let case_data = s:generate_case()
        let result = s:run_case(case_data, iteration)

        if !get(result, 'ok', 0)
            let artifacts = s:write_failure_case(
                \ case_data, result, seed, iteration)
            call s:report_failure(seed, iteration, result, artifacts)
            return 1
        endif

        if iteration % 100 == 0
            echomsg 'Split/join fuzz progress: ' . iteration . '/' . iterations
        endif
    endfor

    echomsg 'PASS: Split/join fuzz passed ' . iterations . ' cases.'
    return 0
endfunction
