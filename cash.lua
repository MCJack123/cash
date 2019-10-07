-- ComputerCraft Advanced Shell
-- Bourne-compatible shell for CraftOS

local topshell = _ENV.shell
local shell = {}
local start_time = os.epoch()
local args = {...}
local running = true

local function splitFile(filename)
    local file = io.open(filename, "r")
    local retval = {}
    for line in file:lines() do table.insert(retval, line) end
    file:close()
    return retval
end

HOME = "/"
SHELL = topshell and topshell.getRunningProgram() or "/usr/bin/cash"
PATH = topshell and string.gsub(topshell.path(), "%.:", "") or "/rom/programs:/rom/programs/fun:/rom/programs/rednet"
USER = "root"
EDITOR = "edit"
OLDPWD = topshell and topshell.dir() or "/"
PWD = topshell and topshell.dir() or "/"
SHLVL = SHLVL and SHLVL + 1 or 1
TERM = "craftos"
COLORTERM = "16color"

local vars = {
    PS1 = "\\s-\\v\\$ ",
    PS2 = "> ",
    IFS = "\n",
    CASH = topshell and topshell.getRunningProgram(),
    CASH_VERSION = "0.1",
    RANDOM = function() return math.random(0, 32767) end,
    SECONDS = function() return math.floor((os.epoch() - start_time) / 1000) end,
    HOSTNAME = os.getComputerLabel(),
    ["*"] = table.concat(args, " "),
    ["@"] = table.concat(args, " "),
    ["#"] = #args,
    ["?"] = 0,
    ["0"] = topshell and topshell.getRunningProgram(),
    _ = topshell and topshell.getRunningProgram(),
    LINENUM = 1,
}

local aliases = topshell and topshell.aliases() or {}
local completion = topshell and topshell.getCompletionInfo() or {}

local builtins = {
    echo = print,
    builtin = function(name, ...) return builtin[name](...) end,
    cd = function(dir)
        if not fs.isDir(shell.resolve(dir or "/")) then 
            printError("cash: cd: " .. dir .. ": No such file or directory")
            return 
        end
        OLDPWD = PWD
        PWD = shell.resolve(dir or "/") 
    end,
    command = function(...) shell.run(...) end,
    complete = function() end, -- TODO
    dirs = function() print(PWD) end,
    eval = function(...) shell.run(...) end,
    exec = function(...) shell.run(...) end,
    exit = shell.exit,
    export = function(...)
        local vars = {...}
        if #vars == 0 or vars[1] == "-p" then for k,v in pairs(_ENV) do if type(v) == "string" or type(v) == "number" then print("export " .. k .. "=" .. v) end end else
            for k,v in ipairs(vars) do
                local kk, vv = string.match(v, "(.+)=(.+)")
                if _ENV[kk] == nil or type(_ENV[kk]) == "string" or type(_ENV[kk]) == "number" then _ENV[kk] = vv end
            end
        end
    end,
    pwd = function() print(PWD) end,
    read = function(var) -- TODO: expand
        vars[var] = read()
    end,
    set = function(...)
        local lvars = {...}
        if #lvars == 0 then for k,v in pairs(vars) do print(k .. "=" .. v) end else
            for k,v in ipairs(lvars) do
                local kk, vv = string.match(v, "(.+)=(.+)")
                vars[kk] = vv
            end
        end
    end,
    alias = function(...)
        local vars = {...}
        if #vars == 0 or vars[1] == "-p" then for k,v in pairs(aliases) do print("alias " .. k .. "=" .. v) end else
            for k,v in ipairs(vars) do
                local kk, vv = string.match(v, "(.+)=(.+)")
                aliases[kk] = vv
            end
        end
    end,
    test = function(...) -- TODO

    end,
    unalias = function(...) for k,v in ipairs({...}) do alias[v] = nil end end,
    unset = function(...) for k,v in ipairs({...}) do vars[v] = nil end end,
    lua = function(...)
        if #({...}) > 0 then print(loadstring("return " .. table.concat({...}, " "))()) else shell.run("/rom/programs/lua.lua") end
    end
}

function shell.exit()
    running = false
end

function shell.dir()
    return PWD
end

