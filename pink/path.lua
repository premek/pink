return {
    of = function(...)
        return { ... }
    end,

    -- Builds a visit-counter path for a label, respecting the knot→stitch hierarchy:
    -- stitch is included only when knot is present, so top-level labels stay bare.
    label = function(knot, stitch, labelName)
        if knot and stitch then
            return { knot, stitch, labelName }
        elseif knot then
            return { knot, labelName }
        else
            return { labelName }
        end
    end,

    toString = function(p)
        return table.concat(p, '.')
    end,
}
