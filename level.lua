levels = {
  {
    direction = 0,
    batches = "200:2t1f:1;150:1f:1;100:2t1f:0",
  },
  {
    direction = 1,
    batches = "150:2t1f:0",
  },
}

function parse_batches(str)
  -- sub :: String -> Int -> Int -> String
  -- start and end are inclusive
  local consumed = 1
  local batches = {}
  -- One baddie "batch" entry
  foreach(split(str, ";"), function(substr)
    local vals = split(substr, ":")
    local my_batch = {
      distance = 0,
      baddies = {},
      direction = 0,
    }
    if #vals != 3 then
      printh("Invalid level string: "..substr)
      stop("Parser encountered invalid values")
    end
    my_batch.distance = tonum(vals[1])
    local i = 1
    while i<#vals[2] do
      local baddie_count = tonum(sub(vals[2], i, i))
      local baddie_type = sub(vals[2], i+1, i+1)
      for j=1,baddie_count do
        add(my_batch.baddies, (baddie_type == "t") and "tree" or "flower")
      end
      i += 2
    end
    my_batch.direction = tonum(vals[3])
    add(batches, my_batch)
  end)
  return batches
end

-- String -> Char -> Int
function index_of(str, chr)
  local found = false
  local idx = 1
  while not found do
    if sub(str, idx, idx) == chr then
      return idx
    end
    idx += 1
  end
  return -1
end

function is_level_end(x, level_direction)
  if level_direction == 0 and x < 8 then
    return true
  elseif level_direction == 1 and x > map_extent - 16 then
    return true
  end
  return false
end

function should_spawn_batch(x, batch_x, level_direction)
  if level_direction == 0 and x < batch_x then
    return true
  elseif level_direction == 1 and x > batch_x then
    return true
  end
  return false
end
