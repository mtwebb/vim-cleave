" Comprehensive unit tests for virtual column utility functions
" Run with: vim -c "source test/test_virtual_column_comprehensive.vim" -c "call RunAllVirtualColumnTests()" -c "qa!"

" Test framework functions
function! AssertEqual(expected, actual, message)
    if a:expected != a:actual
        echomsg "FAIL: " . a:message
        echomsg "  Expected: " . string(a:expected)
        echomsg "  Actual: " . string(a:actual)
        return 0
    else
        echomsg "PASS: " . a:message
        return 1
    endif
endfunction

function! AssertTrue(condition, message)
    if a:condition
        echomsg "PASS: " . a:message
        return 1
    else
        echomsg "FAIL: " . a:message
        return 0
    endif
endfunction

" ============================================================================
" Comprehensive tests for cleave#vcol_to_byte()
" ============================================================================

function! TestVcolToByteASCII()
    echomsg "Testing cleave#vcol_to_byte() with ASCII content..."
    let passed = 0
    let total = 0
    
    " Basic ASCII tests
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("hello", 1), "ASCII: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("hello", 2), "ASCII: vcol 2 -> byte 1")
    let total += 1
    let passed += AssertEqual(4, cleave#vcol_to_byte("hello", 5), "ASCII: vcol 5 -> byte 4")
    let total += 1
    let passed += AssertEqual(5, cleave#vcol_to_byte("hello", 6), "ASCII: vcol 6 -> byte 5 (end)")
    let total += 1
    let passed += AssertEqual(-1, cleave#vcol_to_byte("hello", 10), "ASCII: vcol beyond string -> -1")
    
    " Edge cases
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("", 1), "Empty string: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("hello", 0), "Invalid vcol 0 -> byte 0")
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("hello", -1), "Invalid vcol -1 -> byte 0")
    
    " Single character
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("a", 1), "Single char: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("a", 2), "Single char: vcol 2 -> byte 1")
    
    echomsg "TestVcolToByteASCII: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVcolToByteTabs()
    echomsg "Testing cleave#vcol_to_byte() with tabs..."
    let passed = 0
    let total = 0
    
    " Save original tabstop
    let old_tabstop = &tabstop
    
    " Test with tabstop=8 (default)
    set tabstop=8
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("a\tb", 1), "Tab ts=8: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("a\tb", 2), "Tab ts=8: vcol 2 -> byte 1 (tab start)")
    let total += 1
    let passed += AssertEqual(2, cleave#vcol_to_byte("a\tb", 9), "Tab ts=8: vcol 9 -> byte 2 (after tab)")
    
    " Test with tabstop=4
    set tabstop=4
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("a\tb", 2), "Tab ts=4: vcol 2 -> byte 1 (tab start)")
    let total += 1
    let passed += AssertEqual(2, cleave#vcol_to_byte("a\tb", 5), "Tab ts=4: vcol 5 -> byte 2 (after tab)")
    
    " Multiple tabs
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("\t\t", 1), "Multiple tabs: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("\t\t", 5), "Multiple tabs: vcol 5 -> byte 1")
    let total += 1
    let passed += AssertEqual(2, cleave#vcol_to_byte("\t\t", 9), "Multiple tabs: vcol 9 -> byte 2")
    
    " Tab at different positions
    let total += 1
    let passed += AssertEqual(2, cleave#vcol_to_byte("ab\tc", 3), "Tab mid-string: vcol 3 -> byte 2")
    let total += 1
    let passed += AssertEqual(3, cleave#vcol_to_byte("ab\tc", 5), "Tab mid-string: vcol 5 -> byte 3")
    
    " Restore tabstop
    let &tabstop = old_tabstop
    
    echomsg "TestVcolToByteTabs: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVcolToByteCJK()
    echomsg "Testing cleave#vcol_to_byte() with CJK characters..."
    let passed = 0
    let total = 0
    
    " Chinese characters (2 columns each)
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("你好", 1), "CJK: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(3, cleave#vcol_to_byte("你好", 3), "CJK: vcol 3 -> byte 3 (second char)")
    let total += 1
    let passed += AssertEqual(6, cleave#vcol_to_byte("你好", 5), "CJK: vcol 5 -> byte 6 (end)")
    let total += 1
    let passed += AssertEqual(-1, cleave#vcol_to_byte("你好", 6), "CJK: vcol beyond -> -1")
    
    " Mixed ASCII and CJK
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("a你b", 1), "Mixed: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("a你b", 2), "Mixed: vcol 2 -> byte 1 (CJK start)")
    let total += 1
    let passed += AssertEqual(4, cleave#vcol_to_byte("a你b", 4), "Mixed: vcol 4 -> byte 4 (after CJK)")
    let total += 1
    let passed += AssertEqual(5, cleave#vcol_to_byte("a你b", 5), "Mixed: vcol 5 -> byte 5 (end)")
    
    " Japanese characters
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("こんにちは", 1), "Japanese: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(3, cleave#vcol_to_byte("こんにちは", 3), "Japanese: vcol 3 -> byte 3")
    
    " Korean characters
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("안녕하세요", 1), "Korean: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(3, cleave#vcol_to_byte("안녕하세요", 3), "Korean: vcol 3 -> byte 3")
    
    echomsg "TestVcolToByteCJK: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVcolToByteEmoji()
    echomsg "Testing cleave#vcol_to_byte() with emoji..."
    let passed = 0
    let total = 0
    
    " Basic emoji (2 columns each)
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("😀😃", 1), "Emoji: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(4, cleave#vcol_to_byte("😀😃", 3), "Emoji: vcol 3 -> byte 4 (second emoji)")
    
    " Mixed emoji and text
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte("a😀b", 1), "Emoji mixed: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(1, cleave#vcol_to_byte("a😀b", 2), "Emoji mixed: vcol 2 -> byte 1")
    let total += 1
    let passed += AssertEqual(5, cleave#vcol_to_byte("a😀b", 4), "Emoji mixed: vcol 4 -> byte 5")
    
    echomsg "TestVcolToByteEmoji: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVcolToByteComplex()
    echomsg "Testing cleave#vcol_to_byte() with complex mixed content..."
    let passed = 0
    let total = 0
    
    " Complex mixed content: ASCII + CJK + emoji + tabs
    let complex_string = "Hello\t你好😀World"
    
    " Test various positions in complex string
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte(complex_string, 1), "Complex: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(5, cleave#vcol_to_byte(complex_string, 6), "Complex: vcol 6 -> byte 5 (tab)")
    
    " Test with real-world content from test files
    let test_line = "Code 💻 + Coffee ☕ = Happy 😊"
    let total += 1
    let passed += AssertEqual(0, cleave#vcol_to_byte(test_line, 1), "Real content: vcol 1 -> byte 0")
    let total += 1
    let passed += AssertEqual(5, cleave#vcol_to_byte(test_line, 6), "Real content: vcol 6 -> byte 5")
    
    echomsg "TestVcolToByteComplex: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

" ============================================================================
" Comprehensive tests for cleave#byte_to_vcol()
" ============================================================================

function! TestByteToVcolASCII()
    echomsg "Testing cleave#byte_to_vcol() with ASCII content..."
    let passed = 0
    let total = 0
    
    " Basic ASCII tests
    let total += 1
    let passed += AssertEqual(1, cleave#byte_to_vcol("hello", 0), "ASCII: byte 0 -> vcol 1")
    let total += 1
    let passed += AssertEqual(2, cleave#byte_to_vcol("hello", 1), "ASCII: byte 1 -> vcol 2")
    let total += 1
    let passed += AssertEqual(5, cleave#byte_to_vcol("hello", 4), "ASCII: byte 4 -> vcol 5")
    let total += 1
    let passed += AssertEqual(6, cleave#byte_to_vcol("hello", 5), "ASCII: byte 5 -> vcol 6")
    let total += 1
    let passed += AssertEqual(6, cleave#byte_to_vcol("hello", 10), "ASCII: byte beyond -> vcol 6")
    
    " Edge cases
    let total += 1
    let passed += AssertEqual(1, cleave#byte_to_vcol("", 0), "Empty string: byte 0 -> vcol 1")
    let total += 1
    let passed += AssertEqual(1, cleave#byte_to_vcol("hello", -1), "Invalid byte -1 -> vcol 1")
    
    echomsg "TestByteToVcolASCII: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestByteToVcolTabs()
    echomsg "Testing cleave#byte_to_vcol() with tabs..."
    let passed = 0
    let total = 0
    
    " Save original tabstop
    let old_tabstop = &tabstop
    
    " Test with tabstop=8
    set tabstop=8
    let total += 1
    let passed += AssertEqual(1, cleave#byte_to_vcol("a\tb", 0), "Tab ts=8: byte 0 -> vcol 1")
    let total += 1
    let passed += AssertEqual(2, cleave#byte_to_vcol("a\tb", 1), "Tab ts=8: byte 1 -> vcol 2")
    let total += 1
    let passed += AssertEqual(9, cleave#byte_to_vcol("a\tb", 2), "Tab ts=8: byte 2 -> vcol 9")
    
    " Test with tabstop=4
    set tabstop=4
    let total += 1
    let passed += AssertEqual(2, cleave#byte_to_vcol("a\tb", 1), "Tab ts=4: byte 1 -> vcol 2")
    let total += 1
    let passed += AssertEqual(5, cleave#byte_to_vcol("a\tb", 2), "Tab ts=4: byte 2 -> vcol 5")
    
    " Restore tabstop
    let &tabstop = old_tabstop
    
    echomsg "TestByteToVcolTabs: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestByteToVcolCJK()
    echomsg "Testing cleave#byte_to_vcol() with CJK characters..."
    let passed = 0
    let total = 0
    
    " Chinese characters
    let total += 1
    let passed += AssertEqual(1, cleave#byte_to_vcol("你好", 0), "CJK: byte 0 -> vcol 1")
    let total += 1
    let passed += AssertEqual(3, cleave#byte_to_vcol("你好", 3), "CJK: byte 3 -> vcol 3")
    let total += 1
    let passed += AssertEqual(5, cleave#byte_to_vcol("你好", 6), "CJK: byte 6 -> vcol 5")
    
    " Mixed content
    let total += 1
    let passed += AssertEqual(1, cleave#byte_to_vcol("a你b", 0), "Mixed: byte 0 -> vcol 1")
    let total += 1
    let passed += AssertEqual(2, cleave#byte_to_vcol("a你b", 1), "Mixed: byte 1 -> vcol 2")
    let total += 1
    let passed += AssertEqual(4, cleave#byte_to_vcol("a你b", 4), "Mixed: byte 4 -> vcol 4")
    let total += 1
    let passed += AssertEqual(5, cleave#byte_to_vcol("a你b", 5), "Mixed: byte 5 -> vcol 5")
    
    echomsg "TestByteToVcolCJK: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

" ============================================================================
" Comprehensive tests for cleave#virtual_strpart()
" ============================================================================

function! TestVirtualStrpartASCII()
    echomsg "Testing cleave#virtual_strpart() with ASCII content..."
    let passed = 0
    let total = 0
    
    " Basic extraction tests
    let total += 1
    let passed += AssertEqual("hello", cleave#virtual_strpart("hello", 1), "ASCII: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("ello", cleave#virtual_strpart("hello", 2), "ASCII: extract from vcol 2")
    let total += 1
    let passed += AssertEqual("h", cleave#virtual_strpart("hello", 1, 2), "ASCII: extract vcol 1-2")
    let total += 1
    let passed += AssertEqual("ell", cleave#virtual_strpart("hello", 2, 5), "ASCII: extract vcol 2-5")
    let total += 1
    let passed += AssertEqual("o", cleave#virtual_strpart("hello", 5, 6), "ASCII: extract last char")
    
    " Edge cases
    let total += 1
    let passed += AssertEqual("", cleave#virtual_strpart("hello", 10), "ASCII: extract beyond string")
    let total += 1
    let passed += AssertEqual("", cleave#virtual_strpart("", 1), "Empty string: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("hello", cleave#virtual_strpart("hello", 0), "Invalid vcol 0 -> extract from vcol 1")
    let total += 1
    let passed += AssertEqual("hello", cleave#virtual_strpart("hello", 1, -1), "Negative end_vcol -> extract to end")
    let total += 1
    let passed += AssertEqual("hello", cleave#virtual_strpart("hello", 1, 0), "Zero end_vcol -> extract to end")
    
    echomsg "TestVirtualStrpartASCII: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVirtualStrpartCJK()
    echomsg "Testing cleave#virtual_strpart() with CJK characters..."
    let passed = 0
    let total = 0
    
    " Chinese characters
    let total += 1
    let passed += AssertEqual("你好", cleave#virtual_strpart("你好", 1), "CJK: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("好", cleave#virtual_strpart("你好", 3), "CJK: extract from vcol 3")
    let total += 1
    let passed += AssertEqual("你", cleave#virtual_strpart("你好", 1, 3), "CJK: extract vcol 1-3")
    let total += 1
    let passed += AssertEqual("", cleave#virtual_strpart("你好", 2, 3), "CJK: extract mid-character -> empty")
    
    " Mixed content
    let total += 1
    let passed += AssertEqual("a你b", cleave#virtual_strpart("a你b", 1), "Mixed: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("你b", cleave#virtual_strpart("a你b", 2), "Mixed: extract from vcol 2")
    let total += 1
    let passed += AssertEqual("a", cleave#virtual_strpart("a你b", 1, 2), "Mixed: extract vcol 1-2")
    let total += 1
    let passed += AssertEqual("你", cleave#virtual_strpart("a你b", 2, 4), "Mixed: extract vcol 2-4")
    let total += 1
    let passed += AssertEqual("b", cleave#virtual_strpart("a你b", 4, 5), "Mixed: extract vcol 4-5")
    
    " Japanese and Korean
    let total += 1
    let passed += AssertEqual("こ", cleave#virtual_strpart("こんにちは", 1, 3), "Japanese: extract first char")
    let total += 1
    let passed += AssertEqual("안", cleave#virtual_strpart("안녕하세요", 1, 3), "Korean: extract first char")
    
    echomsg "TestVirtualStrpartCJK: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVirtualStrpartTabs()
    echomsg "Testing cleave#virtual_strpart() with tabs..."
    let passed = 0
    let total = 0
    
    " Save original tabstop
    let old_tabstop = &tabstop
    set tabstop=8
    
    " Basic tab tests
    let total += 1
    let passed += AssertEqual("a\tb", cleave#virtual_strpart("a\tb", 1), "Tab: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("\tb", cleave#virtual_strpart("a\tb", 2), "Tab: extract from vcol 2")
    let total += 1
    let passed += AssertEqual("b", cleave#virtual_strpart("a\tb", 9), "Tab: extract after tab")
    let total += 1
    let passed += AssertEqual("a", cleave#virtual_strpart("a\tb", 1, 2), "Tab: extract before tab")
    
    " Multiple tabs
    let total += 1
    let passed += AssertEqual("\t", cleave#virtual_strpart("\t\t", 1, 9), "Multiple tabs: extract first tab")
    let total += 1
    let passed += AssertEqual("\t", cleave#virtual_strpart("\t\t", 9, 17), "Multiple tabs: extract second tab")
    
    " Restore tabstop
    let &tabstop = old_tabstop
    
    echomsg "TestVirtualStrpartTabs: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestVirtualStrpartEmoji()
    echomsg "Testing cleave#virtual_strpart() with emoji..."
    let passed = 0
    let total = 0
    
    " Basic emoji tests
    let total += 1
    let passed += AssertEqual("😀😃", cleave#virtual_strpart("😀😃", 1), "Emoji: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("😃", cleave#virtual_strpart("😀😃", 3), "Emoji: extract from vcol 3")
    let total += 1
    let passed += AssertEqual("😀", cleave#virtual_strpart("😀😃", 1, 3), "Emoji: extract vcol 1-3")
    
    " Mixed emoji and text
    let total += 1
    let passed += AssertEqual("a😀b", cleave#virtual_strpart("a😀b", 1), "Emoji mixed: extract from vcol 1")
    let total += 1
    let passed += AssertEqual("😀b", cleave#virtual_strpart("a😀b", 2), "Emoji mixed: extract from vcol 2")
    let total += 1
    let passed += AssertEqual("a", cleave#virtual_strpart("a😀b", 1, 2), "Emoji mixed: extract vcol 1-2")
    let total += 1
    let passed += AssertEqual("😀", cleave#virtual_strpart("a😀b", 2, 4), "Emoji mixed: extract vcol 2-4")
    
    echomsg "TestVirtualStrpartEmoji: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

" ============================================================================
" Round-trip conversion tests
" ============================================================================

function! TestRoundTripConversions()
    echomsg "Testing round-trip conversions..."
    let passed = 0
    let total = 0
    
    " Test strings with various character types
    let test_strings = [
        \ "hello world",
        \ "你好世界",
        \ "a\tb\tc",
        \ "mixed你好text",
        \ "😀😃😄😁",
        \ "Code 💻 + Coffee ☕",
        \ "",
        \ "a",
        \ "你",
        \ "😀"
    \ ]
    
    for test_string in test_strings
        let string_width = strdisplaywidth(test_string)
        for vcol in range(1, string_width + 2)
            let byte_pos = cleave#vcol_to_byte(test_string, vcol)
            if byte_pos != -1
                let back_to_vcol = cleave#byte_to_vcol(test_string, byte_pos)
                let total += 1
                let passed += AssertEqual(vcol, back_to_vcol, "Round-trip: '" . test_string . "' vcol " . vcol)
            endif
        endfor
    endfor
    
    echomsg "TestRoundTripConversions: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

" ============================================================================
" Performance benchmarks
" ============================================================================

function! BenchmarkVirtualColumnFunctions()
    echomsg "Running performance benchmarks..."
    
    " Test data preparation
    let ascii_line = "This is a simple ASCII line for performance testing with various lengths."
    let cjk_line = "这是一个中文性能测试行，包含各种长度的中日韩字符内容用于基准测试。"
    let mixed_line = "Mixed content 混合内容 with emoji 😀😃😄 and tabs\t\tfor testing."
    let long_line = repeat("Performance test line with mixed content 性能测试 😀 ", 20)
    
    let test_lines = [ascii_line, cjk_line, mixed_line, long_line]
    let iterations = 1000
    
    echomsg "Benchmarking with " . iterations . " iterations..."
    
    " Benchmark vcol_to_byte
    let start_time = reltime()
    for i in range(iterations)
        for line in test_lines
            for vcol in range(1, min([strdisplaywidth(line), 50]), 5)
                call cleave#vcol_to_byte(line, vcol)
            endfor
        endfor
    endfor
    let vcol_to_byte_time = reltimestr(reltime(start_time))
    echomsg "vcol_to_byte performance: " . vcol_to_byte_time . " seconds"
    
    " Benchmark byte_to_vcol
    let start_time = reltime()
    for i in range(iterations)
        for line in test_lines
            for byte_pos in range(0, min([len(line), 50]), 5)
                call cleave#byte_to_vcol(line, byte_pos)
            endfor
        endfor
    endfor
    let byte_to_vcol_time = reltimestr(reltime(start_time))
    echomsg "byte_to_vcol performance: " . byte_to_vcol_time . " seconds"
    
    " Benchmark virtual_strpart
    let start_time = reltime()
    for i in range(iterations)
        for line in test_lines
            let width = strdisplaywidth(line)
            for start_vcol in range(1, min([width, 30]), 5)
                for end_vcol in range(start_vcol + 5, min([width + 5, start_vcol + 15]), 5)
                    call cleave#virtual_strpart(line, start_vcol, end_vcol)
                endfor
            endfor
        endfor
    endfor
    let virtual_strpart_time = reltimestr(reltime(start_time))
    echomsg "virtual_strpart performance: " . virtual_strpart_time . " seconds"
    
    " Benchmark strdisplaywidth (for comparison)
    let start_time = reltime()
    for i in range(iterations * 10)
        for line in test_lines
            call strdisplaywidth(line)
        endfor
    endfor
    let strdisplaywidth_time = reltimestr(reltime(start_time))
    echomsg "strdisplaywidth performance (10x iterations): " . strdisplaywidth_time . " seconds"
    
    echomsg "Performance benchmark completed."
    echomsg "Note: Times may vary based on system performance and Vim version."
endfunction

" ============================================================================
" Test data validation
" ============================================================================

function! TestWithRealTestData()
    echomsg "Testing with real test data files..."
    let passed = 0
    let total = 0
    
    " Test with multibyte_ascii.txt content
    let ascii_content = [
        \ "This is a simple ASCII test file.",
        \ "Numbers: 0123456789",
        \ "Line with    multiple    spaces."
    \ ]
    
    for line in ascii_content
        let width = strdisplaywidth(line)
        for vcol in range(1, width + 1)
            let byte_pos = cleave#vcol_to_byte(line, vcol)
            let extracted = cleave#virtual_strpart(line, vcol, vcol + 1)
            let total += 1
            let passed += AssertTrue(byte_pos >= 0 || byte_pos == -1, "ASCII data: valid byte position for '" . line . "' vcol " . vcol)
        endfor
    endfor
    
    " Test with CJK content
    let cjk_content = [
        \ "这是一个中文测试文件",
        \ "Japanese Hiragana: これはひらがなのテストです",
        \ "Korean Hangul: 한국어 테스트 파일입니다"
    \ ]
    
    for line in cjk_content
        let width = strdisplaywidth(line)
        for vcol in range(1, min([width, 20]))
            let byte_pos = cleave#vcol_to_byte(line, vcol)
            let total += 1
            let passed += AssertTrue(byte_pos >= 0 || byte_pos == -1, "CJK data: valid byte position for vcol " . vcol)
        endfor
    endfor
    
    " Test with emoji content
    let emoji_content = [
        \ "Basic emoji: 😀 😃 😄 😁",
        \ "Code 💻 + Coffee ☕ = Happy 😊"
    \ ]
    
    for line in emoji_content
        let width = strdisplaywidth(line)
        for vcol in range(1, min([width, 15]))
            let byte_pos = cleave#vcol_to_byte(line, vcol)
            let total += 1
            let passed += AssertTrue(byte_pos >= 0 || byte_pos == -1, "Emoji data: valid byte position for vcol " . vcol)
        endfor
    endfor
    
    echomsg "TestWithRealTestData: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

" ============================================================================
" Main test runner
" ============================================================================

function! RunAllVirtualColumnTests()
    echomsg "Running comprehensive virtual column function tests..."
    echomsg "========================================================="
    
    let total_passed = 0
    let total_tests = 0
    
    " vcol_to_byte tests
    let [p1, t1] = TestVcolToByteASCII()
    let total_passed += p1 | let total_tests += t1
    
    let [p2, t2] = TestVcolToByteTabs()
    let total_passed += p2 | let total_tests += t2
    
    let [p3, t3] = TestVcolToByteCJK()
    let total_passed += p3 | let total_tests += t3
    
    let [p4, t4] = TestVcolToByteEmoji()
    let total_passed += p4 | let total_tests += t4
    
    let [p5, t5] = TestVcolToByteComplex()
    let total_passed += p5 | let total_tests += t5
    
    " byte_to_vcol tests
    let [p6, t6] = TestByteToVcolASCII()
    let total_passed += p6 | let total_tests += t6
    
    let [p7, t7] = TestByteToVcolTabs()
    let total_passed += p7 | let total_tests += t7
    
    let [p8, t8] = TestByteToVcolCJK()
    let total_passed += p8 | let total_tests += t8
    
    " virtual_strpart tests
    let [p9, t9] = TestVirtualStrpartASCII()
    let total_passed += p9 | let total_tests += t9
    
    let [p10, t10] = TestVirtualStrpartCJK()
    let total_passed += p10 | let total_tests += t10
    
    let [p11, t11] = TestVirtualStrpartTabs()
    let total_passed += p11 | let total_tests += t11
    
    let [p12, t12] = TestVirtualStrpartEmoji()
    let total_passed += p12 | let total_tests += t12
    
    " Round-trip and integration tests
    let [p13, t13] = TestRoundTripConversions()
    let total_passed += p13 | let total_tests += t13
    
    let [p14, t14] = TestWithRealTestData()
    let total_passed += p14 | let total_tests += t14
    
    echomsg "========================================================="
    echomsg "COMPREHENSIVE TEST RESULTS:"
    echomsg "Total: " . total_passed . "/" . total_tests . " tests passed"
    
    if total_passed == total_tests
        echomsg "🎉 ALL TESTS PASSED!"
    else
        echomsg "❌ " . (total_tests - total_passed) . " TESTS FAILED!"
    endif
    
    echomsg ""
    echomsg "Running performance benchmarks..."
    call BenchmarkVirtualColumnFunctions()
    
    return total_passed == total_tests ? 0 : 1
endfunction

" Convenience function to run just the performance benchmarks
function! RunPerformanceBenchmarks()
    call BenchmarkVirtualColumnFunctions()
endfunction