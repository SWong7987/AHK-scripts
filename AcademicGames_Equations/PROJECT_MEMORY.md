# EQUATIONS PROJECT MEMORY / CHATGPT HANDOFF

Last updated: 2026-09-23
Repository: SWong7987/AHK-scripts
Default branch: main
Project folder: AcademicGames_Equations

This document is the canonical continuity and handoff document for ChatGPT when continuing the Academic Games EQUATIONS AutoHotkey project in a new conversation.

READ THIS FILE BEFORE MODIFYING THE EQUATIONS SOURCE.

The purpose of this file is to preserve not only the current state, but also the reasons behind design decisions, performance results, failed approaches, testing procedures, user preferences, and the roadmap. A fresh ChatGPT session should be able to recover the project from this document plus the canonical source on GitHub.

---

# 1. START HERE IN A BRAND-NEW CHAT

If a user says to continue the EQUATIONS project, first read this file and then inspect the canonical GitHub source.

Canonical stable source:
AcademicGames_Equations/AcademicGames_Equations.ahk

Current stable GitHub release:
v4.9.2

Stable release commit:
c2ff3dedf2e2b4aebe91c312ac37a4f4c53f5e6b

Canonical Git blob SHA for v4.9.2:
7080454a8edbf7c805aef139bf1108c5a74fb067

Verified v4.9.2 local source size:
242,792 bytes

Verified v4.9.2 SHA-256:
18fc3dc697ac447a22631626c5ddad2d69a6222bfa25ed1f9196a660e1e1cfcf

v4.9.2 regression result:
68 / 68 checks passed on Windows.

v4.9.2 performance checkpoint:
18.77 shakes/sec at 22 workers using the standard 10-shake QUICK benchmark described later in this document.

CURRENT EXPERIMENTAL BUILD:
v4.10

v4.10 is NOT the canonical GitHub source yet and must not be described as promoted unless a later commit explicitly does so.

Current v4.10 local filename used in the prior chat:
AcademicGames_Equations_Hotseat_v4.10.ahk

Current v4.10 local source size:
257,673 bytes

Current v4.10 SHA-256:
e9e38c3ba58790f719b40d0adbb61bcf4d6133de8407b30581e12129f485f3cd

Current v4.10 static verification:
- 242 functions
- 242 unique function names
- balanced parentheses, brackets, and braces
- important referee/parser/scoring functions were intentionally left byte-identical to v4.9.2
- expected self-test count: 74 checks

IMPORTANT:
At the time this memory file was created, the user had NOT YET reported the v4.10 Windows runtime self-test or benchmark result. A future chat must not invent a passing v4.10 runtime result. If exact v4.10 source changes are needed and it is still not on GitHub, ask the user to re-upload the exact v4.10 file and verify its SHA-256 against the value above.

Immediate v4.10 testing order:
1. Ctrl+Shift+T self-test. Expected: 74 checks passed.
2. Visible WATCH BOT GAME, Middle division, 3 Very Hard Bots, 20 shakes, fixed seed.
3. Inspect plan diagnostics and behavior.
4. Standard 10-shake benchmark with seed 1576201967.
5. Only run longer tests if something useful remains uncertain.

---

# 2. USER WORKFLOW AND PREFERENCES

The user is developing this project interactively with ChatGPT and is not an experienced Git/GitHub user.

Important workflow preferences:
- AutoHotkey version is v2 for the current EQUATIONS project.
- NEVER respond with tiny AHK patch snippets when changing the program.
- When code changes are needed, create and provide a complete replacement .ahk file.
- The user is comfortable replacing a whole section or whole file.
- The user strongly prefers raw .ahk files over ZIP archives.
- Functionality and stability matter more than cosmetic perfection.
- Keep the visible WATCH BOT GAME mode. The user enjoys seeing bots play at lightning speed.
- Keep deterministic seeds and reproducible bot runs.
- Do not make the user run long benchmark ladders without a reason.
- Prefer the 10-shake benchmark for quick performance comparisons.
- Use longer 25/50/100-shake tests only for confirmation, stress, or when results are noisy.
- The user does not have Git installed locally. GitHub operations have been done through the connected GitHub tooling.
- Promote only tested versions to the canonical GitHub file.
- Once a version is promoted, use Git history as the version archive rather than proliferating versioned copies inside the canonical folder.
- Do not delete unrelated/root files without explicit permission.
- In particular, an older root file named AcademicGames_Equations_Hotseat_v4.2.ahk may exist and should not be deleted casually.

The user likes concise but clear progress updates during long operations.

---

# 3. CANONICAL REPOSITORY STATE

Repository:
SWong7987/AHK-scripts

Default branch:
main

Canonical project folder:
AcademicGames_Equations/

Canonical stable file:
AcademicGames_Equations/AcademicGames_Equations.ahk

Current canonical version at the time of this document:
v4.9.2

Current canonical promotion commit:
c2ff3dedf2e2b4aebe91c312ac37a4f4c53f5e6b

Commit message:
Promote EQUATIONS v4.9.2 strategic bot release

