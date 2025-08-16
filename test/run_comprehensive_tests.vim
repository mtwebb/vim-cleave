" Test runner script for comprehensive virtual column tests
source test/test_virtual_column_comprehensive.vim

" Run the tests and capture output
redir! > test_results.txt
call RunAllVirtualColumnTests()
redir END

" Display results
edit test_results.txt