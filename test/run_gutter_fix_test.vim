source test/test_gutter_fix.vim

redir! > gutter_fix_results.txt
call TestGutterFix()
redir END

edit gutter_fix_results.txt