The canonical file header begins with:
#Requires AutoHotkey v2.0
#SingleInstance Off
ACADEMIC GAMES EQUATIONS - LOCAL HOT-SEAT PRACTICE v4.9.2

The canonical folder should normally contain the stable source, plus this PROJECT_MEMORY.md continuity document. Temporary transfer folders/workflows used for large-file promotion must be removed after a successful promotion.

---

# 4. GITHUB PROMOTION SAFETY PROCEDURE

Large AHK source files have previously been corrupted/truncated when sent through connector arguments. Do not trust a large direct full-file update without verification.

A robust promotion pattern was proven successfully for v4.6.4 and v4.9.2:

1. Take the exact locally tested .ahk file.
2. Record exact byte size.
3. Record SHA-256.
4. gzip the source.
5. base64 the gzip stream.
6. split the base64 text into small chunks.
7. stage the chunks under a temporary repository folder.
8. add a temporary GitHub Actions workflow.
9. The workflow reconstructs the source.
10. The workflow MUST verify the exact SHA-256.
11. The workflow MUST verify the exact byte size.
12. Only after both gates pass does it replace the canonical file.
13. The workflow removes the transfer chunks and itself.
14. It commits the promoted stable version to main.
15. Fetch the canonical source afterward and verify its header/blob.
16. Confirm temporary material is gone.

The checksum and size gates are mandatory. During the v4.6.4 promotion, one staged chunk was corrupted. The gate correctly prevented the canonical source from being overwritten. The bad chunk was repaired and the workflow was rerun successfully.

Do not assume chunk uploads are safe merely because each chunk is much smaller than the source.

---

# 5. OFFICIAL EQUATIONS RULE SOURCE AND IMPLEMENTATION POLICY

When making substantive claims about current EQUATIONS tournament rules, use the official AGLOA rule source rather than guessing.

Previously used official 2026-27 source:
https://agloa.org/wp-content/uploads/EquationsRules2627.pdf

AGLOA EQUATIONS page:
https://agloa.org/equations/

The rules PDF was updated June 30, 2026.

Important implementation conclusions already established:
- The game uses 24 cubes.
- There are six red, six blue, six green, and six black cubes.
- There is a mat, timer, and challenge block.
- Main challenges include NOW and IMPOSSIBLE.
- Once a Goal cube touches the Goal area it cannot return to Resources.
- Goal cubes may be rearranged/regrouped before GOAL is declared.
- An ungrouped Goal can have any acceptable legal grouping.
- Explicit radical grouping can override the default radical interpretation.
- An illegal Goal may still be said; an opponent can challenge IMPOSSIBLE.
- Basic Solution uses one-digit numerals.
- Goal can use one- or two-digit numerals.
- Required cubes must all be used.
- Forbidden cubes may not be used.
- Permitted cubes are optional.
- NOW may use at most one Resource.
- IMPOSSIBLE may use remaining Resources.
- Forceout has no Resources.
- Goal-setter Bonus is legal only before the first Goal cube.
- NO GOAL is legal only before the first Goal cube/Bonus.
- Bonus is blocked for a player alone in the lead; a tied leader may Bonus.
- In the simulator, ^ or * may represent exponentiation; multiplication is x.
- Do NOT change the meaning of * casually. This was an intentional simulator convention.
- Challenge scoring uses 6/4/2 patterns.
- Forceout scoring uses 4/2 patterns.
- Elementary/Middle illegal challenge/time penalty uses judge confirmation/approval behavior in the simulator.
- The last Resource cannot be Forbidden.
- NOW is not legal when only one Resource cube remains.
- Moving the last Resource starts a two-minute writing period.
- IMPOSSIBLE against the last-cube mover is legal only during the first minute of that writing period.
- Tournament clocks currently implemented:
  - Goal setting: 2:00
  - first turn after Goal: 2:00
  - later turns: 1:00
  - equation writing: 2:00
  - NO GOAL opponent decision: 1:00
  - 10-second grace after time expires
  - then the -1 procedure/additional minute where appropriate
- Elementary power/root rules are stricter than Middle/Junior/Senior.
- Current Elementary implementation requires whole-number base/exponent for powers and counting-number root index plus whole-number radicand/result for roots.
- Middle/Junior/Senior preserve the less restrictive math behavior.
- The tournament rules do not clearly publish a per-face color/cube distribution chart. Do not invent a different physical distribution based on unsupported assumptions.

If a rules question appears uncertain, search the current official source again.

---

# 6. UI AND STABILITY ARCHITECTURE

A major historical stability lesson:
Native Windows Button controls for cubes are reliable.

Do NOT regress to:
- overlapping STATIC controls
- giant painted background hit-test hacks
- fragile z-order systems
- pure coordinate click hitboxes for cube controls

v4.0 rebuilt the cube interaction layer using real Windows Button controls and that was a major stability improvement.

Cube colors are less important than stable interaction.

