pico-8 cartridge // http://www.pico-8.com
version 37
__lua__

#include player.lua
#include baddie.lua
#include level.lua

extent = 0 -- debugging; used for tracking max x extent of player attacks
level = {
  batches = {},
  direction = 0
}
level_index = 1
__update = nil
__draw = nil

timers = {}
function handle_timers(ts, dt)
  foreach(ts, function(t)
    t.remaining -= dt

    if t.remaining <= 0 then
      t.callback()
      del(ts, t)
    end
  end)
end

function _init()
  last_ts = 0
  -- spawn :: Num -> (tree || flower) -> Direction -> Void
  -- bmgr:spawn({"flower", "flower", "flower"}, 1)
  level.batches = parse_batches(levels[level_index].batches)
  level.direction = levels[level_index].direction
  level.boss = levels[level_index].boss
  player:reset(level.direction)
  __update = game_update
  __draw = game_draw
  -- music(4)
end

function _draw()
  __draw()
end

function _update()
  __update()
end

function game_update()
  local now = time()
  local dt = now - last_ts
  handle_timers(timers, dt)
  player:update(dt)
  bmgr:update(dt, player.vx,player.map_x)

  local px0, py0, px1, py1 = player:getBB()
  local current_huggers = bmgr:player_collision(px0,py0,px1,py1)

  local proj_collisions = bmgr:player_projectile_collision(px0,py0,px1,py1)
  if proj_collisions > 0 then
    -- remove some health from player
    player:deduct_health(20)
    sfx(2)
  end

  px0, py0, px1, py1 = player:getFrontBB()
  local boss_collide = bmgr:player_boss_collision(px0,py0,px1,py1,player.map_x)
  player:handle_boss_collision(boss_collide)

  px0, py0, px1, py1 = player:getFrontBufferBB()
  bmgr:player_boss_buffer_collision(px0,py0,px1,py1,player.map_x)

  player:handle_hug(current_huggers)

  local checkme,px0,py0,px1,py1 = player:getAtkBB()
  if checkme then
    bmgr:combat_collision(px0,py0,px1,py1)
    bmgr:boss_combat_collision(px0,py0,px1,py1,player.map_x)
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
      bmgr:spawn_boss(1, player.map_x - 40, level_index)
    else
      bmgr:spawn_boss(0, player.map_x + 40, level_index)
    end
  end
  last_ts = now

  -- handle player death
  if player.health <= 0 then
    music(-1)
    sfx(5)
    __update = death_update
    add(timers, {
      remaining = 1.5,
      callback = function()
        level.batches = parse_batches(levels[level_index].batches)
        level.direction = levels[level_index].direction
        level.boss = levels[level_index].boss
        player:reset(level.direction)
        bmgr:reset()
        -- music(4)
        __update = game_update
      end
    }
    )
  end

  -- check if player has reached end of level
  if is_level_end(player.map_x, level.direction) then
    level_index += 1
    if level_index > #levels then -- display victory msg
      __update = victory_update
      __draw = victory_draw
      return
    end
    -- load new level
    level.batches = parse_batches(levels[level_index].batches)
    level.direction = levels[level_index].direction
    level.boss = levels[level_index].boss
    player:reset(level.direction)
    bmgr:reset()
  end
end

function victory_draw()
  cls()
  print("victory", 40, 64, 7)
end

function victory_update()
end

function death_update()
  local now = time()
  local dt = now - last_ts
  last_ts = now
  handle_timers(timers, dt)
end

function game_draw()
  cls()
  palt(0, false)
  rectfill(0,0,128,128,12)
  rectfill(0,0,128,32,6)
  if player.map_x > 64 and player.map_x < map_extent - 64 then
    for i=0,1 do
      map(0,14,i*128-player.map_x%128,96,16,16)
    end
  else
    map(0,14,0,96,16,16)
  end
  bmgr:draw(player.map_x)
  extent = player:draw(extent)

  print("freeze: " .. (player.freeze_input and "y" or "n"),64,4,0)
  print("level: ".. level_index, 64,20,0)
  print("health: "..player.health, 4, 2, 3)
  print("p: ", 4, 9, 2)
  for i=1,player.mash_count_p do
    rectfill(4 + (8*i), 9, 8 + (8*i), 11, 2)
  end
  print("k: ", 4, 15, 1)
  for i=1,player.mash_count_k do
    rectfill(4 + (8*i), 15, 8 + (8*i), 17, 1)
  end
