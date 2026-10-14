--!strict
--!native
-- `run`'s log, line by line on known inputs (build_starwind.py's validators read it), the names
-- `options.names` gives the masters in it, and its record list: a new one, which `@tes3conv`
-- writes as a plugin.
local addVanillaRefs = require '@add-vanilla-refs'
local tes3conv = require '@tes3conv'
local test = require '@jess/test'
local expect = test.expect
local suite = test.new()

type Record = { [string | number]: any }

local Names = { names = { 'Bloodmoon.esm', 'Tribunal.esm', 'Morrowind.esm' } }

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

local function typed(kind: string, id: string, fields: Record?): Record
  local record: Record = { type = kind, flags = '', id = id }

  for key, value in fields or {} do
    record[key] = value
  end

  return record
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

local function cell(name: string, references: { Record }): Record
  return {
    type = 'Cell',
    flags = '',
    name = name,
    data = { flags = 'IS_INTERIOR', grid = { 0, 0 } },
    references = references,
  }
end

local function reference(index: number, id: string, fields: Record?): Record
  local value: Record = {
    mastIndex = 0,
    refrIndex = index,
    id = id,
    temporary = true,
    translation = { 0, 0, 0 },
    rotation = { 0, 0, 0 },
  }

  for key, item in fields or {} do
    value[key] = item
  end

  return value
end