Stable UI behavior from earlier versions:
- v4.2: select cube, then use GOAL / REQUIRED / PERMITTED / FORBIDDEN zone headers.
- v4.3: Goal rearrangement, physical Goal interpretation, Forceout timing.
- v4.4: auto adjudication of immediately challenged illegal Goals.
- v4.5: division/timer/rules hardening.
- v4.6 onward: bot/controller architecture.

Do not casually redesign the entire board UI while working on bot intelligence.

---

# 7. CORE REFEREE / PARSER DESIGN

The most important principle:
Bots do not get a private rules engine.

Bots should use the same game-engine/referee paths as human players.

A bot may use internal search to propose a candidate equation, but final legality/value checks must still go through the same referee/checker used for human play.

Important functions that have repeatedly been protected across bot strategy changes include:
- CheckBoardEquation
- CheckPresentedGoal
- CheckBoardCubeUsage
- ParseExpression
- ApplyBinary
- SafePower
- StartChallenge
- FinalizeShake
- ScoreForceout
- PlaceSelected
- LockGoal
- BonusSelected
- BotFindBoardEquation
- BotFindExpressionToTarget

Before promoting a strategy-only build, compare these core functions against the stable baseline when practical. Strategy work should not silently alter referee behavior.

---

# 8. IMPORTANT HISTORICAL BUG: INTEGER EXPONENT OVERFLOW

A real arithmetic bug was found before v4.6.4.

Bad example:
(8^((2+3)x6)) = ((8x4))sqrt(0)

This effectively compared 8^30 against the 32nd root of 0.

Root cause:
AutoHotkey integer exponentiation allowed 8 ** 30 to overflow 64-bit integer arithmetic and become zero.

v4.6.4 fixed this:
- SafePower forces floating-point exponentiation.
- 8^30 is approximately 1.23794e27.
- FormatNumber was hardened for huge values.
- regression tests verify the high-power magnitude, root of zero, and inequality.

Do not reintroduce integer-overflow behavior in power evaluation.

---

# 9. BOT TYPES

Current bot/controller architecture supports:
- Human
- Practice Bot
- Very Hard Bot
- Rules Fuzzer
- Parser Fuzzer
- Chaos Fuzzer

Intent:
Practice Bot:
- simpler Goals
- ordinary moves
- occasional NOW
- useful for human practice

Very Hard Bot:
- strong legal play
- tactical NOW/IMPOSSIBLE awareness
- strategic move selection
- deterministic when seeded

Rules Fuzzer:
- boundary states
- Bonus
- last-cube cases
- challenge behavior
- Required/Forbidden-heavy states

Parser Fuzzer:
- nasty expressions and parser stress

Chaos Fuzzer:
- weird/random paths
- may intentionally create illegal Goals
- useful for breaking assumptions

Testing bots/fuzzers should remain available even if normal UI focuses on human play and Very Hard.

---

# 10. BOT LAB / MULTI-PROCESS ARCHITECTURE

The project has a Bot Lab that can run many bot games simultaneously.

Startup/use cases:
1. Player vs player / configurable seats.
2. Visible bots vs bots.
3. Lots of bots with Show All / Show One / Hidden.
4. PC Benchmark mode.

Multi-instance design:
- a main/controller process launches worker AutoHotkey processes.
- workers can coexist.
- visibility modes:
  - Show All
  - Show One
  - Hidden
- hidden workers are much faster because GUI rendering is expensive.
- worker seeds are deterministically derived from a base seed.
- stress workers skip inappropriate real wall-clock timing effects so speed/CPU load does not create tournament time penalties.
- controller aggregates worker completion and search counts.
- full bot move logs can be copied after runs.

The visible WATCH BOT GAME mode is important and should not be removed in the name of optimization.

---

# 11. CHALLENGE EQUATION CACHE

A key race bug was fixed in v4.6.2.

Old failure:
A Practice Bot could search, find a valid NOW equation, call NOW, then later run a fresh randomized search when asked to present the equation. That second search could fail and produce NO EQUATION even though the challenge was originally valid.

Fix:
- BotCachedEquationEntries stores the exact found equation before challenge.
- the presentation step consumes that exact cached equation.
- Third Party also caches a found equation.
- cache resets appropriately at new move/shake boundaries.

Expected diagnostic pattern:
Bot calls NOW after finding and caching a candidate Equation.
Then:
Bot presents the cached NOW Equation: ...

Do not replace a known successful challenge witness with a fresh random search.

---

# 12. DETERMINISM

Deterministic replay matters.

The bot system has seeded RNG behavior.
Worker seeds are derived deterministically from the base seed.

Important historical deterministic check:
A v4.7 watch run using 3 Very Hard bots, 20 shakes, seed 102308923 reproduced exactly, including:
- search successes: 508
- search failures: 2805
- same move sequence

Cross-version identical move sequences are NOT expected after strategy/search optimizations because additional or fewer random calls change the RNG path.

What should remain reproducible:
same version + same settings + same seed should ideally reproduce the same game logic and move sequence.

Elapsed wall-clock time can vary.

---

# 13. PERFORMANCE HISTORY

Performance optimization is a major project goal.

Important lesson:
More search is not automatically smarter.

v4.9 became much slower because it performed deep tactical probes on too many candidate moves.