function shell.setDir(path)
    OLDPWD = PWD
    PWD = path
end

function shell.path()
    return PATH
end

function shell.setPath(path)
    PATH = path
end

function shell.resolve(localPath)
    if string.sub(localPath, 1, 1) == "/" then return fs.combine(localPath, "")
    else return fs.combine(PWD, localPath) end
end

function shell.resolveProgram(name)
    if builtins[name] ~= nil then return name end
    if aliases[name] ~= nil then name = aliases[name] end
    for path in string.gmatch(PATH, "[^:]+") do
        if fs.exists(fs.combine(shell.resolve(path), name)) then return fs.combine(shell.resolve(path), name)
        elseif fs.exists(fs.combine(shell.resolve(path), name .. ".lua")) then return fs.combine(shell.resolve(path), name .. ".lua") end
    end
    if fs.exists(shell.resolve(name)) then return shell.resolve(name), true end
    if fs.exists(shell.resolve(name .. ".lua")) then return shell.resolve(name .. ".lua"), true end
    return nil
end

function shell.aliases()
    return aliases
end

function shell.setAlias(alias, program)
    aliases[alias] = program
end

function shell.clearAlias(alias)
    aliases[alias] = nil
end

local function combineArray(dst, src, prefix)
    for k,v in ipairs(src) do table.insert(dst, (prefix or "") .. v) end
    return dst
end

function shell.programs(showHidden)
    local retval = {}
    for path in string.gmatch(PATH, "[^:]+") do combineArray(retval, fs.find(fs.combine(shell.resolve(path), "*"))) end
    combineArray(retval, fs.find(fs.combine(PWD, "*")), "./")
    return retval
end

function shell.getRunningProgram()
    return vars._
end

function shell.complete(prefix)
    return fs.complete(prefix, PWD)
end

function shell.completeProgram(prefix)
    return fs.complete(prefix, PWD, true, false)
end

function shell.setCompletionFunction(path, completionFunction)
    completion[path] = {fnComplete = completionFunction}
end

function shell.getCompletionInfo()
    return completion
end

local function expandVar(var)
    if string.sub(var, 1, 1) ~= "$" then return nil end
    if string.sub(var, 2, 2) == "{" then
        local varname = string.sub(string.match(var, "%b{}"), 2, -2)
        local retval = _ENV[varname] or vars[varname]
        if type(retval) == "function" then return retval(), #varname + 2 else return retval or "", #varname + 2 end
    elseif tonumber(string.sub(var, 2, 2)) then
        local varname = tonumber(string.match(string.sub(var, 2, 2), "[0-9]+"))
        if varname == 0 then return vars["0"], 1 else return args[varname] or "", math.floor(math.log10(varname)) + 1 end
    else
        local varname = ""
        for c in string.gmatch(string.sub(var, 2), ".") do
            if c == " " then return "", #varname end
            varname = varname .. c
            if _ENV[varname] or vars[varname] then
                local retval = _ENV[varname] or vars[varname]
                if type(retval) == "function" then return retval(), #varname else return retval or "", #varname end
            end
        end
        return "", #var - 1
    end
end

local function tokenize(cmdline)
    -- Expand vars
    local singleQuote = false
    local escape = false
    local expstr = ""
    local i = 1
    while i <= #cmdline do
        local c = string.sub(cmdline, i, i)
        if c == '$' and not escape and not singleQuote then
            local s, n = expandVar(string.sub(cmdline, i))
            expstr = expstr .. s
            i = i + n
        else
            if c == '\'' and not escape then singleQuote = not singleQuote end
            escape = c == '\\' and not escape
            expstr = expstr .. c
        end
        i=i+1
    end
    -- Tokenize
    local retval = {[0] = ""}
    i = 0
    local quoted = false
    escape = false
    for c in string.gmatch(expstr, ".") do
        if c == '"' or c == '\'' and not escape then quoted = not quoted
        elseif c == '\\' and not quoted and not escape then escape = true
        elseif c == ' ' and not quoted and not escape then
            i=i+1
            retval[i] = ""
        else 
            retval[i] = retval[i] .. c 
            escape = false
        end
    end
    local path, islocal = shell.resolveProgram(retval[0])
    path = path or retval[0]
    if not (islocal and string.find(retval[0], "/") == nil) then retval[0] = path end
    retval.vars = {}
    i = 1
    while i < table.maxn(retval) do
        if string.find(retval[i], "=") then
            retval.vars[string.sub(retval[i], 1, string.find(retval[i], "=") - 1)] = string.sub(retval[i], string.find(retval[i], "=") + 1)
            table.remove(retval, i)
        else i=i+1 end
    end
    return retval