--- The log's lines that start with `prefix`, in order.
local function lines(log: { string }, prefix: string): { string }
  return [for line in log if string.sub(line, 1, #prefix) == prefix => line]
end

--- Each import the log reports: the field that asked for it, by the id it copied.
local function imports(log: { string }): { [string]: string }
  local fields = {}

  for index, line in log do
    local id = string.match(line, '^  target=%S+ \'(.*)\'$')

    if id then fields[id] = string.match(log[index + 2], '^  field=(.*)$') :: string end
  end

  return fields
end

local Quiet = {
  'Dialogue liveness population begin',
  'Dialogue liveness population end',
  'Dialogue INFO audit: effective=0, starwind_owned=0, retained_vanilla=0, pruned_vanilla=0',
}

suite.describe('log', function()
  suite.it('says only that it found no actors or dialogue when nothing is needed', function()
    local result, log = addVanillaRefs.run({ header(), misc 'root' }, { { header() } }, Names)
    expect(#result).toBe(2)
    expect(log).toEqual(Quiet)
  end)

  suite.it('names the master a record was copied from, and what asked for it', function()
    local _, log = addVanillaRefs.run(
      { header(), misc('root', 'first_dependency') },
      { { header() }, { header(), misc 'first_dependency' } },
      Names
    )

    expect(log).toEqual {
      'Copying \'first_dependency\' (MISC) to \'Starwind.esp\' from \'Tribunal.esm\'',
      'Dependency import:',
      '  pass=pre-dialogue',
      '  target=MISC \'first_dependency\'',
      '  source=MISC \'root\'',
      '  field=dependency',
      Quiet[1],
      Quiet[2],
      Quiet[3],
    }
  end)

  suite.it('calls a master it has no name for "master"', function()
    local plugin = { header(), misc('root', 'first_dependency') }
    local bases = { { header() }, { header(), misc 'first_dependency' } }
    local _, unnamed = addVanillaRefs.run(plugin, bases)
    expect(lines(unnamed, 'Copying')).toEqual {
      'Copying \'first_dependency\' (MISC) to \'Starwind.esp\' from \'master\'',
    }

    local _, short = addVanillaRefs.run(plugin, bases, { names = { 'Bloodmoon.esm' } })
    expect(lines(short, 'Copying')).toEqual(lines(unnamed, 'Copying'))
  end)

  suite.it('logs a foundation under the master it came from, without a copy line', function()
    local setting = typed('GameSetting', 'sName', { value = { type = 'String', data = 'Name' } })
    local result, log = addVanillaRefs.run(
      { header() },
      { { header() }, { header(), setting } },
      Names
    )
    expect(result[2]).toBe(setting)
    expect(log).toEqual {
      'Dependency import:',
      '  pass=pre-dialogue',
      '  target=GMST \'sName\'',
      '  source=FOUNDATION \'Tribunal.esm\'',
      '  field=foundation',
      Quiet[1],
      Quiet[2],
      Quiet[3],
    }
  end)

  suite.it('names the field of an actor that asked for each record', function()
    local actor = typed('Npc', 'root', {
      script = 'a_script',
      inventory = { { 1, 'b_item' } },
      spells = { 'c_spell' },
      aiPackages = { { type = 'Activate', target = 'D_Target' } },
      race = 'e_race',
      class = 'f_class',
      faction = 'g_faction',
      head = 'h_head',
      hair = 'i_hair',
    })

    local _, log = addVanillaRefs.run({ header(), actor }, {
      {
        header(),
        typed('Script', 'a_script', { text = '' }),
        misc 'b_item',
        typed('Spell', 'c_spell'),
        typed('Activator', 'd_target'),
        typed('Race', 'e_race'),
        typed('Class', 'f_class'),
        typed('Faction', 'g_faction', { reactions = {} }),
        typed('Bodypart', 'h_head'),
        typed('Bodypart', 'i_hair'),
      },
    }, Names)

    expect(imports(log)).toEqual {
      a_script = 'script',
      b_item = 'inventory',
      c_spell = 'spells',
      d_target = 'ai_package.target',
      e_race = 'race',
      f_class = 'class',
      g_faction = 'faction',
      h_head = 'head',
      i_hair = 'hair',
    }

    expect(table.find(log, 'd_target added as an activation target') ~= nil).toBe(true)
    expect(#lines(log, '  source=NPC_ \'root\'')).toBe(9)
    expect(#lines(log, '  pass=pre-dialogue')).toBe(9)
  end)

  suite.it('logs a cell\'s references and their owners, and copies what they name', function()
    local hall = cell('Hall', {
      reference(1, 'Chair', { owner = 'Owner_Npc' }),
      reference(2, 'Chest', { ownerFaction = 'Guild', key = 'chest_key', trap = 'chest_trap' }),
    })

    local result, log = addVanillaRefs.run({ header(), hall }, {
      {
        header(),
        misc 'chair',
        misc 'chest',
        misc 'chest_key',
        typed('Spell', 'chest_trap'),
        typed('Npc', 'owner_npc'),
        typed('Faction', 'guild', { reactions = {} }),
      },
    }, Names)

    expect(#result).toBe(8)
    expect(imports(log)).toEqual {
      chair = 'reference.id',
      chest = 'reference.id',
      chest_key = 'reference.key',
      chest_trap = 'reference.trap',
      owner_npc = 'reference.owner',
      guild = 'reference.owner_faction',
    }

    for _, line in
      {
        'Chair added to Starwind.esp as a cell reference in Hall',
        'owner_npc added to Starwind.esp as an owner reference',
        'Chest added to Starwind.esp as a cell reference in Hall',
        'guild added to Starwind.esp as an owner reference',
      }
    do
      expect(table.find(log, line) ~= nil).toBe(true)
    end

    expect(#lines(log, '  source=CELL \'Hall\'')).toBe(6)
  end)

  suite.it('names the first of a cell\'s references to name a record, and its id first', function()
    local hall = cell('Hall', {
      reference(1, 'Lamp', { owner = 'Shared', key = 'LAMP' }),
      reference(2, 'Shared', { ownerGlobal = 'A_Global', soul = 'a_soul' }),
      reference(3, 'Crate', { ownerFaction = 'A_Soul', trap = 'a_global' }),
    })
    hall.region = 'Hall_Region'
    local yard = cell('Yard', { reference(1, 'Yard_Thing', { soul = 'Hall_Region' }) })
    yard.region = 'yard_thing'

    local _, log = addVanillaRefs.run({ header(), hall, yard }, {
      {
        header(),
        misc 'lamp',
        misc 'shared',
        misc 'crate',
        misc 'yard_thing',
        typed('GlobalVariable', 'a_global'),
        typed('Creature', 'a_soul'),
        typed('Region', 'hall_region'),
      },
    }, Names)

    expect(imports(log)).toEqual {
      lamp = 'reference.id',
      shared = 'reference.owner',
      crate = 'reference.id',
      a_global = 'reference.owner_global',
      a_soul = 'reference.soul',
      hall_region = 'region',
      yard_thing = 'reference.id',
    }

    expect(#lines(log, '  source=CELL \'Hall\'')).toBe(6)
    expect(#lines(log, '  source=CELL \'Yard\'')).toBe(1)
  end)

  suite.it('prints what a record names in both passes, a copied and a mended one\'s too', function()
    local pilot = typed('Npc', 'Pilot', {
      aiPackages = {
        { type = 'Activate', target = 'Lever' },
        { type = 'Escort', target = 'Guide', cell = 'nowhere' },
      },
    })

    local hall = cell('Hall', { reference(1, 'Crate', { owner = 'Pilot' }), reference(2, 'Lever') })
    local guide = typed('Npc', 'guide', { aiPackages = { { type = 'Activate', target = 'Crate' } } })
    local result, log = addVanillaRefs.run(
      { header(), pilot, hall },
      { { header(), typed('Activator', 'lever'), guide, misc 'crate' } },
      Names
    )

    -- The escort's cell isn't defined, so the second pass asks a copy of the pilot.
    expect(result[2] ~= pilot).toBe(true)
    expect(result[2].aiPackages[2].cell).toBe 'igtestcell'
    expect(log).toEqual {
      'lever added as an activation target',
      'Crate added to Starwind.esp as a cell reference in Hall',
      'pilot added to Starwind.esp as an owner reference',
      'Lever added to Starwind.esp as a cell reference in Hall',
      'Copying \'crate\' (MISC) to \'Starwind.esp\' from \'Bloodmoon.esm\'',
      'Dependency import:',
      '  pass=pre-dialogue',
      '  target=MISC \'crate\'',
      '  source=CELL \'Hall\'',
      '  field=reference.id',
      'Copying \'guide\' (NPC_) to \'Starwind.esp\' from \'Bloodmoon.esm\'',
      'Dependency import:',
      '  pass=pre-dialogue',
      '  target=NPC_ \'guide\'',
      '  source=NPC_ \'Pilot\'',
      '  field=ai_package.target',
      'crate added as an activation target',
      'Copying \'lever\' (ACTI) to \'Starwind.esp\' from \'Bloodmoon.esm\'',
      'Dependency import:',
      '  pass=pre-dialogue',
      '  target=ACTI \'lever\'',
      '  source=NPC_ \'Pilot\'',
      '  field=ai_package.target',
      Quiet[1],
      'Dialogue liveness actor\tNpc\tPilot\t\t\tmale',
      'Dialogue liveness actor\tNpc\tguide\t\t\tmale',
      Quiet[2],
      Quiet[3],
      'lever added as an activation target',
      'Crate added to Starwind.esp as a cell reference in Hall',
      'pilot added to Starwind.esp as an owner reference',
      'Lever added to Starwind.esp as a cell reference in Hall',
      'crate added as an activation target',
    }
  end)

  suite.it('lists the actors dialogue is kept by, the ones it copied among them', function()
    local ghost = typed('Npc', 'Ghost', { race = 'Dunmer', class = 'Mage' })
    ghost.flags = 'DELETED'
    local pilot = typed('Npc', 'Pilot', {
      race = 'Human',
      class = 'Scout',
      aiPackages = { { type = 'Follow', target = 'vanilla_guide', cell = '' } },
    })

    local _, log = addVanillaRefs.run(
      {
        header(),
        typed('Npc', 'Guard', { race = 'Nord', class = 'Warrior', npcFlags = 'FEMALE | AUTOCALC' }),
        pilot,
        typed('Creature', 'Rat'),
        ghost,
      },
      { { header(), typed('Npc', 'vanilla_guide', { race = 'Imperial', class = 'Guide' }) } },
      Names
    )

    expect(lines(log, 'Dialogue liveness')).toEqual {
      'Dialogue liveness population begin',
      'Dialogue liveness actor\tNpc\tGuard\tNord\tWarrior\tfemale',
      'Dialogue liveness actor\tNpc\tPilot\tHuman\tScout\tmale',
      'Dialogue liveness actor\tCreature\tRat\t\t\t',
      'Dialogue liveness actor\tNpc\tvanilla_guide\tImperial\tGuide\tmale',
      'Dialogue liveness population end',
    }
  end)

  suite.it('counts the INFOs it kept and pruned, and why it kept the masters\'', function()
    local speaker = typed('Npc', 'speaker', { race = 'Nord', class = 'Warrior' })
    local _, log = addVanillaRefs.run({ header(), speaker, dial 'Topic', info 'StarwindInfo' }, {
      {
        header(),
        dial 'Topic',
        info('Match', '', '', { speakerRace = 'Nord', speakerClass = 'Warrior' }),
        info('Other', 'Match', '', { speakerRace = 'Dunmer' }),
      },
    }, Names)

    expect(lines(log, 'Dialogue INFO')).toEqual {
      'Dialogue INFO audit: effective=3, starwind_owned=1, retained_vanilla=1, pruned_vanilla=1',
      'Dialogue INFO keep reason: VANILLA_DIALOGUE_TOPIC=1',
      'Dialogue INFO keep reason: VANILLA_MATCHING_CLASS=1',
      'Dialogue INFO keep reason: VANILLA_MATCHING_RACE=1',
    }

    expect(lines(log, 'Dialogue DIAL')).toEqual {}
  end)

  suite.it('reports each vanilla topic it materialized, in topic order, and why', function()
    local script = typed('Script', 'starwind_script', { text = 'AddTopic "VanillaTopic"' })
    local result, log = addVanillaRefs.run({ header(), script }, {
      {
        header(),
        dial 'VanillaTopic',
        info('VanillaInfo', '', ''),
        dial('Hello', 'Greeting'),
        info('HelloInfo', '', ''),
        dial 'Unused',
        info('UnusedInfo', '', ''),
      },
    }, Names)

    expect(#result).toBe(6)
    expect(lines(log, 'Dialogue INFO')).toEqual {
      'Dialogue INFO audit: effective=3, starwind_owned=0, retained_vanilla=2, pruned_vanilla=1',
      'Dialogue INFO keep reason: VANILLA_ENGINE_TOPIC_GENERIC=1',
      'Dialogue INFO keep reason: VANILLA_SCRIPT_TOPIC=1',
    }

    expect(lines(log, 'Dialogue DIAL')).toEqual {
      'Dialogue DIAL materialized: topic="hello" source=vanilla live_infos=1 topic_reason=["EngineTopic"]',
      'Dialogue DIAL materialized: topic="vanillatopic" source=vanilla live_infos=1 topic_reason=["ScriptTopic"]',
    }
  end)

  suite.it('logs what kept dialogue needs under the second pass', function()
    local _, log = addVanillaRefs.run(
      { header(), dial 'Topic', info('Info', '', '', { speakerId = 'Vanilla_Speaker' }) },
      { { header(), misc 'vanilla_speaker' } },
      Names
    )

    expect(lines(log, 'Info imported')).toEqual {
      'Info imported as a line spoken by vanilla_speaker',
    }

    expect(lines(log, '  ')).toEqual {
      '  pass=post-dialogue',
      '  target=MISC \'vanilla_speaker\'',
      '  source=INFO \'Info\'',
      '  field=speaker_id',
    }
  end)
end)

suite.describe('records', function()
  suite.it('returns a new list, and leaves the ones it was given as they were', function()
    local actor = typed('Npc', 'root', {
      aiPackages = { { type = 'Escort', target = 'escort_target', cell = '' } },
    })

    local plugin = {
      header { { 'Morrowind.esm', 79837557 } },
      actor,
      dial 'Topic',
      info('S1', 'V1', ''),
    }
    local base = { header(), misc 'escort_target', dial 'Topic', info('V1', '', '') }
    local result = addVanillaRefs.run(plugin, { base }, Names)

    expect(result ~= plugin).toBe(true)
    expect(#plugin).toBe(4)
    expect(#base).toBe(4)
    expect(plugin[1].masters).toEqual { { 'Morrowind.esm', 79837557 } }
    expect(plugin[2]).toBe(actor)
    expect(actor.aiPackages[1].cell).toBe ''
    expect(plugin[4].prevId).toBe 'V1'
    expect(base[4].nextId).toBe ''

    local kept = {}

    for _, record in result do
      if record.type ~= 'Header' then
        table.insert(kept, `{record.type}:{record.id}<{record.prevId or ''}|{record.nextId or ''}>`)
      end
    end

    -- What it copies goes after everything the plugin had.
    expect(kept).toEqual {
      'Npc:root<|>',
      'Dialogue:Topic<|>',
      'DialogueInfo:V1<|S1>',
      'DialogueInfo:S1<V1|>',
      'MiscItem:escort_target<|>',
    }

    expect(result[2].aiPackages[1].cell).toBe 'igtestcell'
    expect(result[6]).toBe(base[2])
  end)

  suite.it('gives records tes3conv writes as a plugin without masters', function()
    local rock = typed('Static', 'vanilla_rock', { mesh = 'rock.nif' })
    local plugin = {
      header { { 'Morrowind.esm', 79837557 } },
      cell('Hall', { reference(1, 'vanilla_rock') }),
    }
    local result = addVanillaRefs.run(plugin, { { header(), rock } }, Names)
    expect(#result).toBe(3)

    -- The copy follows the cell that needed it; tes3conv reads a plugin back in its own order.
    local written = tes3conv.plugin(result)
    expect(written:count()).toBe(3)
    local back: { Record } = tes3conv.records(written)
    expect(back[1].masters).toEqual {}
    expect(back[2]).toEqual(rock)
    expect(back[3].name).toBe 'Hall'
    expect(back[3].references[1].id).toBe 'vanilla_rock'
    local sorted = tes3conv.plugin(tes3conv.sort(result))
    expect(buffer.tostring(tes3conv.plugin(back):save()) == buffer.tostring(sorted:save())).toBe(
      true
    )
  end)
end)

return suite
