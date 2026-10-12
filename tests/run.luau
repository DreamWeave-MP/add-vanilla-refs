--!strict
--!native
-- The addVanillaRefs port's semantics, on records small enough to read: addVanillaRefs's Rust
-- tests, case for case.
local addVanillaRefs = require '@add-vanilla-refs'
local test = require '@jess/test'
local expect = test.expect
local suite = test.new()

type Record = { [string | number]: any }

local function header(masters: { { string | number } }?): Record
  return {
    type = 'Header',
    flags = '',
    version = 1.3,
    fileType = 'Esp',
    author = '',
    description = '',
    numObjects = 0,
    masters = masters or {},
  }
end

local function misc(id: string, script: string?): Record
  return {
    type = 'MiscItem',
    flags = '',
    id = id,
    name = id,
    script = script or '',
    mesh = '',
    icon = '',
  }
end

local function dial(id: string, kind: string?): Record
  return { type = 'Dialogue', flags = '', id = id, dialogueType = kind or 'Topic' }
end

local function info(id: string, prev: string?, next: string?, fields: Record?): Record
  local record: Record = {
    type = 'DialogueInfo',
    flags = '',
    id = id,
    prevId = prev or '',
    nextId = next or '',
    speakerId = '',
    speakerRace = '',
    speakerClass = '',
    speakerFaction = '',
    speakerCell = '',
    playerFaction = '',
    soundPath = '',
    text = '',
    scriptText = '',
    filters = {},
    data = {
      dialogueType = 'Topic',
      disposition = 0,
      speakerRank = -1,
      speakerSex = 'Any',
      playerRank = -1,
    },
  }

  for key, value in fields or {} do
    record[key] = value
  end

  return record
end

local function ids(records: { Record }): { string }
  return [
    for record in records
    if record.type ~= 'Header'
    => `{record.type}:{record.id or record.name or record.effectId}`
  ]
end

local function has(records: { Record }, id: string): boolean
  return any[
    for record in records
    => type(record.id) == 'string' and string.lower(record.id) == string.lower(id)
  ]
end

local function chain(records: { Record }): { string }
  return [
    for {type: kind, id, prevId, nextId} in records
    if kind == 'DialogueInfo'
    => `{id}<{prevId}|{nextId}>`
  ]
end

