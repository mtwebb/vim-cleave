vim9script

# cleave/modeline.vim - modeline parsing and management for cleave plugin

if !exists('g:cleave_modeline')
    g:cleave_modeline = 'read'
endif

# Cleave-relevant option names (abbreviated forms)
var cleave_keys = ['cc', 'tw', 'fdc', 'wm', 've']

# ============================================================================
# Public API
# ============================================================================

# Return the current g:cleave_modeline value (default 'read')
export def Mode(): string
    return get(g:, 'cleave_modeline', 'read')
enddef

# Scan buffer for a vim: modeline and extract cleave-relevant settings.
# Returns {'line': line_number_or_0, 'settings': {...}, 'other': '...'}
export def Parse(bufnr: number): dict<any>
    if !bufexists(bufnr)
        echoerr 'Cleave: buffer ' .. bufnr .. ' does not exist'
        return {'line': 0, 'settings': {}, 'other': ''}
    endif

    var total = getbufinfo(bufnr)[0].linecount
    var ranges = ModelineRanges(total)

    for lnum in ranges
        var text = getbufline(bufnr, lnum)[0]
        var parsed = ParseModelineText(text)
        if !empty(parsed)
            return {'line': lnum, 'settings': parsed.settings, 'other': parsed.other}
        endif
    endfor

    return {'line': 0, 'settings': {}, 'other': ''}
enddef

# Validate a settings dict and return clamped/safe values.
# Returns {'cc': num, 'tw': num, 'fdc': num, 'wm': num, 've': str}
export def Apply(settings: dict<any>): dict<any>
    var result = {}
    result.cc  = Clamp(get(settings, 'cc', 0), 10, 999)
    result.tw  = Clamp(get(settings, 'tw', 0), 10, 999)
    result.fdc = Clamp(get(settings, 'fdc', 0), 0, 12)
    result.wm  = Clamp(get(settings, 'wm', 0), 0, 99)
    result.ve  = ValidateVe(get(settings, 've', 'all'))
    return result
enddef

# Infer cleave settings from buffer state when no modeline is present.
export def Infer(bufnr: number): dict<any>
    if !bufexists(bufnr)
        echoerr 'Cleave: buffer ' .. bufnr .. ' does not exist'
        return {}
    endif

    var settings: dict<any> = {}

    # ve: default 'all'
    settings.ve = 'all'

    # tw: prefer existing textwidth, else infer from average line length
    var buf_tw = getbufvar(bufnr, '&textwidth')
    if buf_tw > 0
        settings.tw = buf_tw
    else
        settings.tw = InferTextwidth(bufnr)
    endif

    # wm: prefer wrapmargin, else default to g:cleave_gutter or 3
    var buf_wm = getbufvar(bufnr, '&wrapmargin')
    if buf_wm > 0
        settings.wm = buf_wm
    else
        settings.wm = get(g:, 'cleave_gutter', 3)
    endif

    # fdc: prefer foldcolumn, else infer from indent variance
    var buf_fdc = getbufvar(bufnr, '&foldcolumn')
    if buf_fdc > 0
        settings.fdc = buf_fdc
    else
        settings.fdc = InferFoldcolumn(bufnr)
    endif

    # cc: prefer colorcolumn, else tw + wm if tw is set, else 79/80
    var buf_cc = getbufvar(bufnr, '&colorcolumn')
    if buf_cc !=# '' && buf_cc =~# '^\d\+$'
        settings.cc = str2nr(buf_cc)
    elseif settings.tw > 0
        settings.cc = settings.tw + settings.wm
    else
        settings.cc = 80
    endif

    return settings
enddef

# Insert or update a modeline in the buffer.
# Only writes if g:cleave_modeline is 'update'.
export def Ensure(bufnr: number, settings: dict<any>)
    if !bufexists(bufnr)
        echoerr 'Cleave: buffer ' .. bufnr .. ' does not exist'
        return
    endif

    if Mode() !=# 'update'
        return
    endif

    if !getbufvar(bufnr, '&modifiable')
        return
    endif

    var parsed = Parse(bufnr)
    var modeline_str = BuildString(settings, parsed.other)

    if parsed.line > 0
        setbufline(bufnr, parsed.line, modeline_str)
    else
        var total = getbufinfo(bufnr)[0].linecount
        appendbufline(bufnr, total, modeline_str)
    endif

    # Apply settings to the buffer's vim options
    ApplySettingsToBuffer(bufnr, settings)
enddef

