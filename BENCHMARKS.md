# add-vanilla-refs benchmarks

`bench/bench.luau` times the package through its public API: `run` over record lists, and
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
  each read through `@tes3` and `@tes3conv` and put back in its file's order, the run, and the
  result written as a plugin in memory.

Each workload is warmed up, sized to a batch of about a tenth of a second, and reported as the
median of seven batches, with a full collection between them. Before the batches and after them
its whole result is hashed (every record and reference and every line of the log, a record's
fields in the order of their names) and has to come to the hash written in the bench, which is
the baseline's: a run that does less, or anything else, fails instead of posting a time.

```sh
jess run --package jpk/add-vanilla-refs --package-path jpk \
  --capability filesystem.read --capability filesystem.write \
  jpk/add-vanilla-refs/bench/bench.luau [filter] [scratch folder]
```

Without a scratch folder the command isn't timed, and no capability is needed.

## The move onto l3i 2.0, base against head

- Machine: Intel Core i7-10870H @ 2.20 GHz, 16 threads, shared with other work while this ran.
- Date: 2026-10-12.
- Binary: the verified release build of Jess 0.1.0 on l3i 2.0.1 (Luau 0.742), the same one for
  both sides, with the same `@tes3` and `@tes3conv` beside both.
- Base: `fa3b211`, the package before the move, with the bench as it is now. Head: `73242b7`.
- Protocol: the whole bench run against base, then head, three times over, back to back under one
  lock; each cell is the median of its three runs. A difference under 5 percent is called no
  change.

| Workload | Base | Head | Base / head |
|---|---:|---:|---:|
| a plugin of 2523 records over masters of 22036: the whole run | 452.6 ms | 67.83 ms | 6.67x |
| a plugin of 4407 records over masters of 18799: objects alone | 102.3 ms | 44.22 ms | 2.31x |
| a plugin of 511 records over masters of 6424: cells of 512 references | 356.8 ms | 38.54 ms | 9.26x |
| a plugin of 1943 records over masters of 23565: dialogue | 63.32 ms | 40.20 ms | 1.58x |
| commands.run, a dry run: a plugin of 506 records over masters of 5364, as files | 102.6 ms | 47.44 ms | 2.16x |

None of it is the dialect, and none of it is the data plane: a run is strings and record tables,
with no numbers in bulk to hand to `@dream/data`. The comprehensions, `any` reducers, slice, and
record patterns the package now uses measured as no change, which is what they are meant to cost.
What moved the numbers was the work a run no longer does, found by profiling it:

| Change | Whole | Objects | Cells | Dialogue | Command |
|---|---:|---:|---:|---:|---:|
| `dc4b98e` which reference of a cell named each record it needs, from one walk of its references instead of a walk for each record | 3.17x | no change | 3.24x | no change | 1.76x |
| `90e6820` the lists of field names a record's ids are read by, made once instead of for each reference | no change | no change | 1.07x | no change | no change |
| `709159f` each spelling of an id lowered once a run | 1.17x | 1.09x | 1.19x | 1.17x | 1.06x |
| `b68fe21` nothing pending for an id that is already defined, and only what is pending sorted | 1.33x | 1.40x | 1.41x | 1.07x | 1.07x |
| `f3449d5` the masters indexed, and their foundations found, once a run instead of in four walks | no change | 1.07x | no change | 1.11x | no change |
| `d9fdf61` the second pass answered with what a record needed in the first | 1.10x | no change | 1.19x | no change | no change |
| `4b6e92a` `tes3.isDeleted` asked only of a record with flags | 1.10x | 1.10x | 1.07x | 1.15x | no change |
| `a760eba` a script's lines read only when it says AddTopic somewhere | 1.11x | 1.24x | 1.09x | no change | 1.06x |
| `b4fa7b6` the first pass's lines added to the log one at a time, not by `table.move` | no change | no change | 1.14x | no change | no change |

Each cell there is one run of the bench against that commit over one against the commit before
it, all thirteen run in order under one lock, so a cell is good to a few percent and no better;
the first table is the measurement. The dialect commits between them (`2e91d94`, `b1b2332`,
`c5e92a7`, `c07e561`, `73242b7`) were in the same run and moved nothing.

The first row is most of it. `dependency_field` walked a cell's references from the top for every
record the cell needed, making a table of six pairs at each reference on the way: the square of
a cell's size, in allocations. The rest are a run's two passes asking the same questions twice.
What is left is mostly what a run has to make: a log line for every reference of every cell in
both passes, a node for every INFO of every master, and a copy of every INFO it keeps. Most
of the command's time is now `@tes3` and `@tes3conv` reading the files and writing the result.

`table.move(lines, 1, #lines, #log + 1, log)` is the one surprise worth knowing outside this
package: Luau resizes the destination to exactly fit when a move runs past its end, so appending
a list to a long one that way copies the long one every time. Adding the lines one at a time is
the last row above.
