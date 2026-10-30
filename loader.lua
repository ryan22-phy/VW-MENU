-- Somente para um host de testes cliente que já autorize HTTP e loadstring.
-- No Roblox Studio padrão, instale dist/VW-MENU.lua como LocalScript.
local url = "https://raw.githubusercontent.com/ryan22-phy/VW-MENU/main/dist/VW-MENU.lua"
assert(type(loadstring) == "function", "Host sem loadstring cliente; use o LocalScript integrado no Studio")
local fetched, source = pcall(function() return game:HttpGet(url) end)
assert(fetched and type(source) == "string", "Não foi possível obter VW MENU: " .. tostring(source))
assert(source:sub(1, 10) == "-- VW MENU", "Conteúdo Raw inesperado")
local chunk, problem = loadstring(source, "@VW-MENU")
assert(chunk, problem)
return chunk()
