" Property-based fuzz tests for Cleave reflow invariants.

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

let s:rng_state = 1
let s:word_bank = [
    \ 'alpha', 'beta', 'gamma', 'delta', 'layout', 'margin',
    \ 'notes', 'anchor', 'buffer', 'window', 'paragraph',
    \ 'alignment', 'document', 'cursor', 'stable', 'iteration',
    \ '中文', '日本語', 'multibyte', 'coverage',
    \ 'antidisestablishmentarianism',
    \ ]
let s:prefix_bank = ['', '  ', '    ', '- ', '* ', '1. ', '  - ']

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

function! s:continuation_prefix(prefix) abort
    if a:prefix =~# '^\s*\([-*+]\|\d\+\.\)\s\+$'
        return repeat(' ', strdisplaywidth(a:prefix))
    endif
    return a:prefix
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
    let cleave_col = s:rng_range(30, 76)
    let max_width = min([44, cleave_col - 4])
    if max_width < 10
        let max_width = 10
    endif

    let case_data = {
        \ 'cleave_col': cleave_col,
        \ 'width': s:rng_range(10, max_width),
        \ 'side': s:rng_choice(['left', 'right']),
        \ 'mode': s:rng_choice(['ragged', 'justify']),
        \ }

    let paragraph_count = s:rng_range(2, 7)
    let lines = []
    for para_idx in range(0, paragraph_count - 1)
        let line_count = s:rng_range(1, 3)
        let left_prefix = s:rng_choice(s:prefix_bank)
        let right_prefix = s:rng_choice(s:prefix_bank)

        for line_idx in range(0, line_count - 1)
            let left_line_prefix = line_idx == 0
                \ ? left_prefix
                \ : s:continuation_prefix(left_prefix)
            let right_line_prefix = line_idx == 0
                \ ? right_prefix
                \ : s:continuation_prefix(right_prefix)

            let left_text = left_line_prefix . s:random_sentence(7, 18)
            let right_text = right_line_prefix . s:random_sentence(7, 20)
            call add(lines,
                \ s:merge_columns(left_text, right_text, cleave_col))
        endfor
        if para_idx < paragraph_count - 1
            call add(lines, '')
            if s:rng_int(5) == 0
                call add(lines, '')
            endif
        endif
    endfor

    let case_data.lines = lines
    return case_data
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
        let lines = ['']
    endif

    let meta_file = get(g:, 'cleave_fuzz_replay_meta', replay_file . '.meta')
    let meta = s:read_meta_file(meta_file)

    return {
        \ 'lines': lines,
        \ 'cleave_col': s:to_number(
        \     get(g:, 'cleave_fuzz_replay_cleave_col',
        \         get(meta, 'cleave_col', 40)), 40),
        \ 'width': s:to_number(
        \     get(g:, 'cleave_fuzz_replay_width', get(meta, 'width', 20)),
        \     20),
        \ 'side': get(g:, 'cleave_fuzz_replay_side',
        \     get(meta, 'side', 'left')),
        \ 'mode': get(g:, 'cleave_fuzz_replay_mode',
        \     get(meta, 'mode', 'ragged')),
        \ }
endfunction

function! s:paragraph_starts(lines) abort
    let starts = []
    for idx in range(0, len(a:lines) - 1)
        if empty(trim(a:lines[idx]))
            continue
        endif
        if idx == 0 || empty(trim(a:lines[idx - 1]))
            call add(starts, idx + 1)
        endif
    endfor
    return starts
endfunction

function! s:paragraph_signatures(lines) abort
    let signatures = []
    let words = []

    for line in a:lines
        if empty(trim(line))
            if !empty(words)
                call add(signatures, join(words, ' '))
                let words = []
            endif
            continue
        endif

        call extend(words, split(trim(line), '\s\+'))
    endfor

    if !empty(words)
        call add(signatures, join(words, ' '))
    endif

    return signatures
endfunction

function! s:trim_trailing_empty(lines) abort
    let normalized = copy(a:lines)
    while !empty(normalized) && normalized[-1] ==# ''
        call remove(normalized, -1)
    endwhile
    return normalized
endfunction

