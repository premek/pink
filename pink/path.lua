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

    -- Qualify a single-element divert path to an absolute form using the
    -- current knot/stitch context, so it resolves correctly when executed
    -- from a different knot. Returns the original path if no qualification needed.
    -- knotEntries: knots[currentKnot]; each stitch entry also holds its sub-labels.
    qualify = function(path, knotName, knotEntries, stitchName)
        if #path ~= 1 then
            return path
        end
        local name = path[1]
        if name == 'END' or name == 'DONE' then
            return path
        end
        -- Case 1b: label within current stitch of current knot (3-part path)
        if stitchName and knotEntries and knotEntries[stitchName] and knotEntries[stitchName][name] then
            return { knotName, stitchName, name }
        end
        -- Case 1a: stitch or gather-label directly in current knot (2-part path)
        if knotEntries and knotEntries[name] then
            return { knotName, name }
        end
        return path
    end,
}
