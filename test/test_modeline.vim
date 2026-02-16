" Test script for cleave#modeline# functionality

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

function! AssertEqual(expected, actual, message)
    if a:expected != a:actual
        echomsg "FAIL: " . a:message
        echomsg "  Expected: '" . string(a:expected) . "'"
        echomsg "  Actual: '" . string(a:actual) . "'"
        return 0
    else
        echomsg "PASS: " . a:message
        return 1
    endif
endfunction

function! TestModelineParseBasic()
    new
    put =['Some text content.',
        \ '',
        \ 'Another paragraph.',
        \ 'vim: cc=91 tw=79 ve=all fdc=5 wm=3']
    1delete
    setlocal nomodified

    let result = cleave#modeline#parse(bufnr('%'))
    let settings = result.settings

    call AssertEqual(91, settings.cc, 'parse basic cc')
    call AssertEqual(79, settings.tw, 'parse basic tw')
    call AssertEqual('all', settings.ve, 'parse basic ve')
    call AssertEqual(5, settings.fdc, 'parse basic fdc')
    call AssertEqual(3, settings.wm, 'parse basic wm')

    bdelete!
    echomsg "TestModelineParseBasic completed"
endfunction

function! TestModelineParseFirstLines()
    new
    put =['vim: cc=80 tw=72 ve=all fdc=0 wm=3',
        \ '',
        \ 'Some text content.',
        \ '',
        \ 'Another paragraph.',
        \ 'More text here.',
        \ 'Even more text.',
        \ 'Last line of content.']
    1delete
    setlocal nomodified

    let result = cleave#modeline#parse(bufnr('%'))
    let settings = result.settings

    call AssertEqual(80, settings.cc, 'parse first lines cc')
    call AssertEqual(72, settings.tw, 'parse first lines tw')
    call AssertEqual(1, result.line, 'parse first lines line number')

    bdelete!
    echomsg "TestModelineParseFirstLines completed"
endfunction

function! TestModelineParseLastLines()
    new
    let lines = []
    for i in range(20)
        call add(lines, 'Line ' . i . ' of content.')
    endfor
    call add(lines, 'vim: cc=91 tw=79 ve=all fdc=5 wm=3')
    put =lines
    1delete
    setlocal nomodified

    let result = cleave#modeline#parse(bufnr('%'))
    let settings = result.settings

    call AssertEqual(21, result.line, 'parse last lines line number')
    call AssertEqual(91, settings.cc, 'parse last lines cc')
    call AssertEqual(79, settings.tw, 'parse last lines tw')

    bdelete!
    echomsg "TestModelineParseLastLines completed"
endfunction

function! TestModelineParseNone()
    new
    put =['Some text content.',
        \ '',
        \ 'No modeline here.',
        \ 'Just regular text.']
    1delete
    setlocal nomodified

    let result = cleave#modeline#parse(bufnr('%'))

    call AssertEqual(0, result.line, 'parse none line is 0')
    call AssertEqual({}, result.settings, 'parse none settings empty')

    bdelete!
    echomsg "TestModelineParseNone completed"
endfunction

function! TestModelineParsePreservesOther()
    new
    put =['Some text content.',
        \ 'vim: cc=91 tw=79 ft=markdown syn=on']
    1delete
    setlocal nomodified

    let result = cleave#modeline#parse(bufnr('%'))
    let settings = result.settings

    call AssertEqual(91, settings.cc, 'parse preserves cc')
    call AssertEqual(79, settings.tw, 'parse preserves tw')
    call AssertEqual(v:true, result.other =~# 'ft=markdown',
        \ 'other contains ft=markdown')
    call AssertEqual(v:true, result.other =~# 'syn=on',
        \ 'other contains syn=on')

    bdelete!
    echomsg "TestModelineParsePreservesOther completed"
endfunction

