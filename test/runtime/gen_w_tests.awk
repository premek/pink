# Extracts Ink code snippets from WritingWithInk.md into test/runtime/Wa.b.ccc/story.ink.
# story.ink is always overwritten; input.txt is created empty only if absent.
#
# Run against the live document:
#   curl -s https://raw.githubusercontent.com/inkle/ink/refs/heads/master/Documentation/WritingWithInk.md \
#     | awk -v outdir=test/runtime -f test/runtime/gen_w_tests.awk
#
# Run against a local copy:
#   awk -v outdir=test/runtime -f test/runtime/gen_w_tests.awk /tmp/WritingWithInk.md

function flush(    i, dir, sf, inf, ret, dummy) {
    # trim trailing blank lines
    while (nlines > 0 && code[nlines-1] == "") nlines--
    if (nlines == 0) return
    if (part == 0 || section == 0) { nlines=0; return }

    # skip interactive game-output blocks (contain "> N" choice prompts)
    for (i = 0; i < nlines; i++)
        if (code[i] ~ /^> /) { nlines=0; return }

    snippet++
    dir = sprintf("%s/W%d.%d.%03d", outdir, part, section, snippet)
    system("mkdir -p " dir)

    sf = dir "/story.ink"
    for (i = 0; i < nlines; i++) print code[i] > sf
    close(sf)

    inf = dir "/input.txt"
    ret = (getline dummy < inf)
    close(inf)
    if (ret < 0) system("touch " inf)

    print "[ok] W" part "." section "." sprintf("%03d", snippet)
    nlines = 0
}

BEGIN { part=0; section=0; snippet=0; in_code=0; in_fence=0; nlines=0 }

{
    gsub(/\r/, "")

    # fenced code block (``` delimiter)
    if (/^```/) {
        if (in_fence) {
            flush(); in_fence=0
        } else {
            if (in_code) { flush(); in_code=0 }
            in_fence=1; nlines=0
        }
        next
    }

    if (in_fence) { code[nlines++] = $0; next }

    if (/^$/) { if (in_code) code[nlines++] = ""; next }

    # tab-indented line → code
    if (/^\t/) {
        if (!in_code) { in_code=1; nlines=0 }
        code[nlines++] = substr($0, 2)   # strip one leading tab
        next
    }

    # non-blank, non-indented → ends any open code block
    if (in_code) { flush(); in_code=0 }

    # Part heading:  # Part One: ...  or  # Part 2: ...
    if (/^# Part /) {
        if (/One/) {
            part = 1
        } else {
            match($0, /[0-9]+/)
            part = substr($0, RSTART, RLENGTH) + 0
        }
        section=0; snippet=0
    }

    # Section heading:  ## 1)  or  ##  6)  (one or two spaces)
    if (/^## +[0-9]+\)/) {
        match($0, /[0-9]+/)
        section = substr($0, RSTART, RLENGTH) + 0
        snippet=0
    }
}

END { if (in_code || in_fence) flush() }
