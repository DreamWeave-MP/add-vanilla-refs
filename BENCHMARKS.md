# add-vanilla-refs benchmarks

`bench/bench.jsl` times the package through its public API: `run` over record lists, and
`commands.run` over plugin files. The lists are made by the bench, the same every run: a plugin
and its three masters in the order a record is looked up in them (Bloodmoon, Tribunal, Morrowind).
A master holds objects of 23 types under ids of two words and a number, each naming what its type
names (an NPC its race, class, head, hair, inventory, spells, and packages; a container what it
holds; a leveled list its entries), game settings, races, classes, and magic effects, and topics
with their chains of INFOs for a speaker, a race, a class, a faction, or anyone, every sixteenth
topic a greeting twelve times as long. The expansions have their own of some of Morrowind's items
(spelled in capitals) and change, move, add to, and delete from its topics. The plugin has objects
and NPCs of its own that name its own things and one in six of the masters', cells of references
(one in eight owned, some with a faction, a key, a trap, or a soul), topics of its own, INFOs put
into Morrowind's topics, and scripts of a few dozen lines, some of which add a topic.

- *the whole run* is all of that at once: 12,288 references in 48 cells, 13,484 records out of
  2,523 (4,884 of them INFOs), and a log of 74,284 lines.
- The others are a plugin of mostly one thing, to show each part of a run by itself: *objects
  alone* (4,407 records, no cells or dialogue, 11,587 out), *cells of 512 references* (64 of
  them, 32,768 references, a log of 98,386 lines), and *dialogue* (960 topics of Morrowind's,
  some 20,000 INFOs across the masters, 10,701 in what comes out).
- *commands.run, a dry run* writes a plugin of 506 records and masters of 5,364 (205 KB, and
  70 KB, 147 KB, and 623 KB) into the scratch folder once, and times the command over the files:
  each read through `@esm` and `@tes3conv` and put back in its file's order, the run, and the
  result written as a plugin in memory.

Each workload is warmed up, sized to a batch of about a tenth of a second, and reported as the
median of seven batches, with a full collection between them. Before the batches and after them
its whole result is hashed (every record and reference and every line of the log, a record's
fields in the order of their names) and has to come to the hash written in the bench, which is
the baseline's: a run that does less, or anything else, fails instead of posting a time.

```sh
jess run --package jpk/add-vanilla-refs --package-path jpk \
  --capability filesystem.read --capability filesystem.write \
  jpk/add-vanilla-refs/bench/bench.jsl [filter] [scratch folder]
```

Without a scratch folder the command isn't timed, and no capability is needed.

## The move onto l3i 2.0, base against head

- Machine: Intel Core i7-10870H @ 2.20 GHz, 16 threads, shared with other work while this ran.
- Date: 2026-10-12.
- Binary: the verified release build of Jess 0.1.0 on l3i 2.0.1 (Luau 0.742), the same one for
  both sides, with the same `@esm` and `@tes3conv` beside both.
- Base: `fa3b211`, the package before the move, with the bench as it is now. Head: `3237943`.
- Protocol: the whole bench run against base, then head, three times over, back to back under one
  lock; each cell is the median of its three runs. A difference under 5 percent is called no
  change.

| Workload | Base | Head | Base / head |
|---|---:|---:|---:|
| a plugin of 2523 records over masters of 22036: the whole run | 451.0 ms | 68.75 ms | 6.56x |
| a plugin of 4407 records over masters of 18799: objects alone | 101.6 ms | 45.50 ms | 2.23x |
| a plugin of 511 records over masters of 6424: cells of 512 references | 367.2 ms | 38.95 ms | 9.43x |
| a plugin of 1943 records over masters of 23565: dialogue | 63.63 ms | 39.17 ms | 1.62x |
| commands.run, a dry run: a plugin of 506 records over masters of 5364, as files | 103.1 ms | 47.01 ms | 2.19x |

None of it is the dialect, and none of it is the data plane: a run is strings and record tables,
with no numbers in bulk to hand to `@dream/data`. The comprehensions, `any` reducers, slice, and
record patterns the package now uses measured as no change, which is what they are meant to cost.
What moved the numbers was the work a run no longer does, found by profiling it:

| Change | Whole | Objects | Cells | Dialogue | Command |
|---|---:|---:|---:|---:|---:|
| `dc4b98e` which reference of a cell named each record it needs, from one walk of its references instead of a walk for each record | 3.23x | no change | 3.31x | no change | 1.75x |
| `90e6820` the lists of field names a record's ids are read by, made once instead of for each reference | no change | no change | 1.05x | no change | no change |
| `709159f` each spelling of an id lowered once a run | 1.14x | 1.09x | 1.20x | 1.16x | no change |
| `b68fe21` nothing pending for an id that is already defined, and only what is pending sorted | 1.28x | 1.33x | 1.37x | 1.09x | 1.08x |
| `f3449d5` the masters indexed, and their foundations found, once a run instead of in four walks | 1.09x | 1.13x | no change | 1.11x | no change |
| `d9fdf61` the second pass answered with what a record needed in the first | no change | no change | 1.15x | no change | no change |
| `4b6e92a` `tes3.isDeleted` asked only of a record with flags | 1.09x | 1.09x | 1.07x | 1.13x | no change |
| `a760eba` a script's lines read only when it says AddTopic somewhere | 1.15x | 1.29x | 1.10x | no change | 1.07x |
| `b4fa7b6` the first pass's lines added to the log one at a time, not by `table.move` | no change | no change | 1.21x | no change | no change |
| `3237943` a record named whenever it is first to need anything, so a cell with no data is refused as it was before `b68fe21` | no change | no change | no change | no change | no change |

Each cell there is the median of three runs of the bench against that commit over the median of
three against the commit before it (four for `d9fdf61` and `4b6e92a`), the two alternating with
their neighbours under one lock. A cell is good to about 5 percent and no better: `90e6820`'s is
at that edge, and a first pass at `d9fdf61` and `4b6e92a` had to be thrown away for a machine busy
enough to move a commit with no change in it by 15 percent. The first table is the measurement.
The dialect commits between them (`2e91d94`, `b1b2332`, `c5e92a7`) were in the same runs and
moved nothing; `c07e561` and `73242b7` touch only the suites and the bench.

The first row is most of it. `dependency_field` walked a cell's references from the top for every
record the cell needed, making a table of six pairs at each reference on the way: the square of
a cell's size, in allocations. The rest are a run's two passes asking the same questions twice.
What is left is mostly what a run has to make: a log line for every reference of every cell in
both passes, a node for every INFO of every master, and a copy of every INFO it keeps. Most
of the command's time is now `@esm` and `@tes3conv` reading the files and writing the result.

`table.move(lines, 1, #lines, #log + 1, log)` is the one surprise worth knowing outside this
package: Luau resizes the destination to exactly fit when a move runs past its end, so appending
a list to a long one that way copies the long one every time. Adding the lines one at a time is
the `b4fa7b6` row above.

## Which modules are native, and why

Jess compiles to machine code only what is marked (`--!native` on a module, `@native` on one
function), and every load pays for what is marked. A module carries `--!native` when a row below
spends its time there and the module is small (12 KB or less); a larger module carries `@native`
on the functions the row spends its time in, and nothing else.

Measured 2026-10-15 with `jess 0.1.0`, the verified release build of jess `07c38cb` on l3i
2.0.3, on the i7-10870H, the one-minute load 1.49 and 1.04 at the start of the two
sessions. In each session the bench ran alternately on this package and on a copy of it with
every module marked, three fresh runs of `bench/bench.jsl` each, every run's row the median of
its batches; a column is the median of the three, and a ratio is against the all-marked runs of
the same session. Which functions a row spends its time in comes from `jess run --profile` of
that row alone, unmarked. The load cost is a fresh `jess run --package <this package>
--package-path jpk` of a script that only requires `@add-vanilla-refs`, the two sides alternating, the
median of five each after one warm-up.

| Requiring `@add-vanilla-refs` | All marked | This state |
| --- | ---: | ---: |
| Unmarked | 0.076 s | 0.061 s |
| Final | 0.057 s | 0.055 s |

| Row | All marked (ms) | Unmarked / all marked | Final (ms) | Final / all marked |
| --- | ---: | ---: | ---: | ---: |
| a plugin of 2523 records over masters of 22036: the whole run | 65.93 | **1.392×** | 67.64 | 1.026× |
| a plugin of 4407 records over masters of 18799: objects alone | 45.74 | **1.414×** | 46.47 | 1.016× |
| a plugin of 511 records over masters of 6424: cells of 512 references | 37.40 | **1.438×** | 37.63 | 1.006× |
| a plugin of 1943 records over masters of 23565: dialogue | 37.52 | **1.569×** | 37.34 | 0.995× |
| commands.run, a dry run: a plugin of 506 records over masters of 5364, as files | 53.66 | **1.118×** | 54.30 | 1.012× |

What carries the directive: `init` and `commands`, whole. `cli` and `main` parse a command line
once a run and are never marked.

Marking only the functions of `init` the runs' profiles named saved 0.006 s a load and left every
run 1.07x to 1.16x slower than all marked: a run reaches most of `init`, so the rest of it is no
long tail to leave as bytecode. Whole, `init` costs 1.5 ms less a load than all marked and no row
is more than 5% slower; a run of the tool is the work `init` does, so that is the state kept.
