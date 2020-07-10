--all objects
os = {}
--player
player = {}
player.update = function (self)
	local sign = new_p()
	if btn(0) then
		sign.x = -1
		self.s.id = 1
		self.s.flip.x = true
	elseif btn(1) then
		sign.x = 1
		self.s.id = 1
		self.s.flip.x = false
	elseif btn(2) then
		sign.y = -1
		self.s.id = 3
	elseif btn(3) then
		sign.y = 1
		self.s.id = 2
	end
	self.p = self.p + sign * self.speed
	self.sign = sign


end
player.speed = 1
--sprite
function add_s(o)
	local s = {}
	s.id = 0
	s.flip = {}
	s.flip.x = false
	s.flip.y = false
	o.s = s
	o.draw = function () 
		spr(o.s.id, o.p.x, o.p.y, 1, 1, o.s.flip.x, o.s.flip.y)
	end
end


--pos
function new_p()
	local o = {}
	o.x = 0
	o.y = 0
	local mt = {
		__add = function(left, right)
			local new = new_p()
			new.x = left.x + right.x
			new.y = left.y + right.y
			return new
		end,
		__mul = function(left, right)
			local pos_or_scalar = function (i, p)
				if type(p) == "table" then
					return p[i]
				else
					return p
				end
			end
			local new = new_p()
			new.x = pos_or_scalar("x", left) * pos_or_scalar("x", right)
			new.y = pos_or_scalar("y", left) * pos_or_scalar("y", right)
			return new
		end
	}
	setmetatable(o, mt)
	return o
end

function _init()
	player.p = new_p()
	add_s(player)
	player.s.id = 1
	add(os, player)
end

function _draw()
	cls(14)
	for _, o in pairs(os) do
		if o.draw ~= nil then
			o.draw()
		end
	end
end
function _update60()
	for _, o in pairs(os) do
		o.update(o)
	end
end
