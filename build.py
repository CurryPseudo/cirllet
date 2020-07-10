import sys
game_name = sys.argv[1]
pico8 = open("{}.p8".format(game_name), mode='r')
lua = open("{}.lua".format(game_name), mode='r')
lua_content = lua.read()
replace_after = pico8.read().format(lua_content)
build = open("{}_build.p8".format(game_name), mode='w')
build.write(replace_after)