The user wants a bot that is both very smart and fast.

Standard quick comparison configuration:
- Profile: QUICK
- Max workers: 22
- Shakes/worker/stage: 10
- Division: Middle
- Players/game: 3
- Visibility: Hidden
- Delay: 1 ms
- Lineup: Very Hard / Very Hard / Very Hard
- Base seed: 1576201967

Historical benchmark results:

v4.7.2, 10 shakes/stage, same seed and lineup:
1 worker: 8.73s, 1.14 shakes/s
2 workers: 8.86s, 2.26
4 workers: 10.52s, 3.80
8 workers: 12.33s, 6.49
12 workers: 13.84s, 8.67
16 workers: 16.98s, 9.42
22 workers: 20.61s, 10.67
Best: 22 workers @ 10.67 shakes/sec

v4.8, same 10-shake benchmark:
1 worker: 7.76s, 1.29
2 workers: 7.89s, 2.53
4 workers: 8.55s, 4.68
8 workers: 12.19s, 6.56
12 workers: 12.72s, 9.43
16 workers: 12.77s, 12.53
22 workers: 14.22s, 15.47
Best: 22 workers @ 15.47 shakes/sec

v4.8 25-shake confirmation:
1 worker: 17.02s, 1.47
2 workers: 19.27s, 2.60
4 workers: 20.03s, 4.99
8 workers: 23.45s, 8.53
12 workers: 25.11s, 11.95
16 workers: 29.64s, 13.49
22 workers: 35.64s, 15.43
Best: 22 workers @ 15.43 shakes/sec

v4.9, 25-shake benchmark after expensive strategic probes:
1 worker: 27.75s, 0.90
2 workers: 26.95s, 1.86
4 workers: 28.05s, 3.57
8 workers: 35.02s, 5.71
12 workers: 41.77s, 7.18
16 workers: 50.75s, 7.88
22 workers: 58.84s, 9.35
Best: 22 workers @ 9.35 shakes/sec

This was considered too slow.

v4.9.1, 10-shake benchmark:
1 worker: 10.28s, 0.97
2 workers: 10.88s, 1.84
4 workers: 12.16s, 3.29
8 workers: 12.50s, 6.40
12 workers: 14.08s, 8.52
16 workers: 15.56s, 10.28
22 workers: 18.61s, 11.82
Best: 22 workers @ 11.82 shakes/sec

Still considered too slow.

v4.9.2, 10-shake benchmark:
1 worker: 6.03s, 1.66
2 workers: 6.25s, 3.20
4 workers: 6.72s, 5.95
8 workers: 8.06s, 9.92
12 workers: 8.94s, 13.43
16 workers: 9.69s, 16.52
22 workers: 11.72s, 18.77
Best: 22 workers @ 18.77 shakes/sec

v4.9.2 is therefore both substantially faster than v4.9 and faster than the strong v4.8 baseline.

---

# 14. WHY v4.9 WAS SLOW

v4.9 introduced strategic candidate evaluation but applied expensive searches too broadly.

A normal Very Hard move could sample up to roughly:
6 Resource cubes x 3 zones = 18 candidate moves.

For each candidate it could run:
- NOW probes
- IMPOSSIBLE-defense probes

With budgets roughly in the tens per candidate, a single move could trigger over a thousand tactical attempts.

Bonus also performed additional tactical searches.
The final cube had additional FORCEOUT search.

This made the bot computationally paranoid:
it was thinking too deeply about every mediocre candidate.

The core lesson:
Use cheap filtering first, then expensive reasoning only on finalists.

---

# 15. v4.9.1 SHORTLIST ARCHITECTURE

v4.9.1 tried to recover performance without making the bot dumb.

Pipeline:
1. cheap structural score of all possible moves
2. preserve shortlist diversity
3. keep strongest Required candidate
4. keep strongest Permitted candidate
5. keep strongest Forbidden candidate
6. fill remaining shortlist slots with best extras
7. tactical search only on finalists
8. deeper confirmation only on the best few

This improved v4.9 from 9.35 to 11.82 shakes/sec, but was still slower than v4.8.

v4.9.1 also reduced excessive Forbidden behavior.

---

# 16. v4.9.2 SHARED NOW ANALYSIS AND PERFORMANCE BREAKTHROUGH

A major duplicated-work problem was found:

After one move in a 3-Very-Hard game, both opponents could independently run up to about 900 NOW-search trials on the exact same board state.

That meant the system could spend about 1,800 trials asking the same public-board question twice.

v4.9.2 introduced shared Very Hard NOW analysis:
- one shared search for the public board
- roughly 1,000 total trials instead of two separate 900-trial searches
- if an equation is found, the witness is cached for the eligible Very Hard bots

This is a key design pattern to preserve:
PUBLIC BOARD FACTS SHOULD BE COMPUTED ONCE AND SHARED WHEN POSSIBLE.

v4.9.2 also made candidate evaluation cheaper:
- all candidates get cheap structural scoring
- only a small diverse finalist set gets a tiny NOW screen
- best finalists get real NOW/IMPOSSIBLE analysis
- Bonus analysis was reduced
- Required scoring gained diminishing-return behavior
- Permitted became more attractive as the board grew restrictive