end

local junOff = 31 + 28 + 31 + 30 + 31 + 30
local function dayToString(day)
    if day <= 31 then return "Jan " .. day
    elseif day > 31 and day <= 31 + 28 then return "Feb " .. day - 31
    elseif day > 31 + 28 and day <= 31 + 28 + 31 then return "Mar " .. day - 31 - 28
    elseif day > 31 + 28 + 31 and day <= 31 + 28 + 31 + 30 then return "Apr " .. day - 31 - 28 - 31
    elseif day > 31 + 28 + 31 + 30 and day <= 31 + 28 + 31 + 30 + 31 then return "May " .. day - 31 - 28 - 31 - 30
    elseif day > 31 + 28 + 31 + 30 + 31 and day <= junOff then return "Jun " .. day - 31 - 28 - 31 - 30 - 31
    elseif day > junOff and day <= junOff + 31 then return "Jul " .. day - junOff
    elseif day > junOff + 31 and day <= junOff + 31 + 31 then return "Aug " .. day - junOff - 31
    elseif day > junOff + 31 + 31 and day <= junOff + 31 + 31 + 30 then return "Sep " .. day - junOff - 31 - 31
    elseif day > junOff + 31 + 31 + 30 and day <= junOff + 31 + 31 + 30 + 31 then return "Oct " .. day - junOff - 31 - 31 - 30
    elseif day > junOff + 31 + 31 + 30 + 31 and day <= junOff + 31 + 31 + 30 + 31 + 30 then return "Nov " .. day - junOff - 31 - 31 - 30 - 31
    else return "Dec " .. day - junOff - 31 - 31 - 30 - 31 - 30 end
end

local function getPrompt()
    local retval = vars.PS1
    for k,v in pairs({
        ["\\d"] = dayToString(os.day()),
        ["\\h"] = string.sub(os.getComputerLabel(), 1, string.find(os.getComputerLabel(), "%.")),
        ["\\H"] = os.getComputerLabel(),
        ["\\n"] = "\n",
        ["\\s"] = string.gsub(fs.getName(vars["0"]), ".lua", ""),
        ["\\t"] = textutils.formatTime(os.epoch(), true),
        ["\\T"] = textutils.formatTime(os.epoch(), false),
        ["\\u"] = "root",
        ["\\v"] = vars.CASH_VERSION,
        ["\\V"] = vars.CASH_VERSION,
        ["\\w"] = PWD,
        ["\\W"] = fs.getName(PWD) == "." and "/" or fs.getName(PWD),
        ["\\%#"] = vars.LINENUM,
        ["\\%$"] = "#",
        ["\\([0-7][0-7][0-7])"] = function(n) return string.char(tonumber(n, 8)) end,
        ["\\\\"] = "\\",
        ["\\%[.+\\%]"] = ""
    }) do retval = string.gsub(retval, k, v) end
    return retval
end

local function execv(tokens)
    local path = tokens[0]
    tokens[0] = nil
    if #tokens == 0 and string.find(path, "=") ~= nil then
        vars[string.sub(path, 1, string.find(path, "=") - 1)] = string.sub(path, string.find(path, "=") + 1)
        return
    end
    local oldenv = {}
    for k,v in pairs(tokens.vars) do 
        oldenv[k] = _ENV[k]
        _ENV[k] = v 
    end
    if builtins[path] ~= nil then builtins[path](table.unpack(tokens))
    else 
        local _old = vars._
        vars._ = path
        os.run(setmetatable({shell = shell}, {__index = _ENV}), path, table.unpack(tokens)) 
        vars._ = _old
    end
    for k,v in pairs(tokens.vars) do _ENV[k] = oldenv[k] end
end