suite.describe('add-vanilla-refs', function()
  local options = { names = { 'Bloodmoon.esm', 'Tribunal.esm', 'Morrowind.esm' } }

  local function run(plugin: { Record }, bases: { { Record } }): ({ Record }, { string })
    return addVanillaRefs.run(plugin, bases, options)
  end

  suite.it('resolves imported records transitively', function()
    local result = run({ header(), misc('root', 'first_dependency') }, {
      { header(), misc('first_dependency', 'second_dependency') },
      { header(), misc('second_dependency', 'third_dependency') },
      { header(), misc 'third_dependency' },
    })
    expect(
      has(result, 'first_dependency')
        and has(result, 'second_dependency')
        and has(result, 'third_dependency')
    ).toBe(true)
  end)

  suite.it('defers dialogue dependencies to the second closure', function()
    local result, log = run(
      { header(), dial 'Topic', info('Info', '', '', { speakerId = 'vanilla_speaker' }) },
      {
        { header(), misc 'vanilla_speaker' },
      }
    )
    expect(has(result, 'vanilla_speaker')).toBe(true)
    local passes = {}

    for index, line in log do
      if line == '  target=MISC \'vanilla_speaker\'' then table.insert(passes, log[index - 1]) end
    end

    expect(passes).toEqual { '  pass=post-dialogue' }
  end)

  suite.it('doesn\'t follow or keep deleted records', function()
    local deleted = misc('deleted_record', 'unwanted_dependency')
    deleted.flags = 'DELETED'
    local result = run({ header(), deleted }, { { header(), misc 'unwanted_dependency' } })
    expect(ids(result)).toEqual {}
  end)

  suite.it('removes exact duplicate magic effects', function()
    local effect =
      { type = 'MagicEffect', flags = '', effectId = 'WaterBreathing', description = '' }
    local result = run({ header(), effect, table.clone(effect) }, {})
    expect(ids(result)).toEqual { 'MagicEffect:WaterBreathing' }
  end)

  suite.it('keeps Bloodmoon precedence', function()
    local result = run({ header(), misc('root', 'shared_dependency') }, {
      { header(), misc('shared_dependency', 'bloodmoon_leaf'), misc 'bloodmoon_leaf' },
      { header(), misc('shared_dependency', 'tribunal_leaf') },
    })
    expect(has(result, 'bloodmoon_leaf')).toBe(true)
    expect(has(result, 'tribunal_leaf')).toBe(false)
  end)

  suite.it('imports the masters\' foundations and what they need', function()
    local result = run({ header(), misc 'WaterBreathing' }, {
      {
        header(),
        { type = 'Race', flags = '', id = 'vanilla_race', spells = { 'vanilla_spell' } },
        { type = 'Spell', flags = '', id = 'vanilla_spell' },
        {
          type = 'MagicEffect',
          flags = '',
          effectId = 'WaterBreathing',
          castVisual = 'vanilla_cast_visual',
        },
        { type = 'Static', flags = '', id = 'vanilla_cast_visual' },
      },
    })
    expect(
      has(result, 'vanilla_race')
        and has(result, 'vanilla_spell')
        and has(result, 'vanilla_cast_visual')
    ).toBe(true)
  end)

  suite.it('follows escort and follow targets, and sends undefined cells to igtestcell', function()
    local actor = {
      type = 'Npc',
      flags = '',
      id = 'root',
      aiPackages = {
        { type = 'Escort', target = 'escort_target', cell = '' },
        { type = 'Follow', target = 'follow_target', cell = 'root' },
      },
    }
    local result = run(
      { header(), actor },
      { { header(), misc 'escort_target', misc 'follow_target' } }
    )
    expect(has(result, 'escort_target') and has(result, 'follow_target')).toBe(true)
    expect(result[2].aiPackages[1].cell).toBe 'igtestcell'
    expect(result[2].aiPackages[2].cell).toBe 'root'
  end)

  suite.it('doesn\'t treat sound paths or filter operands as dependencies', function()
    local line = info('Info', '', '', {
      soundPath = 'sound/dialogue.wav',
      filters = { { id = 'filter_operand', filterType = 'Global' } },
    })
    local result = run(
      { header(), dial 'Topic', line },
      { { header(), misc 'filter_operand', misc 'sound/dialogue.wav' } }
    )
    expect(has(result, 'filter_operand') or has(result, 'sound/dialogue.wav')).toBe(false)
  end)

  suite.it('relinks dialogue around removed vanilla INFOs', function()
    local usable = info('V2', 'V1', 'V3', { speakerCell = 'MissingCell' })
    local bases = {
      {
        header(),
        dial 'Topic',
        info('V1', '', 'V2', { speakerId = 'missing_actor' }),
        usable,
        info('V3', 'V2', '', { speakerId = 'missing_actor' }),
      },
    }
    local first =
      info('S1', '', 'V1', { speakerCell = 'VanillaCell', filters = { { id = 'filter_operand' } } })
    local result =
      run({ header(), dial 'Topic', first, info('S2', 'V2', 'V3'), info('S3', 'V3', '') }, bases)
    expect(chain(result)).toEqual { 'S1<|V2>', 'V2<S1|S2>', 'S2<V2|S3>', 'S3<S2|>' }
  end)

  suite.it(
    'materializes a live vanilla-only topic, and not one only dialogue text names',
    function()
      local script =
        { type = 'Script', flags = '', id = 'starwind_script', text = 'AddTopic "VanillaTopic"' }
      local result = run({ header(), script }, {
        {
          header(),
          dial 'VanillaTopic',
          info('VanillaInfo', '', ''),
          dial 'Ship',
          info('ShipInfo', '', ''),
        },
      })
      expect(has(result, 'VanillaTopic') and has(result, 'VanillaInfo')).toBe(true)
      expect(has(result, 'Ship') or has(result, 'ShipInfo')).toBe(false)

      local priced = info('PriceInfo', '', '', { text = 'VanillaB' })
      local mine = info('StarwindInfo', '', '', { text = 'price on your head; VanillaB' })
      result = run({ header(), dial 'StarwindTopic', mine }, {
        {
          header(),
          dial 'Price on Your Head',
          priced,
          dial 'VanillaB',
          info('VanillaBInfo', '', ''),
        },
      })
      expect(has(result, 'Price on Your Head') or has(result, 'VanillaB')).toBe(false)
    end
  )

  suite.it('reads a script\'s AddTopic lines however they are cased, indented, and ended', function()
    local lines = {
      'begin starwind_script',
      '; AddTopic "Commented"',
      '  addtopic "Quoted Topic"\r',
      '\tADDTOPIC Bare more',
      'AddTopicJoined "Joined"',
      'set done to 1 ; AddTopic "Trailing"',
      'end',
    }

    local script =
      { type = 'Script', flags = '', id = 'starwind_script', text = table.concat(lines, '\n') }
    local result = run({ header(), script }, {
      {
        header(),
        dial 'Commented',
        info 'CommentedInfo',
        dial 'quoted topic',
        info 'QuotedInfo',
        dial 'BARE',
        info 'BareInfo',
        dial 'Joined',
        info 'JoinedInfo',
        dial 'Trailing',
        info 'TrailingInfo',
      },
    })
    expect(has(result, 'QuotedInfo') and has(result, 'BareInfo')).toBe(true)
    expect(has(result, 'quoted topic') and has(result, 'BARE')).toBe(true)
    expect(
      has(result, 'CommentedInfo') or has(result, 'JoinedInfo') or has(result, 'TrailingInfo')
    ).toBe(false)
  end)

  suite.it('resolves what materialized dialogue needs in the second pass', function()
    local result = run({ header() }, {
      {
        header(),
        dial('Topic', 'Voice'),
        info('VanillaInfo', '', '', { speakerFaction = 'Morag Tong' }),
        { type = 'Faction', flags = '', id = 'Morag Tong', reactions = {} },
      },
    })
    expect(has(result, 'VanillaInfo') and has(result, 'Morag Tong')).toBe(true)
  end)

  suite.it('keeps vanilla INFOs a plugin actor could say, and prunes the rest', function()
    local speaker = { type = 'Npc', flags = '', id = 'speaker', race = 'Nord', class = 'Warrior' }
    local function vanilla(fields: Record): { { Record } }
      return { { header(), dial 'Topic', info('VanillaInfo', '', '', fields) } }
    end

    local matching = run(
      { header(), speaker, dial 'Topic', info 'StarwindInfo' },
      vanilla {
        speakerRace = 'Nord',
        speakerClass = 'Warrior',
      }
    )
    expect(has(matching, 'VanillaInfo')).toBe(true)

    local other = run(
      { header(), speaker, dial 'Topic', info 'StarwindInfo' },
      vanilla {
        speakerRace = 'Dunmer',
        speakerClass = 'Warrior',
      }
    )
    expect(has(other, 'VanillaInfo')).toBe(false)

    local impossible = run(
      { header(), dial 'Topic', info 'StarwindInfo' },
      vanilla {
        speakerId = 'missing_speaker',
        speakerFaction = 'some_faction',
      }
    )
    expect(has(impossible, 'VanillaInfo')).toBe(false)
  end)

  suite.it('orders INFOs as OpenMW does, ids matched case-insensitively', function()
    local bases = { { header(), dial 'Topic', info('First', '', ''), info('Third', 'First', '') } }
    local result = run({ header(), dial 'Topic', info('second', 'first', '') }, bases)
    expect(chain(result)).toEqual { 'First<|second>', 'second<First|Third>', 'Third<second|>' }

    local moved = run({ header(), dial 'Topic', info('First', 'First', '') }, {
      { header(), dial 'Topic', info('First', '', ''), info('Second', 'First', '') },
    })
    expect(chain(moved)).toEqual { 'First<|Second>', 'Second<First|>' }
  end)

  suite.it('keeps empty shells, drops tombstones, and writes a topic once', function()
    local shells = run({ header(), dial 'DeadTopic', dial 'LiveTopic', info('LiveInfo', '', '') }, {
      { header(), dial 'DeadTopic' },
    })

    expect(ids(shells)).toEqual {
      'Dialogue:DeadTopic',
      'Dialogue:LiveTopic',
      'DialogueInfo:LiveInfo',
    }

    local tombstone = info('VanillaInfo', '', '')
    tombstone.flags = 'DELETED'
    local suppressed = run(
      { header(), dial 'Topic', tombstone },
      { { header(), dial 'Topic', info 'VanillaInfo' } }
    )
    expect(ids(suppressed)).toEqual { 'Dialogue:Topic' }

    local twice = run({ header(), dial 'Topic', info('Info', '', ''), dial 'Topic' }, {})
    expect(ids(twice)).toEqual { 'Dialogue:Topic', 'DialogueInfo:Info' }
  end)

  suite.it('drops the masters', function()
    local result = run({ header { { 'Morrowind.esm', 79837557 } } }, {})
    expect(#result[1].masters).toBe(0)
    expect(result[1].version).toBe(1.3)
  end)
end)

return suite