end

function collides(x0, y0, x1, y1, x2, y2, x3, y3)
  if (
    x0 < x3
    and x1 > x2
    and y1 > y2
    and y0 < y3
    ) then
    return true
  end

  return false
end

__gfx__
00000000f444444ffffffffffffffffff444444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff444444ff444444f4444444fffffffff
00000000ff994444f444444ff444444fff994444fffffffffffffffffffffffff444444ff444444ff444444ff444444fff994444ff994444f9c94444ffffffff
00000000f9c94444ff994444ff994444f9c94444ffffffffffffffffffffffffff994444ff994444ff994444ff994444f9c94444f9c9444499444944ffffffff
0000000099994944f9c94444f9c9444499994944fffffffffffffffffffffffff9c94444f9c94444f9c94444f9c944449999494499994944f444444fffffffff
00000000f44449449999494499994944f4444944ffffffffffffffffffff00ff99994944999949449999494499994944f4444944f4444944ff44488fffffffff
00000000ff44444ff4444944f4444944ff44444fffffffff00ffffffffff088ff4444944f4444944f4444944f4444944ff44444fff44444fff00099fffffffff
00000000ff4498ffff44444fff44444fff4498ffffffffff088fffffffff088fff84444fff44444fff84444fff44444fff4498ffff4498ff0022899fffffffff
00000000f0899809ff4498ffff4498ffff89808fffffffff0888fffffffff88f880888fff99088ffff4498ffff4498ffff80888fff89808f00228800ffffffff
00000000f0888099ff88880fff808889ff88098f99ffffffff888fff08ffffff880888fff99088ffff8998098f899809ff99088fff88099f4444444fffffffff
00000000f9888899f9888099f9990889ff88998f99fffffffff888ff08ffffffff88888fff88888f8088809980888099ff99888fff88899ff9c94444ffffffff
00000000ff00000ff9000099f990000fff00990fffffffffffff88ffffffffffff00000fff00000f8808889988088899ff00000fff00000f99444944ffffffff
00000000ff88888fff88882fff22888fff88888fffffffffffffffffffffffffff88888fff88888ff88008fff88008ffff88888fff88888ff484444fffffffff
00000000ff88888fff88882fff22888fff88888ffffffffffffffffffffffffff8888888ff88888fff888fffff888fffff88888fff88888fff44488fffffffff
00000000ff88f88ff88ff222f22ff888fff8022ffffffffffffffffffffffffff88fff00ff88f88ffff88ffffff88ffff008f88ff008f22fff000099ffffffff
00000000ff00f00f088ff200022ff800fff0000ffffffffffffffffffffffffff00fff00ff00f80ffff00ffffff00fff000ff00f000ff00f28888899ffffffff
00000000f000f00f000fff00000fff00fff0000fffffffffffffffffffffffff000ffff0f000f00ffff000fffff000fffffff00ffffff00f22888800ffffffff
00000000f444444ff444444ff444444ff44444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000ff994444ff994444ff994444f999444fff44444fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000f9c94444f9c94444f9c94444fc99444fff444444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
000000009999494499994944999949449999944fff444444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000f4444944f4444944f4444944f444944fff494444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000ff44444fff44444fff84444fff4444ffff494444ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000f24498ffff4488ffff4488ffff44888ffff4449fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000f289988ff998088f8808888fff88880ffff88888ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000f988990ff998088f8808888fff88899f88f88880ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000ff00990fff00000fff00000fff00099f88088899ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000f228888ff228888ff228888ff888222f88800099ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000002ff880002ff880002ff8800088f00ff8888200ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000002ff880002ff880002ff88000fff00ffff88200ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
00000000333ff333333ff333333ff333333ff333ffff6ffff6f6ff6ff6ff6f6ffffffffffff333fb333b33fffff3f3b3f3b33ffffff333fb333b33ffffffffff
00000000333b33b3333b33b3333b33b3333b33b36f6666ffff6666f6ff6666fffffffffff333bbb3383333fff33b3333333bb3fff333bbb3383333ffffffffff
000000003f3333333f3333333f3333333f333333f6507766f677776f66777506ffffffff33b3b3b33f3bb3ff3b3b33f3f83333ff33b3b3b33f3bb3ffffffffff
00000000f3b3b343f3b3b343f3b3b343f3b3b3436655776ff655755ff677755fffffffff3b3bb8bb3bb3b33f333338b3bb33333f3b3bb8bb3bb3b33fffffffff
00000000f3b43333f3b43333f3b43333f3b43333f677755f6650750ff6557766ffffffff3bbbbb3333bbbb3f3fb33333b333b33f3bbbbb3333bbbb3fffffffff
00000000334333f3334333f33043330333033303f677750ff677776ff650776fffffffff3b8333333b83b3f3b33b3f3b383333ff3b8333333b83b3f3ffffffff
00000000b3b443f3b3b443f3b30440f3b3b040f3ff6666f66f6666ffff6666f6ffffffff333bf33f443333333b83333b44bb3b33333bf33f44333333ffffffff
00000000f377773ff377773ff377773ff377773ff6ff6f6ffff6ff6ffff6f6fffffffffff33b343444bb3833f3383434443fb383f33b343444bb3833ffffffff
00000000ff7070ffff7070ffff7070ffff7070ffffffffffffffffffffffffffffffffff3338774477b3333f3bf377447733333f3998007700b3333fffffffff
00000000ff7040ffff7040ff9f7040f9ff7040ffffffffffffaaaaffffaaaaffffaaaaff3337007700f3b3ff3337007700f3f3b33997007700f3b3ffffffffff
00000000ff4444ffff4444ff9944449999444499ffaaaafffa70970ffa70970ffa70970f3ff700770099f3333ff700770099f3333f9777777799f333ffffffff
00000000ff4400ffff4400fff944009f9f4400f9fa70970ffa77977ffa77977ffa77977f3f99444444f9ff3fff99444444f9ff3f3f99444444f9ff3fffffffff
00000000ff4044ffff4044ffff4400ffff4400fffa77977fffa3aaffffa3aaffffa3aaffff9f4400044fffffff9f4400044fffffffff4444044fffffffffffff
00000000ff4444ffff4444ffff4444ffff4444ffffa3aafffff33ffffff33ffffff33ffffff45404f044ffffff44540ff044fffffff45444f444ffffffffffff
00000000ff4f444fff44f44fff4f444fff44f44ff4333ffff43f34fffff434ffff4333ffff54fff44ff45ffff54ff44fff45ffffff54fff44ff45fffffffffff
00000000f4ff4f44ff4f4f4ff4ff4f44ff4f4f4ff4fff44ff4fff44ffff4f4ffff4ff44fff44fff45ff44ffff44ff54fff44ffffff44fff45ff44fffffffffff
00000000ffffffffffffffffff8888ffffffffff00000000000000000000000000000000fff333fb333b33fffff333fb333b33fffff333fb333b33ffffffffff
00000000ffff4bffff888ffff888888ffff888ff00000000000000000000000000000000f333bbb3383333fff333bbb3383333fff333bbb3383333ffffffffff
00000000fff4fffff88888fff888878fff88888f0000000000000000000000000000000033b3b3b33f3bb3ff33b3b3b33f3bb3ff33b3b3b33f3bb3ffffffffff
00000000ff8488fff888844ff888878ff448888f000000000000000000000000000000003b3bb8bb3bb3b33f3b3bb8bb3bb3b33f3b3bb8bb3bb3b33fffffffff
00000000f888878ff88888f4ff8488ff4f88888f000000000000000000000000000000003bbbbb3333bbbb3f3bbbbb3333bbbb3f3bbbbb3333bbbb3fffffffff
00000000f888878ff88778fbfff4ffffbf87788f000000000000000000000000000000003b8333333b83b3f33b8333333b83b3f33b8333333b83b3f3ffffffff
00000000f888888fff888fffffff4bfffff888ff00000000000000000000000000000000333bf33f44333333333bf33f44333333333bf33f44333333ffffffff
00000000ff8888ffffffffffffffffffffffffff00000000000000000000000000000000f33b343444bb3833f33b343444bb3833f33b343444bb3833ffffffff
0000000000000000ffffffff0000000000000000000000000000000000000000000000003338779977b3333f3338774477b3333f3338774477b3333fffffffff
0000000000000000ffffffff0000000000000000000000000000000000000000000000003337099900f3b3ff3337777777f3b3ff3337007700f3b3ffffffffff
0000000000000000ffffffff0000000000000000000000000000000000000000000000003ff79077009ff3333ff700770099f3333ff700770099f333ffffffff
0000000000000000ffffffff0000000000000000000000000000000000000000000000003ff94444449fff3f3f99004400f9ff3f3ff9444444f9ff3fffffffff
0000000000000000ffffffff000000000000000000000000000000000000000000000000ffff4400044fffffff9f4404444ffffffff94400044fffffffffffff
0000000000000000ffffffff000000000000000000000000000000000000000000000000fff454000444ffffff995444f444fffffff999900444ffffffffffff
0000000000000000ffffffff000000000000000000000000000000000000000000000000ff54fff44ff45fffff99fff44ff45fffff54f9944ff45fffffffffff
0000000000000000ffffffff000000000000000000000000000000000000000000000000ff44fff45ff44fffff44fff45ff44fffff44fff45ff44fffffffffff
000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
ffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
99fff9fffff9ff9ff99ff99ff9ff9f9f0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
ff99ff99fffffff9ffff99fff9f9ff9f0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
99999999f99f999f999999f9ff99999f0000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
f9999999999999999099f99999999f990000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
9999099999f99f999999f9999f9999090000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
99999999f99f999ff99999999999f9990000000000000000000000000000000000000000ffffffffffffffffffffffffffffffff000000000000000000000000
99ff99999999999999999ff999999f99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999990999f9999999f999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99099999999999999f99999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9999909f9999f9999999999999099999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9999999999f999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9999999999f99999999f999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9f9999999999990999990999999ff999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999ff99999f99999999999f9999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999999999999999999f9999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999999999f9999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999990999999999999990999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9990999f999999999909999999990999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999999999999999f9999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9999999999999999999999999999999f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999999999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999999f909999999999999f9999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999f9999999999999f999999999f9999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99ff999f9999999999990999999f9999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999999999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999999999999999999f9999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999909999999f999909999999999f9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9f99999999999999999909f999909999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
999999999f9999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999999999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
49060000210001e0001c00019000150001400012000100001500012000100000d0000000000000000000000009000060000400001000000000000000000000000000000002000020000200002000020000200002
91070000104000f4000e4000d4000e4000d4000c4000a4000e4000d4000c4000b400104000f4000e4000d40000402004020040200402004020040200402004020040200402004020040200402004020040200402
51060000210001e0001c00019000150001400012000100001500012000100000d0000000000000000000000009000060000400001000000000000000000000000000000002000020000200002000020000200002
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
00100000063450634506345013000b300093250b345063250b3450b32501300013250132501345043250434509345093450934504300013450632509345063250434504345043450030504300013250934509345
001000000b300174250b3450b3000b3450b3450b3000b34504345043000430004300104450430004345043450930009300093250944509300093450934509300063450b3000b4450b30010435013450130004345
00100000123450d3351032515345233001230019300103451533517345123251930010345153252330012345193351c30021300173451232519300103451533517300123000d3451033521325233001232519345
00100000153451234515345103000d325173451530012345103250d345173001530012300103450d335173001530012300103450d325173001533512300103000d345123451234512300103000d3451234512345
00100000153451234515345103000d325173451530012345103250d345173001530012300103450d335173001530012300103450d200173001533512300103000d325122351233212300103000d332122221e322
011000000b300174000b3000b3450b3450b3000b3000b30004345044450430004345044450430004300043000930009300093000934509345093450934509300063000b3000b4000634506345123451234512345
011000000d325122351233212300103000d332122221e322000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000305006050080500a0500d0500a0000d00007000080000a0000d0000d0000c0000d0000e0000f00010000110001200013000140001500000000000000000000000000000000000000000000000000000
0110000006335063350633512300123350d3000d3350d3000d3000d3350d3350a300163350a300163000a33506335063000633506335063350830008335083350f3351b3000f3350f3350f3000f3000f33506335
011000000f1221212214100161000d1220f1001212214122161220d1000f1001212214100161220d1000f1221210014122161000d1220f1001212214122161000f1220f1000f122141000f1000d1000f1220f122
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
01 58686944
02 596a6b44

