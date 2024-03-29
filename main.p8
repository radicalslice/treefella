pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

#include const.lua
#include player.lua
#include baddie.lua
#include level.lua
#include fleas.lua

-- extent = 0 -- debugging; used for tracking max x extent of player attacks
level = {
  batches = {},
  direction = 0
}
level_index = 1
__update = nil
__draw = nil

timers = {}
fc = 0
impact_sprites = {16,32}
-- for shifting arrows up and down
arrow_offsets = {0, 1, 2, 2, 1, 0, -1, -2, -2, -1}
victory_freeze = false
fx = {
  impacts = {},
  arrows = {},
  popups = {},
  parts = {},
}

function handle_timers(ts, dt)
  foreach(ts, function(t)
    t.remaining -= dt

    if t.remaining <= 0 then
      t.callback()
      del(ts, t)
    end
  end)
end

function game_init()
  printh("game init")
  last_ts = time()
  last_level_init = time()
  fc = 0
  level.batches = parse_batches(levels[level_index].batches)
  level.direction = levels[level_index].direction
  level.boss = levels[level_index].boss
  player:reset(level.direction, FREEZE_NONE)
  bmgr:reset()
  __update = game_update
  __draw = level_init_draw
  -- allows level marquee to play
  add(timers, {
    remaining = 2.8,
    callback = function()
      __draw = game_draw
    end
  })
  music(4)
end

function _init()
  printh("cart init")
  last_ts = 0
  level_index = 1
  __update = title_update
  __draw = title_draw
  title_message[4] = 0.2
  player:reset(0, FREEZE_NONE)
  player.last_score = 0
  bmgr:reset()
  fx = {
    impacts = {},
    arrows = {},
    popups = {},
    parts = {},
  }
  -- victory_init()
end

function _draw()
  __draw()
end

function _update()
  __update()
end

function level_init_draw()
  -- draw game stuff first, then
  -- draw level marquee over it
  game_draw()

  local elapsed = time() - last_level_init
  local res = 74
  if elapsed <= 1 then
    res = easeOutQuad(elapsed, 0, 74, 1)
  elseif elapsed >= 2 then
    res = easeInQuad(elapsed - 2, 74, 160, 1)
  end
  rectfill(0, 62, 128, 70 * (elapsed > 2.5 and (2.5 / elapsed) or 1), 7)
  print("level "..level_index, res - 20, 64, 8)
end

