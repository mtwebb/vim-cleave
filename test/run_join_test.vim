source test/test_join_spacing.vim

redir! > join_test_results.txt
call TestJoinSpacing()
redir END

edit join_test_results.txt