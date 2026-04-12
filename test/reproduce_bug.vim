" Reproduction script for multiple inline notes bug
" Run with: vim -u NONE -es -c "source test/reproduce_bug.vim" -c "qa!"

set nocompatible
set cpo&vim
set rtp+=.
runtime plugin/cleave.vim

function! ReproduceBug()
    echomsg "=== Reproducing Multiple Inline Notes Bug ==="
    
    " Test 1: Two notes on same line
    echomsg ""
    echomsg "Test 1: Two notes on same line"
    let input1 = ['This is text ^[first note] with more ^[second note] text.']
    let [left1, right1, nmap1] = cleave#SplitInlineContent(input1)
    
    echomsg "  Input:  " . input1[0]
    echomsg "  Left:   " . left1[0]
    echomsg "  Right:  " . join(right1, ' | ')
    echomsg "  Notes found: " . len(right1)
    echomsg "  BUG: Expected 2 notes, got " . len(filter(copy(right1), 'v:val != ""'))"
    
    if right1[0] !=# 'first note'
        echomsg "  ERROR: First note wrong: " . right1[0]
    endif
    if len(right1) < 2 || right1[1] !=# 'second note'
        echomsg "  ERROR: Second note missing or wrong: " . get(right1, 1, '[MISSING]')
    endif
    
    " Test 2: Three notes on same line
    echomsg ""
    echomsg "Test 2: Three notes on same line"
    let input2 = ['Multiple ^[note one] different ^[note two] and more ^[note three] text.']
    let [left2, right2, nmap2] = cleave#SplitInlineContent(input2)
    
    echomsg "  Input:  " . input2[0]
    echomsg "  Left:   " . left2[0]
    echomsg "  Right:  " . join(right2, ' | ')
    echomsg "  Notes found: " . len(filter(copy(right2), 'v:val != ""'))"
    echomsg "  BUG: Expected 3 notes, got " . len(filter(copy(right2), 'v:val != ""'))"
    
    " Test 3: Four notes on same line
    echomsg ""
    echomsg "Test 3: Four notes on same line"
    let input3 = ['Multiple: ^[alpha] ^[beta] ^[gamma] ^[delta]']
    let [left3, right3, nmap3] = cleave#SplitInlineContent(input3)
    
    echomsg "  Input:  " . input3[0]
    echomsg "  Left:   " . left3[0]
    echomsg "  Right:  " . join(right3, ' | ')
    echomsg "  Notes found: " . len(filter(copy(right3), 'v:val != ""'))"
    echomsg "  BUG: Expected 4 notes, got " . len(filter(copy(right3), 'v:val != ""'))"
    
    echomsg ""
    echomsg "=== Summary ==="
    echomsg "The bug is at line 146 in autoload/cleave.vim:"
    echomsg "  for j in range(1, len(notes) - 1)"
    echomsg "Should be:"
    echomsg "  for j in range(1, len(notes))"
    echomsg ""
    echomsg "When 2 notes exist, range(1, 1) is empty, so second note is lost."
    echomsg "When 3+ notes exist, only first note is preserved."
endfunction

call ReproduceBug()
