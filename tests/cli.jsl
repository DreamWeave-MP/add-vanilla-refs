--!strict
--!native
-- `@add-vanilla-refs/cli`: the one argument list it reads into `commands.run`'s request and the
-- ones it refuses, the text it makes of a result built here by hand, the exit status of each
-- outcome, and whole runs on plugin files in the scratch root. A run's log goes to the suite's
-- own standard output, and its messages to its standard error.
local bytes = require '@dream/bytes'
local cli = require '@add-vanilla-refs/cli'
local commands = require '@add-vanilla-refs/commands'
local support = require './support'
local test = require '@jess/test'

local expect = test.expect
local suite = test.new()

-- Each argument list `parse` refuses, and what it says of it.
local Refused: { { argv: { string }, message: string } } = {
  {
    argv = { 'Starwind.esp' },
    message = 'unexpected argument \'Starwind.esp\' found: add-vanilla-refs takes none',
  },
  {
    argv = { '--version' },
    message = 'unexpected argument \'--version\' found: add-vanilla-refs takes none',
  },
  { argv = { '-V' }, message = 'unexpected argument \'-V\' found: add-vanilla-refs takes none' },
  {
    argv = { '--dry-run' },
    message = 'unexpected argument \'--dry-run\' found: add-vanilla-refs takes none',
  },
  { argv = { 'help' }, message = 'unexpected argument \'help\' found: add-vanilla-refs takes none' },
  { argv = { '--Help' }, message = 'unexpected argument \'--Help\' found: add-vanilla-refs takes none' },
  { argv = { '--' }, message = 'unexpected argument \'--\' found: add-vanilla-refs takes none' },
  { argv = { '' }, message = 'unexpected argument \'\' found: add-vanilla-refs takes none' },
  {
    argv = { 'Starwind.esp', '--help' },
    message = 'unexpected argument \'Starwind.esp\' found: add-vanilla-refs takes none',
  },
  { argv = { '--help', 'run' }, message = 'unexpected argument \'run\' found: help takes none' },
  { argv = { '-h', '-h' }, message = 'unexpected argument \'-h\' found: help takes none' },
}

--- A result as `commands.run` returns one, with `fields` over a run that was written.
local function result(fields: { [string]: unknown }?): commands.RunResult
  local built: { [string]: unknown } = {
    command = 'run',
    plugin = 'work/Starwind.esp',
    masters = {
      { name = 'Bloodmoon.esm', path = 'work/Bloodmoon.esm' },
      { name = 'Tribunal.esm', path = 'work/Tribunal.esm' },
      { name = 'Morrowind.esm', path = 'work/Morrowind.esm' },
    },
    output = 'work/Starwind.esp',
    dryRun = false,
    written = true,
    missing = {},
    log = { 'Dialogue liveness population begin', 'Dialogue liveness population end' },
    records = { plugin = 1, output = 1 },
  }

  for key, value in fields or {} do
    built[key] = value
  end

  return (built :: unknown) :: commands.RunResult
end

suite.describe('parse', function()
  suite.it('reads no arguments as the whole command: addVanillaRefs\'s files in the current folder', function()
    local command, message = cli.parse {}
    expect(command).toEqual { action = 'run', request = { folder = jess.fs.cwd() } }
    expect(message).toBeNil()
  end)

  suite.it('takes the folder it is given in place of the current one', function()
    expect(cli.parse({}, 'work')).toEqual { action = 'run', request = { folder = 'work' } }
  end)

  suite.it('reads help under each spelling', function()
    for _, spelling in { '-h', '--help' } do
      local command, message = cli.parse { spelling }
      expect(command).toEqual { action = 'help' }
      expect(message).toBeNil()
    end
  end)

  suite.it('refuses every other argument, and says which', function()
    for _, case in Refused do
      local command, message = cli.parse(case.argv)
      expect(command).toBeNil()
      expect(message).toBe(case.message)
    end
  end)
end)

