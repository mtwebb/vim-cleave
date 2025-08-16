source test/test_real_join_issue.vim

redir! > real_join_test_results.txt
call TestRealJoinIssue()
redir END

edit real_join_test_results.txt