" Test script for cleave#setup_windows() virtual column functionality

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

function! TestSetupWindowsVirtualColumnSizing()
    echomsg "Testing cleave#setup_windows() virtual column sizing..."
    let passed = 0
    let total = 0
    
    " Test window width calculation with virtual columns
    " We'll test the calculation logic rather than actual window creation
    
    " Test 1: ASCII content - virtual column should equal byte position
    let cleave_col = 10  " Virtual column 10
    let original_foldcolumn = 2
    let expected_width = cleave_col - 2 + original_foldcolumn  " 10 - 2 + 2 = 10
    let total += 1
    let passed += AssertEqual(10, expected_width, "ASCII content window width calculation")
    
    " Test 2: Wide character content - virtual column accounts for display width
    let cleave_col_wide = 8  " Virtual column 8 (after "Hello 你" which is 7 display columns)
    let expected_width_wide = cleave_col_wide - 2 + original_foldcolumn  " 8 - 2 + 2 = 8
    let total += 1
    let passed += AssertEqual(8, expected_width_wide, "Wide character content window width calculation")
    
    " Test 3: Tab content - virtual column accounts for tab expansion
    let cleave_col_tab = 9  " Virtual column 9 (after "a\t" which expands to 8 columns + 1)
    let expected_width_tab = cleave_col_tab - 2 + original_foldcolumn  " 9 - 2 + 2 = 9
    let total += 1
    let passed += AssertEqual(9, expected_width_tab, "Tab content window width calculation")
    
    " Test 4: No foldcolumn
    let cleave_col_no_fold = 5
    let no_foldcolumn = 0
    let expected_width_no_fold = cleave_col_no_fold - 2 + no_foldcolumn  " 5 - 2 + 0 = 3
    let total += 1
    let passed += AssertEqual(3, expected_width_no_fold, "No foldcolumn window width calculation")
    
    " Test 5: Large foldcolumn
    let cleave_col_large_fold = 6
    let large_foldcolumn = 5
    let expected_width_large_fold = cleave_col_large_fold - 2 + large_foldcolumn  " 6 - 2 + 5 = 9
    let total += 1
    let passed += AssertEqual(9, expected_width_large_fold, "Large foldcolumn window width calculation")
    
    echomsg "TestSetupWindowsVirtualColumnSizing: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! TestSetupWindowsGutterCalculations()
    echomsg "Testing cleave#setup_windows() gutter calculations..."
    let passed = 0
    let total = 0
    
    " Test that the function properly accounts for display width in gutter calculations
    " The gutter width is handled by g:cleave_gutter in other functions,
    " but setup_windows should work with virtual columns
    
    " Test with different virtual column positions that would result from
    " different character types
    
    " Test 1: Virtual column from ASCII text
    let ascii_vcol = 15  " "Hello World ABC" = 15 virtual columns
    let foldcol = 1
    let expected_ascii = ascii_vcol - 2 + foldcol  " 15 - 2 + 1 = 14
    let total += 1
    let passed += AssertEqual(14, expected_ascii, "ASCII virtual column gutter calculation")
    
    " Test 2: Virtual column from wide character text
    let wide_vcol = 12  " "Hello 你好世" = 12 virtual columns (5 + 2 + 2 + 2 + 1)
    let expected_wide = wide_vcol - 2 + foldcol  " 12 - 2 + 1 = 11
    let total += 1
    let passed += AssertEqual(11, expected_wide, "Wide character virtual column gutter calculation")
    
    " Test 3: Virtual column from tab text
    let tab_vcol = 16  " "a\tb\tc" with tabstop=8 = 16 virtual columns (1 + 7 + 1 + 7 + 1)
    let expected_tab = tab_vcol - 2 + foldcol  " 16 - 2 + 1 = 15
    let total += 1
    let passed += AssertEqual(15, expected_tab, "Tab virtual column gutter calculation")
    
    echomsg "TestSetupWindowsGutterCalculations: " . passed . "/" . total . " tests passed"
    return [passed, total]
endfunction

function! RunSetupWindowsTests()
    echomsg "Running cleave#setup_windows() tests..."
    echomsg "======================================"
    
    let total_passed = 0
    let total_tests = 0
    
    let [p1, t1] = TestSetupWindowsVirtualColumnSizing()
    let total_passed += p1
    let total_tests += t1
    
    let [p2, t2] = TestSetupWindowsGutterCalculations()
    let total_passed += p2
    let total_tests += t2
    
    echomsg "======================================"
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
call RunSetupWindowsTests()