function shell.run(...)
    local cmd = table.concat({...}, " ")
    --for cmd in string.gmatch(str, "[^;]+") do
        cmd = string.sub(cmd, string.find(cmd, "[^ ]"), nil)
        if string.sub(cmd, 1, 1) ~= "#" then execv(tokenize(cmd)) end
    --end
end

if args[1] ~= nil then
    local path = table.remove(args, 1)
    local file = io.open(shell.resolve(path), "r")
    for line in file:lines() do shell.run(line) end
    file:close()
    return
end

if fs.exists(".cashrc") then
    local file = io.open(".cashrc", "r")
    for line in file:lines() do shell.run(line) end
    file:close()
end

local function ansiWrite(str)
    local seq = nil
    local bold = false
    local function getnum(d) 
        if seq == "[" then return d or 1
        elseif string.find(seq, ";") then return 
            tonumber(string.sub(seq, 2, string.find(seq, ";") - 1)), 
            tonumber(string.sub(seq, string.find(seq, ";") + 1)) 
        else return tonumber(string.sub(seq, 2)) end 
    end
    for c in string.gmatch(str, ".") do
        if seq == "\x1b" then
            if c == "c" then
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
                term.setCursorBlink(true)
            elseif c == "[" then seq = "["
            else seq = nil end
        elseif seq ~= nil and string.sub(seq, 1, 1) == "[" then
            if tonumber(c) ~= nil or c == ';' then seq = seq .. c else
                if c == "A" then term.setCursorPos(term.getCursorPos(), select(2, term.getCursorPos()) - getnum())
                elseif c == "B" then term.setCursorPos(term.getCursorPos(), select(2, term.getCursorPos()) + getnum())
                elseif c == "C" then term.setCursorPos(term.getCursorPos() + getnum(), select(2, term.getCursorPos()))
                elseif c == "D" then term.setCursorPos(term.getCursorPos() - getnum(), select(2, term.getCursorPos()))
                elseif c == "E" then term.setCursorPos(1, select(2, term.getCursorPos()) + getnum())
                elseif c == "F" then term.setCursorPos(1, select(2, term.getCursorPos()) - getnum())
                elseif c == "G" then term.setCursorPos(getnum(), select(2, term.getCursorPos()))
                elseif c == "H" then term.setCursorPos(getnum())
                elseif c == "J" then term.clear() -- ?
                elseif c == "K" then term.clearLine() -- ?
                elseif c == "T" then term.scroll(getnum())
                elseif c == "f" then term.setCursorPos(getnum())
                elseif c == "m" then
                    local n, m = getnum(0)
                    if n == 0 then
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.white)
                    elseif n == 1 then bold = true
                    elseif n == 7 or n == 27 then
                        local bg = term.getBackgroundColor()
                        term.setBackgroundColor(term.getTextColor())
                        term.setTextColor(bg)
                    elseif n == 22 then bold = false
                    elseif n >= 30 and n <= 37 then term.setTextColor(2^(15 - (n - 30) - (bold and 8 or 0)))
                    elseif n == 39 then term.setTextColor(colors.white)
                    elseif n >= 40 and n <= 47 then term.setBackgroundColor(2^(15 - (n - 40) - (bold and 8 or 0)))
                    elseif n == 49 then term.setBackgroundColor(colors.black) end
                    if m ~= nil then
                        if m == 0 then
                            term.setBackgroundColor(colors.black)
                            term.setTextColor(colors.white)
                        elseif m == 1 then bold = true
                        elseif m == 7 or m == 27 then
                            local bg = term.getBackgroundColor()
                            term.setBackgroundColor(term.getTextColor())
                            term.setTextColor(bg)
                        elseif m == 22 then bold = false
                        elseif m >= 30 and m <= 37 then term.setTextColor(2^(15 - (m - 30) - (bold and 8 or 0)))
                        elseif m == 39 then term.setTextColor(colors.white)
                        elseif m >= 40 and m <= 47 then term.setBackgroundColor(2^(15 - (m - 40) - (bold and 8 or 0)))
                        elseif m == 49 then term.setBackgroundColor(colors.black) end
                    end
                end
                seq = nil
            end
        elseif c == string.char(0x1b) then seq = "\x1b"
        else write(c) end
    end
end

