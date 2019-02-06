SILE.require("packages/patchcommand")

if not table.deepEq then
  table.deepEq = function(table1, table2)
     local avoid_loops = {}
     local function recurse(t1, t2)
        -- compare value types
        if type(t1) ~= type(t2) then return false end
        -- Base case: compare simple values
        if type(t1) ~= "table" then return t1 == t2 end
        -- Now, on to tables.
        -- First, let's avoid looping forever.
        if avoid_loops[t1] then return avoid_loops[t1] == t2 end
        avoid_loops[t1] = t2
        -- Copy keys from t2
        local t2keys = {}
        local t2tablekeys = {}
        for k, _ in pairs(t2) do
           if type(k) == "table" then table.insert(t2tablekeys, k) end
           t2keys[k] = true
        end
        -- Let's iterate keys from t1
        for k1, v1 in pairs(t1) do
           local v2 = t2[k1]
           if type(k1) == "table" then
              -- if key is a table, we need to find an equivalent one.
              local ok = false
              for i, tk in ipairs(t2tablekeys) do
                 if table_eq(k1, tk) and recurse(v1, t2[tk]) then
                    table.remove(t2tablekeys, i)
                    t2keys[tk] = nil
                    ok = true
                    break
                 end
              end
              if not ok then return false end
           else
              -- t1 has a key which t2 doesn't have, fail.
              if v2 == nil then return false end
              t2keys[k1] = nil
              if not recurse(v1, v2) then return false end
           end
        end
        -- if t2 has a key which t1 doesn't have, fail.
        if next(t2keys) then return false end
        return true
     end
     return recurse(table1, table2)
  end
end

local popHorizontal = function ()
  local last = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
  SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes] = nil
  return last
end

SILE.scratch.endnotes = {}

SILE.patchCommand("footnote", { after = function(options, content)
  -- Steal the stuff off the typesetter's queue
  SILE.scratch.endnotes[#SILE.scratch.endnotes+1] = {
    material = popHorizontal().material,
    belongsTo = std.tree.clone(SILE.scratch.counters.sectioning or {})
  }
  popHorizontal() -- penalty
end})

SILE.registerCommand("endnotes:header", function(options, content)
  -- Assuming some kind of book class
  SILE.call("chapter", {}, {"Endnotes"})
end)

SILE.registerCommand("endnotes:skipbetweennotes", function(options,content)
  SILE.call("medskip")
end)

SILE.registerCommand("endnotes:newlocationheader", function(options,content)
  -- Assuming we want per-chapter headers as sectinos
  if options.oldlocation.value[1] == options.newlocation.value[1] then
    return
  end
  SILE.call("section", {numbering="no"}, {"Chapter "..options.newlocation.value[1]})
end)

SILE.registerCommand("endnotes:output", function(options, content)
  SILE.call("endnotes:header")
  local lastLocation = {value={}}
  for i = 1,#SILE.scratch.endnotes do
    local endnote = SILE.scratch.endnotes[i]
    if not table.deepEq(endnote.belongsTo, lastLocation) then
      SILE.call("endnotes:newlocationheader", {
        newlocation = endnote.belongsTo,
        oldlocation = lastLocation
      })
    end
    lastLocation = endnote.belongsTo
    local material = endnote.material
    for j = 1,#material do
      local insertion = material[j]
      for k = 1, #(insertion.nodes) do
        SILE.typesetter:pushVertical(insertion.nodes[k])
      end
    SILE.call("endnotes:skipbetweennotes")
    end
  end
  SILE.scratch.endnotes = {}
end)

-- Add to output routine. I hate monkeypatching, but what's the better way?
local oldFinish = SILE.documentState.documentClass.finish
SILE.documentState.documentClass.finish = function(self)
  if #SILE.scratch.endnotes > 0 then
    SILE.call("endnotes:output")
  end
  return oldFinish(self)
end