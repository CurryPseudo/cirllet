--table
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
os = {
	list = {},
	add = function(self, o)
		add(self.list, o)
	end
}
--constant
animation_rate = 60
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
				local dir = {
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
				local from = self:box_pos() + self.box.size * from[self.face]
				local ps = line_pixels(from, dir[self.face], len[self.face])
				if block_move(ps, self.face, self.speed) == nil then
					self.pos = self.pos + face_to_dir[self.face] * self.speed
				end
			end
		end
		--o.draw = function(self)
		--	last_draw(self)
		--	local pos = self:box_pos()
		--	rect(pos.x, pos.y, pos.x + self.box.size.x, pos.y + self.box.size.y)
		--end
	end
}
--player
player = {
	face = 1,
	faces = {"right", "right", "up", "down"},
	flip_x = false,
	animation = {
		right = {
			series = {1, 2, 3, 2, 1},
			bullet_pos = v.new(8, 5)
		},
		right_walk = {
			series = {1, 2, 3, 2, 1},
			bullet_pos = v.new(8, 5)
		},
		up = {
			series = {7, 8, 9, 8, 7},
			bullet_pos = v.new(4, 2)
		},
		up_walk = {
			series = {7, 8, 9, 8, 7},
			bullet_pos = v.new(4, 2)
		},
		down = {
			series = {4, 5, 6, 5, 4},
			bullet_pos = v.new(5, 8)
		},
		down_walk = {
			series = {4, 5, 6, 5, 4},
			bullet_pos = v.new(5, 8)
		},
		current = {
			name = "right",
			t = 0
		}
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
		r.box.size = v.new(5, 7)
		os:add(r)
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
	update = function (self)
		local animation = self.animation
		local current = animation.current
		--face to
		local face = self.face
		local change_face = false
		self.move = true
		if btn(0) then
			face = 1
			self.flip_x = true
		elseif btn(1) then
			face = 2
			self.flip_x = false
		elseif btn(2) then
			face = 3
		elseif btn(3) then
			face = 4
		else
			self.move = false
		end
		local next_name = ""
		if self.move then
			next_name = self.faces[face].."_walk";
		else 
			next_name = self.faces[face];
		end
		if next_name ~= current.name then
			current.name = next_name
			if self.group[next_name] ~= current.name then
				current.t = 0
			end

		end
		self.face = face
		self.s.flip.x = self.flip_x

		--move
		--self.pos = self.pos + self.sign * self.speed
		self:box_block_move()

		--animation
		local current_animation = animation[current.name];
		self.s.id = current_animation.series[flr(current.t / animation_rate * #current_animation.series) + 1]
		current.t = current.t + 1
		if current.t >= animation_rate then
			current.t = 0
		end

		--trigger bullet
		if btnp(4) then
			local dir = clone(self:face_dir())
			local offset = (current_animation.bullet_pos - v.new(3.5, 0)) 
				* v.new(self:flip_x_sign(), 1) + v.new(3.5, 0)
			local pos = self.pos + offset
			bullet.new(dir, pos)
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
bullet = {}
function bullet.new(dir, pos)
	local bullet = {}
	bullet.pos = pos - v.new(1, 1)
	bullet.dir = dir
	bullet.speed = 1
	bullet.update = function(self)
		self.pos = self.pos + dir * self.speed
	end
	s.add_to(bullet)
	bullet.s.id = 10
	os:add(bullet)
	return bullet
end
--map
maps = {
	list = {
		{
			m_pos = v.new(0, 0),
			player_pos = v.new(8, 8)
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
	for _, o in pairs(os.list) do
		if o.update ~=nil then
			o:update()
		end
	end
end