This restored and improved performance:
18.77 shakes/sec at 22 workers in the standard quick benchmark.

---

# 17. REQUIRED / PERMITTED / FORBIDDEN STRATEGY LESSONS

There have been two extremes.

Early strategic bot problem:
Very Hard overvalued Forbidden, especially operators.
It created absurd Forbidden graveyards.

Then:
Very Hard overvalued Required.
Logs showed many sequential Required moves with similar scores.

v4.9.2 rebalanced this and produced more mixed play:
- some Required
- occasional strategically useful Forbidden
- increasing Permitted use as the board becomes restrictive

However, an important real-world insight was learned from the user's actual Academic Games match:
A real opponent used heavy Required pressure and defeated the user.

Therefore:
Lots of Required cubes are NOT inherently bad strategy.

The correct model is not:
"many Required cubes = bad"

The better model is:
"many Required cubes are strong if I already know how to use them and they make life harder for opponents."

Likewise Permitted is not automatically the smart alternative.

The desired behavior:
- If the bot has a robust known solution, strategically adding compatible Required cubes can be excellent pressure.
- If the bot lacks a solution or the plan becomes fragile, preserve flexibility with Permitted.
- Forbid faces/operators when that meaningfully hurts opponents without destroying the bot's own viable solutions.
- Avoid simplistic category obsession.

This directly motivated v4.10.

---

# 18. v4.10 STRATEGIC MEMORY DESIGN

v4.10 is the current experimental direction.

High-level goal:
Make Very Hard behave more like a strong human who remembers equations and follows a plan, rather than rating every move independently.

Key principle:
NEW INTELLIGENCE SHOULD COME MOSTLY FROM REUSING KNOWN WORK, NOT FROM MULTIPLYING SOLVER CALLS.

Each Very Hard seat now keeps a small bounded set of proven solution witnesses for the current shake.

Memory is intentionally bounded:
maximum approximately six witnesses per bot.

Why bounded:
- keeps per-turn checks cheap
- prevents strategy memory from turning into a giant database
- encourages reuse of the best known evidence

A stored witness can answer expensive questions cheaply.

Example:
Known solution:
(7 - 3) x 2 = Goal

Candidate:
2 -> Required

If the witness still satisfies the resulting board:
- the bot already has proof that an equation exists
- this acts as an IMPOSSIBLE-defense witness
- no separate randomized defense search is needed

If the same witness would qualify for NOW after the move:
- that is immediate evidence the move exposes a NOW threat
- no random NOW search is needed to detect that particular danger

This is the core optimization philosophy of v4.10:
memory should replace search whenever possible.

---

# 19. v4.10 PLAN STATES

Very Hard strategy memory was designed around plan states:

FLEXIBILITY
- no strong surviving solution witness
- preserve options
- favor Permitted more
- avoid reckless Required pressure

PRESSURE
- bot has one or more usable solution witnesses
- can add compatible Required cubes if the witness survives
- objective becomes "I know how to use these. Do you?"

STABILIZE
- bot still has a solution but the board is becoming fragile/restrictive
- protect critical faces/operators
- avoid moves that destroy all known solutions

ENDGAME
- few Resources remain
- prioritize preserving a forceout path
- reuse a remembered equation if possible rather than launching another huge search

The plan state should be evidence-driven, not randomly selected.

---

# 20. STRATEGY MEMORY SOURCES

Very Hard can learn/store a witness from work the program is already doing.

Examples:
- Goal setter finds a legal solution while selecting a Goal.
- Tactical candidate search finds a legal defense equation.
- Shared tactical analysis discovers an equation.
- Final-cube search finds a valid equation.

Instead of throwing those answers away, v4.10 stores a bounded set of useful witnesses.

When the board changes:
- cheaply filter stored witnesses against the new Required/Permitted/Forbidden state
- keep survivors
- discard invalidated ones
- search only when memory is insufficient

Future optimization direction:
store multiple independent witnesses with different face/operator dependencies so the bot can measure robustness.

---

# 21. TARGET INTELLIGENCE MODEL

Long-term Very Hard should use roughly four levels of thinking:

LEVEL 0 - MEMORY
Reuse previously discovered equations.
Very cheap.

LEVEL 1 - STRUCTURE
Analyze:
- Required pressure
- duplicate faces
- critical operators
- remaining Resources
- Required/Permitted/Forbidden balance
- score situation
- current plan state
Very cheap.

LEVEL 2 - TACTICAL
Only when necessary:
- can opponent NOW?
- can I defend IMPOSSIBLE?
- does a specific candidate preserve a real witness?
Moderate search.

LEVEL 3 - DEEP SEARCH
Use only when:
- top choices are close
- current plan has broken
- final cube/forceout requires it
- Goal choice needs it
Expensive.

Do NOT return to the v4.9 approach of deep search on nearly every candidate.

---

# 22. POSSIBLE FUTURE STRATEGIC MODES