function! s:join_lines(left_lines, right_lines, cleave_col) abort
    let combined = []
    let line_count = max([len(a:left_lines), len(a:right_lines)])

    for idx in range(0, line_count - 1)
        let left_line = idx < len(a:left_lines) ? a:left_lines[idx] : ''
        let right_line = idx < len(a:right_lines) ? a:right_lines[idx] : ''

        if empty(right_line)
            call add(combined, left_line)
            continue
        endif

        let left_width = strdisplaywidth(left_line)
        let padding = a:cleave_col - 1 - left_width
        if padding < 0
            let padding = 0
        endif

        call add(combined, left_line . repeat(' ', padding) . right_line)
    endfor

    return combined
endfunction

function! s:check_width(lines, width) abort
    let inside_fence = 0

    for idx in range(0, len(a:lines) - 1)
        let line = a:lines[idx]

        if line =~# '^\s*```'
            let inside_fence = !inside_fence
            continue
        endif
        if inside_fence || empty(trim(line))
            continue
        endif

        let line_width = strdisplaywidth(line)
        if line_width <= a:width
            continue
        endif

        if line =~# '[^ -~]' && line_width <= a:width + 1
            continue
        endif

        let tokens = split(trim(line), '\s\+')
        if !empty(tokens) && tokens[0] =~# '^\([-*+]\|\d\+\.\)$'
            call remove(tokens, 0)
        endif

        if len(tokens) <= 1
            continue
        endif

        let has_long_token = 0
        for token in tokens
            if strdisplaywidth(token) > a:width
                let has_long_token = 1
                break
            endif
        endfor

        if has_long_token
            continue
        endif

        return {
            \ 'ok': 0,
            \ 'line_number': idx + 1,
            \ 'line': line,
            \ 'line_width': line_width,
            \ }
    endfor

    return {'ok': 1}
endfunction

function! s:collect_anchor_lines(left_bufnr) abort
    if !has('textprop')
        return []
    endif

    let props = prop_list(1, {
        \ 'bufnr': a:left_bufnr,
        \ 'types': ['cleave_paragraph_start'],
        \ 'end_lnum': -1,
        \ })
    let lines = map(copy(props), 'v:val.lnum')
    call sort(lines, 'n')
    return lines
endfunction

function! s:failure(reason, detail, ...) abort
    let result = {'ok': 0, 'reason': a:reason, 'detail': a:detail}
    if a:0 > 0 && type(a:1) == v:t_dict
        call extend(result, a:1)
    endif
    return result
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

function! s:run_case(case_data, iteration) abort
    let saved_modeline = get(g:, 'cleave_modeline', 'read')
    let saved_hyphenate = get(g:, 'cleave_hyphenate', 1)
    let saved_dehyphenate = get(g:, 'cleave_dehyphenate', 1)

    try
        let g:cleave_modeline = 'ignore'
        let g:cleave_hyphenate = 0
        let g:cleave_dehyphenate = 0

        call s:wipe_case_buffers()
        call setline(1, a:case_data.lines)
        setlocal nomodified

        call cleave#SplitBuffer(bufnr('%'), a:case_data.cleave_col)

        let state = getbufvar(bufnr('%'), 'cleave', {})
        if get(state, 'side', '') !=# 'left'
            wincmd h
            let state = getbufvar(bufnr('%'), 'cleave', {})
        endif

        if get(state, 'side', '') !=# 'left'
            return s:failure('setup', 'missing left cleave buffer state')
        endif

        let left_bufnr = bufnr('%')
        let right_bufnr = get(state, 'peer', -1)
        if right_bufnr == -1 || !bufexists(right_bufnr)
            return s:failure('setup', 'missing right cleave buffer')
        endif

        if a:case_data.side ==# 'right'
            wincmd l
        endif

        let before_lines = getline(1, '$')
        let before_signatures = s:paragraph_signatures(before_lines)

        call cleave#ReflowBuffer(string(a:case_data.width), a:case_data.mode)

        let first_lines = getline(1, '$')
        let width_check = s:check_width(first_lines, a:case_data.width)
        if !get(width_check, 'ok', 0)
            return s:failure('width',
                \ 'line exceeds width with multiple words',
                \ width_check)
        endif

        let first_signatures = s:paragraph_signatures(first_lines)
        if string(first_signatures) !=# string(before_signatures)
            return s:failure('paragraph',
                \ 'paragraph signatures changed',
                \ {
                \ 'before': string(before_signatures),
                \ 'after': string(first_signatures),
                \ })
        endif

        call cleave#ReflowBuffer(string(a:case_data.width), a:case_data.mode)
        let second_lines = getline(1, '$')
        if string(first_lines) !=# string(second_lines)
            return s:failure('idempotence',
                \ 'second reflow changed output')
        endif

        call cleave#SetTextProperties()
        if has('textprop')
            let right_starts = s:paragraph_starts(
                \ getbufline(right_bufnr, 1, '$'))
            let left_anchors = s:collect_anchor_lines(left_bufnr)
            if string(left_anchors) !=# string(right_starts)
                return s:failure('anchors',
                    \ 'left anchors do not match right paragraphs',
                    \ {
                    \ 'anchors': string(left_anchors),
                    \ 'paragraphs': string(right_starts),
                    \ })
            endif
        endif

        let left_before_join = s:trim_trailing_empty(
            \ getbufline(left_bufnr, 1, '$'))
        let right_before_join = s:trim_trailing_empty(
            \ getbufline(right_bufnr, 1, '$'))
        let join_col = get(getbufvar(left_bufnr, 'cleave', {}),
            \ 'col', a:case_data.cleave_col)
        let expected_join = s:trim_trailing_empty(
            \ s:join_lines(left_before_join, right_before_join, join_col))

        call cleave#JoinBuffers()
        let joined_lines = s:trim_trailing_empty(getline(1, '$'))
        if string(expected_join) !=# string(joined_lines)
            return s:failure('roundtrip_join',
                \ 'join output does not match expected merge')
        endif

        call cleave#RecleaveLast()

        let recleave_state = getbufvar(bufnr('%'), 'cleave', {})
        let recleave_side = get(recleave_state, 'side', '')
        if index(['left', 'right'], recleave_side) == -1
            return s:failure('roundtrip', 'failed to re-cleave joined buffer')
        endif

        call cleave#UndoCleave()
    catch /.*/
        return s:failure('exception', v:exception,
            \ {'throwpoint': v:throwpoint})
    finally
        let g:cleave_modeline = saved_modeline
        let g:cleave_hyphenate = saved_hyphenate
        let g:cleave_dehyphenate = saved_dehyphenate
        call s:wipe_case_buffers()
    endtry

    return {'ok': 1}
