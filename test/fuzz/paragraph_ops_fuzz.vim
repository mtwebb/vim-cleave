" Property-based fuzz tests for paragraph shift/alignment invariants.

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
    let case_data.cleave_col = s:rng_range(30, 72)
    let case_data.steps = s:rng_range(10, 30)

    let paragraph_count = s:rng_range(2, 7)
    let lines = []

    for para_idx in range(0, paragraph_count - 1)
        let line_count = s:rng_range(1, 3)
        let left_prefix = s:rng_choice(s:prefix_bank)
        let right_prefix = s:rng_choice(s:prefix_bank)

        for _line_idx in range(1, line_count)
            let left_text = left_prefix . s:random_sentence(4, 10)
            let right_text = right_prefix . s:random_sentence(4, 12)
            call add(lines,
                \ s:merge_columns(left_text, right_text,
                \ case_data.cleave_col))
        endfor

        if para_idx < paragraph_count - 1
            call add(lines, '')
        endif
    endfor

    let case_data.lines = lines
    return case_data
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

function! s:collect_anchor_lines(left_bufnr) abort
    let props = prop_list(1, {
        \ 'bufnr': a:left_bufnr,
        \ 'types': ['cleave_paragraph_start'],
        \ 'end_lnum': -1,
        \ })
    let lines = map(copy(props), 'v:val.lnum')
    call sort(lines, 'n')
    return lines
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
        let lines = ['fallback paragraph ops line', '', 'second paragraph']
    endif

    let meta_file = get(g:, 'cleave_fuzz_replay_meta', replay_file . '.meta')
    let meta = s:read_meta_file(meta_file)

    return {
        \ 'lines': lines,
        \ 'cleave_col': s:to_number(
        \     get(g:, 'cleave_fuzz_replay_cleave_col',
        \         get(meta, 'cleave_col', 40)), 40),
        \ 'steps': s:to_number(
        \     get(g:, 'cleave_fuzz_replay_steps', get(meta, 'steps', 12)),
        \     12),
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

function! s:goto_buffer(bufnr) abort
    let winid = get(win_findbuf(a:bufnr), 0, -1)
    if winid == -1
        return 0
    endif
    return win_gotoid(winid)
endfunction

function! s:failure(reason, detail, ...) abort
    let result = {'ok': 0, 'reason': a:reason, 'detail': a:detail}
    if a:0 > 0 && type(a:1) == v:t_dict
        call extend(result, a:1)
    endif
    return result
endfunction

function! s:run_case(case_data, iteration) abort
    let saved_modeline = get(g:, 'cleave_modeline', 'read')

    try
        let g:cleave_modeline = 'ignore'

        call s:wipe_case_buffers()
        call setline(1, a:case_data.lines)
        setlocal nomodified

        let original_trimmed = s:trim_trailing_empty(getline(1, '$'))
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

        call cleave#SetTextProperties()

        let baseline_left = s:paragraph_signatures(
            \ getbufline(left_bufnr, 1, '$'))
        let baseline_right = s:paragraph_signatures(
            \ getbufline(right_bufnr, 1, '$'))

        for step in range(1, a:case_data.steps)
            let op = s:rng_int(3)
            if op == 0
                if !s:goto_buffer(right_bufnr)
                    return s:failure('window', 'right buffer window missing')
                endif
                let starts = s:paragraph_starts(getline(1, '$'))
                if !empty(starts)
                    let target = starts[s:rng_int(len(starts))]
                    call cursor(target, 1)
                    call cleave#ShiftParagraph(
                        \ s:rng_int(2) == 0 ? 'up' : 'down')
                endif
            elseif op == 1
                if !s:goto_buffer(left_bufnr)
                    return s:failure('window', 'left buffer window missing')
                endif
                let starts = s:paragraph_starts(getline(1, '$'))
                if !empty(starts)
                    let target = starts[s:rng_int(len(starts))]
                    call cursor(target, 1)
                    call cleave#ShiftParagraph(
                        \ s:rng_int(2) == 0 ? 'up' : 'down')
                endif
            else
                if !s:goto_buffer(right_bufnr)
                    return s:failure('window', 'right buffer window missing')
                endif
                call cleave#AlignRightToLeftParagraphs()
            endif

            if !s:goto_buffer(left_bufnr)
                return s:failure('window', 'left buffer window missing')
            endif
            call cleave#SetTextProperties()

            let current_left = s:paragraph_signatures(
                \ getbufline(left_bufnr, 1, '$'))
            let current_right = s:paragraph_signatures(
                \ getbufline(right_bufnr, 1, '$'))
            if string(current_left) !=# string(baseline_left)
                return s:failure('left_signature',
                    \ 'left paragraph text changed',
                    \ {'step': step})
            endif
            if string(current_right) !=# string(baseline_right)
                return s:failure('right_signature',
                    \ 'right paragraph text changed',
                    \ {'step': step})
            endif

            let anchor_lines = s:collect_anchor_lines(left_bufnr)
            let right_starts = s:paragraph_starts(
                \ getbufline(right_bufnr, 1, '$'))
            if string(anchor_lines) !=# string(right_starts)
                return s:failure('anchors',
                    \ 'left anchors and right starts diverged',
                    \ {'step': step})
            endif
        endfor

        if !s:goto_buffer(left_bufnr)
            return s:failure('window', 'left buffer window missing at cleanup')
        endif
        call cleave#UndoCleave()

        let after_undo = s:trim_trailing_empty(getline(1, '$'))
        if string(after_undo) !=# string(original_trimmed)
            return s:failure('undo', 'undo did not restore original text')
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
    let base_name = printf('paragraph_ops_failure_%s_seed%d_iter%d',
        \ stamp, a:seed, a:iteration)
    let case_file = fail_dir . '/' . base_name . '.txt'
    let meta_file = fail_dir . '/' . base_name . '.meta'

    call writefile(a:case_data.lines, case_file)

    let detail = substitute(get(a:result, 'detail', ''), '\n', ' ', 'g')
    call writefile([
        \ 'seed=' . a:seed,
        \ 'iteration=' . a:iteration,
        \ 'cleave_col=' . a:case_data.cleave_col,
        \ 'steps=' . a:case_data.steps,
        \ 'reason=' . get(a:result, 'reason', 'unknown'),
        \ 'detail=' . detail,
        \ ], meta_file)

    return {'case_file': case_file, 'meta_file': meta_file}
endfunction

function! s:report_failure(seed, iteration, result, artifacts) abort
    echomsg 'FAIL: paragraph ops fuzz invariant violated.'
    echomsg '  seed=' . a:seed . ' iteration=' . a:iteration
    echomsg '  reason=' . get(a:result, 'reason', 'unknown')
    echomsg '  detail=' . get(a:result, 'detail', '')
    if has_key(a:result, 'step')
        echomsg '  step=' . a:result.step
    endif
    echomsg '  case=' . a:artifacts.case_file
    echomsg '  meta=' . a:artifacts.meta_file
endfunction

function! RunParagraphOpsFuzz() abort
    if !has('textprop')
        echomsg 'Skipping paragraph ops fuzz: text properties unavailable.'
        return 0
    endif

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
            echomsg 'PASS: paragraph ops replay case satisfies invariants.'
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
            echomsg 'Paragraph ops fuzz progress: ' .
                \ iteration . '/' . iterations
        endif
    endfor

    echomsg 'PASS: Paragraph ops fuzz passed ' . iterations . ' cases.'
    return 0
endfunction