function game_update()
  local now = time()
  local dt = now - last_ts
  fc += 1
  handle_timers(timers, dt)
  local bm = btn()
  local bmp = btnp()
  player:update(dt, bm, bmp)
  bmgr:update(dt, player:get_hinted_vx(bm, bmp),player.map_x)
  foreach(fx.impacts, function(impact) 
    impact.ttl -= dt
    if impact.ttl <= 0 then
      del(fx.impacts, impact)
    end
  end)
  foreach(fx.parts, function(part) 
    part:update(dt)
    if part.ttl <= 0 then
      del(fx.parts, part)
    end
  end)
  foreach(fx.arrows, function(arrow) 
    arrow.since_last_frame += dt
    if arrow.since_last_frame >= arrow.frame_wait then
      arrow.offset_index = (arrow.offset_index % #arrow_offsets) + 1
      arrow.since_last_frame = 0
    end
  end)
  foreach(fx.popups, function(popup) 
    popup.ttl -= dt
    popup.y -= popup.dy
    popup.dy -= 0.02
    if popup.color == 10 then
      popup.color = 9
    else
      popup.color = 10
    end

    if popup.frames != nil then
      popup.since_last_frame += dt

      if popup.since_last_frame > popup.frame_wait then
        popup.frame_index += 1
        popup.since_last_frame = 0
        if popup.frame_index > #popup.frames then
          popup.frame_index = 1
        end
      end
    end

    if popup.ttl <= 0 then
      del(fx.popups, popup)
    end
  end)

  local current_huggers = bmgr:player_collision(player:getBB())

  if player.invincible == 0 then
    local proj_collisions = bmgr:player_projectile_collision(player:getBB())
    if proj_collisions > 0 then
      -- remove some health from player
      player:deduct_health(20, true)
      sfx(2)
    end
  end

  if bmgr.boss != nil then
    local boss_collide = bmgr:player_boss_collision(player:getFrontBB(),player.map_x)
    player:handle_boss_collision(boss_collide)

    bmgr:player_boss_buffer_collision(player:getFrontBufferBB(),player.map_x)
  end

  player:handle_hug(current_huggers)

  local checkme,atkbb = player:getAtkBB()
  if checkme then
    foreach({"baddies", "projectiles"}, function(tbl)
      local killed = bmgr:new_combat_collision(tbl, atkbb)
      if killed != nil then
        local dist = abs(player.draw_x-killed.x)
        local msg = ""
        local startx = player.draw_x
        if dist < 9 then
          player:add_od(1)
          msg = sub("★")
        else
          player:add_od(0.4)
          msg = sub("+")
          startx += 2
        end
        add(fx.popups, {ttl=1,color=7,x=startx,y=player.draw_y-5,dy=0.8,msg=msg})
        del(bmgr[tbl], killed)
      end
      end)
      if bmgr.boss != nil then
        bmgr:boss_combat_collision(atkbb,player.map_x)
      end
  end

  foreach(player_projectiles, function(projectile)
    local x0, x1 = 0,0
    if projectile.direction == 0 then
      x0, x1 = projectile.tail_x, projectile.head_x + 10
    else
      x0, x1 = projectile.head_x, projectile.tail_x
    end
    foreach({"baddies","projectiles"}, function(tbl)
     local killed = bmgr:new_combat_collision(tbl, {x0,projectile.top_y,x1,projectile.bottom_y})
      if killed != nil then
        del(bmgr[tbl], killed)
        if tbl == "baddies" then -- only add score / popup for baddie, not projectiles
          add_leaf_popup(killed.x, killed.y-5, 0.8)
          player.score += 1
        end
      end
    end)
      if bmgr.boss != nil then
        local boss_killed = bmgr:boss_combat_collision({x0,projectile.top_y,x1,projectile.bottom_y},player.map_x)
        if boss_killed then
          for i=1,5 do
            add_leaf_popup(
              bmgr.boss:getDrawX(player.map_x) - (rnd(32) - 16),
              bmgr.boss.y - (rnd(8) - 4),
              0.8 - (rnd(0.2) - 0.1)
            )
          end
          player.score += 5
        end
      end

  end)
  -- check if boss has been killed, draw arrow if so
  if bmgr.boss != nil
    and bmgr.boss.state == "dead"
    and #fx.arrows == 0
    then
    add(fx.arrows,
    {
      offset_index = 1,
      since_last_frame = 0,
      frame_wait = 0.1,
      direction= level.direction,
    })
  end


  -- check if we need to spawn anything
  foreach(level.batches, function(batch) 
    if should_spawn_batch(player.map_x, batch.distance, level.direction) then
      bmgr:spawn(batch.baddies, batch.direction)
      del(level.batches, batch)
    end
  end)

  -- check if we should spawn boss
  if bmgr.boss == nil and should_spawn_batch(player.map_x, level.boss, level.direction) then
    if level.direction == 0 then
      bmgr.boss = new_boss(1, player.map_x - 40)
    else
      bmgr.boss = new_boss(0, player.map_x + 40)
    end
  end
  last_ts = now

  foreach(player_projectiles, function(projectile)
    projectile.ttl -= dt
    projectile.tail_x = projectile.direction == 0 and projectile.tail_x - 20 or projectile.tail_x + 20
    if projectile.ttl <= 0 then
      del(player_projectiles, projectile)
    end
  end)

  -- handle player death
  if player.state == "dead" then
    music(-1)
    sfx(5)
    __update = death_update
    add(timers, {
      remaining = 1.5,
      callback = function()
        last_level_init = last_ts
        level.batches = parse_batches(levels[level_index].batches)
        level.direction = levels[level_index].direction
        level.boss = levels[level_index].boss
        player:reset(level.direction, FREEZE_NONE)
        bmgr:reset()
        music(4)
        fx = {
          impacts = {},
          arrows = {},
          popups = {},
          parts = {},
        }
        __update = game_update
        __draw = level_init_draw
        add(timers, {
          remaining = 2.8,
          callback = function()
            -- __update = game_update
            __draw = game_draw
          end
        })
      end
    }
    )
  end

  -- check if player has reached end of level
  if is_level_end(player.map_x, level.direction) then
    level_index += 1
    if level_index > #levels then -- display victory msg
      -- __update = victory_update
      -- __draw = victory_draw
      fade_init()
      return
    end
    -- load new level
    level.batches = parse_batches(levels[level_index].batches)
    level.direction = levels[level_index].direction
    level.boss = levels[level_index].boss
    player.last_score = player.score
    player:reset(level.direction, FREEZE_LR)
    bmgr:reset()
    last_level_init = last_ts
    fx = {
      impacts = {},
      arrows = {},
      popups = {},
      parts = {},
    }
    __update = game_update
    __draw = level_init_draw
    add(timers, {
      remaining = 2.8,
      callback = function()
        __draw = game_draw
      end
    })
  end
end

function timers_only() -- and particles!
  local now = time()
  local dt = now - last_ts
  last_ts = now
  handle_timers(timers, dt)

  foreach(fx.parts, function(part) 
    part:update(dt)
    part.ttl -= dt
    if part.ttl <= 0 then
      del(fx.parts, part)
    end
  end)
end

function fade_draw(seq)
  return function()
    cls()

    for i=0,15 do
      pal(i, 0)
    end

    if #seq == 4 then
      pal(seq[1], seq[2])
      pal(seq[3], seq[4])
    end

    game_draw()

  end
end

function fade_init()

  music(-1, 500)
  __update = timers_only

  add(timers, {remaining=0.5, callback=function()
      -- __draw = victory_draw({9,0,12,2})
      __draw = fade_draw({9,4,12,13})
    end
  })

  add(timers, {remaining=1, callback=function()
      __draw = fade_draw({9,0,12,2})
    end
  })

  add(timers, {remaining=1.5, callback=function()
      __draw = fade_draw({})
      victory_init()
    end
  })
end

function victory_init()

  player:change_state("walk")
  player.map_x = -4
  player.draw_x = -4
  player.dx = 4
  player.y = 80
  player.invincible = 0
  music(9)
  victory_freeze = true
  __update = victory_update

  __draw = victory_draw({9,0,12,2})

  add(timers, {remaining=1, callback=function()
      __draw = victory_draw({9,4,12,13})
    end
  })
  add(timers, {remaining=1.5, callback=function()
      __draw = victory_draw({})
    end
  })
  add(timers, {remaining=5, callback=function()
      victory_freeze = false 
    end
  })
end

function victory_draw(seq)
  return function()
    cls()
    -- fade-y bits
    if #seq > 1 then
      for i=0,15 do
        pal(i, 0)
      end
      pal(seq[1], seq[2])
      pal(seq[3], seq[4])
    end

    rectfill(0,0,128,128,12)
    palt(0, false)
    map(0,14,0,96,16,16)
    dshad("congratulations!", 32, 24)
    dshad("your desert kingdom is safe", 10, 32)
    dshad("from the botanical scourge", 12, 40)
    palt(15,true)
    spr(228, 55, 48) 
    dshad("X"..player.score, 64, 50)
    player:draw(fc)

    if not victory_freeze then
      dshad("press "..BUTTON_O.." or "..BUTTON_X.." to restart", 14, 64)
      if btn(5) or btn(6) then
        _init()
      end
    end
    pal()
  end
end

function victory_update()
  -- allow the game to restart via button press
  local now = time()
  local dt = now - last_ts
  last_ts = now
  fc += 1
  handle_timers(timers, dt)
  if player.draw_x >= 60 then
    player:change_state("victory")
  end
  -- send a fake "right" keypress while not in middle of screen
  player:update(dt, player.draw_x < 60 and 2 or 0, 0)
end

title_message = {
  {4,9,10}, -- cycle colors
  1, -- index into colors
  0, -- time since last update
  0.2, -- rate of change
}
title_input_freeze = false
function title_draw()
  cls()
  palt(0, false)
  rectfill(0,0,128,128,12)
  rectfill(0,34,128,80,0)
  spr(132, 24, 37, 10, 4) 
  pal()
  print("press "..BUTTON_O.." or "..BUTTON_X, 38, 74, title_message[1][title_message[2]])
  print("v1.0.0", 1, 122, 1)
  print("@kitasuna", 92, 122, 1)
end

function title_update()
  if (btnp(4) or btnp(5)) and not title_input_freeze then
    title_input_freeze = true
    title_message[4] = 0.01
    add(timers, {
      remaining=1.0,
      callback=function()
        game_init() 
        title_input_freeze = false
        sfx(7, -2)
      end
    })
    sfx(7)
  end
  local now = time()
  local dt = now - last_ts
  title_message[3] += dt
  if title_message[3] > title_message[4] then
    title_message[2] += 1
    if title_message[2] > #title_message[1] then
      title_message[2] = 1
    end
    title_message[3] = 0
  end
  last_ts = now
  handle_timers(timers, dt)
end

function death_update()
  local now = time()
  local dt = now - last_ts
  last_ts = now
  handle_timers(timers, dt)
  player:update(dt, btn(), btnp())
end

function game_draw()
  cls()
  local now = time()

  palt(0, false)
  local sky_color = is_last_level() and 1 or 12
  rectfill(0,0,128,128,sky_color)
  rectfill(0,0,128,32,0)
  if player.map_x > 64 and player.map_x < map_extent - 64 then
    for i=0,1 do
      map(0,14,i*128-player.map_x%128,96,16,16)
    end
  else
    map(0,14,0,96,16,16)
  end
  pal()

  player:draw(fc)

  palt(0, false)
  palt(15, true)
  foreach(player_projectiles, function(projectile) 
      local current_x = projectile.head_x
      if projectile.t == "punch" then
        spr(47, projectile.head_x, projectile.top_y, 1, 1, (projectile.direction == 1))
        if projectile.direction == 0 then
          current_x -= 8
        else
          current_x += 8
        end
      end
      local length = abs(projectile.head_x - projectile.tail_x)
      local sprites = projectile.t == "punch" and {44,45,46} or {60,61,62,63}
      if length >= 8 then
        for i=1,length \ 8 do
          spr(sprites[flr(rnd(3) + 1)], current_x, projectile.top_y, 1, 1)
          if projectile.direction == 0 then
            current_x -= 8
          else
            current_x += 8
          end
        end
      end
  end)
  pal()

  bmgr:draw(player.map_x, now)

  palt(0, false)
  palt(15, true)
  spr(0,2,5)
  -- player health draw
  line(13, 3, 63, 3, 7)
  line(13, 10, 63, 10, 7)
  line(12, 4, 12, 9, 7)
  line(64, 4, 64, 9, 7)
  if player.health > 0 then
    rectfill(13, 4, (player.health \ 2) + 13, 9, 8)
  end

  -- overdrive draw
  line(13,15,49,15,9) -- baseline
  line(12,11,12,14,9) -- left diag
  line(50,11,50,14,9) -- right diag
  if player.overdrive_on then
    line(13,10,49,10,9) -- topline
  end
  if player.od > 0 then
    rectfill(13, 12, (player.od * 4) + 13, 14, 10)
  end

  -- score draw
  -- spr(228, 80, 6) 
  local lx, ly = (228 % 16) * 8, (228 \ 16) * 8
  sspr(lx, ly, 8,8, 110, 2, 16,16)
  print("X"..player.score, 111, 20, 11)

  -- boss health draw
  if bmgr.boss != nil then
    spr(120,2,21)
    line(13, 21, 63, 21, 7)
    line(13, 28, 63, 28, 7)
    line(12, 22, 12, 27, 7)
    line(64, 22, 64, 27, 7)
    if bmgr.boss.health > 0 then
      rectfill(13, 22, flr((bmgr.boss.health / bmgr.boss.max_health) * 50) + 13, 27, 11)
    end
  end

  foreach(fx.impacts, function(impact) 
    spr(impact.spr, impact.x, impact.y)
  end)

  foreach(fx.parts, function(p)
    p:draw()
  end)

  foreach(fx.arrows, function(arrow) 
    spr(
      level.direction == 0 and 14 or 30,
      level.direction == 0 and 2 or 110,
      64 + arrow_offsets[arrow.offset_index],
      2,
      1
    )
  end)

  foreach(fx.popups, function(popup) 
    if popup.frames != nil then
      if (popup.since_last_frame * 100) % 2 != 0 then
        spr(popup.frames[popup.frame_index], popup.x, popup.y)
      end
    else
      print(popup.msg, popup.x, popup.y,popup.color)
    end
  end)

  pal()
  --[[
  for i=1,player.mash_count do
    rectfill(4 + (8*i), 9, 8 + (8*i), 11, 2)
  end
  ]]--
end

--[[
  t = time
  b = start val
  c = how much change between start and end
  d = how much time for animation
  https://spicyyoghurt.com/tools/easing-functions
]]--
function easeOutQuad (t, b, c, d)
  -- return max val if too much time has passed
  if t > d then
    return c
  end
  local my_t = t / d
  return -c * my_t * (my_t - 2) + b;
end

function easeInQuad (t, b, c, d) 
  if t > d then
    return c
  end
  local my_t = t / d
  return c * (my_t) * my_t + b;
end

function sumTbl(ss)
  local sum = 0
  for i=1,#ss do
    sum += ss[i]
  end
  return sum
end

-- [x0,y0,x1,y1]
function collides_new(s1,s2)
  if (
    s1[1] < s2[3]
    and s1[3] > s2[1]
    and s1[4] > s2[2]
    and s1[2] < s2[4]
    ) then
    return true
  end

  return false
end

function exists(e, tbl)
  for i=1,#tbl do
    if tbl[i] == e then
      return true
    end
  end
  return false
end

function dshad(str, x, y, ow)
  local colors = {5, 7}
  if ow != nil and #ow == 2 then
    colors = ow
  end
  print(str, x+1, y, colors[1])
  print(str, x, y, colors[2])
end


function add_leaf_popup(x, y, dy)
  add(fx.popups,
  {
    ttl=1,
    color=0,
    x=x,
    y=y,
    dy=dy,
    frame_index=1,
    frames={228,229,230,231},
    frame_wait=0.05,
    since_last_frame=0
  })
end


function is_last_level()
  if level_index >= #levels then
    return true
  end
  return false
end

__gfx__
f444444ff444444ffffffffffffffffff444444fffffffff00fffffffffffffffffffffffffffffffffffffffffffffff444444ff444444ffff7ffff77ffffff
ff994444ff994444f444444ff444444fff994444ffffffff088ffffffffffffff444444ff444444ff444444ff444444fff994444ff994444ff787ff7887ff7ff
f9c94444f9c94444ff994444ff994444f9c94444ffffffff0888ffffffffffffff994444ff994444ff994444ff994444f9c94444f9c94444f7887778777f787f
9999494499994944f9c94444f9c9444499994944ffffffffff888ffffffffffff9c94444f9c94444f9c94444f9c9444499994944999949447888887878878787
f4444944f44449449999494499994944f4444944fffffffffff888fffff00fff99994944999949449999494499994944f4444944f44449447888887877878787
ff44444fff44444ff4444944f4444944ff44444fffffffffffff88fffff0888ff4444944f4444944f4444944f4444944ff44444fff44444ff7887777887f787f
ff4498ffff4498ffff44444fff44444fff4498fffffffffffffffffffff0888fff84444fff44444fff84444fff44444fff4498ffff4498ffff787fff77fff7ff
ff8998fff0899809ff4498ffff4498ffff89808ffffffffffffffffffffff88f880888fff99088ffff4498ffff4498ffff80888fff89808ffff7ffffffffffff
fffffffff0888099ff88880fff808889ff88098f99ffffffffffffff08ffffff880888fff99088ffff8998098f899809ff99088fff88099fff77ffffffff7fff
f7ff7f7ff9888899f9888099f9990889ff88998f99ffffffffffffff08ffffffff88888fff88888f8088809980888099ff99888fff88899ff7887ff7fff787ff
ff7f7fffff00000ff9000099f990000fff00990fffffffffffffffffffffffffff00000fff00000f8808889988088899ff00000fff00000f78777f787777887f
fffff77fff88888fff8888ffff22888fff88888fffffffffffffffffffffffffff88888fff88888ff88008fff88008ffff88888fff88888f7878878787888887
f77fffffff88888fff8888ffff22888fff88888ffffffffffffffffffffffffff8888888ff88888fff888fffff888fffff28888fff88888f7877878787888887
fff7f7ffff88f88ff88ff22ff22ff888fff8022ffffffffffffffffffffffffff88fff00ff88f88ffff88ffffff88ffff002f88ff008f22ff7887f787777887f
f7f7ff7fff00f00ff00ff222022ff800fff0000ffffffffffffffffffffffffff00fff00ff00f80ffff00ffffff00fff000ff00f000ff00fff77fff7fff787ff
fffffffff000f00f000fff00000fff00fff0000fffffffffffffffffffffffff000ffff0f000f00ffff000fffff000fffffff00ffffff00fffffffffffff7fff
fffffffff444444ff444444ff444444ff44444fffffffffffffffffffffffffffffffffffffffffff444444fffffffff89888f88887f8989898f878f88ffffff
f7f7ff7fff994444ff994444ff994444f999444fff44444ffffffffff4444fffff44444fffffffffff994444ffffffff9f8988788788879f878988888888ffff
fff7f7fff9c94444f9c94444f9c94444fc99444fff444444ffffffffff9944ffff444444fffffffff9c9444777ffffff999999979799999999999999999999ff
f77fffff9999494499994944999949449999944fff444444fffffffff9c9444fff444444ffffffff9999494777ffffff77777777777777777777777777777777
fffff77ff4444944f4444944f4444944f444944fff494444ffffffff9999444fff494444fffffffff444494997ffffff77777777777777777777777777777777
ff7f7fffff44444fff44444fff84444fff4444ffff494444fffffffff44494ffff494444ffffffffff8444498fffffff799999799799997999999979999999ff
f7ff7f7ff24498ffff4488ffff4488ffff44888ffff4449ffffffffff84944fffff4449fffffffffff4488088fffffff878988f87889f987898988888888ffff
fffffffff289988ff998088f8808888fff88880ffff88888fffffffff4444ffffff808808fffffffff888808ffffffff8f887888f89888f898f78f8988ffffff
fffffffff988990ff998088f8808888fff88899f88f88880ffffff9208998fff9888808809ffffffff88888fffffffffff9fff7ff9ff8ffff9fff8ffff7fffff
ffffffffff00990fff00000fff00000fff00099f88088899ffffff88888808ff9888888889ffffffff00000fffffffff88789887789888878988887879888889
fffffffff228888ff228888ff228888ff888222f88800099f0fff0088880888fffff0000fffffffff228888fffffffff98997989999979999999799999979999
ffffffff002ff880002ff880002ff8800088f00ff8888200f002228008fff89fffff88888fffffff002ff8800fffffff88988788888888898878878888788988
ffffffff002ff880002ff880002ff88000fff00ffff88200f002028880ffff99fff8888888ffffff002ff8800fffffffff8fff9fff7ff9ffff7fffffffffff8f
ffffffffffffffffffffffffffffffffffffffffffffffffffff0088ffffff99fff88fff880fffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffff008ffffffffffff00ffff00fffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
f444ffff333ff333333ff333333ff333333ff333ffff6ffff6f6ff6ff6ff6f6ffffffffffff333fb333b33fffff3f3b3f3b33ffffff333fb333b33ff333bbfff
4400ffff333b33b3333b33b3333b33b3333b33b36f6666ffff6666f6ff6666fffffffffff333bbb3383333fff33b3333333bb3fff333bbb3383333ff3b3b3fff
4044ffff3f3333333f3333333f3333333f333333f6507766f677776f66777506ffffffff33b3b3b33f3bb3ff3b3b33f3f83333ff33b3b3b33f3bb3ffb3bb8fff
fffffffff3b3b343f3b3b343f3b3b343f3b3b3436655776ff655755ff677755fffffffff3b3bb8bb3bb3b33f333338b3bb33333f3b3bb8bb3bb3b33fbbbbbfff
fffffffff3b43333f3b43333f3b43333f3b43333f677755f6650750ff6557766ffffffff3bbbbb3333bbbb3f3fb33333b333b33f3bbbbb3333bbbb3fb8333fff
ffffffff334333f3334333f33043330333033303f677750ff677776ff650776fffffffff3b8333333b83b3f3b33b3f3b383333ff3b8333333b83b3f333bf3fff
ffffffffb3b443f3b3b443f3b30440f3b3b040f3ff6666f66f6666ffff6666f6ffffffff333bf33f443333333b83333b44bb3b33333bf33f44333333ffffffff
fffffffff377773ff377773ff377773ff377773ff6ff6f6ffff6ff6ffff6f6fffffffffff33b343444bb3833f3383434443fb383f33b343444bb3833ffffffff
477fffffff7070ffff7070ffff7070ffff7070ffffffffffffffffffffffffffffffffff3338774477b3333f3bf377447733333f3998007700b3333ff7744fff
470fffffff7040ffff7040ff9f7040f9ff7040ffffffffffffaaaaffffaaaaffffaaaaff3337007700f3b3ff3337007700f3f3b33997007700f3b3ff70077fff
470fffffff4444ffff4444ff9944449999444499ffaaaafffa70970ffa70970ffa70970f3ff700770099f3333ff700770099f3333f9777777799f33370077fff
ffffffffff4400ffff4400fff944009f9f4400f9fa70970ffa77977ffa77977ffa77977f3f99444444f9ff3fff99444444f9ff3f3f99444444f9ff3ff4444fff
ffffffffff4044ffff4044ffff4400ffff4400fffa77977fffa3aaffffa3aaffffa3aaffff9f4400044fffffff9f4400044fffffffff4444044ffffff4400fff
ffffffffff4444ffff4444ffff4444ffff4444ffffa3aafffff33ffffff33ffffff33ffffff45404f044ffffff44540ff044fffffff45444f444ffffffffffff
ffffffffff4f444fff44f44fff4f444fff44f44ff4333ffff43f34fffff434ffff4333ffff54fff44ff45ffff54ff44fff45ffffff54fff44ff45fffffffffff
fffffffff4ff4f44ff4f4f4ff4ff4f44ff4f4f4ff4fff44ff4fff44ffff4f4ffff4ff44fff44fff45ff44ffff44ff54fff44ffffff44fff45ff44fffffffffff
f3b4ffffffffffffffffffffff8888fffffffffff66fffff776fffff6ffff6ff99fffffffff333fb333b33fffff333fb333b33fffff333fb333b33ff00bfffff
3343ffffffff4bffff888ffff888888ffff888ff650fffff755ffffff6ffff6f9ffffffff333bbb3383333fff333bbb3383333fff333bbb3383333ff003fffff
b3b4fffffff4fffff88888fff888878fff88888f655fffff750fffffff6fffff99ffffff33b3b3b33f3bb3ff33b3b3b33f3bb3ff33b3b3b33f3bb3ff77ffffff
ffffffffff8488fff888844ff888878ff448888fffffffffffffffffffffffff99ffffff3b3bb8bb3bb3b33f3b3bb8bb3bb3b33f3b3bb8bb3bb3b33f44ffffff
fffffffff888878ff88888f4ff8488ff4f88888fffffffffffffffffffffffffffffffff3bbbbb3333bbbb3f3bbbbb3333bbbb3f3bbbbb3333bbbb3fffffffff
fffffffff888878ff88778fbfff4ffffbf87788fffffffffffffffffffffffffffffffff3b8333333b83b3f33b8333333b83b3f33b8333333b83b3f3ffffffff
fffffffff888888fff888fffffff4bfffff888ffffffffffffffffffffffffffffffffff333bf33f44333333333bf33f44333333333bf33f44333333ffffffff
ffffffffff8888fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff33b343444bb3833f33b343444bb3833f33b343444bb3833ffffffff
ff3bffff44ffffffff4bfffff88fffffff8ff8fffaafffffaaffffff3aafffff333333b83338779977b3333f3338774477b3333f3338774477b3333f4fffffff
333ffffff44ffffff4ffffff8788fffff877778fa70fffff970fffff33ffffffbb33b4433337099900f3b3ff3337777777f3b3ff3337007700f3b3ff44ffffff
fb343fffff4fffff8488fffff788ffffff8888ffa77fffff977fffffff44ffffb343444bbff79077009ff3333ff700770099f3333ff700770099f333f45fffff
4333ffffffffffffffffffff8788ffffffffffffffffffffffffffffffffffff8774477bfff94444449fff3f3f99004400f9ff3f3ff9444444f9ff3ff44fffff
3bfffffffffffffffffffffff88fffffffffffffffffffffffffffffffffffff7007700fffff4400044fffffff9f4404444ffffffff94400044fffffffffffff
443fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff70077009fff454000444ffffff995444f444fffffff999900444ffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff9440044fff54fff44ff45fffff99fff44ff45fffff54f9944ff45fffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4444444ff44fff45ff44fffff44fff45ff44fffff44fff45ff44fffffffffff
ffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffff
ffffffffffffffffffffffffffffffff00000000000000000000030000000000000000000000000000000000000000000000000000000000ffffffffffffffff
99fff9fffff9ff9ff99ff99ff9ff9f9f00000000000000003300330300000000000000000000000000000000000000000000000000000000ffffffffffffffff
ff99ff99fffffff9ffff99fff9f9ff9f00000000333333333333bb3300000000000000000000000000000000000000000000000000000000ffffffffffffffff
99999999f99f999f999999f9ff99999f00303303333333333033333000000000000000000000000000000000000000000000000000000000ffffffffffffffff
f9999999999999999099f99999999f9903333b3333b3333b3334433400000000000000000000000000000000000000000000000000000000ffffffffffffffff
9999099999f99f999999f9999f99990903330333333343333433b33300000000000000000000000000000000000000000000000000000000ffffffffffffffff
99999999f99f999ff99999999999f9993bb333433bb333333433b99300000000000000000000000000000000000000000000000000000000ffffffffffffffff
99ff99999999999999999ff999999f9933433333300304433303394300000000000000000000000000000000000000000000000000000000ffffffffffffffff
99999999990999f9999999f99999999994033334344404433303394300000000000000000000000000000000000000000000000000000000ffffffffffffffff
99099999999999999f9999999999999994003b30300444043303094400000000000000000000000000000000000000000000000000000000ffffffffffffffff
9999909f9999f999999999999909999994400300940444043b03094400000000000000000000000000000000000000000000000000000000ffffffffffffffff
9999999999f99999999999999999999994400300940400444300944000000000000000000000000000000000000000000000000000000000ffffffffffffffff
9999999999f99999999f99999999999909400000940404440000944000000000000000000000000000000000000000000000000000000000ffffffffffffffff
9f9999999999990999990999999ff99909400000094444040000944000000000000000000000000000000000000000000000000000000000ffffffffffffffff
99999ff99999f99999999999f999999900000000094444000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffff
999999999999999999999999f9999999000000000774774000000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999999999f9999999999999999000000000704704000444340000344440094344059999990599999059900005990000599999000000000000000000000
99999999990999999999999990999999000000000704704009443344009344440943444059999990599999059900005990000599099000000000000000000000
9990999f999999999909999999990999000000000944444094403094409430000943000059900000599000059900005990000599099000000000000000000000
999999999999999999999f9999999999000000000944040094403094409430000944000059900000599000059900005990000599099000000000000000000000
9999999999999999999999999999999f000000009440440094400094409434400944440059999000599990059900005990000599099000000000000000000000
99999999999999999999999999999999000000009404400094400934009444400944340059999000599990059900005990000599999000000000000000000000
99999999999f909999999999999f9999000000009444400094434430009440000943300059900000599000059900005990000599099000000000000000000000
999f9999999999999f999999999f9999000000094444000094309440009440000943000059900000599000059900005990000599099000000000000000000000
99ff999f9999999999990999999f9999000000944444400094330944009444340944444059900000599999059999905999990599099000000000000000000000
99999999999999999999999999999999000009444444440094400094400943440094444059900000599999059999905999990599099000000000000000000000
999999999999999999999999f9999999000094404044040000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999909999999f999909999999999f9000094044040040000000000000000000000000000000000000000000000000000000000000000000000000000000000
9f99999999999999999909f999909999000040040040044400000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999f9999999999999999999999000040400440400440000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999999999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffff444444ffffffffff444444ffffffffffffffffffffffffff444444fffffff444444fffffffff000000000000000000000000000000000000000000000000
fffff994444ffffffffff994444ffffffffffffffffff45ffffff994444fffffff994444ffffffff000000000000000000000000000000000000000000000000
ffff9c94444fffffffff9c94444ffffffffffffffffff545ffff9c94444ffffff9c94444ffffffff000000000000000000000000000000000000000000000000
fff99994944ffffffff99994944fffffffffffffffff5454fff99994944fffff99994499ffffffff000000000000000000000000000000000000000000000000
ffff4444944fffffffff4444944ffffffffffffffff445fff9ff4444944f9ffff4444499ffffffff000000000000000000000000000000000000000000000000
fffff44444fffffffffff84444ffffffffffffccff444ffff99ff84444f99fffff844488ffffffff000000000000000000000000000000000000000000000000
fffff4498ffffffffffff4498ffffffffffffcccf444fffff88ff4498ff88fffff449888ffffffff000000000000000000000000000000000000000000000000
fff808998ffffffff988089980889fffffffccc5444ffffff888089980888ffff0899088ffffffff000000000000000000000000000000000000000000000000
ff808898802fffff99880898808899ffffcccc5c54ffffffff8808988088fffff089808fffffffff000000000000000000000000000000000000000000000000
ff99f888022ffffffffff8888ffffffffcccc5c5cffffffffffff8888ffffffff98888ffffffffff000000000000000000000000000000000000000000000000
ff9ff888099ffffffffff8880ffffffffcc45c56ccfffffffffff8880fffffffff8880ffffffffff000000000000000000000000000000000000000000000000
fffff0008f9ffffffffff0008ffffffffc954566ccfffffffffff0008fffffffff0008ffffffffff000000000000000000000000000000000000000000000000
ffff88882fffffffffff888888fffffffc595466cfffffffffff888888fffffff888888fffffffff000000000000000000000000000000000000000000000000
ffff88ff22ffffffffff88ff88ffffffffc5966cffffffffffff88ff88fffffff88ff88fffffffff000000000000000000000000000000000000000000000000
fff00fff00fffffffff00ffff00ffffffffccccffffffffffff00ffff00ffffff00ff00fffffffff000000000000000000000000000000000000000000000000
ff000fff000fffffff000ffff000ffffffffffffffffffffff000ffff000ffff000ff000ffffffff000000000000000000000000000000000000000000000000
f444444ff444444ffffff444444ffffffff3fffffff33ffffff3fffffff33fff0000000000000000000000000000000000000000000000000000000000000000
ff994444ff994444ffffff994444ffffff3b3fffff3b33ffff333fffff33b3ff0000000000000000000000000000000000000000000000000000000000000000
f9c94444f9c94444fffff9c94444fffff3b3b3fff3b3bb3ff3b3b3fff3bb3b3f0000000000000000000000000000000000000000000000000000000000000000
9999494499994944ffff99994944ffff33b3b33f333333b33b333b3f3b3333330000000000000000000000000000000000000000000000000000000000000000
f4444944f4444944fffff4444944ffff3b333b3ff3b3bb3f33b3b33ff3bb3b3f0000000000000000000000000000000000000000000000000000000000000000
ff44444fff44444fffffff84444ffffff3b3b3ffff3b33fff3b3b3ffff33b3ff0000000000000000000000000000000000000000000000000000000000000000
ff4498ffff4488ffffffff4498ffffffff333ffffff33fffff3b3ffffff33fff0000000000000000000000000000000000000000000000000000000000000000
f0899808f998088fffff808998808ffffff3fffffffffffffff3ffffffffffff0000000000000000000000000000000000000000000000000000000000000000
92088809f998088ffff88088888088ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff00000fff00000ffff99f00000f99ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f228888ff228888ffff99888888f99ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f00ff880002ff880fffff88ff88fffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ff880002ff880fffff00f088fffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000003300330300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000333333333333bb3300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000303303333333333033333000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000003333b3333b3333b3334433400000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000003330333333343333433b33300000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000003bb333433bb333333433b99300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000033433333300304433303394300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000094033334344404433303394300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000094003b30300444043303094400000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000094400300940444043b03094400000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000094400300940400444300944000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000009400000940404440000944000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000009400000094444040000944000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000094444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000077477400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000070470400044434000034444009434405999999059999905990000599000059999900000000000000000000000000000
00000000000000000000000000000000070470400944334400934444094344405999999059999905990000599000059909900000000000000000000000000000
00000000000000000000000000000000094444409440309440943000094300005990000059900005990000599000059909900000000000000000000000000000
00000000000000000000000000000000094404009440309440943000094400005990000059900005990000599000059909900000000000000000000000000000
00000000000000000000000000000000944044009440009440943440094444005999900059999005990000599000059909900000000000000000000000000000
00000000000000000000000000000000940440009440093400944440094434005999900059999005990000599000059999900000000000000000000000000000
00000000000000000000000000000000944440009443443000944000094330005990000059900005990000599000059909900000000000000000000000000000
00000000000000000000000000000009444400009430944000944000094300005990000059900005990000599000059909900000000000000000000000000000
00000000000000000000000000000094444440009433094400944434094444405990000059999905999990599999059909900000000000000000000000000000
00000000000000000000000000000944444444009440009440094344009444405990000059999905999990599999059909900000000000000000000000000000
00000000000000000000000000009440404404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000009404404004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000004004004004440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000004040044040044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000aaa0aaa0aaa00aa00aa000000aaaaa0000000aa0aaa000000aaaaa000000000000000000000000000000000000
00000000000000000000000000000000000000a0a0a0a0a000a000a0000000aa000aa00000a0a0a0a00000aa0a0aa00000000000000000000000000000000000
00000000000000000000000000000000000000aaa0aa00aa00aaa0aaa00000aa0a0aa00000a0a0aa000000aaa0aaa00000000000000000000000000000000000
00000000000000000000000000000000000000a000a0a0a00000a000a00000aa000aa00000a0a0a0a00000aa0a0aa00000000000000000000000000000000000
00000000000000000000000000000000000000a000a0a0aaa0aa00aa0000000aaaaa000000aa00a0a000000aaaaa000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c1c1c11cccccc111ccccc111ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1cc1c1c111c111c111cc11c1c1c11cc111c
c1c1cc1cccccc1c1ccccc1c1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1c1c1c1cc1ccc1cc1c1c1ccc1c1c1c1c1c1c
c1c1cc1cccccc1c1ccccc1c1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1c1c11ccc1ccc1cc111c111c1c1c1c1c111c
c111cc1cccccc1c1ccccc1c1cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1ccc1c1cc1ccc1cc1c1ccc1c1c1c1c1c1c1c
cc1cc111cc1cc111cc1cc111ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc11c1c1c111cc1cc1c1c11ccc11c1c1c1c1c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081828380818283808182838081828380818283000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9091929390919293909192939091929390919293000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a1a2a3a0a1a2a3a0a1a2a3a0a1a2a3a0a1a2a3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b1b2b3b0b1b2b3b0b1b2b3b0b1b2b3b0b1b2b3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000007630076400765014600176000f60007660076600766007660076500763007620196000b6000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000100000c6620c6620c6620c6620c6620c6621b60216602186021860201602266021e602196020b6020060200602006020060200602006020060200602006020060200602006020060200602006020060200602
000100001d1621c1621b1521a152191021710215152121520e1520a15207102041020110201152001420013200132001020010200102001020010200102001020410200102001020010200102001020010200102
000300001b5621876216572137721157211772115721177211572117721357213772135721677216572187721b5621d7521f55224742275422b7422e5322e7323053233732335323573237532377323753237732
0001000021670206501f6301e6301d6001b6001964016640126400e6400b640086400560003600016400064000640006000060000600006001760000600006000460000600006000060000600006000060000600
50060000210621e0621c05219052150001400212002100001506212062100520d0520000000000000000000009062060620405201052000000000000000000000000000002000020000200002000020000200002
000100000d1320d1420e1420e1420f1421014210142101421014211132111321113210132101320f1320f1320e1320d1220d1220c1220b1220a1220a122091220811208112071120511204112031120211202112
000300001c7421c742237022370218732187323a7022d7021472214722177021970214722147221a7021c7021472214722257022570214722147221d702227021472214722277022870214722147222c7022c702
500900001a6501a6401a6401a6301a6301a6201962019610196001960019600196001a6001a600136000760007600086000860009600096000a6001a6002a6000960009602026020360203602036020000200002
040100000050207502095020b5020d5020e5021050212502035220352207522075320b5320c5420f5420f5421254214542185421854222502225021850214532175321a5421d5422054223542245422755227552
040200001850207502095020b5020d5020e50210502125021b552195521855216552155421354212542115320f5320e5320c5220a522225020a55208552065420454203532035320253202532015220052200522
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000063450b345093250134504325000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000200d04300000226000d000226450000500005000050d043000050d00000005226450d0430d000000050d04300005000050d04322645000050d043226000d043000050d0430460522645226000d00022600
011000200d0432260022600226000d0430a3000d0000b3000d043226000d000226000d0432263522635133000d0430d3000c3000d0430d04322600226000d0430d04304600226002260022635226352264522645
011000200d043226002260022600226000a3000d0000b3000d0430c3000d00022600226001130013300133000d0430d3000c3002260022600226000d000000000d04304600226002260022625226352264522645
01100020033000330003300033000a3000a3000a3000a3000c3000c3000c3000c300113001130011300103001330013300133000c3000c3000a3000c3000c300103000c30010300103000a3000a3000a30000000
011000200d043226002262522635226450a3000d0000b3000d0430c3000d00022600226451130013300133000d0430d3000c3000c30022625226350d000000000d0430460022600226000d0230d0002262522645
0110000006324063250930006300063000630006325063350b3450b345013000630001300043000432504325093250930004300093000934509300093000932504325043000130004300000000b3001232512325
01100000123340d33510345153451530012300193001030015300123001030019300103001530010325123450d34512300213000d3001230019300103451533510300123000d3001030021325233001232519300
0110000006300093000b30001300043000000000000000000000000000000000000000000000000000000000173450000000000173000d3350000000000000001033500000173001734515345123450d34512345
01100000063450634506345013000b300093250b345063250b3450b32501300013250132501345043250434509345093450934504300013450632509345063250434504345043450030504300013250934509345
001000000b300174250b3450b3000b3450b3450b3000b34504345043000430004300104450430004345043450930009300093250944509300093450934509300063450b3000b4450b30010435013450130004345
00100000123450d3351032515345233001230019300103451533517345123251930010345153252330012345193351c30021300173451232519300103451533517300123000d3451033521325233001232519345
00100000153451234515345103000d325173451530012345103250d345173001530012300103450d335173001530012300103450d325173001533512300103000d345123451234512300103000d3451234512345
01100000153451234515345103000d325173451530012345103250d345173001530012300103450d335173001530012300103450d200173001533512300103000d325122351233212300103000d332122221e322
011000000b300174000b3000b3450b3450b3000b3000b30004345044450430004345044450430004300043000930009300093000934509345093450934509300063000b3000b4000634506345123451234512345
011000000d325122351233212300103000d332122221e322000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000015345123450d34517345103450d0500e0500f0501005011050120501305014050150500e0000f00010000110001200013000140001500000000000000000000000000000000000000000000000000000
01100000173421734217345173350d3002260022635226351e3441e3421e3451e335163002260022635226352334423340226351734522635226350b3440b3420b3320b3250f3000f30006300000000000000000
0010000012342123421234512335063000f3000d0430d0431934419342193451933510300163000d0430d04312344123400d0431e3450d0430d0431234412342123321232517300123000f3000d3000f3000f300
011000000d3350d3000d3350d3000d3350d3350d3350d335083350833508335083000830008335083350833506335063000633506335063350830008335083350f3350f3350f3350f3350f3000f3350f33506335
011000000d145141000f14212132161220d100141000f14512145161420d100141450f10012100161450d132141250f10012145161000d145141220f14512100161440d125141050f14412135161000d10014135
__music__
03 48464744
01 181d4344
00 191d1e44
00 191d2244
01 1a1d1f44
01 18202244
00 18202244
00 18212344
02 19252444
00 28296944
02 596a6b44