suite.describe('render', function()
  suite.it('prints the log as addVanillaRefs prints it, each line ended', function()
    expect(cli.render(result())).toBe(
      'Dialogue liveness population begin\nDialogue liveness population end\n'
    )
  end)

  suite.it('keeps a line\'s tabs and quotes as they are', function()
    local log = {
      'Copying \'gold_001\' (MISC) to \'Starwind.esp\' from \'Morrowind.esm\'',
      'Dialogue liveness actor\tNpc\tsw_npc\tDark Elf\tGuard\tmale',
      'Dialogue DIAL materialized: topic="greeting 0" source=vanilla live_infos=1 topic_reason=["EngineTopic"]',
    }

    expect(cli.render(result { log = log })).toBe(table.concat(log, '\n') .. '\n')
  end)

  suite.it('prints the same of a dry run, and nothing of a log without lines', function()
    expect(cli.render(result { dryRun = true, written = false })).toBe(cli.render(result()))
    expect(cli.render(result { log = {} })).toBe ''
  end)

  suite.it('is what addVanillaRefs printed on the suite\'s four files, from its log', function()
    local golden = support.golden 'decoupleLog.txt'
    expect(cli.render(result { log = support.lines(golden) })).toBe(golden)
  end)

  suite.it('names the files that weren\'t there', function()
    local missing = result {
      written = false,
      log = {},
      missing = { 'work/Starwind.esp', 'work/Morrowind.esm' },
    }

    expect(cli.render(missing)).toBe(
      'add-vanilla-refs: these files aren\'t there: work/Starwind.esp, work/Morrowind.esm\n'
    )
  end)
end)

suite.describe('status', function()
  suite.it('is 0 for a run, written or dry, and 9 for one that found files missing', function()
    expect(cli.status(result())).toBe(0)
    expect(cli.status(result { dryRun = true, written = false })).toBe(0)
    expect(cli.status(result { written = false, missing = { 'work/Starwind.esp' } })).toBe(9)
  end)
end)

suite.describe('run', function()
  suite.it(
    'numbers its exit statuses as Jess\'s other commands do',
    function() expect(cli.Exit).toEqual { ok = 0, invalidInput = 8, runtime = 9 } end
  )

  suite.it('returns 0 for help', function()
    expect(cli.run { '--help' }).toBe(0)
    expect(cli.run { '-h' }).toBe(0)
  end)

  suite.it('returns 8 for every command line parse refuses, and touches no file', function()
    local folder = support.folder 'cli-refused'
    local paths = support.sources(folder)
    local before = support.bytes(paths['Starwind.esp'])

    for _, case in Refused do
      expect(cli.run(case.argv, folder)).toBe(8)
    end

    expect(support.bytes(paths['Starwind.esp']) == before).toBe(true)
  end)

  suite.it('writes Starwind.esp over itself in the folder it runs in, and returns 0', function()
    local folder = support.folder 'cli-run'
    local paths = support.sources(folder)
    local golden = support.golden 'Starwind.esp'

    expect(cli.run({}, folder)).toBe(0)

    local written = support.bytes(paths['Starwind.esp'])
    expect(#written).toBe(#golden)
    expect(bytes.sha256(written)).toBe(bytes.sha256(golden))
    expect(#jess.fs.list(folder)).toBe(4)
  end)

  suite.it('returns 9 in a folder without the files, and makes nothing there', function()
    local folder = support.folder 'cli-empty'
    expect(cli.run({}, folder)).toBe(9)
    expect(jess.fs.list(folder)).toEqual {}
  end)

  suite.it('returns 9 for a master that isn\'t a plugin, Starwind.esp as it was', function()
    local folder = support.folder 'cli-not-a-plugin'
    local paths = support.sources(folder)
    local before = support.bytes(paths['Starwind.esp'])
    jess.fs.write(paths['Bloodmoon.esm'], 'not a plugin at all', { backup = false })

    expect(cli.run({}, folder)).toBe(9)
    expect(support.bytes(paths['Starwind.esp']) == before).toBe(true)
  end)
end)

return suite
