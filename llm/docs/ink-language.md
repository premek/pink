# Ink Language Reference (condensed)

Full upstream docs: [WritingWithInk](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md)

## Structure

```
=== knot_name(p1, p2) ===   knot — named section, optional params
= stitch_name               stitch — subdivision of a knot, no params
-> target(args)             divert — jump; target is knot, stitch, or label
-> target(args) ->          tunnel — jump and return (subroutine)
->->                        tunnel return
<- target(args)             thread — merge content from another knot in parallel
```

## Choices & Gathers

```
* once-only choice
+ sticky choice (repeatable)
* [shown when choosing, hidden after] shown after choosing
* shown when choosing and after [hidden part]
** nested choice (depth by * count)
- gather point (branches converge here)
- (label) gather with a label
```

## Flow

```
-> END              stop story
-> DONE             stop story (no more choices)
```

Weave: the implicit structure of nested choices and gathers. No syntax — just indentation by nesting depth.

## Variables & Logic

```
VAR name = value        global, mutable
CONST name = value      global, immutable
temp name = value       local to current knot/function
~ name = expr           assignment
~ return expr           return from function (bare ~ return returns nothing)
```

## Conditionals

```
{condition: shown if true}
{condition: true text | false text}
{- condition: block body}
{- cond1: body | - cond2: body | else body}
```

## Sequences

```
{b1|b2|b3}          stopping (sequence, then stays on last)
{&b1|b2|b3}         cycle
{!b1|b2|b3}         once-only (blank after exhausted)
{~b1|b2|b3}         shuffle
```

## Functions

```
=== function name(p1, p2) ===
    ~ return value
```
No choices or diverts inside functions. Can be called inline as `{name(args)}` or from `~` lines.

## Lists

```
LIST name = el1, (el2), el3    define; elements in () are initially active
VAR x = (el1, el2)             list variable
~ x += el3                     add element
~ x -= el2                     remove element
x ? el1                        contains
x ^^ y                         intersection
LIST_ALL(x)                    all elements
LIST_MIN(x) / LIST_MAX(x)
LIST_COUNT(x)
LIST_INVERT(x)
LIST_RANDOM(x)
LIST_RANGE(x, min, max)
LIST_VALUE(el)
```

## Tags

```
# tag text              attached to preceding output line
# tag                   above a line applies to that line too
```

Tags at top of knot are knot-level metadata. Tags at top of file are global tags.

## Other

```
<>                      glue — suppress newline between adjacent lines
INCLUDE path/file.ink   inline another file at parse time
EXTERNAL name(p1, p2)   declare host-provided function
```

## Built-in Functions

`INT(n)` `FLOAT(n)` `FLOOR(n)` `CEILING(n)` `MIN(a,b)` `MAX(a,b)` `ABS(n)` `POW(b,e)` `RANDOM(min,max)` `SEED_RANDOM(n)` `CHOICE_COUNT()` `READ_COUNT(target)` `TURNS()` `TURNS_SINCE(->target)`
