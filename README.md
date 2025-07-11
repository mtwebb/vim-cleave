# vim-cleave

Vim-cleave is a plugin that splits a buffer's content vertically at a specified column, creating separate left and right buffers while maintaining spatial positioning.

## Installation

### Manual Installation

```bash
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/mtwebb/vim-cleave.git
```

### vim-plug

```vim
Plug 'mtwebb/vim-cleave'
```

## Usage

### Commands

*   `:Cleave` - Splits the current buffer at the cursor position.
*   `:CleaveAt <column>` - Splits the current buffer at the specified column.
*   `:CleaveUndo` - Restores the original buffer and closes the cleaved windows.

### Options

*   `g:cleave_auto_sync` - When set to `v:true`, changes in one of the cleaved buffers will be reflected in the other. Default: `v:false`.
