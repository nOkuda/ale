scriptencoding utf-8
" Author: w0rp <devw0rp@gmail.com>
" Description: This file defines a handler function which ought to work for
" any program which outputs errors in the format that GCC uses.

function! s:AddIncludedErrors(output, include_lnum, include_lines) abort
    if a:include_lnum > 0
        call add(a:output, {
        \   'lnum': a:include_lnum,
        \   'type': 'E',
        \   'text': 'Problems were found in the header (See :ALEDetail)',
        \   'detail': join(a:include_lines, "\n"),
        \})
    endif
endfunction

function! ale#handlers#gcc#HandleGCCFormat(buffer, lines) abort
    let l:include_pattern = '\v^(In file included | *)from [^:]*:(\d+)'
    let l:include_lnum = 0
    let l:include_lines = []
    let l:included_filename = ''
    " Look for lines like the following.
    "
    " <stdin>:8:5: warning: conversion lacks type at end of format [-Wformat=]
    " <stdin>:10:27: error: invalid operands to binary - (have ‘int’ and ‘char *’)
    " -:189:7: note: $/${} is unnecessary on arithmetic variables. [SC2004]
    let l:pattern = '^\(.\+\):\(\d\+\):\(\d\+\): \([^:]\+\): \(.\+\)$'
    let l:output = []

    for l:line in a:lines
        let l:match = matchlist(l:line, l:pattern)

        if empty(l:match)
            " Check for matches in includes.
            " We will keep matching lines until we hit the last file, which
            " is our file.
            let l:include_match = matchlist(l:line, l:include_pattern)

            if empty(l:include_match)
                " If this isn't another include header line, then we
                " need to collect it.
                call add(l:include_lines, l:line)
            else
                " Get the line number out of the parsed include line,
                " and reset the other variables.
                let l:include_lnum = str2nr(l:include_match[2])
                let l:include_lines = []
                let l:included_filename = ''
            endif
        elseif l:include_lnum > 0
        \&& (empty(l:included_filename) || l:included_filename ==# l:match[1])
            " If we hit the first error after an include header, or the
            " errors below have the same name as the first filename we see,
            " then include these lines, and remember what that filename was.
            let l:included_filename = l:match[1]
            call add(l:include_lines, l:line)
        else
            " If we hit a regular error again, then add the previously
            " collected lines as one error, and reset the include variables.
            call s:AddIncludedErrors(l:output, l:include_lnum, l:include_lines)
            let l:include_lnum = 0
            let l:include_lines = []
            let l:included_filename = ''

            call add(l:output, {
            \   'lnum': l:match[2] + 0,
            \   'col': l:match[3] + 0,
            \   'type': l:match[4] =~# 'error' ? 'E' : 'W',
            \   'text': l:match[5],
            \})
        endif
    endfor

    " Add remaining include errors after we go beyond the last line.
    call s:AddIncludedErrors(l:output, l:include_lnum, l:include_lines)

    return l:output
endfunction