These are conceptual roadmap items, not necessarily all implemented yet.

Required Pressure
- bot has robust solution witnesses
- make compatible faces Required
- deliberately reduce opponent freedom

Flexibility / Permitted
- no strong solution yet
- preserve optional resources
- avoid self-trapping

Operator Denial
- forbid an operator opponents are likely to need
- only if own known witnesses survive

NOW Setup
- steer toward a board where the next opponent is likely to expose an easy NOW opportunity

Forceout Plan
- as Resources shrink, maintain a known equation after Resources disappear

Robustness
- prefer plans with multiple independent solution witnesses
- avoid a plan that depends on one fragile operator/face

The bot should not randomly choose these. It should infer them from stored evidence and board state.

---

# 23. GOAL STRATEGY

v4.9 introduced more strategic Goal selection.

Very Hard does not simply choose any solvable Goal.
It scores candidate Goals and their solution witnesses.

Existing preferences include:
- real solvability witness required
- longer/stronger witness may be valued
- trivial Goal values such as 0 and +/-1 are de-emphasized
- candidate structure can matter

Be careful:
Do not turn bounded search failure into proof that a Goal is impossible.

A found equation is positive proof of solvability.
A failed bounded search is only "not found within budget."

---

# 24. BONUS STRATEGY

Very Hard Bonus became strategic in v4.9 and then was optimized.

Original v4.9 strategic Bonus concept:
- consider resource candidates
- require a bounded IMPOSSIBLE-defense witness
- reject if bounded NOW search already finds an opponent win
- operator denial had extra value
- trailing score could increase aggression
- avoid Bonus with very few Resources

Problem:
Bonus added substantial search cost and could over-contribute to Forbidden behavior.

v4.9.1/v4.9.2 made Bonus more selective and cheaper.

Continue treating Bonus as a purposeful tactical move, not a random frequency knob.

---

# 25. LAST RESOURCE / FORCEOUT STRATEGY

Very Hard should not blindly make the last Resource Required.

It should consider Required vs Permitted and preserve a viable forceout equation where possible.

The last Resource:
- cannot be Forbidden
- NOW is no longer legal when only one Resource remains
- after it moves, the two-minute writing period begins
- IMPOSSIBLE against the last-cube mover remains available only in the first minute

Historical bot behavior sometimes reached forceout with no equation.
This remains an important intelligence metric.

A strong future bot should:
- preserve a known endgame witness
- reuse witness memory
- avoid making a late move that destroys every surviving equation
- only deep-search if memory cannot answer the final decision

---

# 26. BOUNDED SEARCH SAFETY RULE

This rule is critical.

A bounded solver has asymmetric meaning:

FOUND equation:
positive proof that the equation exists.

NO equation found:
NOT proof that no equation exists.

Therefore:
- never auto-declare IMPOSSIBLE solely because a randomized/bounded search failed
- never treat "NOW probe clear" as mathematical proof there is no NOW unless a complete proof mechanism exists
- strategy may use bounded failure as a heuristic
- referee decisions must not convert bounded failure into certainty

This distinction was explicitly preserved in v4.9/v4.9.2 strategy comments and should remain.

---

# 27. SELF-TEST HISTORY

Important known test counts:
v4.6.4: 55 / 55 passed
v4.7.2: 59 / 59 passed
v4.8: 62 / 62 passed
v4.9: expected 65
v4.9.1: 68 / 68 passed
v4.9.2: 68 / 68 passed
v4.10: expected 74, NOT YET runtime-confirmed at time of this document

Ctrl+Shift+T runs the regression self-test.

Ctrl+Shift+B is used for diagnostics/copying bot diagnostic information in the developed versions.

Do not claim a version passed unless the user actually ran it or a real AutoHotkey runtime did.

The ChatGPT container does not have a reliable Windows AutoHotkey runtime, so Windows runtime confirmation comes from the user's machine.

---

# 28. VERSION HISTORY SUMMARY

v4.0
- stable native Windows Button cube controls
- major interaction stability improvement

v4.2
- select cube then GOAL/REQUIRED/PERMITTED/FORBIDDEN headers
- known stable interaction model

v4.3
- Goal rearrangement/grouping
- broader physical Goal interpretation
- Forceout timing work

v4.4
- automatic adjudication for immediate IMPOSSIBLE against an illegal Goal
- if no legal Goal interpretation exists, challenge can auto-succeed
- third-party scoring/decision logic
- parser overflow should not automatically rule Goal illegal
- auto illegal-Goal adjudication only immediately after Goal

v4.5
- tournament timing
- division selector
- Elementary power/root restrictions
- timer safety
- physical cube representation
- user reported timer worked well

v4.6
- bot/controller layer

v4.6.1
- Ctrl+Shift+B diagnostics clipboard

v4.6.2
- challenge equation cache
- search hardening
- independent arithmetic value tracking for generated candidates

v4.6.4
- fixed real exponent integer overflow
- 55/55 self-tests passed
- promoted successfully to GitHub at the time
- historical stable commit: 8e883545214680e36eb7c2f079dbc23bf7e07b7e