local history = {}
local function readCommand()
    ansiWrite(getPrompt())
    local str = ""
    local ox, oy = term.getCursorPos()
    local coff = 0
    local histpos = table.maxn(history) + 1
    local lastlen = 0
    local waitTab = false
    local function redrawStr()
        term.setCursorPos(ox, oy)
        local x, y
        local i = 0
        for c in string.gmatch(str, ".") do
            if term.getCursorPos() == term.getSize() then
                if select(2, term.getCursorPos()) == select(2, term.getSize()) then
                    term.scroll(1)
                    oy = oy - 1
                    term.setCursorPos(1, select(2, term.getCursorPos()))
                else term.setCursorPos(1, select(2, term.getCursorPos()) + 1) end
            end
            if i == coff then x, y = term.getCursorPos() end
            term.write(c)
            i=i+1
        end
        if x == nil then x, y = term.getCursorPos() end
        for i = 0, lastlen - #str - 1 do term.write(" ") end
        lastlen = #str
        term.setCursorPos(x, y)
    end
    term.setCursorBlink(true)
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "key" then
            if ev[2] == keys.enter then break
            elseif ev[2] == keys.up and history[histpos-1] ~= nil then 
                histpos = histpos - 1
                str = history[histpos]
                coff = #str
                waitTab = false
            elseif ev[2] == keys.down and history[histpos+1] ~= nil then 
                histpos = histpos + 1
                str = history[histpos]
                coff = #str
                waitTab = false
            elseif ev[2] == keys.down and histpos == table.maxn(history) then
                histpos = histpos + 1
                str = ""
                coff = 0
                waitTab = false
            elseif ev[2] == keys.left and coff > 0 then 
                coff = coff - 1
                waitTab = false
            elseif ev[2] == keys.right and coff < #str then 
                coff = coff + 1
                waitTab = false
            elseif ev[2] == keys.backspace and coff > 0 then
                str = string.sub(str, 1, coff - 1) .. string.sub(str, coff + 1)
                coff = coff - 1
                waitTab = false
            elseif ev[2] == keys.tab and coff == #str then
                local tokens = tokenize(str)
                if completion[tokens[0]] ~= nil then
                    local t = {}
                    for i = 1, table.maxn(tokens) - 1 do t[i] = tokens[i] end
                    local res = completion[tokens[0]].fnComplete(shell, table.maxn(tokens), tokens[table.maxn(tokens)], t)
                    if #res > 0 then
                        local longest = res[1]
                        local function getLongest(a, b)
                            for i = 1, math.min(#a, #b) do if string.sub(a, i, i) ~= string.sub(b, i, i) then return string.sub(a, 1, i-1) end end
                            return a 
                        end
                        for k,v in ipairs(res) do longest = getLongest(longest, v) end
                        if longest == "" then
                            if not waitTab then waitTab = true else
                                print("")
                                textutils.pagedTabulate(res)
                                ansiWrite(getPrompt())
                                ox, oy = term.getCursorPos()
                            end
                        else
                            str = str .. longest
                            coff = #str
                            waitTab = false
                        end
                    end
                else
                    local res = fs.complete(tokens[table.maxn(tokens)], shell.path())
                    if #res > 0 then
                        local longest = res[1]
                        local function getLongest(a, b)
                            for i = 1, math.min(#a, #b) do if string.sub(a, i, i) ~= string.sub(b, i, i) then return string.sub(a, 1, i-1) end end
                            return a 
                        end
                        for k,v in ipairs(res) do longest = getLongest(longest, v) end
                        if longest == "" then
                            if not waitTab then waitTab = true else
                                print("")
                                textutils.pagedTabulate(res)
                                ansiWrite(getPrompt())
                                ox, oy = term.getCursorPos()
                            end
                        else
                            str = str .. longest
                            coff = #str
                            waitTab = false
                        end
                    end
                end
            end
        elseif ev[1] == "char" then
            str = string.sub(str, 1, coff) .. ev[2] .. string.sub(str, coff + 1)
            coff = coff + 1
            waitTab = false
        end
        redrawStr()
    end
    print("")
    term.setCursorBlink(false)
    if str ~= "" then table.insert(history, str) end
    return str
end

while running do shell.run(readCommand()) end