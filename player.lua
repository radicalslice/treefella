map_extent = 256
player = {
  -- stand | walk | pantic | kantic | punch | kick
  state = "stand",
  state_t = 0,
  frame_wait = 0.1,
  map_x = map_extent - 16,
  draw_x = 64,
  draw_y = 80,
  since_last_frame = 0,
  since_last_state = 0,
  frames_walk = {2,4,3,4},
  frames_stand = {1},
  frames_pantic = {9},
  frames_punch = {8},
  frames_kantic = {11},
  frames_kick = {10},
  frames_crouch = {33},
  frames_cpantic = {34},
  frames_cpunch = {35},
  frames_ckantic = {36},
  frames_ckick = {37},
  frame_index = 1,
  frames_current = nil,
  direction = 0,
  reset = function(p)
    p.frames_current = p.frames_stand  
    p.state = "stand"
  end,
  update = function(p, dt)
    if p.state == "stand" then
      p_update_stand(p, dt)
    elseif p.state == "walk" then
      p_update_walk(p, dt)
    elseif p.state == "pantic" then
      p_update_pantic(p, dt)
    elseif p.state == "kantic" then
      p_update_kantic(p, dt)
    elseif p.state == "punch" then
      p_update_punch(p, dt)
    elseif p.state == "kick" then
      p_update_kick(p, dt)
    elseif p.state == "crouch" then
      p_update_crouch(p, dt)
    elseif p.state == "cpantic" then
      p_update_cpantic(p, dt)
    elseif p.state == "cpunch" then
      p_update_cpunch(p, dt)
    elseif p.state == "ckantic" then
      p_update_ckantic(p, dt)
    elseif p.state == "ckick" then
      p_update_ckick(p, dt)
    end
    p.since_last_frame += dt

    if p.since_last_frame > p.frame_wait then
      p.frame_index += 1
      p.since_last_frame = 0
      if p.frame_index > #p.frames_current then
        p.frame_index = 1
      end
    end

  end,
  getBB = function(p)
    local face_right = p.direction == 1
    if face_right then
      return p.draw_x - 1,p.draw_y,p.draw_x + 8,p.draw_y + 16
    else
      return p.draw_x,p.draw_y,p.draw_x + 8,p.draw_y + 16
    end
  end,
  getAtkBB = function(p)
    local face_right = p.direction == 1
    if p.state == "punch" then
      if face_right then
        local left = p.draw_x + 8
        return true,left,p.draw_y+6,left+2,p.draw_y+8
        else
        local left = p.draw_x -3
        return true,left,p.draw_y+6,left+2,p.draw_y+8
      end
    elseif p.state == "kick" then
      if face_right then
        return true,p.draw_x+8,p.draw_y+4,p.draw_x + 12,p.draw_y+7
        else
        local left = p.draw_x -5
        return true,left,p.draw_y+4,left + 3,p.draw_y+7
      end
    elseif p.state == "cpunch" then
      if face_right then
        return true,p.draw_x + 6,p.draw_y+6,p.draw_x + 10,p.draw_y+9
        else
        return true,p.draw_x - 3,p.draw_y+6,p.draw_x,p.draw_y+9
      end
   elseif p.state == "ckick" then
      if face_right then
        return true,p.draw_x + 8,p.draw_y+5,p.draw_x + 12,p.draw_y+8
        else
        return true,p.draw_x - 5,p.draw_y+5,p.draw_x - 1,p.draw_y+8
      end
    

    end

    return false
  end,
  draw = function(p, last_extent, dt)
    palt(0, false)
    palt(15, true)
    local face_right = p.direction == 1
    if p.map_x < 64 then
      p.draw_x = max(0,p.map_x)
    elseif p.map_x > (map_extent - 64) then
      p.draw_x = min(120,128 - (map_extent - p.map_x))
    end

    spr(p.frames_current[p.frame_index], p.draw_x, p.draw_y, 1, 2, face_right and true or false,false)

    -- Draw player's collision box
    local x0, y0, x1, y1 = p:getBB()
    -- rect(x0, y0, x1, y1,11)


    -- Draw the attack-y bits
    if p.state == "punch" then
      spr(21, face_right and p.draw_x + 8 or p.draw_x - 2, p.draw_y + 8)
    elseif p.state == "kantic" then
      spr(23,face_right and p.draw_x + 2 or p.draw_x - 2,p.draw_y + 8,1,1,face_right and true or false)
    elseif p.state == "kick" then
      spr(6,face_right and p.draw_x + 4 or p.draw_x - 4,p.draw_y,1,2,face_right and true or false)
    elseif p.state == "cpunch" then
      spr(21,face_right and p.draw_x + 2 or p.draw_x - 2,p.draw_y+7,1,1,face_right and true or false)
    elseif p.state == "ckick" then
      spr(7,face_right and p.draw_x + 7 or p.draw_x - 7,p.draw_y+2,1,1,face_right and true or false)
    end

    -- Draw fist / leg collision
    local checkme,x2,y2,x3,y3 = p:getAtkBB()
    if checkme then
      -- rect(x2, y2, x3, y3,14)
      -- last_extent = face_right and x3 or x2
    end
    pal()
    -- printh(p.state)
    return last_extent
  end,
}

