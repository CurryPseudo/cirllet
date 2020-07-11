pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--table
function swap(a, b)
	local t = a
	a = b
	b = t
end
function sort (arr, comp)
  if not comp then
    comp = function (a, b)
      return a < b
    end
  end
  local function partition (a, lo, hi)
      pivot = a[hi]
      i = lo - 1
      for j = lo, hi - 1 do
        if comp(a[j], pivot) then
          i = i + 1
          a[i], a[j] = a[j], a[i]
        end
      end
      a[i + 1], a[hi] = a[hi], a[i + 1]
      return i + 1
    end
  local function quicksort (a, lo, hi)
    if lo < hi then
      p = partition(a, lo, hi)
      quicksort(a, lo, p - 1)
      return quicksort(a, p + 1, hi)
    end
  end
  return quicksort(arr, 1, #arr)
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
objects_list = {}
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
		local r = clone(objects)
		add(objects_list, r)
		return r
	end,
	clear_all = function()
		for _, os in pairs(objects_list) do
			os.list = {}
			os.len = 1
		end
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
tile_map = {
	new = function()
		local r = {}
		for i = 0, 15 do
			r[i] = {}
		end
		return r
	end
}
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
		o.check_collision = function(self, face, distance)
			if face ~= nil then
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
				local from = box_pos + (self.box.size - v.new(1, 1)) * from[face]
				--local ps = line_pixels(from, line_dir[face], len[face])
				local ps = { from, from + line_dir[face] * (len[face] - 1)}
				local p, s = block_move(ps, face, distance)
				if p ~= nil then
					return p, s
				end
			end
			if self.collision_list ~= nil then
				local box_pos = self:box_pos()
				if face ~= nil then
					box_pos = box_pos + face_to_dir[face] * distance
				end
				local max = box_pos + self.box.size
				for _, l in pairs(self.collision_list) do
					for _, o in pairs(l.list)do
						if o.box ~= nil then
							local o_box_pos = o:box_pos()
							local o_max = o_box_pos + o.box.size
							if box_pos.x < o_max.x and box_pos.y < o_max.y and 
								o_box_pos.x < max.x and o_box_pos.y < max.y then
								return o
							end
						end
					end
				end
			end
		end
		o.box_block_move = function(self)
			if self.move then
				local p, s = self:check_collision(self.face, self.speed)
				if p ~= nil then
					if self.on_collision ~= nil then
						self:on_collision(p, s)
					end
					if p.box == nil or p.box.block then
						return
					end
				end
				self.pos = self.pos + face_to_dir[self.face] * self.speed
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
		self.s.id = current_animation.series[flr(animation.t) % #current_animation.series + 1]
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
players = objects.new()
player = {
	depth = 1,
	face = 2,
	faces = {"right", "right", "up", "down"},
	flip_x = false,
	reload_time = 2,
	reload_time_left = 0,
	fsm = {
		states = {
			idle = {
				update = function(state, self)
					self:process_move()
					--trigger bullet
					if abtnp(4) then
						self:fire_bullet()
						self.reload_time_left = self.reload_time
						self.fsm:change(self, "reload")
						return
					end
					if abtnp(5) then
						self.fsm:change(self, "prepare_parry")
					end
				end
			},
			reload = {
				enter = function(state, self)
					if self.reload_time_left <= 0 then
						self.fsm:change(self, "idle")
						return
					end
					local pos_f = function()
						return self.pos
					end
					state.progress_bar = progress_bar.new(pos_f, v.new(-1, -2), self.reload_time, self.reload_time_left)
				end,
				update = function(state, self)
					self:process_move()
					if self.reload_time_left > 0 then
						self.reload_time_left = self.reload_time_left - frame_time
					else
						self.fsm:change(self, "idle")
					end
					if abtnp(5) then
						self.fsm:change(self, "prepare_parry")
					end
				end,
				exit = function(state, self)
					if state.progress_bar ~= nil then
						state.progress_bar:destroy()
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
						self.reload_time_left = self.reload_time
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
	--player new
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
				series = {19, 17, 3},
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
				series = {23, 21, 9},
				rate = 6,
			}
		}
		r.animation.name = "right"
		os:add(r)
		players:add(r)
	end,
	on_collision = function(self, p, s)
		printh(dump(p))
		printh(s)
		if s ~= nil then
			if s == 29 then
				maps:next()
			end
		end
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
		if bullets.size >= 5 then
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
	depth = 2,
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
				local valid_face = o.other:valid_face(self.face)
				if valid_face == nil then
					self:destroy()
				end
				self.face = valid_face
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
			elseif o.hit_by_bullet ~= nil then
				o:hit_by_bullet()
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
		r.collision_list = { parrying_players }
		os:add(r)
		bullets:add_bullet(r)
		return r
	end
}
--block move
function block_move(ps, face, len)
	for i = 1, len do
		for _, p in pairs(ps) do
			local target_p = p + face_to_dir[face] * len
			target_p = target_p / 8
			local map_p = target_p + maps:current()
			local s = mget(map_p.x, map_p.y) 
			if fget(s, 0) then
				return target_p, s
			end
			local o = maps.tile[flr(target_p.x)][flr(target_p.y)]
			if o ~= nil then
				return o
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
	new = function(follow_pos_f, offset, time, time_left)
		local r = {}
		r.follow_pos_f = follow_pos_f
		r.offset = offset
		r.time_left = time_left or time
		r.time = time
		r.len = 10
		r.c = 8
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
		return r
	end
}
--portal
portals = objects.new()
portal = {
	new = function(begin_s)
		local generator = {}
		maps.dynamic[begin_s] = {
			o = generator,
			into_tile = true
		}
		generator.new = function(pos)
			local r = {}
			r.depth = 1
			r.begin_s = begin_s
			r.pos = pos
			s.add_to(r)
			r.animation = animation.new()
			r.animation.data = {
				idle = {
					series = {begin_s, begin_s + 1, begin_s + 2, begin_s + 3},
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
			for _, portal in pairs(portals.list) do
				if portal.begin_s == r.begin_s then
					r.other = portal
					portal.other = r
					break
				end
			end
			r.valid_face = function(self, face)
				local next = {
					3, 4, 2, 1
				}
				local current_face = face
				local first = true
				while true do
					if current_face == face and not first then
						return
					end
					first = false
					local p = self:check_collision(current_face, 1)
					if p ~= nil then
						current_face = next[current_face]
					else
						return current_face
					end
				end
			end
			os:add(r)
			portals:add(r)
			return r
		end
		return generator
	end,
}
--door
doors = objects.new()
door = {
	new = function(strength, begin_s)
		local generator = {}
		maps.dynamic[begin_s] = {
			o = generator,
			into_tile = true
		}
		generator.new = function(pos)
			local r = {}
			r.depth = 1
			r.reopen_time = 3
			r.pos = pos
			s.add_to(r)
			r.s.id = begin_s
			r.animation = animation.new()
			r.enable_animation = false
			r.strength_left = strength
			r.animation.data = {
				opened = {
					series = {16},
				},
				close = {
					series = {begin_s + 2, begin_s + 1},
					rate = 2
				}
			}
			local strength_to_id = function(strength_left)
				local t = 1 - strength_left / strength
				return 3 * sqrt(t) + begin_s
			end
			local open_time = 0.5
			r.update = function(self)
				if self.open_time_left ~= nil then
					if self.open_time_left > 0 then
						self.s.id = strength_to_id(self.open_time_left / open_time)
						self.open_time_left = self.open_time_left - frame_time
					else 
						self.open_time_left = nil
						self.enable_animation = true
						self.animation.t = 0
						doors:remove(self.door_id)
						self.animation:change("opened")
						r.reopen_time_left = r.reopen_time
					end
				elseif self.enable_animation then
					self.animation:update(self)
				else
					self.s.id = strength_to_id(self.strength_left)
					self.strength_left = self.strength_left + frame_time * 0.5
					if self.strength_left > strength then
						self.strength_left = strength
					end
				end
				if self.reopen_time_left ~= nil then
					if self.reopen_time_left > 0 then
						self.reopen_time_left = self.reopen_time_left - frame_time
					else
						if self:check_collision() == nil then
							self.door_id = doors:add(self)
							self.animation:change("close", function()
								self.enable_animation = false
							end)
							self.reopen_time_left = nil
							self.strength_left = strength
						end
					end
				end
			end
			r.hit_by_bullet = function(self)
				self.strength_left = self.strength_left - 1
				if self.strength_left <= 0 then
					self.open_time_left = (self.strength_left + 1) / strength * open_time
				end
			end
			box.add_to(r)
			r.box.size = v.new(8, 8)
			r.box.block = true
			r.collision_list = { players }
			os:add(r)
			r.door_id = doors:add(r)
			return r
		end
		return generator
	end,
}
--map
maps = {
	list = {
		v.new(0, 0),
		v.new(16, 0),
	},
	dynamic = {
	},
	current_index = 1,
	current = function(self)
		return self.list[self.current_index]
	end,
	next = function(self)
		self.current_index = self.current_index + 1
		self:init()
	end,
	init = function(self)
		objects.clear_all()
		local current = self:current();
		self.tile = tile_map.new()
		local map = {
			m_pos = current,
			depth = 0,
			draw = function(self)
				map(self.m_pos.x, self.m_pos.y, 0, 0, 16, 16)
			end
		}
		for i = 0, 15 do
			for j = 0, 15 do
				local pos = v.new(i, j) + current
				local s = mget(pos.x, pos.y)
				local dynamic = maps.dynamic[s]
				if dynamic ~= nil then
					local o = dynamic.o.new(v.new(i * 8, j * 8))
					if dynamic.not_erase == nil then
						mset(pos.x, pos.y, 0)
					end
					if dynamic.into_tile ~= nil then
						self.tile[i][j] = o
					end
				end
			end
		end
		os:add(map)
	end
}
maps.dynamic[30] = {o = player, not_erase = true}

door_green = door.new(1, 33)
door_yellow = door.new(1.5, 36)
door_red = door.new(2, 39)
portal_blue = portal.new(49)
portal_yellow = portal.new(53)
portal_red = portal.new(57)
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
	cls(6)
	local draw_list = {}
	for _, o in pairs(os.list) do
		if o.draw ~= nil then
			add(draw_list, o)
		end
	end
	sort(draw_list, function(o1, o2)
		if o1.depth == nil then
			return true
		else
			if o2.depth == nil then
				return false
			else
				return o1.depth < o2.depth
			end
		end
	end)
	for _, o in pairs(draw_list) do
		o:draw()
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

__gfx__
000000000044440000444400004444000044440000444400004444000044440000444400004444000800000077777777777777771ddddddd1ddddddddddddddd
00000000009999000099990000999900009999000099990000999900009999000099990000999900878000001ddddddd1ddddddd1ddddddd1ddddddddddddddd
00700700044444400444444004444440044444400444444004444440044444400444444004444440080000001ddddddd1ddddddd1ddddddd1ddddddddddddddd
0007700000f1f10000f1f10000f1f10000f1f10000f1f10000f1f10000ffff0000ffff0000ffff00000000001ddddddd1ddddddd1ddddddd1ddddddddddddddd
0007700000ffff0000ffff0040ffff0000ffff0000ffff0040ffff0000ffff0000ffff0004fff400000000001ddddddd1ddddddd1ddddddd1ddddddddddddddd
00700700004995550449955504499555004955000449550004495500004445000444440000444500000000001ddddddd1ddddddd1ddddddd1ddddddddddddddd
00000000044995004049950000499500044995004049950000499500044440000099900000999000000000001ddddddd1ddddddd1ddddddd1ddddddddddddddd
0000000000303000003030000030300000303500003035000030350000303000003030000030300000000000111111111ddddddd1ddddddd1111111111111111
0000000000444400004444000044440000cccc0000444400004444000044440000cccc00000000000000000077777777777777770000001d7777777700000000
0000000000999900009999000099990000dddd0000999900009999000099990000dddd000000000000000000dddddddddddddddd00001d1d7666666700000000
000000000444444004444440044444400cccccc00444444004444440044444400cccccc00000000000000000dddddddddddddddd001d1d1d766661d700000000
0000000000f1f10000f1f10000f1f100001f1f0000ffff0000ffff0000ffff00001111000000000000000000dddddddddddddddd1d1d1d1d7661d1d700000000
0000000000ffff0000ffff0000ffff000011110000ffff0000ffff0000ffff00001111000000000000000000dddddddddddddddd1d1d1d1171d1d1d700000000
0000000000449000004440000044440000cccc0000449000004490000049940000cddc000000000000000000dddddddddddddddd1d1d11d171d1d11700000000
000000000444900004444000044444000ccccc000444900000449400044994000ccddc000000000000000000dddddddddddddddd1d11ddd171d11d1700000000
0000000000303000003030000030300000e0e00000303000003030000030300000e0e000000000000000000011111111dddddddd111111117777777700000000
00000000777777777770077777000077777777777770077777000077777777777770077777000077000000000000000000000000000000000000000000000000
000000003bbb3bbb3bb003bb3b00003b499949994990049949000049288828882880018828000028000000000000000000000000000000000000000000000000
000000003bbb3bbb3bb003bb3b00003b499949994990049949000049288828882880018828000028000000000000000000000000000000000000000000000000
000000003bbb3bbb3bb003bb3b00003b499949994990049949000049288828882880018828000028000000000000000000000000000000000000000000000000
000000003bbb3bbb3bb003bb3b00003b499949994990049949000049288828882880018828000028000000000000000000000000000000000000000000000000
000000003bbb3bbb3bb003bb3b00003b499949994990049949000049288828882880018828000028000000000000000000000000000000000000000000000000
000000003bbb3bbb3bb003bb3b00003b499949994990049949000049288828882880018828000028000000000000000000000000000000000000000000000000
00000000333333333330033333000033444444444440044444000044222222222220011122000022000000000000000000000000000000000000000000000000
00000000000cc000000cc000000cc000000ccc00000aa000000aa000000aa000000aaa0000088000000880000008800000088800000000000000000000000000
0000000000c11c0000c11c00c0c11c0000c11c0000a99a0000a99a00a0a99a0000a99a0000822800008228008082280000822800000000000000000000000000
000000000c1111c00c11c1c00c1111c00c1111c00a9999a00a99a9a00a9999a00a9999a008222280082282800822228008222280000000000000000000000000
000000000cc1c1c00c1111c00c1111c00c1111c00aa9a9a00a9999a00a9999a00a9999a008828280082222800822228008222280000000000000000000000000
000000000c1111c00c1111c00c1111cc0cc111c00a9999a00a9999a00a9999aa0aa999a008222280082222800822228808822280000000000000000000000000
000000000c1111c00c11c1c00c1111c00c1111c00a9999a00a99a9a00a9999a00a9999a008222280082282800822228008222280000000000000000000000000
0000000000c11c0000c11c0000c11c0000c11c0000a99a0000a99a0000a99a0000a99a0000822800008228000082280000822800000000000000000000000000
00000000000cc000000cc000000cc000000cc0c0000aa000000aa000000aa000000aa0a000088000000880000008800000088080000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000007777777777777777499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444449999999499999994444444444444444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000007777777777777777000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444499999999000000000000000000000000
__gff__
0000000000000000000000010101010100000000000000000000000101050000000101010101010101010000000000000000000000000000000000000000000000000000000000000000000303030303000000000000000000000003030000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d1e0000000000001d0000000000000d0d1e0000000000001d0000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000002124270000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000c1b000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4d00000e31000000000000000000004d4d00000000000000000000000000004d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4d00000000003100000000000000004d4d00000000000000000000000000004d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00003900000000000000350000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000003500000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000003900000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d00000000000000000000000000000d0d00000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e1b1b1b1b1b1b1b1b1b1b1b1b1b1b0f0e1b1b1b1b1b1b1b1b1b1b1b1b1b1b0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
