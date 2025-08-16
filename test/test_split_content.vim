" Test script for cleave#split_content() virtual column functionality

" Load the cleave plugin
source autoload/cleave.vim

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

function! TestSplitContentVirtualColumns()
    echomsg "Testing cleave#split_content() with virtual columns..."
    let passed = 0
    let total = 0
    
    " Test 1: ASCII content
    let lines = ['Hello World', 'Simple text']
    let [left, right] = cleave#split_content(lines, 6)
    let total += 1
    let passed += AssertEqual(['Hello', 'Simpl'], left, "ASCII split left part")
    let total += 1
    let passed += AssertEqual([' World', 'e text'], right, "ASCII split right part")
    
    " Test 2: Content with wide characters
    let lines = ['Hello 你好 World', 'Test 世界 line']
    let [left2, right2] = cleave#split_content(lines, 8)
    let total += 1
    let passed += AssertEqual(['Hello 你', 'Test 世'], left2, "Wide char split left part")
    let total += 1
    let passed += AssertEqual(['好 World', '界 line'], right2, "Wide char split right part")
    
    " Test 3: Content with tabs
    let lines = ['a\tb\tc', 'x\ty\tz']
    let [left3, right3] = cleave#split_content(lines, 3)
    let total += 1
    let passed += AssertEqual(['a\t', 'x\t'], left3, "Tab split left part")
    let total += 1
    let passed += AssertEqual(['b\tc', 'y\tz'], right3, "Tab split right part")
    
    " Test 4: Mixed content (ASCII + wide chars + tabs)
    let lines = ['a你\tb世', 'x界\ty好']
    let [left4, right4] = cleave#split_content(lines, 4)
    let total += 1
    let passed += AssertEqual(['a你\t', 'x界\t'], left4, "Mixed content split left part")
    let total += 1
    let passed += AssertEqual(['b世', 'y好'], right4, "Mixed content split right part")
    
    " Test 5: Split at beginning
    let lines = ['Hello World']
    let [left5, right5] = cleave#split_content(lines, 1)
    let total += 1
    let passed += AssertEqual([''], left5, "Split at beginning left part")
    let total += 1
    let passed += AssertEqual(['Hello World'], right5, "Split at beginning right part")
    
    " Test 6: Split at end
    let lines = ['Hello']
    let [left6, right6] = cleave#split_content(lines, 6)
    let total += 1
    let passed += AssertEqual(['Hello'], left6, "Split at end left part")
    let total += 1
    let passed += AssertEqual([''], right6, "Split at end right part")
    
    " Test 7: Empty lines
    let lines = ['', 'content', '']
    let [left7, right7] = cleave#split_content(lines, 3)
    let total += 1
    let passed += AssertEqual(['', 'co', ''], left7, "Empty lines split left part")
    let total += 1
    let passed += AssertEqual(['', 'ntent', ''], right7, "Empty lines split right part")
    
    echomsg "TestSplitContentVirtualColumns: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestSplitContentCharacterBoundaries()
    echomsg "Testing cleave#split_content() character boundary handling..."
    let passed = 0
    let total = 0
    
    " Test splitting at character boundaries with wide characters
    let lines = ['你好世界']
    
    " Split at virtual column 1 (before first character)
    let [left1, right1] = cleave#split_content(lines, 1)
    let total += 1
    let passed += AssertEqual([''], left1, "Split before first wide char - left")
    let total += 1
    let passed += AssertEqual(['你好世界'], right1, "Split before first wide char - right")
    
    " Split at virtual column 3 (after first wide character)
    let [left2, right2] = cleave#split_content(lines, 3)
    let total += 1
    let passed += AssertEqual(['你'], left2, "Split after first wide char - left")
    let total += 1
    let passed += AssertEqual(['好世界'], right2, "Split after first wide char - right")
    
    " Split at virtual column 5 (after second wide character)
    let [left3, right3] = cleave#split_content(lines, 5)
    let total += 1
    let passed += AssertEqual(['你好'], left3, "Split after second wide char - left")
    let total += 1
    let passed += AssertEqual(['世界'], right3, "Split after second wide char - right")
    
    echomsg "TestSplitContentCharacterBoundaries: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! RunSplitContentTests()
    echomsg "Running cleave#split_content() tests..."
    echomsg "======================================="
    
    let total_passed = 0
    let total_tests = 0
    
    let [p1, t1] = TestSplitContentVirtualColumns()
    let total_passed += p1
    let total_tests += t1
    
    let [p2, t2] = TestSplitContentCharacterBoundaries()
    let total_passed += p2
    let total_tests += t2
    
    echomsg "======================================="
    echomsg "TOTAL: " . total_passed . "/" . total_tests . " tests passed"
    
    if total_passed == total_tests
        echomsg "ALL TESTS PASSED!"
        return 0
    else
        echomsg "SOME TESTS FAILED!"
        return 1
    endif
endfunction

" Run the tests
call RunSplitContentTests()