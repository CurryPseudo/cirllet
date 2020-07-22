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
max_bullet_count = 3
face_to_dir = {
	v.new(-1, 0), 
	v.new(1, 0), 
	v.new(0, -1), 
	v.new(0, 1)
}
face_revert = {2, 1, 4, 3}
--collider box
tile_map = {
	new = function()
		local r = {}
		for i = 0, 15 do
			r[i] = {}
		end
		r.get_tile = function(p)
			return r[flr(p.x)][flr(p.y)]
		end
		r.get = function(p)
			p = p / 8
			return r.get_tile(p)
		end
		r.set_tile = function(p, o)
			r[flr(p.x)][flr(p.y)] = o
		end
		r.set = function(p, o)
			p = p / 8
			r.set_tile(p, o)
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
				local to = from + line_dir[face] * (len[face] - 1)
				local p_from, s_from = block_move(from, face, distance, self.block_flags)
				local p_to, s_to = block_move(to, face, distance, self.block_flags)
				if s_from and not s_to then
					return line_dir[face], s_from
				end
				if not s_from and s_to then
					return line_dir[face] * -1, s_to
				end
				if s_from and s_to then
					return v.new(0, 0), s_from
				end
				if p_from or p_to then
					return p_from or p_to
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
					if p.x ~= nil then
						self.pos = self.pos + p
						return
					elseif p.box and p.box.block then
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
	block_flags = {0},
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
					sfx(-2, 0)
					sfx(4)
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
					state.counter = bullet_counter.new(function()
						return self.pos
					end, v.new(2, -4), function()
						return state.parried_bullet
					end)
					sfx(3, 0)
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
					state.counter:destroy()
					sfx(-2, 0)
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
					sfx(5)
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
						--self.reload_time_left = self.reload_time
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
		player.singleton = r
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
				series = {65, 66},
				loop = true,
				rate = 3
			},
			up = {
				series = {7, 8, 9, 8, 7},
				loop = true
			},
			up_walk = {
				series = {69, 70},
				loop = true,
				rate = 3
			},
			down = {
				series = {4, 5, 6, 5, 4},
				loop = true
			},
			down_walk = {
				series = {67, 68},
				loop = true,
				rate = 3
			},
			prepare_parry_down = {
				series = {17, 18, 19},
				rate = 1
			},
			parry_down = {
				series = {20, 19},
				rate = 3,
				loop = true
			},
			after_parry_down = {
				series = {19, 17, 3},
				rate = 6,
			},
			prepare_parry_up = {
				series = {21, 22, 23},
				rate = 1
			},
			parry_up = {
				series = {24, 23},
				rate = 3,
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
		objects.concat_destroy(r, function(self)
			sfx(-2, 0)
		end)
	end,
	on_collision = function(self, o, s)
		if o.other ~= nil then --portal
			local valid_face = o.other:valid_face(self)
			if valid_face ~= nil then
				self.face = valid_face
				local target_pos = {
					v.new(-8, 0),
					v.new(8, 0),
					v.new(0, -8),
					v.new(0, 8),
				}
				local after_pos = o.other.pos + target_pos[self.face]
				o:on_transport(self.pos + v.new(3.5, 3.5), after_pos + v.new(3.5, 3.5), self.face)
				self.pos = o.other.pos + target_pos[self.face]
			end
		end
		if s ~= nil then
			if s == 29 then
				sfx(-2, 0)
				sfx(6)
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
		for i = 1, 15 do
			particle.new(clone(pos), 2, 0.05, 0.5, 0, 5)
		end
		sfx(0)
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
		local last_move = self.move
		self:fetch_face()
		local next_name = ""
		if self.move then
			next_name = self.faces[self.face].."_walk";
			if not last_move and self.move then
				sfx(7, 0)
			end
		else 
			next_name = self.faces[self.face];
			if last_move and not self.move then
				sfx(-2, 0)
			end
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
		if bullets.size >= max_bullet_count then
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
	block_flags = {1, 2},
	depth = 2,
	speed = 1,
	move = true,
	update = function(self)
		self:box_block_move()
	end,
	hit_destroy = function(self)
		for i = 1, 10 do
			particle.new(self.pos + v.new(1, 1), 1, 0.05, 0.5, 7, 7, face_revert[self.face])
		end
		sfx(1)
		self:destroy()
	end,
	on_collision = function(self, p, s)
		if p.box == nil then
			if fget(s, 1) then
				self.face = face_revert[self.face]
			else
				self:hit_destroy()
			end
		else
			local o = p
			if o.other ~= nil then --portal
				local valid_face = o.other:valid_face(self)
				if valid_face == nil then
					self:hit_destroy()
				end
				self.face = valid_face
				local target_pos = {
					v.new(-1, 3.5),
					v.new(8, 3.5),
					v.new(3.5, -1),
					v.new(3.5, 8),
				}
				local after_pos = o.other.pos + target_pos[self.face]
				o:on_transport(self.pos + v.new(1, 1), after_pos, self.face)
				self:set_pos(after_pos)
			elseif o.on_parry_bullet ~= nil then
				o:on_parry_bullet()
				self:hit_destroy()
			elseif o.hit_by_bullet ~= nil then
				o:hit_by_bullet()
				self:hit_destroy()
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
function block_move(p, face, len, block_flags)
	local test_flag = function(s)
		if block_flags ~= nil then
			for _, f in pairs(block_flags) do
				if fget(s, f) then
					return true
				end
			end
		end
		return false
	end
	for i = 1, len do
		local target_p = p + face_to_dir[face] * len
		target_p = target_p / 8
		local map_p = target_p + maps:current()
		local s = mget(map_p.x, map_p.y) 
		if test_flag(s) then
			return target_p, s
		end
		local o = maps.tile.get_tile(target_p)
		if o ~= nil then
			return o
		end
	end
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
		r.depth = 100
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
--particle
particle = {
	new = function(pos, rr, rv, vv, c1, c2, face)
		local r = {}
		r.depth = 90
		r.pos = pos
		if face ~= nil then
			local vs = {
				v.new(-rnd(vv / 2), -vv/2 + rnd(vv)),
				v.new(rnd(vv / 2), -vv/2 + rnd(vv)),
				v.new(-vv/2 + rnd(vv), -rnd(vv / 2)),
				v.new(-vv/2 + rnd(vv), rnd(vv / 2)),
			}
			r.v = vs[face]
		else
			r.v = v.new(- vv/2 + rnd(vv), -vv/2 + rnd(vv))
		end
		r.r = 0.5 + rnd(rr)
		r.rv = rv
		r.c = c1 + flr(rnd(2)) * (c2 - c1)
		r.update = function(self)
			self.pos = self.pos + self.v
			self.r = self.r - self.rv
			if self.r <= 0 then
				self:destroy()
			end
		end
		r.draw = function(self)
			circfill(self.pos.x, self.pos.y, self.r, self.c)
		end
		os:add(r)
		return r
	end
}
--bullet counter
bullet_counter = {
	new = function(follow_pos_f, offset, bullet_count_f)
		local r = {}
		r.follow_pos_f = follow_pos_f
		r.offset = offset
		r.bullet_count_f = bullet_count_f
		r.bullets = {}
		r.last_count = 0
		r.space = 4
		for i = 1, max_bullet_count do
			local bullet = {}
			s.add_to(bullet)
			bullet.s.id = 10
			bullet.depth = 100
			add(r.bullets, bullet)
		end
		r.update = function(self)
			local this_count = self.bullet_count_f()
			for i = self.last_count + 1, this_count do
				os:add(self.bullets[i])
			end
			for i = this_count + 1, self.last_count do
				self.bullets[i]:destroy()
				self.bullets[i].destroy = nil
			end
			for i = 0, this_count - 1 do
				local follow_pos = self.follow_pos_f() + self.offset
				local x = (i - (this_count - 1) / 2) * self.space
				self.bullets[i + 1].pos = v.new(x, 0) + follow_pos
			end
			self.last_count = this_count
		end
		os:add(r)
		objects.concat_destroy(r, function(self)
			for i = 1, r.last_count do
				self.bullets[i]:destroy()
			end
		end)
		return r
	end
}
text = {
	new = function(s, pos)
		local r = {}
		r.depth = 100
		r.draw = function(self)
			print(s, pos.x, pos.y, 0)
		end
		os:add(r)
	end
}
--portal
portals = objects.new()
portal = {
	new = function(begin_s, c1, c2)
		local generator = {}
		maps.dynamic[begin_s] = {
			o = generator,
			into_tile = true
		}
		generator.new = function(pos)
			local r = {}
			r.c1 = c1
			r.c2 = c2
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
			r.valid_face = function(self, o)
				self.block_flags = o.block_flags
				local next = {
					3, 4, 2, 1
				}
				local face = o.face
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
			r.on_transport = function(self, pos, after_pos, face)
				for i = 0, 5 do
					particle.new(pos, 2, 0.1, 0.5, self.c1, self.c2, face_revert[face])
				end
				for i = 0, 5 do
					particle.new(after_pos, 2, 0.1, 0.5, self.c1, self.c2, face)
				end
				sfx(2)
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
	new = function(strength, begin_s, reopen_time)
		local generator = {}
		maps.dynamic[begin_s] = {
			o = generator,
			into_tile = true
		}
		generator.new = function(pos)
			local r = {}
			r.depth = 1
			r.reopen_time = reopen_time
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
						maps.tile.set(self.pos, nil)
						self.animation:change("opened")
						r.reopen_time_left = r.reopen_time
						sfx(8)
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
							maps.tile.set(self.pos, self)
							self.door_id = doors:add(self)
							self.animation:change("close", function()
								self.enable_animation = false
							end)
							self.reopen_time_left = nil
							self.strength_left = strength
							sfx(9)
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
--shield
shield = {
	new = function(pos)
		local r = {}
		r.depth = 0.5
		r.pos = pos
		s.add_to(r)
		r.animation = animation.new()
		r.animation.data = {
			idle = {
				series = {45, 46, 47},
				loop = true
			}
		}
		r.animation.name = "idle"
		r.update = function(self)
			self.animation:update(self)
			local player_pos = player.singleton.pos
			if player_pos.y < self.pos.y then
				self.depth = 1.5
			else
				self.depth = 0.5
			end
		end
		r.hit_by_bullet = function(self)
		end
		os:add(r)
		return r
	end
}
--map
maps = {
	list = {
		v.new(0, 0),
		v.new(16, 0),
		v.new(32, 0),
		v.new(48, 0),
		v.new(64, 0),
		v.new(80, 0),
	},
	dynamic = {
	},
	current_index = 1,
	current = function(self)
		return self.list[self.current_index]
	end,
	next = function(self)
		self.current_index = self.current_index + 1
		objects.clear_all()
		if self.current_index > #self.list then
			text.new("Thank you for playing", v.new(20, 50))
		else
			self:init()
		end
	end,
	init = function(self)
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
maps.dynamic[45] = {o = shield, not_erase = true}

door_green = door.new(1, 33, 1.5)
door_yellow = door.new(1.5, 36, 3)
door_red = door.new(2, 39, 4.5)
portal_blue = portal.new(49, 1, 12)
portal_yellow = portal.new(53, 9, 10)
portal_red = portal.new(57, 2, 8)
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
0000000000444400004444000044440000cccc0000444400004444000044440000cccc00000000000000000077777777777777770000001d2222222200000000
0000000000999900009999000099990000dddd0000999900009999000099990000dddd000000000000000000dddddddddddddddd00001d1d2666666200000000
000000000444444004444440044444400cccccc00444444004444440044444400cccccc00000000000000000dddddddddddddddd001d1d1d266661d200000000
0000000000f1f10000f1f10000f1f100001f1f0000ffff0000ffff0000ffff00001111000000000000000000dddddddddddddddd1d1d1d1d2661d1d200000000
0000000000ffff0000ffff0000ffff000011110000ffff0000ffff0000ffff00001111000000000000000000dddddddddddddddd1d1d1d1121d1d1d200000000
0000000000449000004440000044440000cccc0000449000004490000049940000cddc000000000000000000dddddddddddddddd1d1d11d121d1d11200000000
000000000444900004444000044444000ccccc000444900000449400044994000ccddc000000000000000000dddddddddddddddd1d11ddd121d11d1200000000
0000000000303000003030000030300000e0e00000303000003030000030300000e0e000000000000000000011111111dddddddd111111112222222200000000
0000000077777777777007777700007777777777777007777700007777777777777007777700007700000000dddddddd00000000888888888888888888888888
000000003bbb3bbb3bb003bb3b00003b49994999499004994900004928882888288001882800002800000000dddddddd000000000777c7c00cc77cc007ccc770
000000003bbb3bbb3bb003bb3b00003b49994999499004994900004928882888288001882800002800000000dddddddd000000000cc7cc70077cc7c007c777c0
000000003bbb3bbb3bb003bb3b00003b49994999499004994900004928882888288001882800002800000000dddddddd1777777107cc77c007c7c7700c77ccc0
000000003bbb3bbb3bb003bb3b00003b49994999499004994900004928882888288001882800002800000000dddddddd1dddddd10777c7c00cc77cc007ccc770
000000003bbb3bbb3bb003bb3b00003b49994999499004994900004928882888288001882800002800000000dddddddd1dddddd10cc7cc70077cc7c007c777c0
000000003bbb3bbb3bb003bb3b00003b49994999499004994900004928882888288001882800002800000000dddddddd1dddddd107cc77c007c7c7700c77ccc0
0000000033333333333003333300003344444444444004444400004422222222222001112200002200000000dddddddd11111111888888888888888888888888
00000000000cc000000cc000000cc000000ccc00000aa000000aa000000aa000000aaa0000088000000880000008800000088800000000000000000000000000
0000000000c11c0000c11c00c0c11c0000c11c0000a99a0000a99a00a0a99a0000a99a0000822800008228008082280000822800000000000000000000000000
000000000c1111c00c11c1c00c1111c00c1111c00a9999a00a99a9a00a9999a00a9999a008222280082282800822228008222280000000000000000000000000
000000000cc1c1c00c1111c00c1111c00c1111c00aa9a9a00a9999a00a9999a00a9999a008828280082222800822228008222280000000000000000000000000
000000000c1111c00c1111c00c1111cc0cc111c00a9999a00a9999a00a9999aa0aa999a008222280082222800822228808822280000000000000000000000000
000000000c1111c00c11c1c00c1111c00c1111c00a9999a00a99a9a00a9999a00a9999a008222280082282800822228008222280000000000000000000000000
0000000000c11c0000c11c0000c11c0000c11c0000a99a0000a99a0000a99a0000a99a0000822800008228000082280000822800000000000000000000000000
00000000000cc000000cc000000cc000000cc0c0000aa000000aa000000aa000000aa0a000088000000880000008800000088080000000000000000000000000
00000000004444000044440000444400004444000044440000444400000000000000000000000000000000007777777777777777499999994999999999999999
00000000009999000099990000999900009999000099990000999900000000000000000000000000000000004999999949999999499999994999999999999999
00000000044444400444444004444440044444400444444004444440000000000000000000000000000000004999999949999999499999994999999999999999
0000000000ff1f0000ff1f0000f1f10000f1f10000ffff0000ffff00000000000000000000000000000000004999999949999999499999994999999999999999
0000000040ffff0000ffff0004ffff0000ffff0004ffff0000ffff00000000000000000000000000000000004999999949999999499999994999999999999999
00000000044495550044955500495500044955000044450004444500000000000000000000000000000000004999999949999999499999994999999999999999
00000000034495000444950000499500004995000034400000443000000000000000000000000000000000004999999949999999499999994999999999999999
00000000000030000033000000003500003005000000300000300000000000000000000000000000000000004444444449999999499999994444444444444444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000007777777777777777000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999999999999999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444499999999000000000000000000000000
__gff__
0000000000000000000000050505050500000000000000000000000505050000000101010101010101010005010400000000000000000000000000000000000000000000000000000000000303030303000000000000000000000003030000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0c1c1c1c1c1c1c1b1c1c1c1c1c1c1c1c0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c0c1c1c1c1c1c1c1b1c1c1c1c1c1c1c1c0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b1d0d2b2b2b2b2b2b2b0d2b2b2b2b310d2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b0f0f1e0d2b2b2b2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b312c000d2b2b0f2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b2b0f2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b0f2b2b2b2b2b0f0f0f0f2b0d2b2b2b2b0f0f0f0f0f0f0f0f0f0f2b0d2b2b2b2b2c0c000e0f0f310e0f0f2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b2b310d2b2b2b2b2b2b2b2b2b0d2b2b2b2b390d2b2b2b2b000000000d0d2b2b2b2b390000000000000000000d0d2b2b2b2b000d00000000000000000d0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b000c1c000d0d2b2b2b2b0b1c1c1c000c000c1c000d0d2b2b2b2b000d00000000000000350d0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d0f0f0f0f2c0e0f0f0f0f0f0f0f0f2b0d0f0f0f0f2c0e0f0f0f0f0f0f0f0f2b0d0f0f0f0f000e0f0f2b0f000e0f000d0d0f0f0f0f000e0f0f000e000e0f000d0d2b2b2b2b000d00000000210000000d0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b210d2b2b2b2b2b2b2b0d1e0000000000000000002400001d0d0d1e0000000000000000002700001d0d0d1e0000003100001d0d00310000000d0d1e0000003100001d2400310000000d0d2b2b0f0f000e00000000000000000d0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d1c1c1c1c1c1c1c1c1c1c2c0c1c1c2b0d1c1c1c1c2c1c1c1c1c1c1c1c1c1c2b0d1c1c1c1c000c1c1c2b1c1c1c1c1c2b0d1c1c1c1c000c1c1c1c1c1c1c1c1c2b0d2b2b1d242c2c00000000000000390d0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b000d2b2b2b0d2b2b2b2b002b2b2b2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b1c002c0c1c1c350c1c1c1c1c2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b000d2b2b2b0d2b2b2b2b312b2b2b2b2b2b2b2b2b2b0d2b2b2b2b390d2b2b2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b002c0d2b2b1c2b2b2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b000d2b2b2b0d2b2b2b2b1c2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b1c2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b000d2b2b2b2b2b2b2b2b2b0d2b2b2b00000d2b2b2b2b2b2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b000d2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2c0d2b2b2b2b2b2b2b2b2b0d2b2b2b2b390d2b2b2b2b2b2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b000d2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b000d2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b390d2b2b2b2b2b2b2b2b2b0d2b2b2b2b1c2b2b2b2b2b2b2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0d2b2b2b2b2b2b1e0d2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b310d2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b1c2b2b2b2b2b2b2b2b2b2b0d2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b0000000000000000000000000000000000000000000000000000000000000000
0e0f0f0f0f0f0f1b0f0f0f0f0f0f0f0f0e0f0f0f0f0f0f0f0f0f0f1b0f0f0f0f0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0000000000000000000000000000000000000000000000000000000000000000
__sfx__
000200002d6732866324663206531c6531a6431864314633116330e6330c6230a623096230862307613056130461303613026130261301613006130061311603106030f6030e6030d603160030b6030960309603
000100003d6403d6303d6303d6203b6203a620366203562033620316102c61028610236101e6101a6101261007610006102f6002f6002e6000060000600006000060000600006000060000600006000060000600
00010000030700407005070050700607006070060700707007070080700807009070090700a0700b0700c0700c0700d0700d0700e0700f07010070100701107012070140701607017070190701a0701c0701f070
00020012137701376013750137401373013720137100e7000f7001170014700167001a7001c7001f70024700277002d700337003f700007000070000700007000070000700007000070000700007000070000700
000100000c5700b560095600855008550075500655006540065400554005540055400453004530045300353003530035300253002520015200152001520015200152000520005100051000510005100051000510
000100000e570095600756006560065600555005550055500555005550055500656006560065600656006560065600756007560075600856008560095600a5600b5600c5600d5600d5600e5600f5601056011570
000300001467314653146431463300603006030060300603146031460314603146031467314653146431463314603146031460314603006030060300603006031467314653146431463300603006030060300603
000200083604536035360253601536015000050000500005000052e00500005000050000500005000050000500005000050000500005000050000500005000050000514005140050000500005000050000500005
000200001367413664136541365413654136441364413644136443610436104296002960029600296002960029600296742965429644296342963429634001040010400104001040010400104001040010400104
000200002967429664296542965429644296440000000000000000000000000000000000000000000000000013674136641365413654136441364413634136341363400000000000000000000000000000000000