function p_update_stand(p)
    if btn(4) then
      p.state = "pantic"
      p.state_t = 0.1
      p.frames_current = p.frames_pantic
      p.since_last_state = 0
      return
    end

    if btn(5) then
      p.state = "kantic"
      p.state_t = 0.1
      p.frames_current = p.frames_kantic
      p.since_last_state = 0
      return
    end

    if btn(0) then
      p.direction = 0 
      p.frames_current = p.frames_walk
      p.state = "walk"
    elseif btn(1) then
      p.direction = 1
      p.frames_current = p.frames_walk
      p.state = "walk"
    elseif btn(3) then
      p.frames_current = p.frames_crouch
      p.state = "crouch"
      p.draw_y += 3
      return
    end
end

function p_update_walk(p)
  
  if not btn(0) and not btn(1) then
    p.frames_current = p.frames_stand
    p.frame_index = 1
    p.state = "stand"
  elseif btn(0) and p.map_x > 0 then
    p.direction = 0 
    p.map_x -= 1
  elseif btn(1) and p.map_x < (map_extent - 8) then
    p.direction = 1
    p.map_x += 1
  end
end

function p_update_pantic(p, dt)
    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "punch"
      p.since_last_state = 0
      p.state_t = 0.1
      p.frames_current = p.frames_punch
    end
end

function p_update_kantic(p, dt)
    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "kick"
      p.since_last_state = 0
      p.state_t = 0.10
      p.frames_current = p.frames_kick
    end
end

function p_update_punch(p, dt)
    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "stand"
      p.since_last_state = 0
      p.frames_current = p.frames_stand
    end

end

function p_update_kick(p, dt)

    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "stand"
      p.since_last_state = 0
      p.frames_current = p.frames_stand
    end
end

function p_update_crouch(p, dt)
    if btn(4) then
      p.state = "cpantic"
      p.state_t = 0.1
      p.frames_current = p.frames_cpantic
      p.since_last_state = 0
    end
    if btn(5) then
      p.state = "ckantic"
      p.state_t = 0.1
      p.frames_current = p.frames_ckantic
      p.since_last_state = 0
    end
    if not btn(3) then
      p.state = "stand"
      p.since_last_state = 0
      p.frames_current = p.frames_stand
      p.draw_y -= 3
    end
end

function p_update_cpantic(p, dt)
    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "cpunch"
      p.since_last_state = 0
      p.state_t = 0.1
      p.frames_current = p.frames_cpunch
    end
end

function p_update_ckantic(p, dt)
    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "ckick"
      p.since_last_state = 0
      p.state_t = 0.1
      p.frames_current = p.frames_ckick
    end
end

function p_update_cpunch(p, dt)

    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "crouch"
      p.since_last_state = 0
      p.frames_current = p.frames_crouch
    end
end

function p_update_ckick(p, dt)

    p.since_last_state += dt

    if p.since_last_state > p.state_t then
      p.state = "crouch"
      p.since_last_state = 0
      p.frames_current = p.frames_crouch
    end
end
