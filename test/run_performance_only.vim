" Performance benchmark runner for virtual column functions
source test/test_virtual_column_comprehensive.vim

" Run only the performance benchmarks
redir! > performance_results.txt
call BenchmarkVirtualColumnFunctions()
redir END

" Display results
edit performance_results.txt