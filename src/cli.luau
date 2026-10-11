--!strict
--!native
--[[
@add-vanilla-refs/cli: addVanillaRefs's command line, over @add-vanilla-refs/commands.

  parse(argv, folder?) -> (command, nil) | (nil, message)
  render(result) -> text
  status(result) -> exit status
  run(argv, folder?) -> exit status

  add-vanilla-refs

addVanillaRefs has no arguments: every file it reads and writes is fixed in its source, and found
in the folder it is run in. So no arguments is the whole command line, and `parse` reads it into
the request `commands.run` takes: addVanillaRefs's own files in the current folder. `folder`
stands in for the current folder, for a caller that isn't run from where the files are.
addVanillaRefs doesn't look at arguments it is given, and runs whatever they are; this reads `-h`
and `--help` as a call for the usage, and refuses anything else, so that a mistaken argument
doesn't rewrite a plugin.

`render` is a result as the text addVanillaRefs prints: its log, each line ended. The Starwind
build keeps that as decoupleLog.txt. Of a run that found files missing, it is one line saying
which. `status` is the exit status of that outcome. `run` does the three in turn, and writes the
text to standard output when the status is 0, and to standard error when it isn't.

Exit statuses: 0 when the plugin was written; 8 when the command line can't be used (any
argument but `-h` or `--help`); 9 when the run failed (a file that isn't there, or isn't a
plugin), where addVanillaRefs exits 1. Messages go to standard error as
`add-vanilla-refs: <message>`.
]]

local commands = require '@add-vanilla-refs/commands'
local process = require '@dream/process'

export type Command = {
  action: 'run' | 'help',
  --- What `commands.run` is to be called with, when the action is `run`.
  request: commands.RunRequest?,
}

local Exit = table.freeze { ok = 0, invalidInput = 8, runtime = 9 }

local Usage = [[
add-vanilla-refs: motherJungle's addVanillaRefs for Jess, under the package's hyphenated name

Makes Starwind.esp stand without its Bethesda masters: it copies in every record of theirs the
plugin needs, rebuilds its dialogue as OpenMW would see it and keeps what an actor of the plugin's
can still say, and drops the masters from its header.

Usage: add-vanilla-refs

It takes no arguments, as addVanillaRefs takes none. Every file is fixed, in the current folder:

  reads   Starwind.esp, and Bloodmoon.esm, Tribunal.esm, and Morrowind.esm, a record being
          looked up in the masters in that order
  writes  Starwind.esp, over the one it read, with no backup
  prints  what it copied and what asked for it, the actors dialogue was kept for, and the
          dialogue audit: the log the Starwind build keeps as decoupleLog.txt

  -h, --help  Print this. addVanillaRefs has no help, and runs whatever arguments it is given;
              any other argument is refused here.

addVanillaRefs prints the references it finds in a cell in hash-map order, differently each run.
This prints them in the cell's order, every run; the rest of what it prints, and the plugin it
writes, are addVanillaRefs's.

Exit status: 0 done; 8 the command line can't be used; 9 the run failed (addVanillaRefs exits 1).]]

local function err(text: string) process.write('stderr', `{text}\n`) end

local function usage(message: string): number
  err(`add-vanilla-refs: {message}`)
  return Exit.invalidInput
end

local function parse(argv: { string }, folder: string?): (Command?, string?)
  local first = argv[1]

  if not first then
    local request: commands.RunRequest = { folder = folder or jess.fs.cwd() }
    return { action = 'run' :: 'run', request = request }, nil
  end

  if first ~= '-h' and first ~= '--help' then
    return nil, `unexpected argument '{first}' found: add-vanilla-refs takes none`
  end

  if argv[2] then return nil, `unexpected argument '{argv[2]}' found: help takes none` end

  return { action = 'help' :: 'help' }, nil
end

local function render(result: commands.RunResult): string
  if #result.missing > 0 then
    local files = table.concat(result.missing, ', ')
    return `add-vanilla-refs: these files aren't there: {files}\n`
  end

  if #result.log == 0 then return '' end

  return table.concat(result.log, '\n') .. '\n'
end

local function status(result: commands.RunResult): number
  return if #result.missing > 0 then Exit.runtime else Exit.ok
end

--- Says why the run stopped: the error's message, without the script position `error` puts in
--- front of one that isn't the command's own.
local function failed(caught: unknown): number
  err(`add-vanilla-refs: {(string.gsub(tostring(caught), '^[^\n]-:%d+: ', ''))}`)
  return Exit.runtime
end

local function run(argv: { string }, folder: string?): number
  local command, message = parse(argv, folder)

  if not command then return usage(message :: string) end

  if command.action == 'help' then
    process.write('stdout', `{Usage}\n`)
    return Exit.ok
  end

  -- `run` raises for a file that can't be read as a plugin, or written.
  local ran, result = pcall(commands.run, command.request :: commands.RunRequest)

  if not ran then return failed(result) end

  local code = status(result)
  process.write(if code == Exit.ok then 'stdout' else 'stderr', render(result))
  return code
end

return table.freeze { Exit = Exit, parse = parse, render = render, status = status, run = run }