v4.7
- startup modes
- deterministic seeds
- multi-process Bot Lab
- hidden/show-one/show-all workers

v4.7.2
- benchmark mode
- Copy All Bot Moves
- fixed parser/log code syntax issue
- 59/59 self-tests
- baseline benchmark around 10.67 shakes/sec at 22 workers in the standard 10-shake comparison

v4.8
- major solver-performance optimization
- fewer full-array copies/shuffles
- faster random pop/swap
- partial sampling of optional cubes
- cached unchanged Goal interpretations
- target-aware final operation in both operand directions
- faster common integer exponent path
- referee validation retained
- 62/62 self-tests
- standard 10-shake benchmark around 15.47 shakes/sec
- 25-shake confirmation around 15.43 shakes/sec

v4.9
- first major Very Hard strategic pass
- opponent-aware move evaluation
- NOW/IMPOSSIBLE probes
- strategic Bonus
- smarter final-cube choice
- strategic Goal score
- expected 65 self-tests
- too slow: 9.35 shakes/sec on the 25-shake benchmark
- also overvalued Forbidden at first

v4.9.1
- shortlist strategy
- reduced deep probes
- Bonus more selective
- Required/Forbidden rebalance
- 68/68 passed
- still slow: 11.82 shakes/sec in standard 10-shake benchmark
- Required bias still visible

v4.9.2
- shared Very Hard NOW analysis
- eliminated duplicate public-board NOW searches
- cheaper finalist pipeline
- improved Required/Permitted balance
- 68/68 passed
- standard quick benchmark: 18.77 shakes/sec at 22 workers
- promoted to GitHub
- CURRENT STABLE BASELINE

v4.10
- CURRENT EXPERIMENTAL BUILD
- strategic memory per Very Hard seat
- bounded witness set
- plan states: FLEXIBILITY / PRESSURE / STABILIZE / ENDGAME
- reuse known equations to avoid solver calls
- evidence-driven Required pressure
- protect important faces/operators
- reuse witnesses for IMPOSSIBLE defense and NOW-danger evidence
- expected 74 tests
- NOT YET runtime-tested at time this document was created
- NOT YET promoted to GitHub

IMPORTANT HISTORICAL CORRECTION:
A supposed v4.7.3 was a misunderstanding and should NOT be treated as a real/canonical project version or resurrected into history.

---

# 29. KNOWN PERFORMANCE/BEHAVIOR OBSERVATIONS

GUI rendering is a major slowdown.
Hidden mode is fastest.
Show One is a useful compromise.
Show All is slow but fun.

A historical 16-worker x 100-shake hidden v4.7 run completed 1600/1600 with zero failures/stops.

Search counts can legitimately differ across versions because strategy/search optimizations change RNG consumption.

Within a single version, same seed/settings should remain reproducible.

A strategy build that performs more searches is not automatically better.
Prefer:
- caching
- witness reuse
- shared public-board analysis
- progressive search
- cheap pruning
- early exits

---

# 30. DIAGNOSTICS AND LOGGING

Useful outputs:
- Ctrl+Shift+B bot diagnostics
- Copy All Bot Moves
- benchmark summary
- worker status

Logs should make strategy explainable.

Examples of useful diagnostics:
- plan FLEXIBILITY / PRESSURE / STABILIZE / ENDGAME
- number of surviving witnesses
- strategy score
- NOW probe threat/clear
- IMPOSSIBLE defense witness/not found
- cached/shared NOW equation
- Goal strategy score
- solution witness cube count
- strategic Bonus reasoning

Avoid removing diagnostics merely to make the code shorter. They are critical for debugging bot decisions.

---

# 31. TESTING GATES BEFORE PROMOTION

A reasonable release-candidate gate:

1. Static verification
- no duplicate functions
- balanced delimiters
- expected version labels
- important referee/parser/scoring functions unchanged unless intentionally modified

2. Regression self-test
- exact expected count passes

3. Visible watch test
- 3 Very Hard Bots
- Middle division
- around 20 shakes
- fixed seed
- inspect decisions and logs
- no crash/stall
- no illegal last-cube Forbidden
- no bogus equations
- challenge cache works
- plan behavior makes sense

4. Short performance benchmark
- standard 10-shake QUICK benchmark
- seed 1576201967
- compare against stable v4.9.2 = 18.77 shakes/sec at 22 workers

5. Deterministic replay when strategy changes materially
- same version/settings/seed twice
- moves/search behavior should reproduce

6. Hidden stress run if appropriate
- example: 16 or 22 workers
- 50 or 100 shakes per worker
- zero failures/stops
- workers end in expected state

7. Only then promote if the user agrees or has clearly authorized promotion.

Do not require every long test for every tiny change. Use judgment and minimize unnecessary waiting.

---

# 32. WHAT NOT TO DO

