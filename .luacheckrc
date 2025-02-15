std = "max"

files["**/.luacheckrc"].std = "+luacheckrc"
files["examples/love2d/*.lua"].std = "+love"
files["pink/pink.lua"].std = "+love"
files["test/*.lua"] = { ignore = { "111/test.*" } } -- setting non-standard global variable starting with 'test'

exclude_files = { "test/lib" }

ignore = {
	"211/_.*", -- Unused local variable starting with '_'
	"212/_.*", -- Unused argument starting with '_'
	"213/_.*", -- Unused loop variable starting with '_'
}
