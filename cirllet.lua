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
s = {}
s.id = 0
s.flip = {}
s.flip.x = false
s.flip.y = false
s.add_to = function(o)
	o.s = clone(s)
	o.draw = function () 
		spr(o.s.id, o.pos.x, o.pos.y, 1, 1, o.s.flip.x, o.s.flip.y)
	end

end

--pos
p = {}
p.x = 0
p.y = 0
do
	local mt = {
		__add = function(left, right)
			return p.new(left.x + right.x, left.y + right.y)
		end,
		__sub = function(left, right)
			return p.new(left.x - right.x, left.y - right.y)
		end,
		__mul = function(left, right)
			local pos_or_scalar = function (i, p)
				if type(p) == "table" then
					return p[i]
				else
					return p
				end
			end
			return p.new(
				pos_or_scalar("x", left) * pos_or_scalar("x", right),
				pos_or_scalar("y", left) * pos_or_scalar("y", right)
			)
		end
	}
	setmetatable(p, mt)
end
p.print = function(self)
	printh("x="..self.x)
	printh("y="..self.y)
end
p.new = function(x, y)
	local r = clone(p)
	r.x = x or 0
	r.y = y or 0
	return r
end
--all objects
os = {}
os.list = {}
function os.add(o)
	add(os.list, o)
end
--constant
animation_rate = 60
face_to_dir = {
	p.new(-1, 0), 
	p.new(1, 0), 
	p.new(0, -1), 
	p.new(0, 1)
}
--collider box
box = {}
box.pos = p.new()
box.size = p.new(1, 1)
--player
player = {}
player.face = 1
player.faces = {"right", "right", "up", "down"}
player.flip_x = false
do 
	local animation = {}
	animation.right = {
		series = {1, 2, 3, 2, 1},
		bullet_pos = p.new(8, 5)
	}
	animation.right_walk = clone(animation.right)
	animation.down = {
		series = {4, 5, 6, 5, 4},
		bullet_pos = p.new(5, 8)
	}
	animation.down_walk = clone(animation.down)
	animation.up = {
		series = {7, 8, 9, 8, 7},
		bullet_pos = p.new(4, 2)
	}
	animation.up_walk = clone(animation.up)
	animation.current = {}
	animation.current.name = "right"
	animation.current.t = 0
	player.animation = animation
end
do
	local group = {}
	local index = 0
	local function insert_animation_group(animations)
		for _, animation in pairs(animations) do
			group[animation] = index
		end
		index = index + 1
	end
	insert_animation_group({"right", "up", "down"})
	insert_animation_group({"right_walk", "up_walk", "down_walk"})
	player.group = group
end
player.pos = p.new()
s.add_to(player)
player.s.id = 1
os.add(player)
player.face_dir = function (self)
	local face = {
		p.new(-1, 0),
		p.new(1, 0),
		p.new(0, -1),
		p.new(0, 1),
	}
	return face[self.face]
end
player.flip_x_sign = function (self)
	return self.flip_x and -1 or 1
end
player.update = function (self)
	local self = player
	local animation = self.animation
	local current = animation.current
	--face to
	local sign = p.new()
	local face = self.face
	local change_face = false
	if btn(0) then
		sign.x = -1
		face = 1
		change_face = true
		self.flip_x = true
	elseif btn(1) then
		sign.x = 1
		face = 2
		change_face = true
		self.flip_x = false
	elseif btn(2) then
		sign.y = -1
		face = 3
		change_face = true
	elseif btn(3) then
		sign.y = 1
		face = 4
		change_face = true
	end
	local next_name = ""
	if change_face then
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
	self.sign = sign
	self.s.flip.x = self.flip_x

	--move
	self.pos = self.pos + self.sign * self.speed

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
		local offset = (current_animation.bullet_pos - p.new(3.5, 0)) 
			* p.new(self:flip_x_sign(), 1) + p.new(3.5, 0)
		local pos = self.pos + offset
		printh(self:flip_x_sign())
		offset:print()
		bullet.new(dir, pos)
	end
end
player.speed = 1
--bullet
bullet = {}
function bullet.new(dir, pos)
	local bullet = {}
	bullet.pos = pos - p.new(1, 1)
	bullet.dir = dir
	bullet.speed = 1
	bullet.update = function(self)
		self.pos = self.pos + dir * self.speed
	end
	s.add_to(bullet)
	bullet.s.id = 10
	os.add(bullet)
	return bullet
end

function _init()
end

function _draw()
	cls(0)
	for _, o in pairs(os.list) do
		if o.draw ~= nil then
			o.draw()
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
