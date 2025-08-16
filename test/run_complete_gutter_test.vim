source test/test_complete_gutter_workflow.vim

redir! > complete_gutter_results.txt
call TestCompleteGutterWorkflow()
redir END

edit complete_gutter_results.txt