endfunction

function! s:write_failure_case(case_data, result, seed, iteration) abort
    let fail_dir = get(g:, 'cleave_fuzz_fail_dir', 'test/fixtures/failures')
    call mkdir(fail_dir, 'p')

    let stamp = strftime('%Y%m%d_%H%M%S')
    let base_name = printf('reflow_failure_%s_seed%d_iter%d',
        \ stamp, a:seed, a:iteration)
    let case_file = fail_dir . '/' . base_name . '.txt'
    let meta_file = fail_dir . '/' . base_name . '.meta'

    call writefile(a:case_data.lines, case_file)

    let detail = substitute(get(a:result, 'detail', ''), '\n', ' ', 'g')
    call writefile([
        \ 'seed=' . a:seed,
        \ 'iteration=' . a:iteration,
        \ 'cleave_col=' . a:case_data.cleave_col,
        \ 'width=' . a:case_data.width,
        \ 'side=' . a:case_data.side,
        \ 'mode=' . a:case_data.mode,
        \ 'reason=' . get(a:result, 'reason', 'unknown'),
        \ 'detail=' . detail,
        \ ], meta_file)

    return {'case_file': case_file, 'meta_file': meta_file}
endfunction

function! s:report_failure(seed, iteration, result, artifacts) abort
    echomsg 'FAIL: reflow fuzz invariant violated.'
    echomsg '  seed=' . a:seed . ' iteration=' . a:iteration
    echomsg '  reason=' . get(a:result, 'reason', 'unknown')
    echomsg '  detail=' . get(a:result, 'detail', '')
    if has_key(a:result, 'line_number')
        echomsg '  line_number=' . a:result.line_number
    endif
    if has_key(a:result, 'line_width')
        echomsg '  line_width=' . a:result.line_width
    endif
    if has_key(a:result, 'line')
        echomsg '  line=' . a:result.line
    endif
    echomsg '  case=' . a:artifacts.case_file
    echomsg '  meta=' . a:artifacts.meta_file
endfunction

function! RunReflowFuzz() abort
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
            echomsg 'PASS: replay case satisfies reflow invariants.'
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
            echomsg 'Cleave fuzz progress: ' . iteration . '/' . iterations
        endif
    endfor

    echomsg 'PASS: Cleave reflow fuzz passed ' . iterations . ' cases.'
    return 0
endfunction
