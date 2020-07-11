--table
function swap(a, b)
	local t = a
	a = b
	b = t
end
function dump(value, call_indent)

  if not call_indent then 
    call_indent = ""
  end

  local indent = call_indent .. "  "

  local output = ""

  if type(value) == "table" then
      output = output .. "{"
      local first = true
      for inner_key, inner_value in pairs ( value ) do
        if not first then 
          output = output .. ", "
        else
          first = false
        end
        output = output .. "\n" .. indent
        output = output  .. inner_key .. " = " .. dump ( inner_value, indent ) 
      end
      output = output ..  "\n" .. call_indent .. "}"

  elseif type (value) == "userdata" then
    output = "userdata"
  elseif type (value)  == "function" then
    output = "function"
  elseif type(value) == "boolean" then
	output = value and "true" or "false"
  else
    output =  value
  end
  return output 
end
function unpack (arr, i, j)
  local n = {}
  local k = 0
  local initial_i = i
  j = j or #arr
  for i = i or 1, j do
    k = k + 1
    n[k] = arr[i]
  end
  local l = k
  local function create_arg(l, ...)
    if l == 0 then
      return ...
    else
      return create_arg(l - 1, n[l], ...)
    end
  end
  return create_arg(l)
end
function clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[clone(orig_key)] = clone(orig_value)
        end
        setmetatable(copy, clone(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
--sprite
s = {
	id = 0,
	flip = {
		x = false,
		y = false
	},
	add_to = function(o)
		o.s = clone(s)
		o.draw = function (self) 
			spr(self.s.id, self.pos.x, self.pos.y, 1, 1, self.s.flip.x, self.s.flip.y)
		end
	end
}

--pos
v = {
	x = 0,
	y = 0,
	print = function(self)
		printh("x="..self.x)
		printh("y="..self.y)
	end,
	new = function(x, y)
		local r = clone(v)
		r.x = x or 0
		r.y = y or 0
		return r
	end,
	pos_or_scalar = function(i, p)
		if type(p) == "table" then
			return p[i]
		else
			return p
		end
	end
}
do
	local mt = {
		__add = function(left, right)
			return v.new(left.x + right.x, left.y + right.y)
		end,
		__sub = function(left, right)
			return v.new(left.x - right.x, left.y - right.y)
		end,
		__mul = function(left, right)
			return v.new(
				v.pos_or_scalar("x", left) * v.pos_or_scalar("x", right),
				v.pos_or_scalar("y", left) * v.pos_or_scalar("y", right)
			)
		end,
		__div = function(left, right)
			return v.new(
				v.pos_or_scalar("x", left) / v.pos_or_scalar("x", right),
				v.pos_or_scalar("y", left) / v.pos_or_scalar("y", right)
			)
		end
	}
	setmetatable(v, mt)
end
--all objects
objects = {
	list = {},
	len = 1,
	add = function(self, o)
		self.list[self.len] = o
		local id = self.len
		self.len = self.len + 1
		local destroy = function(o_self)
			self.list[id] = nil
		end
		objects.concat_destroy(o, function(o_self)
			destroy(o_self)
		end)
		return id
	end,
	remove = function(self, id)
		self.list[id] = nil
	end,
	concat_destroy = function(o, destroy)
		local last_destroy = o.destroy
		if last_destroy ~= nil then
			o.destroy = function(o_self)
				last_destroy(o_self)
				destroy(o_self)
			end
		else
			o.destroy = destroy
		end
	end,
	new = function()
		return clone(objects)
	end
}
os = objects.new()
--constant
frame_rate = 60
frame_time = 1 / frame_rate
animation_rate = 0.1
face_to_dir = {
	v.new(-1, 0), 
	v.new(1, 0), 
	v.new(0, -1), 
	v.new(0, 1)
}
--collider box
box = {
	offset = v.new(),
	size = v.new(1, 1),
	f = {false, false, false, false, false, false, false, false},
	get_f = function(self, i)
		return self.f[i + 1]
	end,
	set_f = function(self, i, b)
		self.f[i + 1] = b
	end,
	add_to = function(o)
		o.box = clone(box)
		local last_draw = o.draw
		o.box_pos = function(self)
			return self.pos + self.box.offset
		end
		o.box_block_move = function(self)
			if self.move then
				local from = {
					v.new(0, 1),
					v.new(1, 0),
					v.new(0, 0),
					v.new(1, 1),
				}
				local line_dir = {
					v.new(0, -1),
					v.new(0, 1),
					v.new(1, 0),
					v.new(-1, 0),
				}
				local len = {
					self.box.size.y,
					self.box.size.y,
					self.box.size.x,
					self.box.size.x
				}
				local box_pos = self:box_pos()
				local from = box_pos + (self.box.size - v.new(1, 1)) * from[self.face]
				local ps = line_pixels(from, line_dir[self.face], len[self.face])
				local p, s = block_move(ps, self.face, self.speed)
				if p ~= nil then
					if self.on_collision ~= nil then
						self:on_collision(p, s)
					end
					return
				end
				local dir = face_to_dir[self.face]
				if self.collision_list ~= nil then
					box_pos = box_pos + dir * self.speed
					local max = box_pos + self.box.size
					for _, l in pairs(self.collision_list) do
						for _, o in pairs(l.list)do
							if o.box ~= nil then
								local o_box_pos = o:box_pos()
								local o_max = o_box_pos + o.box.size
								if box_pos.x < o_max.x and box_pos.y < o_max.y and 
									o_box_pos.x < max.x and o_box_pos.y < max.y then
									if self.on_collision ~= nil then
										self:on_collision(o)
									end
									if o.box.block then
										return
									end
								end
							end
						end
					end
				end
				self.pos = self.pos + dir * self.speed
			end
		end
		--o.draw = function(self)
		--	last_draw(self)
		--	local pos = self:box_pos()
		--	rect(pos.x, pos.y, pos.x + self.box.size.x - 1, pos.y + self.box.size.y - 1, 8)
		--end
	end
}
--animation
--
animation = {
	t = 0,
	current_animation = function(animation)
		return animation.data[animation.name]
	end,
	change = function(animation, name, after_finish)
		animation.name = name
		animation.after_finish = after_finish
	end,
	update = function(animation, self)
		local current_animation = animation:current_animation()
		local rate = current_animation.rate or 1
		self.s.id = current_animation.series[flr(animation.t) + 1]
		animation.t = animation.t + animation_rate * rate
		if animation.t >= #current_animation.series  then
			if current_animation.loop then
				animation.t = animation.t % #current_animation.series
			else
				animation.t = #current_animation.series - 1
				if animation.after_finish ~= nil then
					animation.after_finish()
					animation.after_finish = nil
				end
			end
		end
	end,
	new = function()
		return clone(animation)
	end
}
--player
parrying_players = objects.new()
player = {
	face = 2,
	faces = {"right", "right", "up", "down"},
	flip_x = false,
	fsm = {
		states = {
			idle = {
				update = function(state, self)
					self:process_move()
					--trigger bullet
					if abtnp(4) then
						self:fire_bullet()
						self.fsm:change(self, "reload")
						return
					end
					if abtnp(5) then
						self.fsm:change(self, "prepare_parry")
					end
				end
			},
			reload = {
				reload_time = 2,
				reload_time_left = 0,
				enter = function(state, self)
					local pos_f = function()
						return self.pos
					end
					progress_bar.new(pos_f, v.new(-1, -2), state.reload_time)
					state.reload_time_left = state.reload_time
				end,
				update = function(state, self)
					self:process_move()
					if state.reload_time_left > 0 then
						state.reload_time_left = state.reload_time_left - frame_time
					else
						self.fsm:change(self, "idle")
					end
				end
			},
			prepare_parry = {
				enter = function(state, self)
					self.animation.t = 0
					self.animation:change("prepare_parry_"..self:up_or_down(), function()
						self.fsm:change(self, "parry")
					end)
				end,
				update = function(state, self)
					self.animation:update(self)
				end
			},
			parry = {
				on_parry_bullet = function(state, self)
					state.parried_bullet = state.parried_bullet + 1
				end,
				play_animation = function(self)
					self:fetch_face()
					self.animation:change("parry_"..self:up_or_down())
				end,
				enter = function(state, self)
					self.animation.t = 0
					state.play_animation(self)
					state.parring_id = parrying_players:add(self)
					state.parried_bullet = 0
				end,
				update = function(state, self)
					self.animation:update(self)
					state.play_animation(self)
					if not btn(5) then
						self.fsm.states.after_parry.parried_bullet = state.parried_bullet
						self.fsm:change(self, "after_parry")
					end
				end,
				exit = function(state, self)
					parrying_players:remove(state.parring_id)
				end
			},
			after_parry = {
				bullet_step_time = 0.1,
				bullet_step_time_left = 0,
				parried_bullet = 0,
				animation_finish = false,
				enter = function(state, self)
					self.animation.t = 0
					state.bullet_step_time_left = 0
					state.animation_finish = false
					self.animation:change("after_parry_"..self:up_or_down(), function()
						state.animation_finish = true
					end)
				end,
				update = function(state, self)
					self.animation:update(self)
					if state.bullet_step_time_left > 0 then
						state.bullet_step_time_left = state.bullet_step_time_left - frame_time
					elseif state.parried_bullet > 0 then
						self:fire_bullet()
						state.parried_bullet = state.parried_bullet - 1
						state.bullet_step_time_left = state.bullet_step_time_left + state.bullet_step_time
					elseif state.animation_finish then 
						self.fsm:change(self, "reload")
					end
				end
			}
		},
		current_name = "idle",
		current = function(fsm)
			return fsm.states[fsm.current_name]
		end,
		change = function(fsm, self, state_name)
			local next = fsm.states[state_name]
			local current = fsm:current()
			if current.exit ~= nil then
				current:exit(self)
			end
			if next.enter ~= nil then
				next:enter(self)
			end
			fsm.current_name = state_name
		end
	},
	group = {},
	pos = v.new(),
	new = function(pos)
		local r = clone(player)
		s.add_to(r)
		r.s.id = 1
		r.pos = pos
		box.add_to(r)
		r.box.offset = v.new(1, 0)
		r.box.size = v.new(6, 8)
		r.animation = animation.new()
		r.animation.data = {
			right = {
				series = {1, 2, 3, 2, 1},
				loop = true
			},
			right_walk = {
				series = {1, 2, 3, 2, 1},
				loop = true
			},
			up = {
				series = {7, 8, 9, 8, 7},
				loop = true
			},
			up_walk = {
				series = {7, 8, 9, 8, 7},
				loop = true
			},
			down = {
				series = {4, 5, 6, 5, 4},
				loop = true
			},
			down_walk = {
				series = {4, 5, 6, 5, 4},
				loop = true
			},
			prepare_parry_down = {
				series = {17, 18, 19},
				rate = 2
			},
			parry_down = {
				series = {20, 19},
				rate = 2,
				loop = true
			},
			after_parry_down = {
				series = {19, 18, 17},
				rate = 6,
			},
			prepare_parry_up = {
				series = {21, 22, 23},
				rate = 2
			},
			parry_up = {
				series = {24, 23},
				rate = 2,
				loop = true
			},
			after_parry_up = {
				series = {23, 22, 21},
				rate = 6,
			}
		}
		r.animation.name = "right"
		r.collision_list = { portals }
		os:add(r)
	end,
	fire_bullet = function(self)
		local target_pos = {
			v.new(8, 5),
			v.new(8, 5),
			v.new(4, 2),
			v.new(5, 8)
		}
		local offset = (target_pos[self.face] - v.new(3.5, 0)) 
			* v.new(self:flip_x_sign(), 1) + v.new(3.5, 0)
		local pos = self.pos + offset
		bullet.new(self.face, pos)
	end,
	on_parry_bullet = function(self)
		self.fsm.states.parry:on_parry_bullet(self)
	end,
	up_or_down = function(self)
		local table = {"down", "down", "up", "down"}
		return table[self.face]
	end,
	face_dir = function (self)
		local face = {
			v.new(-1, 0),
			v.new(1, 0),
			v.new(0, -1),
			v.new(0, 1),
		}
		return face[self.face]
	end,
	flip_x_sign = function (self)
		return self.flip_x and -1 or 1
	end,
	fetch_face = function(self)
		self.move = true
		if btn(0) then
			self.face = 1
			self.flip_x = true
		elseif btn(1) then
			self.face = 2
			self.flip_x = false
		elseif btn(2) then
			self.face = 3
		elseif btn(3) then
			self.face = 4
		else
			self.move = false
		end
		self.s.flip.x = self.flip_x
	end,
	process_move = function(self)
		local animation = self.animation
		local current = animation.current
		self:fetch_face()
		local next_name = ""
		if self.move then
			next_name = self.faces[self.face].."_walk";
		else 
			next_name = self.faces[self.face];
		end
		self.animation:change(next_name)

		--move
		--self.pos = self.pos + self.sign * self.speed
		self:box_block_move()

		--animation
		self.animation:update(self)
	end,
	update = function (self)
		local current_state = self.fsm:current()
		if current_state.update ~= nil then
			current_state:update(self)
		end
	end,
	speed = 1
}
do
	local index = 0
	local function insert_animation_group(animations)
		for _, animation in pairs(animations) do
			player.group[animation] = index
		end
		index = index + 1
	end
	insert_animation_group({"right", "up", "down"})
	insert_animation_group({"right_walk", "up_walk", "down_walk"})
end
--bullet
bullets = objects.new()
bullets.size = 0
do
	local last_add = bullets.add
	bullets.add_bullet = function(self, o)
		if bullets.size >= 3 then
			for _, bullet in pairs(bullets.list) do
				bullet:destroy()
				break
			end
		end
		bullets:add(o)
		objects.concat_destroy(o, function(o_self)
			bullets.size = bullets.size - 1
		end)
		bullets.size = bullets.size + 1
	end
end
bullet = {
	speed = 1,
	move = true,
	update = function(self)
		self:box_block_move()
	end,
	on_collision = function(self, p, s)
		if p.box == nil then
			if fget(s, 1) then
				local next = {2, 1, 4, 3}
				self.face = next[self.face]
			else
				self:destroy()
			end
		else
			local o = p
			if o.other ~= nil then --portal
				local target_pos = {
					v.new(-1, 3.5),
					v.new(8, 3.5),
					v.new(3.5, -1),
					v.new(3.5, 8),
				}
				self:set_pos(o.other.pos + target_pos[self.face])
			elseif o.on_parry_bullet ~= nil then
				o:on_parry_bullet()
				self:destroy()
			end
		end
	end,
	set_pos = function(self, pos)
		self.pos = pos - v.new(1, 1)
	end,
	new = function(face, pos)
		local r = clone(bullet)
		r:set_pos(pos)
		r.face = face
		s.add_to(r)
		box.add_to(r)
		r.s.id = 10
		r.box.size = v.new(3, 3)
		r.collision_list = { portals, parrying_players }
		os:add(r)
		bullets:add_bullet(r)
		return r
	end
}
--map
maps = {
	list = {
		{
			m_pos = v.new(0, 0),
			player_pos = v.new(8, 8),
			portals = {
				{v.new(4, 5), v.new(6, 7)}
			}
		}
	},
	current_index = 1,
	current = function(self)
		return self.list[self.current_index]
	end,
	next = function(self)
		self.current_index = self.current_index + 1
	end,
	init = function(self)
		local current = self:current();
		player.new(clone(current.player_pos))
		local map = {
			m_pos = current.m_pos,
			draw = function(self)
				map(self.m_pos.x, self.m_pos.y, 0, 0, 16, 16)
			end
		}
		for _, pair in pairs(current.portals) do
			portal.new_pair(unpack(pair))
		end
		os:add(map)
	end
}
--block move
function block_move(ps, face, len)
	for i = 1, len do
		for _, p in pairs(ps) do
			local target_p = p + face_to_dir[face] * len
			local map_p = target_p / 8 + maps:current().m_pos
			local s = mget(map_p.x, map_p.y) 
			if fget(s, 0) then
				return target_p, s
			end
		end
	end
	return
end
function line_pixels(from, dir, len)
	local r = {}
	for i = 0, len - 1 do
		add(r, from + dir * i)
	end
	return r
end
--progress_bar
progress_bar = {
	new = function(follow_pos_f, offset, time)
		local r = {}
		r.follow_pos_f = follow_pos_f
		r.offset = offset
		r.time_left = time
		r.time = time
		r.len = 10
		r.c = 11
		r.update = function(self)
			self.time_left = self.time_left - frame_time
		end
		r.draw = function(self)
			local len = self.len * self.time_left / self.time
			for i = 0, len - 1 do
				local pos = self.follow_pos_f() + self.offset
				pset(pos.x + i, pos.y, self.c)
			end
		end
		os:add(r)
	end
}
--portal
portals = objects.new()
portal = {
	new_pair = function(tile_pos_1, tile_pos_2)
		local left = portal.new(tile_pos_1)
		local right = portal.new(tile_pos_2)
		left.other = right
		right.other = left
		return left, right
	end,
	new = function(tile_pos)
		local r = {}
		r.pos = tile_pos * 8
		s.add_to(r)
		r.animation = animation.new()
		r.animation.data = {
			idle = {
				series = {29, 30, 31, 43},
				loop = true
			}
		}
		r.animation.name = "idle"
		r.update = function(self)
			self.animation:update(self)
		end
		box.add_to(r)
		r.box.size = v.new(8, 8)
		r.box.block = true
		os:add(r)
		portals:add(r)
		return r
	end,
}
--accurate btnp
last_btn_cache = {false, false, false, false, false, false}
current_btn_cache = {false, false, false, false, false, false}
function abtnp(b)
	return (not last_btn_cache[b + 1]) and current_btn_cache[b + 1]
end
function _init()
	maps:init()
end

function _draw()
	cls(0)
	for _, o in pairs(os.list) do
		if o.draw ~= nil then
			o:draw()
		end
	end
end
function _update60()
	last_btn_cache = clone(current_btn_cache)
	for i = 0, 5 do
		current_btn_cache[i + 1] = btn(i)
	end
	for _, o in pairs(os.list) do
		if o.update ~=nil then
			o:update()
		end
	end
end
