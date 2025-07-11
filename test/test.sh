vim -u NONE -c 'set rtp+=.' -c 'source plugin/cleave.vim' -c 'e test.txt' -c 'call cursor(1, 33)' -c 'Cleave'
echo "rm -f *.swp *.swo"