function! TestModelineParseSetFormat()
    new
    put =['Some text content.',
        \ 'vim: set cc=91 tw=79 :']
    1delete
    setlocal nomodified

    let result = cleave#modeline#parse(bufnr('%'))
    let settings = result.settings

    call AssertEqual(91, settings.cc, 'parse set format cc')
    call AssertEqual(79, settings.tw, 'parse set format tw')

    bdelete!
    echomsg "TestModelineParseSetFormat completed"
endfunction

function! TestModelineInfer()
    new
    put =['Some text for inference.',
        \ 'Another line of text.',
        \ 'Third line here.']
    1delete
    setlocal textwidth=70
    setlocal foldcolumn=3
    setlocal nomodified

    let settings = cleave#modeline#infer(bufnr('%'))

    call AssertEqual(70, settings.tw, 'infer tw from textwidth')
    call AssertEqual(3, settings.fdc, 'infer fdc from foldcolumn')
    call AssertEqual(v:true, has_key(settings, 'cc'), 'infer has cc')
    call AssertEqual(v:true, has_key(settings, 've'), 'infer has ve')
    call AssertEqual(v:true, has_key(settings, 'wm'), 'infer has wm')

    bdelete!
    echomsg "TestModelineInfer completed"
endfunction

function! TestModelineEnsureInsert()
    new
    put =['Some text content.',
        \ '',
        \ 'No modeline yet.']
    1delete
    setlocal nomodified

    let g:cleave_modeline = 'update'
    call cleave#modeline#ensure(bufnr('%'),
        \ {'cc': 91, 'tw': 79, 'fdc': 5, 'wm': 3, 've': 'all'})

    let last_line = getline('$')
    call AssertEqual(v:true, last_line =~# 'vim:', 'ensure insert has vim:')
    call AssertEqual(v:true, last_line =~# 'cc=91', 'ensure insert has cc=91')
    call AssertEqual(v:true, last_line =~# 'tw=79', 'ensure insert has tw=79')
    call AssertEqual(v:true, last_line =~# 'fdc=5', 'ensure insert has fdc=5')
    call AssertEqual(v:true, last_line =~# 'wm=3', 'ensure insert has wm=3')
    call AssertEqual(v:true, last_line =~# 've=all', 'ensure insert has ve=all')

    let g:cleave_modeline = 'read'
    bdelete!
    echomsg "TestModelineEnsureInsert completed"
endfunction

function! TestModelineEnsureUpdate()
    new
    put =['Some text content.',
        \ '',
        \ 'vim: cc=80 tw=72 ve=all fdc=0 wm=3']
    1delete
    setlocal nomodified

    let modeline_lnum = 3
    let g:cleave_modeline = 'update'
    call cleave#modeline#ensure(bufnr('%'),
        \ {'cc': 91, 'tw': 79, 'fdc': 0, 'wm': 3, 've': 'all'})

    let updated_line = getline(modeline_lnum)
    call AssertEqual(v:true, updated_line =~# 'cc=91',
        \ 'ensure update cc=91')
    call AssertEqual(v:true, updated_line =~# 'tw=79',
        \ 'ensure update tw=79')
    call AssertEqual(line('$'), modeline_lnum,
        \ 'ensure update same line count')

    let g:cleave_modeline = 'read'
    bdelete!
    echomsg "TestModelineEnsureUpdate completed"
endfunction

function! TestModelineEnsurePreservesOther()
    new
    put =['Some text content.',
        \ 'vim: cc=80 tw=72 ft=markdown']
    1delete
    setlocal nomodified

    let g:cleave_modeline = 'update'
    call cleave#modeline#ensure(bufnr('%'),
        \ {'cc': 91, 'tw': 72, 'fdc': 0, 'wm': 3, 've': 'all'})

    let updated_line = getline(2)
    call AssertEqual(v:true, updated_line =~# 'cc=91',
        \ 'ensure preserves updates cc')
    call AssertEqual(v:true, updated_line =~# 'ft=markdown',
        \ 'ensure preserves ft=markdown')

    let g:cleave_modeline = 'read'
    bdelete!
    echomsg "TestModelineEnsurePreservesOther completed"
endfunction

function! TestModelineEnsureIgnoreMode()
    new
    put =['Some text content.',
        \ 'No modeline here.']
    1delete
    setlocal nomodified

    let g:cleave_modeline = 'ignore'
    let line_count_before = line('$')
    call cleave#modeline#ensure(bufnr('%'),
        \ {'cc': 91, 'tw': 79, 'fdc': 5, 'wm': 3, 've': 'all'})

    call AssertEqual(line_count_before, line('$'),
        \ 'ignore mode no lines added')
    call AssertEqual('No modeline here.', getline('$'),
        \ 'ignore mode last line unchanged')

    let g:cleave_modeline = 'read'
    bdelete!
    echomsg "TestModelineEnsureIgnoreMode completed"
endfunction

function! TestModelineEnsureReadMode()
    new
    put =['Some text content.',
        \ 'No modeline here.']
    1delete
    setlocal nomodified

    let g:cleave_modeline = 'read'
    let line_count_before = line('$')
    call cleave#modeline#ensure(bufnr('%'),
        \ {'cc': 91, 'tw': 79, 'fdc': 5, 'wm': 3, 've': 'all'})

    call AssertEqual(line_count_before, line('$'),
        \ 'read mode no lines added')
    call AssertEqual('No modeline here.', getline('$'),
        \ 'read mode last line unchanged')

    bdelete!
    echomsg "TestModelineEnsureReadMode completed"
endfunction

function! TestModelineBuildString()
    let result = cleave#modeline#build_string(
        \ {'cc': 91, 'tw': 79, 'fdc': 5, 'wm': 3, 've': 'all'}, '')

    call AssertEqual(v:true, result =~# 'vim:', 'build string has vim:')
    call AssertEqual(v:true, result =~# 'cc=91', 'build string has cc=91')
    call AssertEqual(v:true, result =~# 'tw=79', 'build string has tw=79')
    call AssertEqual(v:true, result =~# 'fdc=5', 'build string has fdc=5')
    call AssertEqual(v:true, result =~# 'wm=3', 'build string has wm=3')
    call AssertEqual(v:true, result =~# 've=all', 'build string has ve=all')

    bdelete!
    echomsg "TestModelineBuildString completed"
endfunction

function! RunModelineTests()
    let s:pass_count = 0
    let s:fail_count = 0

    echomsg "Starting modeline tests..."
    echomsg "========================"

    " Capture messages and count pass/fail
    redir => s:messages
    silent! call TestModelineParseBasic()
    silent! call TestModelineParseFirstLines()
    silent! call TestModelineParseLastLines()
    silent! call TestModelineParseNone()
    silent! call TestModelineParsePreservesOther()
    silent! call TestModelineParseSetFormat()
    silent! call TestModelineInfer()
    silent! call TestModelineEnsureInsert()
    silent! call TestModelineEnsureUpdate()
    silent! call TestModelineEnsurePreservesOther()
    silent! call TestModelineEnsureIgnoreMode()
    silent! call TestModelineEnsureReadMode()
    silent! call TestModelineBuildString()
    redir END

    " Count results from captured messages
    let lines = split(s:messages, "\n")
    for line in lines
        if line =~# '^PASS:'
            let s:pass_count += 1
        elseif line =~# '^FAIL:'
            let s:fail_count += 1
        endif
        echomsg line
    endfor

    echomsg "========================"
    echomsg "Results: " . s:pass_count . " passed, " .
        \ s:fail_count . " failed"
    if s:fail_count > 0
        cquit!
    endif
endfunction

" Run tests if called directly
if expand('%:t') == 'test_modeline.vim'
    call RunModelineTests()
    qa!
endif
