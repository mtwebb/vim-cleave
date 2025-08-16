source test/test_gutter_reflow_merge.vim

redir! > gutter_test_results.txt
call RunGutterTests()
redir END

edit gutter_test_results.txt