Do NOT:
- replace the stable native Button UI with fragile overlapping controls
- treat bounded search failure as proof of impossibility
- rerun a fresh randomized challenge search when an exact cached witness already exists
- make every candidate move perform deep tactical searches
- blindly penalize Required merely because there are many Required cubes
- blindly prefer Permitted as the opposite extreme
- blindly overvalue Forbidden operators
- delete the visible bot-watch mode
- remove deterministic seeds
- remove fuzzers/testing bots without a reason
- casually change * from exponentiation
- casually alter the referee while working on strategy
- claim a version is on GitHub before verifying the canonical file
- claim a runtime test passed when only static checks were performed
- resurrect the nonexistent v4.7.3
- give the user tiny patch snippets instead of a full replacement .ahk file

---

# 33. NEAR-TERM ROADMAP AFTER v4.10

First:
Run v4.10 self-test.
Expected: 74 checks.

Then:
Run visible 20-shake 3x Very Hard.
Inspect:
- whether plan states change sensibly
- whether witness counts persist
- whether Required pressure happens only with surviving equations
- whether the bot protects critical operators
- whether it falls back to Permitted when it loses confidence
- whether NOW challenge/caching still works
- whether endgame memory prevents some no-equation forceouts

Then:
Run standard 10-shake benchmark with seed 1576201967.

Primary performance goal:
stay near v4.9.2 speed if possible.

The desired direction is:
v4.9.2-like or better speed
plus
v4.10-like persistent planning intelligence

If v4.10 is slower:
first profile/reason about duplicated or unnecessary search.
Do not immediately reduce intelligence.
Look for:
- repeated checks that can be cached
- board states already solved
- witness validation that can replace search
- duplicate opponent analysis
- repeated Goal interpretation parsing
- candidate symmetry

If v4.10 is fast but behaves poorly:
tune plan logic/evidence thresholds before increasing search budgets.

---

# 34. FUTURE OPTIMIZATION IDEAS

Potential high-value ideas:
- board-state transposition cache
- cache exact public board -> NOW result
- cache exact board -> known legal equations
- incremental witness filtering
- dependency masks/face-count signatures for each witness
- store multiple independent solution families
- rank witnesses by robustness
- detect critical faces appearing in most surviving solutions
- progressive solver budgets
- stop searching as soon as the needed tactical fact is proven
- share additional public-board calculations between Very Hard seats
- avoid re-parsing unchanged Goal interpretations
- deterministic cache keys so replay remains reproducible

Any caching system must be invalidated correctly across:
- new shake
- Goal changes
- zone changes
- challenge state changes
- division changes where legality differs

---

# 35. CONTINUITY INSTRUCTIONS FOR CHATGPT

When starting from this document in a fresh chat:

1. Read this entire file.
2. Fetch the canonical AcademicGames_Equations.ahk from GitHub.
3. Confirm the header/version.
4. If the user is working on an experimental version newer than the canonical stable version, ask for the exact current .ahk only if a code change requires it.
5. Do not make the user retell the entire history.
6. Use the stable GitHub source as the recovery point if an experiment is lost.
7. Preserve the user's preference for full replacement files.
8. Preserve performance benchmarks and regression counts.
9. Preserve the distinction between stable and experimental versions.
10. Update this memory file after important promotions or architectural breakthroughs.

If PROJECT_MEMORY.md disagrees with the actual canonical source:
- inspect Git history and current source
- prefer verified repository state for exact code
- update this document after resolving the discrepancy

If the user says a newer build was promoted:
- verify GitHub before changing the stable-version section.

---

# 36. CURRENT STATUS SNAPSHOT

Stable:
v4.9.2

Stable GitHub commit:
c2ff3dedf2e2b4aebe91c312ac37a4f4c53f5e6b

Stable Git blob:
7080454a8edbf7c805aef139bf1108c5a74fb067

Stable source SHA-256:
18fc3dc697ac447a22631626c5ddad2d69a6222bfa25ed1f9196a660e1e1cfcf

Stable source size:
242,792 bytes

Stable self-test:
68/68

Stable standard benchmark:
18.77 shakes/sec @ 22 workers

Experimental:
v4.10

Experimental local SHA-256:
e9e38c3ba58790f719b40d0adbb61bcf4d6133de8407b30581e12129f485f3cd

Experimental local size:
257,673 bytes

Experimental expected self-test:
74

Experimental runtime status at this document creation:
NOT YET CONFIRMED

Experimental GitHub status:
NOT PROMOTED

Current development objective:
Test and refine strategic witness memory so Very Hard can intentionally use Required pressure when it has proven equations, preserve flexibility when it does not, and gain intelligence mainly through reuse/caching rather than brute-force search.

---

# 37. FINAL DESIGN PRINCIPLE

The long-term target is not a bot that merely searches more.

The target is a bot that:
- remembers what it already proved
- understands which cubes/operators its solutions depend on
- deliberately pressures opponents with Required when safe
- uses Permitted to preserve flexibility when uncertain
- uses Forbidden selectively
- anticipates NOW/IMPOSSIBLE
- protects a forceout path
- shares public calculations
- remains deterministic and explainable
- stays fast enough for large Bot Lab runs

In short:

SMARTER THROUGH MEMORY, STRUCTURE, CACHING, AND SELECTIVE SEARCH — NOT BRUTE FORCE.