# Apply modeline settings to buffer/window vim options
def ApplySettingsToBuffer(bufnr: number, settings: dict<any>)
    if has_key(settings, 'tw') && settings.tw > 0
        setbufvar(bufnr, '&textwidth', settings.tw)
    endif
    if has_key(settings, 'wm') && settings.wm >= 0
        g:cleave_gutter = settings.wm
    endif
    # colorcolumn and foldcolumn are window-local; virtualedit is global
    var winid = get(win_findbuf(bufnr), 0, -1)
    if winid != -1
        if has_key(settings, 'fdc')
            setwinvar(win_id2win(winid), '&foldcolumn', settings.fdc)
        endif
        if has_key(settings, 'cc') && settings.cc > 0
            setwinvar(win_id2win(winid), '&colorcolumn',
                string(settings.cc))
        endif
    endif
    if has_key(settings, 've') && !empty(settings.ve)
        &virtualedit = settings.ve
    endif
enddef

# Build a modeline string from settings dict and any other non-cleave options.
# Format: vim: cc=91 tw=79 ve=all fdc=5 wm=3 [other options]
export def BuildString(settings: dict<any>, other_opts: string): string
    var parts: list<string> = []
    for key in cleave_keys
        if has_key(settings, key)
            add(parts, key .. '=' .. settings[key])
        endif
    endfor
    var result = 'vim: ' .. join(parts, ' ')
    if other_opts !=# ''
        result ..= ' ' .. other_opts
    endif
    return result
enddef

# ============================================================================
# Script-local helpers
# ============================================================================

# Return line numbers to scan for modelines (first 5 and last 5)
def ModelineRanges(total: number): list<number>
    var lines: list<number> = []
    var head = min([5, total])
    for i in range(1, head)
        add(lines, i)
    endfor
    var tail_start = max([head + 1, total - 4])
    for i in range(tail_start, total)
        add(lines, i)
    endfor
    return lines
enddef

# Parse a single line of text for a vim: modeline.
# Returns {} if not a modeline, or {'settings': {...}, 'other': '...'} if found.
def ParseModelineText(text: string): dict<any>
    # Match vim: at start or after whitespace/comment chars
    # Handle both 'vim: set opt1=val1 opt2=val2 :' and 'vim: opt1=val1 opt2=val2'
    var pat = '\v^.*<vim:\s*(set\s+)?(.*)'
    var m = matchlist(text, pat)
    if empty(m)
        return {}
    endif

    var opts_str = m[2]
    # Strip trailing ':' from 'vim: set ... :' format
    opts_str = substitute(opts_str, '\s*:\s*$', '', '')

    var settings: dict<any> = {}
    var other_parts: list<string> = []

    for token in split(opts_str)
        var kv = matchlist(token, '^\([a-zA-Z]\+\)=\(.*\)$')
        if !empty(kv)
            var key = kv[1]
            var val = kv[2]
            if index(cleave_keys, key) >= 0
                if key ==# 've'
                    settings[key] = val
                else
                    settings[key] = str2nr(val)
                endif
            else
                add(other_parts, token)
            endif
        else
            # bare option (e.g., 'noai')
            add(other_parts, token)
        endif
    endfor

    return {'settings': settings, 'other': join(other_parts, ' ')}
enddef

# Clamp a numeric value to [lo, hi]
def Clamp(val: any, lo: number, hi: number): number
    var n = type(val) == v:t_string ? str2nr(val) : val
    return max([lo, min([hi, n])])
enddef

# Validate virtualedit value
def ValidateVe(val: string): string
    var valid = ['all', 'block', 'insert', 'onemore', 'none', '']
    if index(valid, val) >= 0
        return val
    endif
    return 'all'
enddef

# Infer textwidth from average non-empty line length in buffer (cap at 79)
def InferTextwidth(bufnr: number): number
    var lines = getbufline(bufnr, 1, '$')
    var total_len = 0
    var line_count = 0
    for line in lines
        if line !=# ''
            total_len += strdisplaywidth(line)
            line_count += 1
        endif
    endfor
    if line_count == 0
        return 79
    endif
    var avg = total_len / line_count
    return min([avg, 79])
enddef

# Infer foldcolumn from leading-indent variance (default 0)
def InferFoldcolumn(bufnr: number): number
    var lines = getbufline(bufnr, 1, '$')
    var indents: list<number> = []
    for line in lines
        if line !=# ''
            var leading = len(matchstr(line, '^\s*'))
            add(indents, leading)
        endif
    endfor
    if len(indents) < 2
        return 0
    endif
    # If there is significant indent variance, suggest a small foldcolumn
    var min_indent = min(indents)
    var max_indent = max(indents)
    if max_indent - min_indent > 4
        return min([max_indent, 4])
    endif
    return 0
enddef
