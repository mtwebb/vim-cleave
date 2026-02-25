" Property-based fuzz tests for modeline parse/split/join invariants.

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

let s:rng_state = 1
let s:word_bank = [
    \ 'alpha', 'beta', 'gamma', 'delta', 'layout', 'margin',
    \ 'notes', 'anchor', 'buffer', 'window', 'paragraph',
    \ 'document', 'cursor', 'stable', 'iteration',
    \ ]
let s:valid_ve = ['all', 'block', 'insert', 'onemore', 'none']
let s:other_bank = ['ft=markdown', 'syn=on', 'ts=4', 'et', 'ai']

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
    return s:rng_choice(s:word_bank)
endfunction

function! s:random_sentence(min_words, max_words) abort
    let word_count = s:rng_range(a:min_words, a:max_words)
    let words = []
    for _idx in range(1, word_count)
        call add(words, s:random_word())
    endfor
    return join(words, ' ')
endfunction

function! s:generate_case() abort
    let cc = s:rng_range(20, 120)
    let tw = s:rng_range(10, min([90, cc]))
    let settings = {
        \ 'cc': cc,
        \ 'tw': tw,
        \ 'fdc': s:rng_range(0, 6),
        \ 'wm': s:rng_range(0, 8),
        \ 've': s:rng_choice(s:valid_ve),
        \ }

    let other_tokens = []
    let other_count = s:rng_range(0, 2)
    while len(other_tokens) < other_count
        let token = s:rng_choice(s:other_bank)
        if index(other_tokens, token) == -1
            call add(other_tokens, token)
        endif
    endwhile
    let other_opts = join(other_tokens, ' ')
    let modeline_line = cleave#modeline#BuildString(settings, other_opts)

    let body = []
    for _idx in range(1, 8)
        if s:rng_int(7) == 0
            call add(body, '')
        else
            call add(body, s:random_sentence(6, 14))
        endif
    endfor

    let lines = copy(body)
    if s:rng_int(2) == 0
        call insert(lines, modeline_line, 0)
        let cursor_line = min([2, len(lines)])
    else
        call add(lines, modeline_line)
        let cursor_line = 1
    endif

    return {
        \ 'settings': settings,
        \ 'other_tokens': other_tokens,
        \ 'modeline_line': modeline_line,
        \ 'lines': lines,
        \ 'cursor_line': cursor_line,
        \ }
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
        let lines = ['vim: cc=80 tw=72 fdc=0 wm=3 ve=all', 'fallback']
    endif

    let meta_file = get(g:, 'cleave_fuzz_replay_meta', replay_file . '.meta')
    let meta = s:read_meta_file(meta_file)

    let settings = {
        \ 'cc': s:to_number(get(meta, 'cc', 80), 80),
        \ 'tw': s:to_number(get(meta, 'tw', 72), 72),
        \ 'fdc': s:to_number(get(meta, 'fdc', 0), 0),
        \ 'wm': s:to_number(get(meta, 'wm', 3), 3),
        \ 've': get(meta, 've', 'all'),
        \ }

    return {
        \ 'settings': settings,
        \ 'other_tokens': split(get(meta, 'other_tokens', ''), ','),
        \ 'modeline_line': get(lines, 0, ''),
        \ 'lines': lines,
        \ 'cursor_line': s:to_number(get(meta, 'cursor_line', 1), 1),
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

function! s:run_case(case_data, iteration) abort
    let saved_modeline = get(g:, 'cleave_modeline', 'read')
    let saved_gutter = get(g:, 'cleave_gutter', 3)
    let saved_virtualedit = &virtualedit

    try
        let expected = cleave#modeline#Apply(a:case_data.settings)

        call s:wipe_case_buffers()
        call setline(1, [a:case_data.modeline_line])
        setlocal nomodified

        let parsed_direct = cleave#modeline#Parse(bufnr('%'))
        if parsed_direct.line != 1
            return s:failure('parse', 'direct parse did not find modeline')
        endif

        let parsed_settings = cleave#modeline#Apply(parsed_direct.settings)
        if parsed_settings.cc != expected.cc ||
            \ parsed_settings.tw != expected.tw ||
            \ parsed_settings.fdc != expected.fdc ||
            \ parsed_settings.wm != expected.wm
            return s:failure('parse_settings',
                \ 'direct parse settings mismatch')
        endif

        for token in a:case_data.other_tokens
            if empty(token)
                continue
            endif
            if stridx(parsed_direct.other, token) == -1
                return s:failure('parse_other',
                    \ 'direct parse lost other option: ' .. token)
            endif
        endfor

        call s:wipe_case_buffers()
        call setline(1, a:case_data.lines)
        setlocal nomodified

        let g:cleave_modeline = 'read'
        call cursor(max([1, a:case_data.cursor_line]), 2)
        call cleave#SplitBuffer(bufnr('%'))

        let state = getbufvar(bufnr('%'), 'cleave', {})
        if get(state, 'side', '') !=# 'left'
            wincmd h
            let state = getbufvar(bufnr('%'), 'cleave', {})
        endif
        if get(state, 'side', '') !=# 'left'
            return s:failure('split', 'missing left buffer state')
        endif

        let observed_col = get(state, 'col', -1)
        if observed_col != expected.cc
            return s:failure('split_col',
                \ 'split did not honor modeline cc')
        endif

        if get(g:, 'cleave_gutter', -1) != expected.wm
            return s:failure('split_wm',
                \ 'split did not apply modeline wm')
        endif

        let g:cleave_modeline = 'update'
        call cleave#JoinBuffers()

        let parsed_after = cleave#modeline#Parse(bufnr('%'))
        if parsed_after.line <= 0
            return s:failure('join_modeline',
                \ 'join did not produce parseable modeline')
        endif

        let after_settings = cleave#modeline#Apply(parsed_after.settings)
        if after_settings.cc != expected.cc
            return s:failure('join_cc', 'join modeline cc drifted')
        endif
        if after_settings.wm != expected.wm
            return s:failure('join_wm', 'join modeline wm drifted')
        endif

        for token in a:case_data.other_tokens
            if empty(token)
                continue
            endif
            if stridx(parsed_after.other, token) == -1
                return s:failure('join_other',
                    \ 'join modeline lost other option: ' .. token)
            endif
        endfor
    catch /.*/
        return s:failure('exception', v:exception,
            \ {'throwpoint': v:throwpoint})
    finally
        let g:cleave_modeline = saved_modeline
        let g:cleave_gutter = saved_gutter
        let &virtualedit = saved_virtualedit
        call s:wipe_case_buffers()
    endtry

    return {'ok': 1}
endfunction

function! s:write_failure_case(case_data, result, seed, iteration) abort
    let fail_dir = get(g:, 'cleave_fuzz_fail_dir', 'test/fixtures/failures')
    call mkdir(fail_dir, 'p')

    let stamp = strftime('%Y%m%d_%H%M%S')
    let base_name = printf('modeline_failure_%s_seed%d_iter%d',
        \ stamp, a:seed, a:iteration)
    let case_file = fail_dir . '/' . base_name . '.txt'
    let meta_file = fail_dir . '/' . base_name . '.meta'

    call writefile(a:case_data.lines, case_file)

    let detail = substitute(get(a:result, 'detail', ''), '\n', ' ', 'g')
    call writefile([
        \ 'seed=' . a:seed,
        \ 'iteration=' . a:iteration,
        \ 'cc=' . a:case_data.settings.cc,
        \ 'tw=' . a:case_data.settings.tw,
        \ 'fdc=' . a:case_data.settings.fdc,
        \ 'wm=' . a:case_data.settings.wm,
        \ 've=' . a:case_data.settings.ve,
        \ 'cursor_line=' . a:case_data.cursor_line,
        \ 'other_tokens=' . join(a:case_data.other_tokens, ','),
        \ 'reason=' . get(a:result, 'reason', 'unknown'),
        \ 'detail=' . detail,
        \ ], meta_file)

    return {'case_file': case_file, 'meta_file': meta_file}
endfunction

function! s:report_failure(seed, iteration, result, artifacts) abort
    echomsg 'FAIL: modeline fuzz invariant violated.'
    echomsg '  seed=' . a:seed . ' iteration=' . a:iteration
    echomsg '  reason=' . get(a:result, 'reason', 'unknown')
    echomsg '  detail=' . get(a:result, 'detail', '')
    echomsg '  case=' . a:artifacts.case_file
    echomsg '  meta=' . a:artifacts.meta_file
endfunction

function! RunModelineFuzz() abort
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
            echomsg 'PASS: modeline replay case satisfies invariants.'
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
            echomsg 'Modeline fuzz progress: ' . iteration . '/' . iterations
        endif
    endfor

    echomsg 'PASS: Modeline fuzz passed ' . iterations . ' cases.'
    return 0
endfunction
