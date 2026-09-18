#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; ACADEMIC GAMES EQUATIONS - LOCAL HOT-SEAT PRACTICE v4.6.4
; AutoHotkey v2.0
;
; Basic EQUATIONS only - NO Adventurous variations yet.
;
; What this version does:
;   - 2 or 3 players share one computer.
;   - Rolls 24 simulated EQUATIONS cubes.
;   - Players select actual rolled cubes and place them on a digital tabletop
;     patterned after the classic EQUATIONS playing-mat layout.
;   - Goal-setter may physically group the Goal with parentheses.
;   - Supports Bonus, NOW, IMPOSSIBLE, NO GOAL, Last Cube / forceout.
;   - Equation writers TYPE their Solution and Goal interpretation.
;   - The program checks the Equation automatically instead of asking
;     "Was it correct?"
;   - The checker verifies:
;       * legal Basic EQUATIONS syntax / real-number value
;       * Goal interpretation
;       * ambiguity (no normal order-of-operations shortcut)
;       * at least two Solution cubes
;       * one-digit numerals in the Solution
;       * every Required cube is used
;       * no Forbidden cube is used
;       * only available Permitted / Resource cubes are used
;       * NOW uses at most one Resource cube
;       * IMPOSSIBLE may use any remaining Resource cubes
;       * forceout uses Required + Permitted after Resources are gone
;   - Scores shakes and final match points.
;   - Includes automatic rule-aware turn/Goal timing plus the original manual 1-/2-minute controls.
;   - Keeps the game log out of the way behind a History button.
;   - v4.0 rebuilt the tabletop interaction layer for stability:
;       * cubes are real Windows Button controls, not overlapping STATIC text controls
;       * large painted mat backgrounds are removed entirely
;       * zone color is limited to non-overlapping header strips / borders
;       * mat placement still uses click-anywhere-in-zone coordinate detection
;   - This avoids the Windows STATIC repaint/hit-test problems seen in v3.x.
;   - v4.2 removes coordinate hit-testing entirely:
;       * each board-zone header is a real clickable Button
;       * select a cube, then click the GOAL / REQUIRED / PERMITTED / FORBIDDEN header
;       * no invisible hitboxes, no ScreenToClient math, no child-control offsets
;       * the stable native cube buttons from v4.0 are retained
;   - v4.3 tightens current 2026-27 tournament behavior:
;       * Goal cubes can be rearranged but never returned to Resources
;       * ungrouped Goals allow non-default radical groupings when written explicitly
;       * illegal Goals can be said and then challenged IMPOSSIBLE
;       * the last-cube two-minute clock starts automatically
;       * IMPOSSIBLE closes after the first minute of last-cube writing
;       * shake-ending actions always stop the table timer
;   - v4.4 automatically adjudicates an immediate IMPOSSIBLE challenge
;     when the Goal itself has no legal Basic interpretation, without warning
;     the Goal-setter in advance or asking the players to judge it manually.
;   - v4.5 is a rules-accuracy / regression-safety release:
;       * adds Elementary / Middle / Junior / Senior match setup
;       * enforces the Elementary General Rule for powers and roots
;       * automatically starts the 2-minute Goal clock, the 2-minute first-turn
;         clock, and 1-minute later-turn clocks without changing move mechanics
;       * adds the official 10-second grace countdown, -1 prompt, and additional minute
;       * locks manual timer controls during Last Cube / forceout
;       * makes the 24 physical tournament cubes explicit and self-checking
;       * adds Ctrl+Shift+T parser/cube regression tests
;     Existing v4.4 board, challenge, scoring, Goal grouping, and checker behavior
;     is retained unless a division/timing rule specifically requires otherwise.
;
;   - v4.6 adds a controller/bot layer without replacing the v4.5 game engine:
;       * every seat can be Human, Practice Bot, Very Hard Bot, Rules Fuzzer,
;         Parser Fuzzer, or Chaos Fuzzer
;       * bots use the SAME PlaceSelected / LockGoal / StartChallenge / checker paths
;         used by human controls instead of bypassing the referee
;       * Practice Bot favors simple legal Goals, ordinary moves, and occasional NOW
;       * Very Hard Bot uses bounded expression search for Goals, moves, NOW, and writing
;       * three fuzzers emphasize rule boundaries, parser edge cases, and random state paths
;       * all-bot fuzzer tables can run accelerated Bot Lab shakes for regression testing
;       * Ctrl+Shift+B copies bot diagnostics to clipboard; Ctrl+Shift+T includes bot-search smoke tests
;     v4.5 Human-vs-Human behavior remains the baseline when all seats are Human.
;   - v4.6.1 makes Ctrl+Shift+B copy the full bot diagnostic report to the
;     Windows clipboard and shows only a short confirmation popup.
;   - v4.6.2 hardens bot challenge/search reliability after live testing:
;       * caches the exact Equation a bot found before calling NOW, so it cannot
;         lose a justified challenge merely because a second random search fails
;       * Very Hard Third Party decisions reuse the Equation that justified writing
;       * bot-built expression trees carry an independently calculated value
;       * bot search requires that independent value to equal the Goal before the
;         ordinary v4.5 referee checker is allowed to accept the candidate
;       * Ctrl+Shift+T adds cache and high-power/root sanity regressions
;   - v4.6.4 fixes real AutoHotkey integer overflow in exponentiation:
;       * SafePower forces floating-point arithmetic so large integer powers do not wrap to 0
;       * large values are formatted without overflowing Round()
;       * Ctrl+Shift+T verifies 8^30 against its known magnitude and the 32nd root of 0
;
;   - v4.6.3 corrects the v4.6.2 high-power/root self-test:
;       * the regression now tests the arithmetic primitives directly instead of
;         requiring the ambiguity-aware parser to expose exactly one internal result
;       * no game-rule, parser, checker, timer, scoring, or bot decision logic changed
;
; The checker accepts:
;   +  -  x  /  ^  sqrt
;   parentheses (), brackets [], or braces {}
;   Unicode multiplication/division/radical symbols are normalized.
;
; Examples:
;   (5x5)+8-1
;   (6x6)+1
;   3sqrt8       ; cube notation for cube root of 8
;   sqrt9        ; square root of 9
;   (2+1)sqrt8   ; cube root of 8
;
; Important EQUATIONS behavior:
;   Ordinary mathematical order of operations is NOT assumed. The parser
;   considers all legal parenthesizations that are not fixed by grouping.
;   If one legal interpretation of a Solution fails to equal the Goal, the
;   Solution is rejected as ambiguous, matching EQUATIONS checking practice.
;
; Standard cube faces used here:
;   Red   : 0 1 2 3 + -
;   Blue  : 0 1 2 3 x /
;   Green : 4 5 6 - x ^
;   Black : 7 8 9 sqrt + /
; ============================================================================

; ------------------------------ GLOBAL STATE -------------------------------

global PlayerCount := 0
global Players := []
global PlayerTypes := []
global Division := "Middle"

; v4.6 controller / bot state. Human is the default so existing hot-seat setup
; behaves exactly like v4.5 unless a bot type is explicitly selected.
global BotThinking := false
global BotActionSerial := 0
global BotChallengeCheckedSerial := 0
global BotDelayMs := 650
global BotAutoRun := false
global BotAutoRunMaxShakes := 20
global BotAutoRunFinished := false
global BotSearchTrialsPractice := 220
global BotSearchTrialsHard := 1800
global BotSearchTrialsFuzzer := 500
global BotSearchAttemptsLast := 0
global BotSearchSuccesses := 0
global BotSearchFailures := 0
global BotDiagnosticLines := []
global BotCachedEquationEntries := Map()
global Totals := []
global ShakeDelta := []
global MatchPoints := []

global GoalSetter := 0
global CurrentPlayer := 0
global LastMover := 0
global LastAction := ""
global Phase := "Setup"
global ShakeNumber := 0

global Cubes := []
global GoalOrder := []
global SelectedCube := 0
global GoalPhysicalExpr := ""
global GoalWasGrouped := false
global BonusUsedThisTurn := false

global ColorFaces := Map(
    "Red",   ["0", "1", "2", "3", "+", "-"],
    "Blue",  ["0", "1", "2", "3", "x", "/"],
    "Green", ["4", "5", "6", "-", "x", "^"],
    "Black", ["7", "8", "9", "sqrt", "+", "/"]
)

; Tournament play uses six cubes of each color. v4.5 makes all 24 physical
; tournament cubes explicit, but deliberately preserves the exact v4.4 per-color
; face tables until a current authoritative per-face equipment chart is available.
; This improves testability without inventing a new roll distribution.
global PhysicalCubeFaces := Map(
    "Red",   [
        ["0", "1", "2", "3", "+", "-"], ["0", "1", "2", "3", "+", "-"],
        ["0", "1", "2", "3", "+", "-"], ["0", "1", "2", "3", "+", "-"],
        ["0", "1", "2", "3", "+", "-"], ["0", "1", "2", "3", "+", "-"]
    ],
    "Blue",  [
        ["0", "1", "2", "3", "x", "/"], ["0", "1", "2", "3", "x", "/"],
        ["0", "1", "2", "3", "x", "/"], ["0", "1", "2", "3", "x", "/"],
        ["0", "1", "2", "3", "x", "/"], ["0", "1", "2", "3", "x", "/"]
    ],
    "Green", [
        ["4", "5", "6", "-", "x", "^"], ["4", "5", "6", "-", "x", "^"],
        ["4", "5", "6", "-", "x", "^"], ["4", "5", "6", "-", "x", "^"],
        ["4", "5", "6", "-", "x", "^"], ["4", "5", "6", "-", "x", "^"]
    ],
    "Black", [
        ["7", "8", "9", "sqrt", "+", "/"], ["7", "8", "9", "sqrt", "+", "/"],
        ["7", "8", "9", "sqrt", "+", "/"], ["7", "8", "9", "sqrt", "+", "/"],
        ["7", "8", "9", "sqrt", "+", "/"], ["7", "8", "9", "sqrt", "+", "/"]
    ]
)

global ColorShort := Map("Red", "R", "Blue", "B", "Green", "G", "Black", "K")
global LogLines := []

; Parsing limits prevent a pathological expression from generating millions
; of possible parenthesizations. Normal EQUATIONS Solutions are far below it.
global ParseResultLimit := 6000

; ------------------------------- GUI GLOBALS -------------------------------

global MainGui := 0
global ScoreText := 0
global StatusText := 0
global ResourcesText := 0
global SelectedText := 0

global CubeButtons := []
global GoalZoneBtn := 0
global RequiredZoneBtn := 0
global PermittedZoneBtn := 0
global ForbiddenZoneBtn := 0
global ZoneLabels := Map()
global ZoneCountTexts := Map()
global SolutionMatText := 0
global GoalGroupingEdit := 0

global FinishGoalBtn := 0
global GoalLeftBtn := 0
global GoalRightBtn := 0
global BonusBtn := 0
global NoGoalBtn := 0

global ChallengeDDL := 0
global NowBtn := 0
global ImpossibleBtn := 0
global ForceoutBtn := 0
global PenaltyBtn := 0
global NextShakeBtn := 0
global EndMatchBtn := 0
global HistoryBtn := 0

global LogEdit := 0

global ZoneOrder := Map("Required", [], "Permitted", [], "Forbidden", [])
global CubeColors := Map(
    "Red", "C74343",
    "Blue", "356DB8",
    "Green", "2F8B57",
    "Black", "303238"
)
global CubeTextColors := Map(
    "Red", "FFFFFF",
    "Blue", "FFFFFF",
    "Green", "FFFFFF",
    "Black", "F5D76E"
)

global TimerText := 0
global TimerPurposeText := 0
global OneMinBtn := 0
global TwoMinBtn := 0
global ResetTimerBtn := 0
global TimerRemaining := 0
global TimerRunning := false
global TimerPurpose := "Manual timer"
global TimerOwner := 0
global TimerRuleManaged := false
global TimerPenaltyEligible := false
global TimerPenaltyStage := 0
global TimerGraceRemaining := 0
global TimerTaskToken := 0
global ForceoutStartTick := 0

; --------------------------------- START -----------------------------------

if !SetupPlayers()
    ExitApp()

BuildGui()
GoalSetter := DetermineFirstGoalSetter()

 ; Show the stable v4.0 board, then render the first shake.
MainGui.Show("w1320 h900")
StartShake(false)
ScheduleBotController()
return

; ============================================================================
; PLAYER / MATCH SETUP
; ============================================================================

SetupPlayers() {
    global PlayerCount, Players, PlayerTypes, Division, Totals, ShakeDelta, MatchPoints
    global BotAutoRun, BotAutoRunMaxShakes, BotDelayMs

    loop {
        result := InputBox(
            "Enter the number of players.`n`nOfficial EQUATIONS matches use 2 or 3 players.",
            "EQUATIONS - Players",
            "w410 h175",
            "3"
        )

        if (result.Result != "OK")
            return false

        value := Trim(result.Value)
        if RegExMatch(value, "^[23]$") {
            PlayerCount := value + 0
            break
        }

        MsgBox("Please enter only 2 or 3.", "Invalid player count")
    }

    loop {
        divResult := InputBox(
            "Choose the tournament division.`n`nElementary  = E`nMiddle      = M`nJunior      = J`nSenior      = S`n`nMiddle is the default and preserves the v4.4 Basic parser behavior.",
            "EQUATIONS - Division",
            "w430 h245",
            "Middle"
        )

        if (divResult.Result != "OK")
            return false

        value := StrLower(Trim(divResult.Value))
        if (value = "e" || value = "elementary") {
            Division := "Elementary"
            break
        }
        if (value = "m" || value = "middle") {
            Division := "Middle"
            break
        }
        if (value = "j" || value = "junior") {
            Division := "Junior"
            break
        }
        if (value = "s" || value = "senior") {
            Division := "Senior"
            break
        }

        MsgBox("Enter Elementary, Middle, Junior, Senior, or E/M/J/S.", "Invalid division")
    }

    Players := []
    PlayerTypes := []

    loop PlayerCount {
        i := A_Index
        nameResult := InputBox(
            "Enter Player " . i . "'s name:",
            "EQUATIONS - Player " . i,
            "w410 h150",
            "Player " . i
        )

        if (nameResult.Result != "OK")
            return false

        name := Trim(nameResult.Value)
        if (name = "")
            name := "Player " . i

        loop {
            typeResult := InputBox(
                "Choose Player " . i . "'s controller:`n`n"
                . "H = Human`n"
                . "P = Practice Bot`n"
                . "V = Very Hard Bot`n"
                . "R = Rules Fuzzer`n"
                . "F = Parser Fuzzer`n"
                . "C = Chaos Fuzzer`n`n"
                . "Human is the default and preserves normal v4.5 hot-seat play.",
                "EQUATIONS - Player " . i . " Type",
                "w455 h310",
                "Human"
            )

            if (typeResult.Result != "OK")
                return false

            playerType := NormalizePlayerType(typeResult.Value)
            if (playerType != "")
                break

            MsgBox("Enter Human, Practice, Very Hard, Rules Fuzzer, Parser Fuzzer, Chaos Fuzzer, or H/P/V/R/F/C.", "Invalid player type")
        }

        if (name = "Player " . i && playerType != "Human")
            name := BotTypeLabel(playerType) . " " . i

        Players.Push(name)
        PlayerTypes.Push(playerType)
    }

    Totals := []
    ShakeDelta := []
    MatchPoints := []

    loop PlayerCount {
        Totals.Push(0)
        ShakeDelta.Push(0)
        MatchPoints.Push(0)
    }

    ; If every seat is automated, offer a fast regression-lab mode. It does
    ; not alter legal move/checker logic; it only removes human pacing/dialogs
    ; between shakes so fuzzers can traverse many states quickly.
    allBots := true
    loop PlayerCount {
        if (PlayerTypes[A_Index] = "Human") {
            allBots := false
            break
        }
    }

    BotAutoRun := false
    BotDelayMs := 650

    if allBots {
        answer := MsgBox(
            "Every seat is a bot.`n`nRun accelerated BOT LAB mode?`n`nYES = fast automated shakes with result dialogs suppressed.`nNO = normal visible tournament pacing.",
            "EQUATIONS - Bot Lab",
            "YesNo"
        )

        if (answer = "Yes") {
            BotAutoRun := true
            BotDelayMs := 30

            limitResult := InputBox(
                "How many shakes should Bot Lab run before stopping?`n`nEnter 1-500.",
                "EQUATIONS - Bot Lab Limit",
                "w420 h175",
                "20"
            )

            if (limitResult.Result = "OK" && RegExMatch(Trim(limitResult.Value), "^\d+$")) {
                requested := Trim(limitResult.Value) + 0
                BotAutoRunMaxShakes := Max(1, Min(500, requested))
            }
        }
    }

    return true
}

; ============================================================================
; v4.6 CONTROLLER / BOT LAYER
; ============================================================================

NormalizePlayerType(value) {
    v := StrLower(Trim(value))

    if (v = "h" || v = "human")
        return "Human"
    if (v = "p" || v = "practice" || v = "practice bot")
        return "Practice Bot"
    if (v = "v" || v = "very hard" || v = "very hard bot" || v = "hard" || v = "hard bot")
        return "Very Hard Bot"
    if (v = "r" || v = "rules" || v = "rules fuzzer")
        return "Rules Fuzzer"
    if (v = "f" || v = "parser" || v = "parser fuzzer" || v = "math fuzzer")
        return "Parser Fuzzer"
    if (v = "c" || v = "chaos" || v = "chaos fuzzer")
        return "Chaos Fuzzer"

    return ""
}

BotTypeLabel(playerType) {
    if (playerType = "Practice Bot")
        return "Practice Bot"
    if (playerType = "Very Hard Bot")
        return "Very Hard Bot"
    if (playerType = "Rules Fuzzer")
        return "Rules Fuzzer"
    if (playerType = "Parser Fuzzer")
        return "Parser Fuzzer"
    if (playerType = "Chaos Fuzzer")
        return "Chaos Fuzzer"
    return "Human"
}

PlayerTypeName(player) {
    global PlayerTypes

    if (player < 1 || player > PlayerTypes.Length)
        return "Human"
    return PlayerTypes[player]
}

IsBotPlayer(player) {
    return (player > 0 && PlayerTypeName(player) != "Human")
}

IsFuzzerPlayer(player) {
    t := PlayerTypeName(player)
    return (t = "Rules Fuzzer" || t = "Parser Fuzzer" || t = "Chaos Fuzzer")
}

AllPlayersBots() {
    global PlayerCount

    loop PlayerCount {
        if !IsBotPlayer(A_Index)
            return false
    }
    return true
}

MarkBotChallengeWindow() {
    global BotActionSerial, BotChallengeCheckedSerial
    global BotCachedEquationEntries

    BotActionSerial += 1
    BotChallengeCheckedSerial := 0
    BotCachedEquationEntries := Map()
}

ScheduleBotController(delay := 0) {
    global BotDelayMs

    if (delay <= 0)
        delay := BotDelayMs

    SetTimer(BotControllerTick, 0)
    SetTimer(BotControllerTick, -delay)
}

BotControllerTick(*) {
    global BotThinking, Phase, GoalSetter, CurrentPlayer, LastMover
    global BotActionSerial, BotChallengeCheckedSerial
    global BotAutoRun, BotAutoRunMaxShakes, BotAutoRunFinished, ShakeNumber

    if BotThinking
        return

    BotThinking := true
    try {
        if (Phase = "GoalSetting") {
            if IsBotPlayer(GoalSetter)
                BotTakeGoalTurn(GoalSetter)
            return
        }

        if (Phase = "Play") {
            ; Every new Mover action creates exactly one automated challenge
            ; window. This prevents bots from repeatedly challenging the same move.
            if (LastMover > 0 && BotActionSerial > 0 && BotChallengeCheckedSerial != BotActionSerial) {
                BotChallengeCheckedSerial := BotActionSerial
                if BotTryChallengeLastMove()
                    return
            }

            if (CurrentPlayer > 0 && IsBotPlayer(CurrentPlayer))
                BotTakePlayTurn(CurrentPlayer)
            return
        }

        if (Phase = "Forceout") {
            if (BotAutoRun && AllPlayersBots())
                ScoreForceout()
            return
        }

        if (Phase = "BetweenShakes" && BotAutoRun && AllPlayersBots()) {
            if (ShakeNumber >= BotAutoRunMaxShakes) {
                if !BotAutoRunFinished {
                    BotAutoRunFinished := true
                    AddLog("BOT LAB reached its requested " . BotAutoRunMaxShakes . " shake limit.")
                    MsgBox(
                        "BOT LAB completed " . BotAutoRunMaxShakes . " automated shakes.`n`n"
                        . "Open History or press Ctrl+Shift+B for diagnostics. The match is paused between shakes so you can inspect it.",
                        "EQUATIONS - Bot Lab complete"
                    )
                }
                return
            }

            NextShake()
            return
        }
    } finally {
        BotThinking := false
    }
}

BotTakeGoalTurn(player) {
    global Phase, GoalSetter, SelectedCube, GoalGroupingEdit, BotAutoRun, ShakeNumber

    if (Phase != "GoalSetting" || player != GoalSetter)
        return

    candidate := BotChooseGoalCandidate(player)
    if !candidate.OK {
        AddLog(PlayerName(player) . " bot could not build a candidate Goal; using a safe single-digit fallback.")
        candidate := BotSingleDigitGoalFallback()
    }

    if !candidate.OK {
        AddLog(PlayerName(player) . " bot found no usable Goal cube.")
        if BotAutoRun {
            ; Treat an all-bot impossible-to-set position as an agreed NO GOAL
            ; reroll. This keeps stress testing from deadlocking on an extreme roll.
            ShakeNumber -= 1
            AddLog("BOT LAB treats the position as agreed NO GOAL and rerolls with the same Goal-setter.")
            StartShake(false)
        }
        return
    }

    AddBotDiagnostic(PlayerName(player) . " sets candidate Goal " . candidate.Expr . " using " . candidate.Indices.Length . " cube(s).")

    for _, idx in candidate.Indices {
        if (Phase != "GoalSetting")
            return
        SelectedCube := idx
        PlaceSelected("Goal")
    }

    GoalGroupingEdit.Value := (candidate.Indices.Length > 1) ? candidate.Expr : ""
    LockGoal()
}

BotChooseGoalCandidate(player) {
    global Cubes

    playerType := PlayerTypeName(player)
    resources := BotIndicesInZone("Resources")

    if (resources.Length = 0)
        return {OK: false}

    ; Chaos occasionally creates an intentionally illegal Goal when the exact
    ; physical faces exist. This is useful for exercising v4.4's automatic
    ; immediate-IMPOSSIBLE illegal-Goal adjudication.
    if (playerType = "Chaos Fuzzer" && Random(1, 100) <= 18) {
        bad := BotGoalFromFacePattern(["8", "/", "0"])
        if bad.OK {
            bad.Expr := "8/0"
            bad.Value := 0
            return bad
        }
    }

    ; Parser Fuzzer prefers radical/power Goals when the current roll allows it.
    if (playerType = "Parser Fuzzer") {
        patterns := [
            ["sqrt", "9"], ["sqrt", "4"], ["3", "sqrt", "8"],
            ["2", "^", "3"], ["3", "^", "2"]
        ]
        for _, pattern in patterns {
            special := BotGoalFromFacePattern(pattern)
            if special.OK {
                analysis := ParseExpression(special.Expr, "Goal")
                if (analysis.OK && analysis.Results.Length = 1) {
                    special.Value := analysis.Results[1].Value
                    return special
                }
            }
        }
    }

    minCubes := 1
    maxCubes := 3
    candidateTrials := 45
    requireSolvable := true
    solutionTrials := 120

    if (playerType = "Very Hard Bot") {
        minCubes := 2
        maxCubes := 5
        candidateTrials := 90
        solutionTrials := 320
    } else if (playerType = "Rules Fuzzer") {
        minCubes := 3
        maxCubes := 6
        candidateTrials := 100
        solutionTrials := 120
    } else if (playerType = "Parser Fuzzer") {
        minCubes := 2
        maxCubes := 5
        candidateTrials := 90
        solutionTrials := 100
    } else if (playerType = "Chaos Fuzzer") {
        minCubes := 1
        maxCubes := 6
        candidateTrials := 80
        solutionTrials := 80
        requireSolvable := (Random(1, 100) <= 70)
    }

    best := {OK: false}
    bestScore := -1000000

    loop candidateTrials {
        count := Random(minCubes, Min(maxCubes, resources.Length))
        picked := BotRandomDistinct(resources, count)
        candidate := BotBuildGoalCandidate(picked)
        if !candidate.OK
            continue

        remaining := BotArrayWithout(resources, candidate.Indices)
        solution := BotFindExpressionToTarget(remaining, candidate.Value, solutionTrials, 2, 8)
        solvable := solution.OK

        if (requireSolvable && !solvable)
            continue

        score := candidate.Indices.Length * 4
        if solvable
            score += 20

        ; Practice prefers smaller/easier Goals. Hard/fuzzers prefer more structure.
        if (playerType = "Practice Bot")
            score := 40 - (candidate.Indices.Length * 6) + (solvable ? 10 : 0)
        else if (playerType = "Very Hard Bot")
            score += BotGoalComplexity(candidate.Expr)
        else if (playerType = "Rules Fuzzer")
            score += candidate.Indices.Length * 3
        else if (playerType = "Parser Fuzzer")
            score += (InStr(candidate.Expr, "sqrt") || InStr(candidate.Expr, "^")) ? 12 : 0
        else if (playerType = "Chaos Fuzzer")
            score += Random(-15, 15)

        if (score > bestScore) {
            best := candidate
            bestScore := score
        }
    }

    if best.OK
        return best

    return BotSingleDigitGoalFallback()
}

BotSingleDigitGoalFallback() {
    global Cubes

    resources := BotIndicesInZone("Resources")
    digitIndices := []
    for _, idx in resources {
        if IsDigitFace(Cubes[idx].Face)
            digitIndices.Push(idx)
    }

    if (digitIndices.Length = 0)
        return {OK: false}

    ; Prefer a one-cube Goal for which the bounded search can already exhibit
    ; a different-cube Solution. This makes the safety fallback useful for
    ; Practice/Hard rather than merely choosing a random digit.
    shuffled := BotShuffledCopy(digitIndices)
    for _, idx in shuffled {
        remaining := BotArrayWithout(resources, [idx])
        target := Cubes[idx].Face + 0
        if BotFindExpressionToTarget(remaining, target, 220, 2, 7).OK
            return {OK: true, Expr: Cubes[idx].Face, Value: target, Indices: [idx]}
    }

    idx := shuffled[1]
    return {OK: true, Expr: Cubes[idx].Face, Value: Cubes[idx].Face + 0, Indices: [idx]}
}

BotGoalFromFacePattern(faces) {
    global Cubes

    available := BotIndicesInZone("Resources")
    used := Map()
    indices := []

    for _, face in faces {
        found := 0
        for _, idx in available {
            if used.Has(idx)
                continue
            if (Cubes[idx].Face = face) {
                found := idx
                break
            }
        }

        if !found
            return {OK: false}

        used[found] := true
        indices.Push(found)
    }

    expr := BotFacesToSimpleExpression(faces)
    return {OK: true, Expr: expr, Indices: indices, Value: 0}
}

BotFacesToSimpleExpression(faces) {
    if (faces.Length = 1)
        return faces[1]

    if (faces.Length = 2 && faces[1] = "sqrt")
        return "sqrt(" . faces[2] . ")"

    if (faces.Length = 3) {
        if (faces[2] = "sqrt")
            return "(" . faces[1] . ")sqrt(" . faces[3] . ")"
        return "(" . faces[1] . faces[2] . faces[3] . ")"
    }

    out := ""
    for _, face in faces
        out .= face
    return out
}

BotBuildGoalCandidate(indices) {
    exprResult := BotBuildExpressionFromIndices(indices)
    if !exprResult.OK
        return {OK: false}

    analysis := ParseExpression(exprResult.Expr, "Goal")
    if (!analysis.OK || analysis.Results.Length != 1)
        return {OK: false}

    tokenInfo := TokenizeExpression(exprResult.Expr, "Goal")
    if !tokenInfo.OK
        return {OK: false}

    orderedIndices := BotMapFacesToIndices(tokenInfo.Faces, indices)
    if (orderedIndices.Length != tokenInfo.Faces.Length)
        return {OK: false}

    return {
        OK: true,
        Expr: exprResult.Expr,
        Value: analysis.Results[1].Value,
        Indices: orderedIndices
    }
}

BotGoalComplexity(expr) {
    score := 0
    score += StrLen(expr)
    if InStr(expr, "sqrt")
        score += 8
    if InStr(expr, "^")
        score += 8
    if InStr(expr, "/")
        score += 4
    return score
}

BotTakePlayTurn(player) {
    global Phase, CurrentPlayer, SelectedCube, Cubes, BonusUsedThisTurn

    if (Phase != "Play" || player != CurrentPlayer)
        return

    playerType := PlayerTypeName(player)
    resources := BotIndicesInZone("Resources")
    if (resources.Length = 0)
        return

    ; Some bots exercise BONUS, but only through the existing legal BONUS path.
    if (!BonusUsedThisTurn && ResourceCount() > 1 && CanBonus(player)) {
        bonusChance := 0
        if (playerType = "Practice Bot")
            bonusChance := 8
        else if (playerType = "Very Hard Bot")
            bonusChance := 16
        else if (playerType = "Rules Fuzzer")
            bonusChance := 45
        else if (playerType = "Parser Fuzzer")
            bonusChance := 12
        else if (playerType = "Chaos Fuzzer")
            bonusChance := 30

        if (Random(1, 100) <= bonusChance) {
            SelectedCube := resources[Random(1, resources.Length)]
            BonusSelected()
            return
        }
    }

    move := (playerType = "Very Hard Bot") ? BotChooseHardMove(player) : BotChooseOrdinaryMove(player)
    if !move.OK
        return

    SelectedCube := move.Index
    AddBotDiagnostic(PlayerName(player) . " chooses " . CubeCode(Cubes[move.Index]) . " -> " . move.Zone . ".")
    PlaceSelected(move.Zone)
}

BotChooseOrdinaryMove(player) {
    global Cubes

    playerType := PlayerTypeName(player)
    resources := BotIndicesInZone("Resources")
    if (resources.Length = 0)
        return {OK: false}

    idx := resources[Random(1, resources.Length)]

    if (resources.Length = 1) {
        zone := (Random(1, 100) <= 55) ? "Required" : "Permitted"
        return {OK: true, Index: idx, Zone: zone}
    }

    roll := Random(1, 100)
    if (playerType = "Practice Bot") {
        zone := (roll <= 38) ? "Required" : (roll <= 78 ? "Permitted" : "Forbidden")
    } else if (playerType = "Rules Fuzzer") {
        ; Push rule boundaries: lots of Required/Forbidden, while keeping the
        ; final-cube restriction delegated to PlaceSelected.
        zone := (roll <= 46) ? "Required" : (roll <= 62 ? "Permitted" : "Forbidden")
    } else if (playerType = "Parser Fuzzer") {
        zone := (roll <= 52) ? "Required" : (roll <= 88 ? "Permitted" : "Forbidden")
    } else {
        zone := (roll <= 34) ? "Required" : (roll <= 67 ? "Permitted" : "Forbidden")
    }

    return {OK: true, Index: idx, Zone: zone}
}

BotChooseHardMove(player) {
    global Cubes

    resources := BotIndicesInZone("Resources")
    if (resources.Length = 0)
        return {OK: false}

    if (resources.Length = 1)
        return {OK: true, Index: resources[1], Zone: "Required"}

    sampleCount := Min(resources.Length, 8)
    sample := BotRandomDistinct(resources, sampleCount)
    best := {OK: false}
    bestScore := -1000000

    for _, idx in sample {
        for _, zone in ["Required", "Permitted", "Forbidden"] {
            if (resources.Length = 1 && zone = "Forbidden")
                continue

            oldZone := Cubes[idx].Zone
            Cubes[idx].Zone := zone
            probe := BotFindBoardEquation("IMPOSSIBLE", 65)
            Cubes[idx].Zone := oldZone

            score := probe.Submitted ? 20 : -35
            if (zone = "Required")
                score += 8
            else if (zone = "Forbidden")
                score += 6
            else
                score += 2

            face := Cubes[idx].Face
            if (zone = "Forbidden" && (face = "sqrt" || face = "^" || face = "/"))
                score += 4
            if (zone = "Required" && IsDigitFace(face))
                score += 2

            score += Random(-2, 2)

            if (score > bestScore) {
                bestScore := score
                best := {OK: true, Index: idx, Zone: zone}
            }
        }
    }

    if best.OK
        return best
    return BotChooseOrdinaryMove(player)
}

BotTryChallengeLastMove() {
    global PlayerCount, LastMover, LastAction, ChallengeDDL, Phase

    if (LastMover <= 0 || (Phase != "Play" && Phase != "Forceout"))
        return false

    ; First give bot opponents a chance to catch an illegal Goal exactly as a
    ; human would: by calling IMPOSSIBLE after GOAL, not by receiving a warning.
    if (LastAction = "set the Goal") {
        legality := AnalyzeCurrentGoalLegality()
        if (legality.Known && !legality.Legal) {
            loop PlayerCount {
                p := A_Index
                if (p = LastMover || !IsBotPlayer(p))
                    continue

                t := PlayerTypeName(p)
                catchChance := (t = "Practice Bot") ? 70 : 100
                if (Random(1, 100) <= catchChance) {
                    ChallengeDDL.Choose(p)
                    AddBotDiagnostic(PlayerName(p) . " detects an illegal Goal and calls IMPOSSIBLE.")
                    StartChallenge("IMPOSSIBLE")
                    return true
                }
            }
        }
    }

    if (Phase != "Play")
        return false

    nowLegal := (ResourceCount() >= 2 && (CountZone("Required") + CountZone("Permitted") > 0))

    loop PlayerCount {
        p := A_Index
        if (p = LastMover || !IsBotPlayer(p))
            continue

        t := PlayerTypeName(p)

        if nowLegal {
            chance := 0
            trials := 0

            if (t = "Practice Bot") {
                chance := 24
                trials := 180
            } else if (t = "Very Hard Bot") {
                chance := 100
                trials := 900
            } else if (t = "Rules Fuzzer") {
                chance := (ResourceCount() <= 3) ? 85 : 38
                trials := 300
            } else if (t = "Parser Fuzzer") {
                chance := 58
                trials := 260
            } else if (t = "Chaos Fuzzer") {
                chance := 30
                trials := 180
            }

            if (Random(1, 100) <= chance) {
                found := BotFindBoardEquation("NOW", trials)
                if found.Submitted || t = "Parser Fuzzer" || (t = "Chaos Fuzzer" && Random(1, 100) <= 25) {
                    if found.Submitted
                        BotCacheEquation(p, "NOW", found)
                    ChallengeDDL.Choose(p)
                    AddBotDiagnostic(PlayerName(p) . " calls NOW" . (found.Submitted ? " after finding and caching a candidate Equation." : " as a fuzzer probe."))
                    StartChallenge("NOW")
                    return true
                }
            }
        }

        ; Rules/Chaos fuzzers occasionally make a legal IMPOSSIBLE challenge to
        ; exercise scoring/checking even when they have not proved impossibility.
        ; This is deliberate adversarial testing, not claimed optimal play.
        if ((t = "Rules Fuzzer" && Random(1, 100) <= 5) || (t = "Chaos Fuzzer" && Random(1, 100) <= 8)) {
            ChallengeDDL.Choose(p)
            AddBotDiagnostic(PlayerName(p) . " makes an adversarial IMPOSSIBLE test challenge.")
            StartChallenge("IMPOSSIBLE")
            return true
        }
    }

    return false
}

GetEquationEntry(player, roleText, mode, manageTimer := true) {
    if !IsBotPlayer(player)
        return PromptEquation(player, roleText, manageTimer)

    return BotGenerateEquationEntry(player, mode)
}

GetNoGoalEquationEntry(player, roleText) {
    if !IsBotPlayer(player)
        return PromptNoGoalEquation(player, roleText)

    return BotGenerateNoGoalEquationEntry(player)
}

BotGenerateEquationEntry(player, mode) {
    global BotSearchTrialsPractice, BotSearchTrialsHard, BotSearchTrialsFuzzer

    cached := BotTakeCachedEquation(player, mode)
    if cached.Found {
        AddBotDiagnostic(PlayerName(player) . " presents the cached " . mode . " Equation: " . cached.Entry.Solution . " = " . cached.Entry.Goal)
        return cached.Entry
    }

    playerType := PlayerTypeName(player)

    if (playerType = "Parser Fuzzer") {
        if (Random(1, 100) <= 62)
            return BotParserFuzzEntry()
        return BotFindBoardEquation(mode, BotSearchTrialsFuzzer)
    }

    if (playerType = "Chaos Fuzzer" && Random(1, 100) <= 35)
        return BotParserFuzzEntry()

    trials := BotSearchTrialsPractice
    if (playerType = "Very Hard Bot")
        trials := BotSearchTrialsHard
    else if (playerType = "Rules Fuzzer" || playerType = "Chaos Fuzzer")
        trials := BotSearchTrialsFuzzer

    entry := BotFindBoardEquation(mode, trials)
    if entry.Submitted
        AddBotDiagnostic(PlayerName(player) . " found " . mode . " Equation: " . entry.Solution . " = " . entry.Goal)
    else
        AddBotDiagnostic(PlayerName(player) . " found no " . mode . " Equation inside its bounded search budget.")

    return entry
}

BotParserFuzzEntry() {
    goal := BotFirstLegalGoalInterpretation()
    if !goal.OK
        return {Submitted: false, Solution: "", Goal: ""}

    expressions := [
        "0^0", "8/0", "sqrt5", "3sqrt9", "4^(1/2)",
        "(2-5)^4", "sqrt(sqrt(9))", "2^(3^2)",
        "((2+3)x4)", "sqrt(2+7)", "3sqrt(1+7)",
        "(((1+2)x3)-4)", "(9/(3-3))"
    ]

    expr := expressions[Random(1, expressions.Length)]
    return {Submitted: true, Solution: expr, Goal: goal.Expr}
}

BotGenerateNoGoalEquationEntry(player) {
    playerType := PlayerTypeName(player)

    if (playerType = "Parser Fuzzer" && Random(1, 100) <= 50)
        return {Submitted: true, Solution: "8/0", Goal: "0"}

    trials := (playerType = "Very Hard Bot") ? 1200 : 360
    return BotFindNoGoalEquation(trials)
}

BotThirdPartyWillWrite(player, context) {
    playerType := PlayerTypeName(player)

    if (playerType = "Very Hard Bot") {
        mode := InStr(context, "NOW") ? "NOW" : (InStr(context, "IMPOSSIBLE") ? "IMPOSSIBLE" : "")
        if (mode != "") {
            found := BotFindBoardEquation(mode, 420)
            if found.Submitted {
                BotCacheEquation(player, mode, found)
                return true
            }
            return false
        }
        return true
    }

    if (playerType = "Practice Bot")
        return (Random(1, 100) <= 50)
    if (playerType = "Rules Fuzzer")
        return (Random(1, 100) <= 70)
    if (playerType = "Parser Fuzzer")
        return true
    if (playerType = "Chaos Fuzzer")
        return (Random(1, 100) <= 50)

    return false
}

BotFindBoardEquation(mode, trials := 400) {
    global Cubes, BotSearchAttemptsLast, BotSearchSuccesses, BotSearchFailures

    goals := BotLegalGoalInterpretations()
    if (goals.Length = 0) {
        BotSearchFailures += 1
        return {Submitted: false, Solution: "", Goal: ""}
    }

    required := BotIndicesInZone("Required")
    permitted := BotIndicesInZone("Permitted")
    resources := BotIndicesInZone("Resources")

    if (mode = "FORCEOUT")
        resources := []

    BotSearchAttemptsLast := 0

    loop trials {
        BotSearchAttemptsLast := A_Index
        selected := BotCopyArray(required)

        totalUsable := required.Length + permitted.Length + resources.Length
        maxTotal := Min(9, totalUsable)
        if (maxTotal < required.Length)
            maxTotal := required.Length
        if (maxTotal < 2)
            maxTotal := 2
        desiredMin := Max(2, selected.Length)
        if (desiredMin > maxTotal)
            desiredMin := maxTotal
        desired := Random(desiredMin, maxTotal)

        permCopy := BotShuffledCopy(permitted)
        for _, idx in permCopy {
            if (selected.Length >= desired)
                break
            if (Random(1, 100) <= 62)
                selected.Push(idx)
        }

        resourceCap := (mode = "NOW") ? 1 : 5
        usedResources := 0
        resCopy := BotShuffledCopy(resources)
        for _, idx in resCopy {
            if (selected.Length >= desired || usedResources >= resourceCap)
                break
            if (Random(1, 100) <= 58) {
                selected.Push(idx)
                usedResources += 1
            }
        }

        ; If Required alone has fewer than two cubes, fill from legal optional pools.
        if (selected.Length < 2) {
            fill := BotShuffledCopy(permitted)
            for _, idx in fill {
                if !BotArrayHas(selected, idx)
                    selected.Push(idx)
                if (selected.Length >= 2)
                    break
            }
        }

        if (selected.Length < 2 && resources.Length > 0) {
            for _, idx in resources {
                if !BotArrayHas(selected, idx) {
                    selected.Push(idx)
                    usedResources += 1
                }
                if (selected.Length >= 2 || (mode = "NOW" && usedResources >= 1))
                    break
            }
        }

        if (selected.Length < 2)
            continue

        exprResult := BotBuildExpressionFromIndices(selected)
        if !exprResult.OK
            continue

        goal := goals[Random(1, goals.Length)]

        ; v4.6.2 independent bot-side arithmetic guard. BotBuildExpressionFromIndices
        ; evaluates the exact generated tree as it builds it. Require that value
        ; to match the selected Goal before asking the normal referee checker.
        if !NearlyEqual(exprResult.Value, goal.Value)
            continue

        entry := {Submitted: true, Solution: exprResult.Expr, Goal: goal.Expr}
        checked := CheckBoardEquation(entry, mode)
        if checked.Correct {
            BotSearchSuccesses += 1
            return entry
        }
    }

    BotSearchFailures += 1
    return {Submitted: false, Solution: "", Goal: ""}
}

BotFindExpressionToTarget(poolIndices, target, trials := 300, minCubes := 2, maxCubes := 8) {
    if (poolIndices.Length < minCubes)
        return {OK: false}

    upper := Min(maxCubes, poolIndices.Length)
    lower := Min(minCubes, upper)

    loop trials {
        count := Random(lower, upper)
        selected := BotRandomDistinct(poolIndices, count)
        built := BotBuildExpressionFromIndices(selected)
        if !built.OK
            continue

        if !NearlyEqual(built.Value, target)
            continue

        analysis := ParseExpression(built.Expr, "Solution")
        if !analysis.OK
            continue

        allMatch := true
        for _, result in analysis.Results {
            if !NearlyEqual(result.Value, target) {
                allMatch := false
                break
            }
        }

        if allMatch
            return {OK: true, Expr: built.Expr, Indices: selected}
    }

    return {OK: false}
}

BotFindNoGoalEquation(trials := 500) {
    global Cubes

    resources := BotIndicesInZone("Resources")
    if (resources.Length < 3)
        return {Submitted: false, Solution: "", Goal: ""}

    loop trials {
        goalCount := Random(1, Min(4, resources.Length - 2))
        goalIndices := BotRandomDistinct(resources, goalCount)
        candidate := BotBuildGoalCandidate(goalIndices)
        if !candidate.OK
            continue

        remaining := BotArrayWithout(resources, candidate.Indices)
        solution := BotFindExpressionToTarget(remaining, candidate.Value, 100, 2, 8)
        if !solution.OK
            continue

        entry := {Submitted: true, Solution: solution.Expr, Goal: candidate.Expr}
        if CheckNoGoalEquation(entry).Correct
            return entry
    }

    return {Submitted: false, Solution: "", Goal: ""}
}

BotBuildExpressionFromIndices(indices) {
    global Cubes

    if (indices.Length = 0)
        return {OK: false, Expr: "", Value: 0}

    numbers := []
    roots := []
    otherOps := []

    for _, idx in indices {
        face := Cubes[idx].Face
        if IsDigitFace(face)
            numbers.Push(idx)
        else if (face = "sqrt")
            roots.Push(idx)
        else
            otherOps.Push(idx)
    }

    if (numbers.Length = 0)
        return {OK: false, Expr: "", Value: 0}

    binaryNeeded := numbers.Length - 1
    if (otherOps.Length > binaryNeeded)
        return {OK: false, Expr: "", Value: 0}
    if ((otherOps.Length + roots.Length) < binaryNeeded)
        return {OK: false, Expr: "", Value: 0}

    shuffledRoots := BotShuffledCopy(roots)
    binaryOps := BotCopyArray(otherOps)
    rootBinaryNeeded := binaryNeeded - otherOps.Length

    loop rootBinaryNeeded {
        binaryOps.Push(shuffledRoots.RemoveAt(1))
    }

    unaryRoots := shuffledRoots
    numbers := BotShuffledCopy(numbers)
    binaryOps := BotShuffledCopy(binaryOps)

    operands := []
    for _, idx in numbers
        operands.Push({Expr: Cubes[idx].Face, Value: Cubes[idx].Face + 0})

    ; Extra radical cubes are legal unary square roots. Apply them to randomly
    ; selected existing operands, preserving every physical cube exactly once.
    ; v4.6.2 also evaluates the generated tree independently while building it.
    for _, rootIdx in unaryRoots {
        targetPos := Random(1, operands.Length)
        calc := ApplyRoot(2, operands[targetPos].Value)
        if !calc.OK
            return {OK: false, Expr: "", Value: 0}
        operands[targetPos].Expr := "sqrt(" . operands[targetPos].Expr . ")"
        operands[targetPos].Value := calc.Value
    }

    while (operands.Length > 1) {
        operands := BotShuffledCopy(operands)
        left := operands.RemoveAt(operands.Length)
        right := operands.RemoveAt(operands.Length)
        opIdx := binaryOps.RemoveAt(binaryOps.Length)
        op := Cubes[opIdx].Face

        if (op = "sqrt") {
            calc := ApplyRoot(left.Value, right.Value)
            if !calc.OK
                return {OK: false, Expr: "", Value: 0}
            expr := "(" . left.Expr . ")sqrt(" . right.Expr . ")"
        } else {
            calc := ApplyBinary(op, left.Value, right.Value)
            if !calc.OK
                return {OK: false, Expr: "", Value: 0}
            expr := "(" . left.Expr . op . right.Expr . ")"
        }

        operands.Push({Expr: expr, Value: calc.Value})
    }

    if (binaryOps.Length != 0)
        return {OK: false, Expr: "", Value: 0}

    return {OK: true, Expr: operands[1].Expr, Value: operands[1].Value}
}

BotLegalGoalInterpretations() {
    global GoalPhysicalExpr

    out := []
    analysis := ParsePhysicalGoalExpression(GoalPhysicalExpr)
    if !analysis.OK
        return out

    seen := Map()
    for _, result in analysis.Results {
        expr := BotCanonToInput(result.Canon)
        if (expr = "" || seen.Has(expr))
            continue

        check := CheckPresentedGoal(expr)
        if check.OK {
            seen[expr] := true
            out.Push({Expr: expr, Value: check.Value})
        }
    }

    return out
}

BotFirstLegalGoalInterpretation() {
    goals := BotLegalGoalInterpretations()
    if (goals.Length = 0)
        return {OK: false, Expr: "", Value: 0}
    return {OK: true, Expr: goals[1].Expr, Value: goals[1].Value}
}

BotCanonToInput(canon) {
    s := Trim(canon)
    if (s = "")
        return ""

    if RegExMatch(s, "^\\d+$")
        return s

    if (SubStr(s, 1, 5) = "sqrt(" && SubStr(s, -1) = ")") {
        inner := SubStr(s, 6, StrLen(s) - 6)
        return "sqrt(" . BotCanonToInput(inner) . ")"
    }

    if (SubStr(s, 1, 5) = "root(" && SubStr(s, -1) = ")") {
        inner := SubStr(s, 6, StrLen(s) - 6)
        comma := BotTopLevelComma(inner)
        if !comma
            return ""
        left := SubStr(inner, 1, comma - 1)
        right := SubStr(inner, comma + 1)
        return "(" . BotCanonToInput(left) . ")sqrt(" . BotCanonToInput(right) . ")"
    }

    if BotStringOuterParensEnclose(s) {
        inner := SubStr(s, 2, StrLen(s) - 2)
        split := BotTopLevelBinaryOperator(inner)
        if split.Pos {
            left := SubStr(inner, 1, split.Pos - 1)
            right := SubStr(inner, split.Pos + 1)
            return "(" . BotCanonToInput(left) . split.Op . BotCanonToInput(right) . ")"
        }
        return "(" . BotCanonToInput(inner) . ")"
    }

    return s
}

BotTopLevelComma(s) {
    depth := 0
    loop StrLen(s) {
        ch := SubStr(s, A_Index, 1)
        if (ch = "(")
            depth += 1
        else if (ch = ")")
            depth -= 1
        else if (ch = "," && depth = 0)
            return A_Index
    }
    return 0
}

BotTopLevelBinaryOperator(s) {
    depth := 0
    loop StrLen(s) {
        ch := SubStr(s, A_Index, 1)
        if (ch = "(") {
            depth += 1
            continue
        }
        if (ch = ")") {
            depth -= 1
            continue
        }
        if (depth = 0 && (ch = "+" || ch = "-" || ch = "x" || ch = "/" || ch = "^"))
            return {Pos: A_Index, Op: ch}
    }
    return {Pos: 0, Op: ""}
}

BotStringOuterParensEnclose(s) {
    if (StrLen(s) < 2 || SubStr(s, 1, 1) != "(" || SubStr(s, -1) != ")")
        return false

    depth := 0
    loop StrLen(s) {
        ch := SubStr(s, A_Index, 1)
        if (ch = "(")
            depth += 1
        else if (ch = ")")
            depth -= 1

        if (depth = 0 && A_Index < StrLen(s))
            return false
    }
    return (depth = 0)
}

BotIndicesInZone(zone) {
    global Cubes

    out := []
    for idx, cube in Cubes {
        if (cube.Zone = zone)
            out.Push(idx)
    }
    return out
}

BotMapFacesToIndices(faces, candidates) {
    global Cubes

    out := []
    used := Map()

    for _, face in faces {
        found := 0
        for _, idx in candidates {
            if used.Has(idx)
                continue
            if (Cubes[idx].Face = face) {
                found := idx
                break
            }
        }
        if !found
            return []
        used[found] := true
        out.Push(found)
    }

    return out
}

BotRandomDistinct(arr, count) {
    copy := BotShuffledCopy(arr)
    out := []
    count := Min(count, copy.Length)
    loop count
        out.Push(copy[A_Index])
    return out
}

BotShuffledCopy(arr) {
    copy := BotCopyArray(arr)
    ShuffleArray(copy)
    return copy
}

BotCopyArray(arr) {
    out := []
    for _, value in arr
        out.Push(value)
    return out
}

BotArrayHas(arr, value) {
    for _, item in arr {
        if (item = value)
            return true
    }
    return false
}

BotArrayWithout(arr, removeArr) {
    remove := Map()
    for _, value in removeArr
        remove[value] := true

    out := []
    for _, value in arr {
        if !remove.Has(value)
            out.Push(value)
    }
    return out
}

BotCacheEquation(player, mode, entry) {
    global BotCachedEquationEntries

    if !entry.Submitted
        return

    key := player . "|" . mode
    BotCachedEquationEntries[key] := {
        Submitted: true,
        Solution: entry.Solution,
        Goal: entry.Goal
    }
}

BotTakeCachedEquation(player, mode) {
    global BotCachedEquationEntries

    key := player . "|" . mode
    if !BotCachedEquationEntries.Has(key)
        return {Found: false, Entry: {Submitted: false, Solution: "", Goal: ""}}

    entry := BotCachedEquationEntries[key]
    BotCachedEquationEntries.Delete(key)
    return {Found: true, Entry: entry}
}

AddBotDiagnostic(message) {
    global BotDiagnosticLines

    BotDiagnosticLines.Push(message)
    while (BotDiagnosticLines.Length > 120)
        BotDiagnosticLines.RemoveAt(1)

    AddLog("[BOT] " . message)
}

ShowBotDiagnostics(*) {
    global PlayerCount, Players, PlayerTypes, BotAutoRun, BotAutoRunMaxShakes
    global BotActionSerial, BotChallengeCheckedSerial, BotSearchAttemptsLast
    global BotSearchSuccesses, BotSearchFailures, BotDiagnosticLines, BotCachedEquationEntries, Phase, ShakeNumber

    seats := []
    loop PlayerCount
        seats.Push(Players[A_Index] . " = " . PlayerTypes[A_Index])

    text := "Phase: " . Phase . " | Shake: " . ShakeNumber
        . "`nBot Lab: " . (BotAutoRun ? "ON (limit " . BotAutoRunMaxShakes . ")" : "off")
        . "`nAction serial: " . BotActionSerial . " | challenge checked: " . BotChallengeCheckedSerial
        . "`nLast bounded-search attempts: " . BotSearchAttemptsLast
        . "`nSearch successes: " . BotSearchSuccesses . " | failures: " . BotSearchFailures
        . "`nCached challenge Equations waiting: " . BotCachedEquationEntries.Count
        . "`n`nSeats:`n" . JoinArray(seats, "`n")

    if (BotDiagnosticLines.Length > 0)
        text .= "`n`nRecent bot decisions:`n" . JoinArray(BotDiagnosticLines, "`n")

    A_Clipboard := text
    ClipWait(1)
    MsgBox("Bot diagnostics copied to the clipboard.`n`nPaste them with Ctrl+V.", "EQUATIONS v4.6.4 - Bot diagnostics")
}


; ============================================================================
; GUI
; ============================================================================

BuildGui() {
    global MainGui, ScoreText, StatusText, ResourcesText, SelectedText
    global CubeButtons, GoalZoneBtn, RequiredZoneBtn, PermittedZoneBtn
    global ForbiddenZoneBtn, ZoneLabels, ZoneCountTexts, SolutionMatText
    global GoalGroupingEdit, FinishGoalBtn, GoalLeftBtn, GoalRightBtn, BonusBtn, NoGoalBtn
    global ChallengeDDL, NowBtn, ImpossibleBtn, ForceoutBtn, PenaltyBtn
    global NextShakeBtn, EndMatchBtn, HistoryBtn, Players
    global CubeColors, CubeTextColors, TimerText, TimerPurposeText
    global OneMinBtn, TwoMinBtn, ResetTimerBtn

    MainGui := Gui("", "Academic Games EQUATIONS - Digital Tabletop")
    MainGui.BackColor := "F3F0E8"
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.OnEvent("Close", CloseMain)
    MainGui.OnEvent("Escape", CancelSelection)

    ; ------------------------------------------------------------------------
    ; SCORE / CURRENT TURN
    ; ------------------------------------------------------------------------
    MainGui.Add("GroupBox", "x20 y10 w1280 h72", "Match")
    ScoreText := MainGui.Add("Text", "x38 y31 w1245 h22", "")
    ScoreText.SetFont("s11 bold", "Segoe UI")
    StatusText := MainGui.Add("Text", "x38 y55 w1245 h20", "")

    ; ------------------------------------------------------------------------
    ; DIGITAL PLAYING MAT
    ; Classic visual order:
    ;   RESOURCES
    ;   FORBIDDEN | PERMITTED | REQUIRED
    ;   SOLUTION = GOAL
    ; ------------------------------------------------------------------------
    MainGui.Add("GroupBox", "x20 y90 w920 h745", "Playing Mat")

    ; ------------------------------------------------------------------------
    ; v4.0 STABLE TABLETOP LAYER
    ; ------------------------------------------------------------------------
    ; Do NOT place large filled STATIC controls underneath the cubes. Windows
    ; can repaint/hit-test overlapping STATIC siblings unpredictably. Instead
    ; the board uses thin borders plus small header strips that never overlap
    ; cube positions. The 24 cubes themselves are ordinary BUTTON controls.

    ResourcesText := 0
    AddBoardBorder(MainGui, 45, 116, 850, 210, "D8CCAA")
    resourcesHeader := MainGui.Add("Text", "x57 y126 w826 h34 BackgroundFFF3D1", "")
    resourcesLabel := MainGui.Add("Text", "x66 y132 w240 h22 BackgroundFFF3D1", "RESOURCES")
    resourcesLabel.SetFont("s13 bold", "Segoe UI")
    resourcesLabel.OnEvent("Click", CancelSelection)

    ; Middle mat zones. Header strips stop well above the first cube row.
    ZoneLabels := Map()
    ZoneCountTexts := Map()

    AddBoardBorder(MainGui, 45, 345, 270, 310, "D6B8B8")
    ForbiddenZoneBtn := MainGui.Add("Button", "x55 y353 w158 h36", "FORBIDDEN")
    ForbiddenZoneBtn.SetFont("s11 bold", "Segoe UI")
    ForbiddenZoneBtn.OnEvent("Click", PlaceSelected.Bind("Forbidden"))
    ZoneLabels["Forbidden"] := ForbiddenZoneBtn
    ZoneCountTexts["Forbidden"] := MainGui.Add("Text", "x218 y361 w78 h22 Right", "0 cubes")

    AddBoardBorder(MainGui, 335, 345, 270, 310, "B9CBE0")
    PermittedZoneBtn := MainGui.Add("Button", "x345 y353 w158 h36", "PERMITTED")
    PermittedZoneBtn.SetFont("s11 bold", "Segoe UI")
    PermittedZoneBtn.OnEvent("Click", PlaceSelected.Bind("Permitted"))
    ZoneLabels["Permitted"] := PermittedZoneBtn
    ZoneCountTexts["Permitted"] := MainGui.Add("Text", "x508 y361 w78 h22 Right", "0 cubes")

    AddBoardBorder(MainGui, 625, 345, 270, 310, "B9D3B9")
    RequiredZoneBtn := MainGui.Add("Button", "x635 y353 w158 h36", "REQUIRED")
    RequiredZoneBtn.SetFont("s11 bold", "Segoe UI")
    RequiredZoneBtn.OnEvent("Click", PlaceSelected.Bind("Required"))
    ZoneLabels["Required"] := RequiredZoneBtn
    ZoneCountTexts["Required"] := MainGui.Add("Text", "x798 y361 w78 h22 Right", "0 cubes")

    ; Bottom row resembles the physical Equation-writing relationship.
    ; No cube controls overlap the Solution area, so this can safely remain a
    ; clickable Text control.
    SolutionMatText := MainGui.Add("Text", "x45 y675 w390 h125 Border Center BackgroundF5F5F3 0x100", "SOLUTION`n`nwritten after a challenge / forceout")
    SolutionMatText.SetFont("s12 bold", "Segoe UI")
    SolutionMatText.OnEvent("Click", SolutionMatClicked)
    equalsText := MainGui.Add("Text", "x446 y716 w27 h42 Center", "=")
    equalsText.SetFont("s24 bold", "Segoe UI")

    AddBoardBorder(MainGui, 485, 675, 410, 125, "D7C29A")
    GoalZoneBtn := MainGui.Add("Button", "x495 y683 w158 h36", "GOAL")
    GoalZoneBtn.SetFont("s11 bold", "Segoe UI")
    GoalZoneBtn.OnEvent("Click", PlaceSelected.Bind("Goal"))
    ZoneLabels["Goal"] := GoalZoneBtn
    ZoneCountTexts["Goal"] := MainGui.Add("Text", "x800 y691 w77 h22 Right", "0 / 6")

    ; Real BUTTON controls are intentionally used here. They have their own
    ; native paint/click behavior and do not depend on STATIC-control overlap.
    ; The first line identifies the physical cube color; the second is its face.
    CubeButtons := []
    colors := ["Red", "Blue", "Green", "Black"]
    for row, color in colors {
        loop 6 {
            idx := ((row - 1) * 6) + A_Index
            cubeCtrl := MainGui.Add("Button", "x0 y0 w52 h52 0x2000", "") ; BS_MULTILINE
            cubeCtrl.SetFont("s11 bold", "Segoe UI")
            cubeCtrl.OnEvent("Click", CubeClicked.Bind(idx))
            CubeButtons.Push(cubeCtrl)
        }
    }

    ; ------------------------------------------------------------------------
    ; RIGHT-SIDE CONTROLS - actions kept compact so the board stays primary.
    ; ------------------------------------------------------------------------
    MainGui.Add("GroupBox", "x960 y90 w340 h215", "Turn Controls")
    MainGui.Add("Text", "x978 y116 w300 h34", "Goal grouping (optional): type grouping only when the physical Goal needs it, e.g. 3x(5+2).")
    GoalGroupingEdit := MainGui.Add("Edit", "x978 y151 w302 h29", "")

    FinishGoalBtn := MainGui.Add("Button", "x978 y190 w95 h36", "Say GOAL")
    GoalLeftBtn := MainGui.Add("Button", "x1081 y190 w46 h36", "←")
    GoalRightBtn := MainGui.Add("Button", "x1130 y190 w46 h36", "→")
    NoGoalBtn := MainGui.Add("Button", "x1184 y190 w96 h36", "NO GOAL")
    BonusBtn := MainGui.Add("Button", "x978 y236 w145 h36", "BONUS -> Forbidden")
    PenaltyBtn := MainGui.Add("Button", "x1133 y236 w147 h36", "Apply -1 Penalty")

    FinishGoalBtn.OnEvent("Click", LockGoal)
    GoalLeftBtn.OnEvent("Click", MoveSelectedGoal.Bind(-1))
    GoalRightBtn.OnEvent("Click", MoveSelectedGoal.Bind(1))
    NoGoalBtn.OnEvent("Click", VoidNoGoal)
    BonusBtn.OnEvent("Click", BonusSelected)
    PenaltyBtn.OnEvent("Click", ManualPenalty)

    ; Challenge block / challenge controls.
    MainGui.Add("GroupBox", "x960 y315 w340 h190", "Challenge Block")
    block := MainGui.Add("Text", "x978 y343 w72 h72 Center Border Background55585C cFFFFFF", "CHALLENGE`nBLOCK")
    block.SetFont("s9 bold", "Segoe UI")
    MainGui.Add("Text", "x1062 y343 w80 h21", "Challenger:")
    ChallengeDDL := MainGui.Add("DropDownList", "x1062 y365 w218 Choose1", Players)
    NowBtn := MainGui.Add("Button", "x1062 y405 w104 h42", "NOW")
    ImpossibleBtn := MainGui.Add("Button", "x1176 y405 w104 h42", "IMPOSSIBLE")
    MainGui.Add("Text", "x978 y458 w302 h32", "Select who challenges, then press the challenge actually called at the table.")

    NowBtn.OnEvent("Click", StartChallenge.Bind("NOW"))
    ImpossibleBtn.OnEvent("Click", StartChallenge.Bind("IMPOSSIBLE"))

    ; v4.5 tournament-aware clock. Manual controls remain available between
    ; rule-managed periods, so the v4.4 timer workflow is still usable.
    MainGui.Add("GroupBox", "x960 y515 w340 h120", "Tournament Timer")
    TimerText := MainGui.Add("Text", "x978 y542 w85 h38 Center Border BackgroundFFFFFF", "1:00")
    TimerText.SetFont("s18 bold", "Segoe UI")
    OneMinBtn := MainGui.Add("Button", "x1076 y542 w64 h38", "1 min")
    TwoMinBtn := MainGui.Add("Button", "x1148 y542 w64 h38", "2 min")
    ResetTimerBtn := MainGui.Add("Button", "x1220 y542 w60 h38", "Reset")
    OneMinBtn.OnEvent("Click", StartManualTimer.Bind(60))
    TwoMinBtn.OnEvent("Click", StartManualTimer.Bind(120))
    ResetTimerBtn.OnEvent("Click", ResetBoardTimer)
    TimerPurposeText := MainGui.Add("Text", "x978 y588 w302 h34", "Manual timer")

    ; Shake / match controls.
    MainGui.Add("GroupBox", "x960 y645 w340 h190", "Shake / Match")
    ForceoutBtn := MainGui.Add("Button", "x978 y673 w145 h38", "Write Forceout")
    NextShakeBtn := MainGui.Add("Button", "x1133 y673 w147 h38", "Next Shake")
    EndMatchBtn := MainGui.Add("Button", "x978 y721 w145 h38", "End Match")
    HistoryBtn := MainGui.Add("Button", "x1133 y721 w147 h38", "History / Log")
    ForceoutBtn.OnEvent("Click", ScoreForceout)
    NextShakeBtn.OnEvent("Click", NextShake)
    EndMatchBtn.OnEvent("Click", EndMatch)
    HistoryBtn.OnEvent("Click", ShowHistory)
    MainGui.Add("Text", "x978 y772 w302 h46", "Normal turn: click a Resource cube, then a destination header. Before GOAL, click a Goal cube and use ← / → to rearrange it; once a cube touches Goal it stays there.")

    SelectedText := MainGui.Add("Text", "x35 y850 w1265 h28 Center", "Selected: none")
    SelectedText.SetFont("s10 bold", "Segoe UI")

    ; v4.2 intentionally has NO global mouse hit-testing. Each destination
    ; header is a real Button with its own Click event, so placement cannot be
    ; shifted by child-control coordinate systems or DPI/window offsets.
}

AddBoardBorder(guiObj, x, y, w, h, color := "B8B8B8") {
    ; Four thin, non-overlapping lines. Unlike a filled background control,
    ; these never sit underneath the playable cube area.
    guiObj.Add("Text", "x" . x . " y" . y . " w" . w . " h2 Background" . color, "")
    guiObj.Add("Text", "x" . x . " y" . (y + h - 2) . " w" . w . " h2 Background" . color, "")
    guiObj.Add("Text", "x" . x . " y" . y . " w2 h" . h . " Background" . color, "")
    guiObj.Add("Text", "x" . (x + w - 2) . " y" . y . " w2 h" . h . " Background" . color, "")
}

BoardMatMouseDown(wParam, lParam, msg, hwnd) {
    global MainGui, SelectedCube, Phase

    if !SelectedCube || !MainGui
        return

    ; v4.1: Do NOT trust lParam here. WM_LBUTTONDOWN coordinates are relative
    ; to the particular child control which received the message. With a GUI
    ; containing GroupBoxes, labels, borders and buttons, converting those
    ; child-relative coordinates produced an offset hitbox on some systems.
    ;
    ; Instead, read the actual cursor position in SCREEN coordinates at the
    ; instant of the click, then convert that one point directly into the main
    ; GUI's client coordinate system. The visible board and BoardZoneAt() now
    ; use exactly the same coordinate space.
    MouseGetPos(&screenX, &screenY)
    pt := Buffer(8, 0)
    NumPut("Int", screenX, pt, 0)
    NumPut("Int", screenY, pt, 4)
    DllCall("ScreenToClient", "Ptr", MainGui.Hwnd, "Ptr", pt)
    gx := NumGet(pt, 0, "Int")
    gy := NumGet(pt, 4, "Int")

    zone := BoardZoneAt(gx, gy)
    if (zone = "")
        return

    ; Only consume clicks that can represent a placement in the current phase.
    if (Phase = "GoalSetting") {
        if (zone != "Goal")
            return
    } else if (Phase = "Play") {
        if (zone = "Goal")
            return
    } else {
        return
    }

    PlaceSelected(zone)
    return 0
}

BoardZoneAt(x, y) {
    if PointInRect(x, y, 45, 345, 270, 310)
        return "Forbidden"
    if PointInRect(x, y, 335, 345, 270, 310)
        return "Permitted"
    if PointInRect(x, y, 625, 345, 270, 310)
        return "Required"
    if PointInRect(x, y, 485, 675, 410, 125)
        return "Goal"
    return ""
}

PointInRect(x, y, rx, ry, rw, rh) {
    return (x >= rx && x < rx + rw && y >= ry && y < ry + rh)
}

CloseMain(*) {
    ResetBoardTimer()
    ExitApp()
}

; ============================================================================
; FIRST GOAL-SETTER LOT
; ============================================================================

DetermineFirstGoalSetter() {
    global PlayerCount, Players

    candidates := []
    loop PlayerCount
        candidates.Push(A_Index)

    AddLog("Determining the first Goal-setter by red-cube lot.")

    loop {
        rolls := Map()
        digitPlayers := []
        rollText := []

        for _, p in candidates {
            face := RandomFace("Red")
            rolls[p] := face
            rollText.Push(Players[p] . "=" . face)

            if IsDigitFace(face)
                digitPlayers.Push(p)
        }

        AddLog("Lot roll: " . JoinArray(rollText, ", "))

        if (digitPlayers.Length = 0)
            continue

        high := -1
        winners := []

        for _, p in digitPlayers {
            value := rolls[p] + 0

            if (value > high) {
                high := value
                winners := [p]
            } else if (value = high) {
                winners.Push(p)
            }
        }

        if (winners.Length = 1) {
            AddLog(Players[winners[1]] . " wins the lot and sets the first Goal.")
            return winners[1]
        }

        tiedNames := []
        for _, p in winners
            tiedNames.Push(Players[p])

        AddLog("Tie for high digit between " . JoinArray(tiedNames, ", ") . "; tied players reroll.")
        candidates := winners
    }
}

; ============================================================================
; SHAKE / CUBE MANAGEMENT
; ============================================================================

StartShake(rotateGoalSetter := true) {
    global PlayerCount, ShakeNumber, GoalSetter, CurrentPlayer, LastMover
    global LastAction, Phase, Cubes, GoalOrder, SelectedCube
    global GoalPhysicalExpr, GoalWasGrouped, GoalGroupingEdit
    global ForceoutStartTick
    global BonusUsedThisTurn, ShakeDelta, ChallengeDDL, ZoneOrder
    global BotActionSerial, BotChallengeCheckedSerial, BotCachedEquationEntries

    if rotateGoalSetter
        GoalSetter := NextPlayer(GoalSetter)

    ShakeNumber += 1
    CurrentPlayer := GoalSetter
    LastMover := 0
    LastAction := ""
    Phase := "GoalSetting"
    GoalOrder := []
    SelectedCube := 0
    GoalPhysicalExpr := ""
    GoalWasGrouped := false
    ForceoutStartTick := 0
    BonusUsedThisTurn := false
    BotActionSerial := 0
    BotChallengeCheckedSerial := 0
    BotCachedEquationEntries := Map()
    ZoneOrder := Map("Required", [], "Permitted", [], "Forbidden", [])
    SetTimer(ForceoutCutoffReached, 0)
    ResetBoardTimer()

    ShakeDelta := []
    loop PlayerCount
        ShakeDelta.Push(0)

    RollAllCubes()
    GoalGroupingEdit.Value := ""
    ChallengeDDL.Choose(NextPlayer(GoalSetter))

    AddLog("")
    AddLog("--- SHAKE " . ShakeNumber . " ---")
    AddLog("Goal-setter: " . PlayerName(GoalSetter) . ". 24 cubes rolled.")
    UpdateGui()
    StartRuleTimer(120, "Setting the Goal", GoalSetter, true)
    ScheduleBotController()
}

RollAllCubes() {
    global Cubes, PhysicalCubeFaces

    Cubes := []
    colors := ["Red", "Blue", "Green", "Black"]
    slots := []
    loop 24
        slots.Push(A_Index)
    ShuffleArray(slots)

    id := 0
    for _, color in colors {
        cubeSets := PhysicalCubeFaces[color]
        loop 6 {
            id += 1
            cubeNumber := A_Index
            faces := cubeSets[cubeNumber]
            Cubes.Push({
                Id: id,
                Color: color,
                PhysicalNumber: cubeNumber,
                Face: faces[Random(1, faces.Length)],
                Zone: "Resources",
                HomeSlot: slots[id]
            })
        }
    }
}

RandomFace(color) {
    global ColorFaces
    faces := ColorFaces[color]
    return faces[Random(1, faces.Length)]
}

CubeClicked(idx, *) {
    global Phase, Cubes, SelectedCube, GoalOrder, GoalGroupingEdit

    if (Phase != "GoalSetting" && Phase != "Play")
        return

    cube := Cubes[idx]

    ; Once a cube touches Goal, current tournament rules require it to remain
    ; part of the Goal. During Goal-setting, clicking a Goal cube selects it so
    ; the Goal-setter can rearrange its position with the ← / → controls.
    if (Phase = "GoalSetting" && cube.Zone = "Goal") {
        SelectedCube := (SelectedCube = idx) ? 0 : idx
        UpdateGui()
        return
    }

    if (cube.Zone != "Resources")
        return

    SelectedCube := (SelectedCube = idx) ? 0 : idx
    UpdateGui()
}

PlaceSelected(zone, *) {
    global Phase, SelectedCube, Cubes, GoalOrder, ZoneOrder, GoalGroupingEdit
    global CurrentPlayer, LastMover, LastAction, BonusUsedThisTurn, ForceoutStartTick

    if !SelectedCube {
        SoundBeep(800, 80)
        return
    }

    idx := SelectedCube
    cube := Cubes[idx]

    if (cube.Zone != "Resources") {
        SelectedCube := 0
        UpdateGui()
        return
    }

    if (zone = "Goal") {
        if (Phase != "GoalSetting")
            return

        if (GoalOrder.Length >= 6) {
            MsgBox("A Goal may use at most 6 cubes.", "Goal limit")
            return
        }

        cube.Zone := "Goal"
        GoalOrder.Push(idx)
        GoalGroupingEdit.Value := ""
        SelectedCube := 0

        AddLog(PlayerName(CurrentPlayer) . " places " . CubeCode(cube) . " into the Goal.")
        UpdateGui()
        return
    }

    if (Phase != "Play")
        return

    if (zone != "Required" && zone != "Permitted" && zone != "Forbidden")
        return

    if (ResourceCount() = 1 && zone = "Forbidden") {
        MsgBox(
            "With one cube left in Resources, the last cube may be moved only to Required or Permitted, or the player may challenge IMPOSSIBLE.",
            "Last Cube Rule"
        )
        return
    }

    cube.Zone := zone
    ZoneOrder[zone].Push(idx)
    SelectedCube := 0
    LastMover := CurrentPlayer
    LastAction := "moved " . CubeCode(cube) . " to " . zone
    MarkBotChallengeWindow()

    AddLog(PlayerName(CurrentPlayer) . " moves " . CubeCode(cube) . " to " . zone . ".")

    if (ResourceCount() = 0) {
        Phase := "Forceout"
        ForceoutStartTick := A_TickCount
        AddLog("Last cube moved. The automatic two-minute writing period begins now; IMPOSSIBLE remains legal only through the first minute.")
        CurrentPlayer := 0
        BonusUsedThisTurn := false
        StartRuleTimer(120, "Last Cube writing period", 0, false)
        SetTimer(ForceoutCutoffReached, -60000)
    } else {
        CurrentPlayer := NextPlayer(CurrentPlayer)
        BonusUsedThisTurn := false

        if (ResourceCount() = 1)
            AddLog("One Resource cube remains. NOW is no longer legal. The last cube must go to Required or Permitted unless someone challenges IMPOSSIBLE.")

        StartRuleTimer(60, "Regular turn", CurrentPlayer, true)
    }

    SetDefaultChallenger()
    UpdateGui()
    ScheduleBotController()
}

BonusSelected(*) {
    global Phase, SelectedCube, Cubes, GoalOrder, GoalSetter, CurrentPlayer
    global BonusUsedThisTurn, LastMover, LastAction, ZoneOrder

    if !SelectedCube {
        MsgBox("Select the Resource cube you want to use for BONUS first.", "BONUS")
        return
    }

    if (Phase = "GoalSetting") {
        player := GoalSetter

        if (GoalOrder.Length > 0) {
            MsgBox("The Goal-setter's BONUS must happen before the first Goal cube is placed.", "BONUS")
            return
        }
    } else if (Phase = "Play") {
        player := CurrentPlayer

        if (ResourceCount() <= 1) {
            MsgBox("There are not enough Resource cubes remaining for a BONUS followed by the required regular move.", "BONUS")
            return
        }
    } else {
        return
    }

    if BonusUsedThisTurn {
        MsgBox("This player already made a BONUS move on this turn.", "BONUS")
        return
    }

    if !CanBonus(player) {
        MsgBox(PlayerName(player) . " is alone in the lead and may not make a BONUS move.", "BONUS")
        return
    }

    idx := SelectedCube
    cube := Cubes[idx]
    cube.Zone := "Forbidden"
    ZoneOrder["Forbidden"].Push(idx)
    SelectedCube := 0
    BonusUsedThisTurn := true

    AddLog(PlayerName(player) . " calls BONUS and moves " . CubeCode(cube) . " to Forbidden.")

    if (Phase = "Play") {
        LastMover := player
        LastAction := "bonus-moved " . CubeCode(cube) . " to Forbidden"
        MarkBotChallengeWindow()
        SetDefaultChallenger()
    }

    UpdateGui()
    ScheduleBotController()
}

LockGoal(*) {
    global Phase, GoalOrder, GoalGroupingEdit, GoalPhysicalExpr, GoalWasGrouped
    global GoalSetter, CurrentPlayer, LastMover, LastAction, BonusUsedThisTurn

    if (Phase != "GoalSetting")
        return

    if (GoalOrder.Length < 1) {
        MsgBox("Place at least one cube in the Goal first.", "No Goal")
        return
    }

    grouping := Trim(GoalGroupingEdit.Value)
    rawGoal := GoalRawExpression()

    if (grouping != "") {
        tokenInfo := TokenizeExpression(grouping, "Goal")
        if !tokenInfo.OK {
            MsgBox("The physical grouping text cannot be read:`n`n" . tokenInfo.Reason, "Goal grouping")
            return
        }

        if !FacesEqualSequence(tokenInfo.Faces, GoalFaceSequence()) {
            MsgBox(
                "The physical grouping must use the SAME Goal cubes in the SAME order.`n`nGoal cubes: " . rawGoal . "`nGrouping entered: " . grouping,
                "Goal grouping does not match cubes"
            )
            return
        }

        if !ParenthesesBalanced(tokenInfo.Tokens) {
            MsgBox("The grouping symbols are not balanced.", "Goal grouping")
            return
        }

        GoalPhysicalExpr := grouping
        GoalWasGrouped := true
    } else {
        GoalPhysicalExpr := rawGoal
        GoalWasGrouped := false
    }

    ; Do not protect the Goal-setter from an illegal Goal. At a real table the
    ; Goal may be set and an opponent should catch it with an immediate
    ; IMPOSSIBLE challenge. The checker evaluates the Goal silently only when
    ; that challenge is actually made, so the Goal-setter receives no warning.

    Phase := "Play"
    LastMover := GoalSetter
    LastAction := "set the Goal"
    MarkBotChallengeWindow()
    CurrentPlayer := NextPlayer(GoalSetter)
    BonusUsedThisTurn := false

    AddLog(PlayerName(GoalSetter) . " says GOAL. Goal cubes: " . rawGoal . ".")
    if GoalWasGrouped
        AddLog("Physical Goal grouping: " . GoalPhysicalExpr)
    else
        AddLog("Goal left ungrouped on the mat; Equation-writers may state any acceptable interpretation with grouping symbols.")
    AddLog("First mover: " . PlayerName(CurrentPlayer) . ".")
    SetDefaultChallenger()

    UpdateGui()
    StartRuleTimer(120, "First turn after the Goal", CurrentPlayer, true)
    ScheduleBotController()
}

MoveSelectedGoal(direction, *) {
    global Phase, GoalOrder, Cubes, SelectedCube, GoalGroupingEdit

    if (Phase != "GoalSetting" || !SelectedCube)
        return

    cube := Cubes[SelectedCube]
    if (cube.Zone != "Goal")
        return

    pos := FindIndexInArray(GoalOrder, SelectedCube)
    if !pos
        return

    newPos := pos + direction
    if (newPos < 1 || newPos > GoalOrder.Length)
        return

    other := GoalOrder[newPos]
    GoalOrder[newPos] := GoalOrder[pos]
    GoalOrder[pos] := other
    GoalGroupingEdit.Value := ""

    AddLog("Goal-setter rearranges the Goal: " . GoalRawExpression() . ".")
    UpdateGui()
}

; ============================================================================
; NO GOAL
; ============================================================================

VoidNoGoal(*) {
    global Phase, GoalOrder, BonusUsedThisTurn, ShakeNumber
    global ChallengeDDL, GoalSetter

    if (Phase != "GoalSetting")
        return

    if (GoalOrder.Length > 0 || BonusUsedThisTurn) {
        MsgBox("NO GOAL may be declared only before any Goal cube or Goal-setter BONUS move.", "NO GOAL")
        return
    }

    AddLog(PlayerName(GoalSetter) . " declares NO GOAL.")
    StartRuleTimer(60, "NO GOAL opponent decision", 0, false)

    answer := MsgBox(
        "Do ALL opponents agree that no legal Goal with a correct Solution can be made?`n`nYES = all agree; this shake is void and the same Goal-setter rerolls.`nNO = the opponent selected in Challenger disagrees and challenges the declaration.",
        "NO GOAL declaration",
        "YesNoCancel"
    )

    if (answer = "Cancel") {
        StartRuleTimer(120, "Setting the Goal", GoalSetter, true)
        return
    }

    if (answer = "Yes") {
        ShakeNumber -= 1
        AddLog("All opponents agree with NO GOAL. Shake void; no points.")
        StartShake(false)
        return
    }

    challenger := ChallengeDDL.Value
    if (challenger < 1)
        challenger := 1

    if (challenger = GoalSetter) {
        MsgBox("Select an OPPONENT in the Challenger list first.", "Choose challenger")
        StartRuleTimer(120, "Setting the Goal", GoalSetter, true)
        return
    }

    ResolveNoGoalChallenge(challenger)
}

ResolveNoGoalChallenge(challenger) {
    global PlayerCount, GoalSetter

    third := (PlayerCount = 3) ? ThirdParty(challenger, GoalSetter) : 0
    thirdWillWrite := false

    AddLog(PlayerName(challenger) . " challenges the NO GOAL declaration by " . PlayerName(GoalSetter) . ".")

    if (PlayerCount = 3)
        thirdWillWrite := AskOptionalEquation(third, "NO GOAL challenge")

    challengerEntry := GetNoGoalEquationEntry(challenger, "NO GOAL Challenger - you must show a legal Goal and Solution")
    challengerCheck := CheckNoGoalEquation(challengerEntry)

    thirdCheck := {Correct: false, Reason: "No Equation presented", Submitted: false}
    thirdEntry := {Submitted: false, Solution: "", Goal: ""}

    if thirdWillWrite {
        thirdEntry := GetNoGoalEquationEntry(third, "NO GOAL Third Party - optional Equation")
        thirdCheck := CheckNoGoalEquation(thirdEntry)
    }

    baseScores := []
    loop PlayerCount
        baseScores.Push(0)

    baseScores[challenger] := challengerCheck.Correct ? 6 : 2

    if (PlayerCount = 2) {
        baseScores[GoalSetter] := challengerCheck.Correct ? 2 : 6
    } else {
        if thirdWillWrite {
            if thirdCheck.Correct
                baseScores[third] := challengerCheck.Correct ? 4 : 6
            else
                baseScores[third] := 2
        } else {
            baseScores[third] := challengerCheck.Correct ? 2 : 6
        }

        baseScores[GoalSetter] := (challengerCheck.Correct || (thirdWillWrite && thirdCheck.Correct)) ? 2 : 6
    }

    resultLines := []
    resultLines.Push(EquationResultLine(challenger, challengerEntry, challengerCheck))
    if (PlayerCount = 3) {
        if thirdWillWrite
            resultLines.Push(EquationResultLine(third, thirdEntry, thirdCheck))
        else
            resultLines.Push(PlayerName(third) . ": no Equation presented")
    }

    ShowCheckedResults("NO GOAL challenge", resultLines, baseScores)
    FinalizeShake(baseScores, "NO GOAL challenge")
}

; ============================================================================
; CHALLENGES
; ============================================================================

StartChallenge(type, *) {
    global Phase, ChallengeDDL, LastMover, LastAction

    if (Phase != "Play" && Phase != "Forceout")
        return

    if (LastMover = 0)
        return

    challenger := ChallengeDDL.Value
    if (challenger < 1)
        challenger := 1

    if (challenger = LastMover) {
        OfferIllegalChallengePenalty(challenger, "A player may not challenge themself because they are the last Mover.")
        return
    }

    if (type = "IMPOSSIBLE" && Phase = "Forceout" && !ForceoutImpossibleOpen()) {
        OfferIllegalChallengePenalty(challenger, "IMPOSSIBLE against the last-cube Mover must be made by the end of the first minute of the two-minute writing period.")
        return
    }

    if (type = "NOW") {
        if (ResourceCount() < 2) {
            OfferIllegalChallengePenalty(challenger, "NOW requires at least two cubes to remain in Resources.")
            return
        }

        if ((CountZone("Required") + CountZone("Permitted")) = 0) {
            OfferIllegalChallengePenalty(challenger, "NOW is illegal before at least one cube has been played to Required or Permitted.")
            return
        }
    }

    ; A legal challenge ends the current move/Goal-setting task clock. Writing
    ; clocks are started separately for the hot-seat Equation entry dialogs.
    StopBoardTimer()

    ; If IMPOSSIBLE is called immediately after GOAL, first check whether the
    ; Goal itself is definitively illegal. If it is, nobody can write a legal
    ; Equation, so the program can adjudicate the challenge without asking the
    ; players to judge the Goal or type a doomed Equation. A legal Goal is not
    ; announced; normal IMPOSSIBLE play continues because the Mover may still
    ; or may not be able to write a correct Equation from the board position.
    if (type = "IMPOSSIBLE" && LastAction = "set the Goal") {
        goalLegality := AnalyzeCurrentGoalLegality()
        if (goalLegality.Known && !goalLegality.Legal) {
            ResolveIllegalGoalImpossible(challenger, goalLegality.Reason)
            return
        }
    }

    ResolveChallenge(type, challenger)
}

OfferIllegalChallengePenalty(player, reason) {
    answer := MsgBox(
        reason . "`n`nAn invalid challenge costs 1 point.`nApply the -1 penalty to " . PlayerName(player) . "?",
        "Illegal challenge",
        "YesNo"
    )

    if (answer = "Yes")
        AddPenalty(player, "Illegal challenge")
}

AnalyzeCurrentGoalLegality() {
    global GoalPhysicalExpr

    analysis := ParsePhysicalGoalExpression(GoalPhysicalExpr)

    if analysis.OK {
        return {
            Known: true,
            Legal: true,
            Reason: "The Goal has at least one legal Basic EQUATIONS interpretation."
        }
    }

    ; A parser-overflow result means the automatic checker did not finish the
    ; search. Do not falsely call the Goal illegal; fall back to ordinary
    ; IMPOSSIBLE play instead.
    if InStr(analysis.Reason, "too many possible groupings") {
        return {
            Known: false,
            Legal: false,
            Reason: analysis.Reason
        }
    }

    return {
        Known: true,
        Legal: false,
        Reason: analysis.Reason
    }
}

ResolveIllegalGoalImpossible(challenger, reason) {
    global PlayerCount, LastMover

    mover := LastMover
    third := (PlayerCount = 3) ? ThirdParty(challenger, mover) : 0
    thirdWillWrite := false

    AddLog(PlayerName(challenger) . " challenges IMPOSSIBLE against " . PlayerName(mover) . ".")

    ; In a three-player game, the Third Party must decide whether to present
    ; before the automatic result is revealed. If the Goal is illegal, any
    ; attempted Equation is necessarily incorrect, but the decision still
    ; affects the Third Party's challenge score.
    if (PlayerCount = 3)
        thirdWillWrite := AskOptionalEquation(third, "IMPOSSIBLE challenge")

    baseScores := []
    loop PlayerCount
        baseScores.Push(0)

    baseScores[mover] := 2
    baseScores[challenger] := 6

    if (PlayerCount = 3)
        baseScores[third] := thirdWillWrite ? 2 : 4

    resultLines := []
    resultLines.Push(
        PlayerName(mover) . ": automatic checker -> no correct Equation is possible because the Goal is illegal. " . reason
    )

    if (PlayerCount = 3) {
        if thirdWillWrite
            resultLines.Push(PlayerName(third) . ": chose to present; automatically incorrect because the Goal has no legal interpretation.")
        else
            resultLines.Push(PlayerName(third) . ": no Equation presented")
    }

    AddLog("Automatic Goal check: IMPOSSIBLE succeeds because the Goal has no legal Basic interpretation.")
    ShowCheckedResults("IMPOSSIBLE challenge - illegal Goal", resultLines, baseScores)
    FinalizeShake(baseScores, "IMPOSSIBLE challenge against illegal Goal")
}

ResolveChallenge(type, challenger) {
    global PlayerCount, LastMover

    mover := LastMover
    third := (PlayerCount = 3) ? ThirdParty(challenger, mover) : 0
    thirdWillWrite := false

    AddLog(PlayerName(challenger) . " challenges " . type . " against " . PlayerName(mover) . ".")

    if (PlayerCount = 3)
        thirdWillWrite := AskOptionalEquation(third, type . " challenge")

    writer := (type = "NOW") ? challenger : mover
    roleText := (type = "NOW") ? "NOW Challenger - you must present an Equation" : "IMPOSSIBLE Mover - you must present an Equation"
    mode := type

    writerEntry := GetEquationEntry(writer, roleText, mode)
    writerCheck := CheckBoardEquation(writerEntry, mode)

    thirdEntry := {Submitted: false, Solution: "", Goal: ""}
    thirdCheck := {Correct: false, Reason: "No Equation presented", Submitted: false}

    if thirdWillWrite {
        thirdEntry := GetEquationEntry(third, type . " Third Party - optional Equation", mode)
        thirdCheck := CheckBoardEquation(thirdEntry, mode)
    }

    baseScores := []
    loop PlayerCount
        baseScores.Push(0)

    if (type = "NOW") {
        challengerCorrect := writerCheck.Correct
        baseScores[challenger] := challengerCorrect ? 6 : 2

        if (PlayerCount = 2) {
            baseScores[mover] := challengerCorrect ? 2 : 6
        } else {
            thirdCorrect := thirdWillWrite && thirdCheck.Correct
            moverCorrect := (!challengerCorrect && !thirdCorrect)
            baseScores[mover] := moverCorrect ? 6 : 2

            if thirdWillWrite {
                if thirdCorrect
                    baseScores[third] := challengerCorrect ? 4 : 6
                else
                    baseScores[third] := 2
            } else {
                baseScores[third] := challengerCorrect ? 2 : 6
            }
        }
    } else {
        moverCorrect := writerCheck.Correct
        baseScores[mover] := moverCorrect ? 6 : 2

        if (PlayerCount = 2) {
            baseScores[challenger] := moverCorrect ? 2 : 6
        } else {
            thirdCorrect := thirdWillWrite && thirdCheck.Correct
            challengerCorrect := (!moverCorrect && !thirdCorrect)
            baseScores[challenger] := challengerCorrect ? 6 : 2

            if thirdWillWrite {
                if thirdCorrect
                    baseScores[third] := 6
                else
                    baseScores[third] := 2
            } else {
                ; A Third Party who presents nothing after IMPOSSIBLE is correct
                ; only when nobody writes a correct Equation; that correct Third
                ; Party scores 4 under the current scoring rule.
                baseScores[third] := moverCorrect ? 2 : 4
            }
        }
    }

    resultLines := []
    resultLines.Push(EquationResultLine(writer, writerEntry, writerCheck))
    if (PlayerCount = 3) {
        if thirdWillWrite
            resultLines.Push(EquationResultLine(third, thirdEntry, thirdCheck))
        else
            resultLines.Push(PlayerName(third) . ": no Equation presented")
    }

    ShowCheckedResults(type . " challenge", resultLines, baseScores)
    FinalizeShake(baseScores, type . " challenge")
}

AskOptionalEquation(player, context) {
    if IsBotPlayer(player)
        return BotThirdPartyWillWrite(player, context)

    answer := MsgBox(
        PlayerName(player) . " is the Third Party for this " . context . ".`n`nWill " . PlayerName(player) . " PRESENT an Equation?`n`nChoose before any Equation is checked.",
        "Third Party decision",
        "YesNo"
    )
    return (answer = "Yes")
}

ThirdParty(challenger, mover) {
    global PlayerCount

    if (PlayerCount != 3)
        return 0

    loop 3 {
        if (A_Index != challenger && A_Index != mover)
            return A_Index
    }

    return 0
}

; ============================================================================
; FORCEOUT / LAST CUBE
; ============================================================================

ScoreForceout(*) {
    global Phase, PlayerCount

    if (Phase != "Forceout")
        return

    entries := []
    checks := []

    loop PlayerCount {
        p := A_Index
        entry := GetEquationEntry(p, "Last Cube / Forceout - enter the Equation you wrote during the shared two-minute period", "FORCEOUT", false)
        check := CheckBoardEquation(entry, "FORCEOUT")
        entries.Push(entry)
        checks.Push(check)
    }

    baseScores := []
    resultLines := []

    loop PlayerCount {
        p := A_Index
        baseScores.Push(checks[p].Correct ? 4 : 2)
        resultLines.Push(EquationResultLine(p, entries[p], checks[p]))
    }

    ShowCheckedResults("Last Cube / Forceout", resultLines, baseScores)
    FinalizeShake(baseScores, "Last Cube / forceout")
}

; ============================================================================
; EQUATION ENTRY DIALOGS
; ============================================================================

PromptEquation(player, roleText, manageTimer := true) {
    global MainGui, GoalPhysicalExpr

    if manageTimer
        StartRuleTimer(120, "Writing an Equation", player, true)

    result := {Submitted: false, Solution: "", Goal: ""}
    dlg := Gui("+Owner" . MainGui.Hwnd, "Write Equation - " . PlayerName(player))
    dlg.BackColor := "F5F2EA"
    dlg.SetFont("s10", "Segoe UI")

    handoff := dlg.Add("Text", "x15 y15 w750 h48 Center Border BackgroundFFF4CC", "HAND THE COMPUTER TO " . StrUpper(PlayerName(player)) . "`n" . roleText)
    handoff.SetFont("s11 bold", "Segoe UI")

    dlg.Add("Text", "x20 y75 w740 h96 Border BackgroundFFFFFF", BoardSummaryForWriter())
    dlg.Add("Text", "x20 y182 w740 h52", "Write the same Equation you would present on paper. The checker uses the real cube locations and EQUATIONS grouping rules. Previous writers stay hidden until scoring is revealed. For challenge writing, the 2-minute tournament clock is running.")

    dlg.Add("Text", "x25 y250 w310 h22 Center", "SOLUTION")
    dlg.Add("Text", "x430 y250 w310 h22 Center", "GOAL INTERPRETATION")
    solutionEdit := dlg.Add("Edit", "x25 y276 w310 h38", "")
    equalsText := dlg.Add("Text", "x350 y274 w60 h42 Center", "=")
    equalsText.SetFont("s22 bold", "Segoe UI")

    defaultGoal := ""
    physicalAnalysis := ParsePhysicalGoalExpression(GoalPhysicalExpr)
    if (physicalAnalysis.OK && physicalAnalysis.Results.Length = 1)
        defaultGoal := GoalPhysicalExpr
    goalEdit := dlg.Add("Edit", "x430 y276 w310 h38", defaultGoal)

    dlg.Add("Text", "x25 y326 w715 h46", "Type +  -  x  /  ^  sqrt and grouping symbols. Do not type the equals sign in either box. If the Goal has more than one possible interpretation, group the Goal side to show the interpretation you are presenting.")

    submitBtn := dlg.Add("Button", "x425 y390 w155 h40 Default", "Present Equation")
    giveUpBtn := dlg.Add("Button", "x590 y390 w150 h40", "No Equation")

    submitBtn.OnEvent("Click", (*) => FinishEquationDialog(result, solutionEdit, goalEdit, dlg))
    giveUpBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())

    hwnd := dlg.Hwnd
    MainGui.Opt("+Disabled")
    dlg.Show("w780 h450")
    solutionEdit.Focus()
    WinWaitClose("ahk_id " . hwnd)
    MainGui.Opt("-Disabled")
    MainGui.Show()

    if manageTimer
        StopBoardTimer()

    return result
}

PromptNoGoalEquation(player, roleText) {
    global MainGui

    StartRuleTimer(120, "Writing a NO GOAL Equation", player, true)
    result := {Submitted: false, Solution: "", Goal: ""}
    dlg := Gui("+Owner" . MainGui.Hwnd, "NO GOAL Equation - " . PlayerName(player))
    dlg.BackColor := "F5F2EA"
    dlg.SetFont("s10", "Segoe UI")

    handoff := dlg.Add("Text", "x15 y15 w750 h48 Center Border BackgroundFFF4CC", "HAND THE COMPUTER TO " . StrUpper(PlayerName(player)) . "`n" . roleText)
    handoff.SetFont("s11 bold", "Segoe UI")
    dlg.Add("Text", "x20 y75 w740 h72 Border BackgroundFFFFFF", "ROLLED RESOURCES`n" . ZoneFaceOnlyString("Resources"))
    dlg.Add("Text", "x20 y158 w740 h58", "For this special NO GOAL challenge, create BOTH sides from different physical cubes in the roll. Goal: 1-6 cubes and one- or two-digit numerals. Solution: at least 2 cubes and one-digit numerals. The 2-minute writing clock is running.")

    dlg.Add("Text", "x25 y238 w310 h22 Center", "SOLUTION")
    dlg.Add("Text", "x430 y238 w310 h22 Center", "GOAL")
    solutionEdit := dlg.Add("Edit", "x25 y264 w310 h38", "")
    equalsText := dlg.Add("Text", "x350 y262 w60 h42 Center", "=")
    equalsText.SetFont("s22 bold", "Segoe UI")
    goalEdit := dlg.Add("Edit", "x430 y264 w310 h38", "")

    dlg.Add("Text", "x25 y316 w715 h42", "Use parentheses to show the Goal interpretation you are presenting. The same physical cube cannot be counted on both sides.")
    submitBtn := dlg.Add("Button", "x425 y375 w155 h40 Default", "Present Equation")
    giveUpBtn := dlg.Add("Button", "x590 y375 w150 h40", "No Equation")

    submitBtn.OnEvent("Click", (*) => FinishEquationDialog(result, solutionEdit, goalEdit, dlg))
    giveUpBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())

    hwnd := dlg.Hwnd
    MainGui.Opt("+Disabled")
    dlg.Show("w780 h435")
    solutionEdit.Focus()
    WinWaitClose("ahk_id " . hwnd)
    MainGui.Opt("-Disabled")
    MainGui.Show()
    StopBoardTimer()

    return result
}

FinishEquationDialog(result, solutionEdit, goalEdit, dlg) {
    result.Submitted := true
    result.Solution := Trim(solutionEdit.Value)
    result.Goal := Trim(goalEdit.Value)
    dlg.Destroy()
}

BoardSummaryForWriter() {
    global GoalPhysicalExpr, GoalWasGrouped

    goalDesc := GoalRawExpression()
    if GoalWasGrouped
        goalDesc .= "   [physically grouped as " . GoalPhysicalExpr . "]"
    else
        goalDesc .= "   [ungrouped]"

    return "Goal: " . goalDesc
        . "`nRequired: " . ZoneFaceOnlyString("Required")
        . "`nPermitted: " . ZoneFaceOnlyString("Permitted")
        . "`nResources: " . ZoneFaceOnlyString("Resources")
        . "`nForbidden: " . ZoneFaceOnlyString("Forbidden")
}

; ============================================================================
; AUTOMATIC EQUATION CHECKING
; ============================================================================

CheckBoardEquation(entry, mode) {
    global GoalPhysicalExpr

    if !entry.Submitted
        return CheckFail("No Equation was presented.")

    if (Trim(entry.Solution) = "" || Trim(entry.Goal) = "")
        return CheckFail("Both the Solution and the Goal interpretation must be written.")

    goalCheck := CheckPresentedGoal(entry.Goal)
    if !goalCheck.OK
        return CheckFail(goalCheck.Reason)

    solutionAnalysis := ParseExpression(entry.Solution, "Solution")
    if !solutionAnalysis.OK
        return CheckFail("Solution: " . solutionAnalysis.Reason)

    if (solutionAnalysis.Faces.Length < 2)
        return CheckFail("The Solution must contain at least two cubes.")

    cubeCheck := CheckBoardCubeUsage(solutionAnalysis.Faces, mode)
    if !cubeCheck.OK
        return CheckFail(cubeCheck.Reason)

    goalValue := goalCheck.Value

    for _, result in solutionAnalysis.Results {
        if !NearlyEqual(result.Value, goalValue) {
            if (solutionAnalysis.Results.Length > 1) {
                return CheckFail(
                    "The Solution is ambiguous. A legal grouping " . result.Canon . " equals " . FormatNumber(result.Value)
                    . ", not the presented Goal value " . FormatNumber(goalValue) . "."
                )
            }

            return CheckFail(
                "The Solution equals " . FormatNumber(result.Value) . ", but the presented Goal equals " . FormatNumber(goalValue) . "."
            )
        }
    }

    return {
        Correct: true,
        Submitted: true,
        Reason: "Correct. Solution and Goal both equal " . FormatNumber(goalValue) . ".",
        Value: goalValue
    }
}

CheckPresentedGoal(goalExpr) {
    global GoalPhysicalExpr

    writerInfo := TokenizeExpression(goalExpr, "Goal")
    if !writerInfo.OK
        return {OK: false, Reason: "Goal interpretation: " . writerInfo.Reason}

    if !FacesEqualSequence(writerInfo.Faces, GoalFaceSequence()) {
        return {
            OK: false,
            Reason: "The written Goal interpretation does not use the exact Goal cubes in their physical order."
        }
    }

    writerAnalysis := ParseExpression(goalExpr, "Goal")
    if !writerAnalysis.OK
        return {OK: false, Reason: "Goal interpretation: " . writerAnalysis.Reason}

    ; The Equation-writer must actually state an interpretation of the Goal.
    ; If several parse trees remain, the written Goal is still ambiguous.
    if (writerAnalysis.Results.Length != 1) {
        return {
            OK: false,
            Reason: "The written Goal interpretation is still ambiguous. Add grouping symbols to show exactly how you interpret the Goal."
        }
    }

    physicalAnalysis := ParsePhysicalGoalExpression(GoalPhysicalExpr)
    if !physicalAnalysis.OK {
        return {
            OK: false,
            Reason: "The Goal on the mat has no legal mathematical interpretation."
        }
    }

    writerCanon := writerAnalysis.Results[1].Canon
    allowed := false

    for _, physicalResult in physicalAnalysis.Results {
        if (physicalResult.Canon = writerCanon) {
            allowed := true
            break
        }
    }

    if !allowed {
        return {
            OK: false,
            Reason: "The written Goal grouping is not a legal interpretation of the Goal as physically grouped on the mat."
        }
    }

    return {
        OK: true,
        Value: writerAnalysis.Results[1].Value,
        Canon: writerCanon
    }
}

CheckNoGoalEquation(entry) {
    if !entry.Submitted
        return CheckFail("No Equation was presented.")

    if (Trim(entry.Solution) = "" || Trim(entry.Goal) = "")
        return CheckFail("Both a Goal and a Solution are required for a NO GOAL challenge Equation.")

    goalAnalysis := ParseExpression(entry.Goal, "Goal")
    if !goalAnalysis.OK
        return CheckFail("Goal: " . goalAnalysis.Reason)

    if (goalAnalysis.Faces.Length < 1 || goalAnalysis.Faces.Length > 6)
        return CheckFail("A Goal must contain from 1 through 6 cubes.")

    if (goalAnalysis.Results.Length != 1)
        return CheckFail("The Goal you present must be grouped clearly enough to show one interpretation.")

    solutionAnalysis := ParseExpression(entry.Solution, "Solution")
    if !solutionAnalysis.OK
        return CheckFail("Solution: " . solutionAnalysis.Reason)

    if (solutionAnalysis.Faces.Length < 2)
        return CheckFail("The Solution must contain at least two cubes.")

    combined := CountFaces(goalAnalysis.Faces)
    AddFaceCounts(combined, CountFaces(solutionAnalysis.Faces))
    available := ZoneFaceCounts("Resources")

    for symbol, needed in combined {
        if (needed > MapGet(available, symbol)) {
            return CheckFail(
                "The Goal and Solution together need " . needed . " cube(s) showing " . symbol
                . ", but only " . MapGet(available, symbol) . " were rolled. A physical cube cannot be used twice."
            )
        }
    }

    goalValue := goalAnalysis.Results[1].Value
    for _, result in solutionAnalysis.Results {
        if !NearlyEqual(result.Value, goalValue) {
            if (solutionAnalysis.Results.Length > 1)
                return CheckFail("The Solution is ambiguous; " . result.Canon . " does not equal the Goal.")
            return CheckFail("The Solution does not equal the Goal.")
        }
    }

    return {
        Correct: true,
        Submitted: true,
        Reason: "Correct NO GOAL challenge Equation. Both sides equal " . FormatNumber(goalValue) . ".",
        Value: goalValue
    }
}

CheckBoardCubeUsage(solutionFaces, mode) {
    required := ZoneFaceCounts("Required")
    permitted := ZoneFaceCounts("Permitted")
    resources := ZoneFaceCounts("Resources")
    used := CountFaces(solutionFaces)

    ; Every Required cube must be used.
    for symbol, reqCount in required {
        if (MapGet(used, symbol) < reqCount) {
            return {
                OK: false,
                Reason: "Required cube rule: need " . reqCount . " cube(s) showing " . symbol
                    . ", but the Solution uses only " . MapGet(used, symbol) . "."
            }
        }
    }

    ; Remove the Required allocation first. Remaining uses must come from
    ; Permitted and, when the challenge allows it, Resources.
    extras := Map()
    for symbol, usedCount in used {
        extra := usedCount - MapGet(required, symbol)
        if (extra > 0)
            extras[symbol] := extra
    }

    resourceNeededTotal := 0

    for symbol, extraCount in extras {
        permCount := MapGet(permitted, symbol)
        fromPermitted := Min(extraCount, permCount)
        stillNeeded := extraCount - fromPermitted

        if (mode = "FORCEOUT") {
            if (stillNeeded > 0) {
                return {
                    OK: false,
                    Reason: "The Solution needs " . stillNeeded . " additional " . symbol
                        . " cube(s), but after forceout only Required and Permitted cubes may be used."
                }
            }
            continue
        }

        if (stillNeeded > MapGet(resources, symbol)) {
            return {
                OK: false,
                Reason: "Not enough available cubes showing " . symbol . " for this Solution."
            }
        }

        resourceNeededTotal += stillNeeded
    }

    if (mode = "NOW" && resourceNeededTotal > 1) {
        return {
            OK: false,
            Reason: "A NOW Solution may use at most one cube from Resources. This Solution requires " . resourceNeededTotal . " Resource cubes after using Required and Permitted."
        }
    }

    ; IMPOSSIBLE allows any number of remaining Resource cubes. NOW handled
    ; its one-cube cap above.
    return {OK: true, Reason: "Cube usage is legal."}
}

CheckFail(reason) {
    return {Correct: false, Submitted: false, Reason: reason}
}

EquationResultLine(player, entry, check) {
    if !entry.Submitted
        return PlayerName(player) . ": NO EQUATION -> INCORRECT - " . check.Reason

    status := check.Correct ? "CORRECT" : "INCORRECT"
    return PlayerName(player) . ": " . entry.Solution . " = " . entry.Goal . " -> " . status . " - " . check.Reason
}

ShowCheckedResults(title, resultLines, baseScores) {
    global PlayerCount, BotAutoRun

    scoreLines := []
    loop PlayerCount
        scoreLines.Push(PlayerName(A_Index) . " scores " . baseScores[A_Index] . " before penalties")

    text := JoinArray(resultLines, "`n`n") . "`n`n--- Shake scoring ---`n" . JoinArray(scoreLines, "`n")
    if !BotAutoRun
        MsgBox(text, title . " - automatic check")

    for _, line in resultLines
        AddLog(line)
}

; ============================================================================
; EXPRESSION TOKENIZER / PARSER
; ============================================================================

ParseExpression(expr, mode) {
    global ParseResultLimit

    tokenInfo := TokenizeExpression(expr, mode)
    if !tokenInfo.OK
        return {OK: false, Reason: tokenInfo.Reason, Results: [], Faces: []}

    if (tokenInfo.Tokens.Length = 0)
        return {OK: false, Reason: "The expression is empty.", Results: [], Faces: tokenInfo.Faces}

    if !ParenthesesBalanced(tokenInfo.Tokens)
        return {OK: false, Reason: "Grouping symbols are not balanced.", Results: [], Faces: tokenInfo.Faces}

    memo := Map()
    state := {Overflow: false}
    results := ParseRange(tokenInfo.Tokens, 1, tokenInfo.Tokens.Length, memo, state)
    results := DedupeResults(results)

    if state.Overflow {
        return {
            OK: false,
            Reason: "This expression has too many possible groupings for the automatic checker. Add parentheses to make the intended grouping clearer.",
            Results: [],
            Faces: tokenInfo.Faces
        }
    }

    if (results.Length = 0) {
        return {
            OK: false,
            Reason: "The expression has no legal real-number interpretation in Basic EQUATIONS. Check operators, adjacency, roots, division by zero, and grouping.",
            Results: [],
            Faces: tokenInfo.Faces
        }
    }

    return {OK: true, Reason: "", Results: results, Faces: tokenInfo.Faces}
}

ParsePhysicalGoalExpression(expr) {
    global ParseResultLimit

    tokenInfo := TokenizeExpression(expr, "Goal")
    if !tokenInfo.OK
        return {OK: false, Reason: tokenInfo.Reason, Results: [], Faces: []}

    if (tokenInfo.Tokens.Length = 0)
        return {OK: false, Reason: "The expression is empty.", Results: [], Faces: tokenInfo.Faces}

    if !ParenthesesBalanced(tokenInfo.Tokens)
        return {OK: false, Reason: "Grouping symbols are not balanced.", Results: [], Faces: tokenInfo.Faces}

    memo := Map()
    state := {Overflow: false}
    results := ParsePhysicalGoalRange(tokenInfo.Tokens, 1, tokenInfo.Tokens.Length, memo, state)
    results := DedupeResults(results)

    if state.Overflow {
        return {
            OK: false,
            Reason: "This Goal has too many possible groupings for the automatic checker. Add physical grouping to make it clearer.",
            Results: [],
            Faces: tokenInfo.Faces
        }
    }

    if (results.Length = 0) {
        return {
            OK: false,
            Reason: "The Goal has no legal real-number interpretation in Basic EQUATIONS.",
            Results: [],
            Faces: tokenInfo.Faces
        }
    }

    return {OK: true, Reason: "", Results: results, Faces: tokenInfo.Faces}
}

; Physical Goals are special. Current rules say ordinary order of operations
; does not apply and an ungrouped Goal may be interpreted in any valid way.
; In particular, the radical's default short scope does NOT prevent an
; Equation-writer from explicitly grouping a larger radicand on the Goal side.
; This parser therefore enumerates those larger radical scopes while still
; honoring any grouping that the Goal-setter physically entered.
ParsePhysicalGoalRange(tokens, start, finish, memo, state) {
    global ParseResultLimit

    if (start > finish)
        return []

    key := start . ":" . finish
    if memo.Has(key)
        return memo[key]

    if OuterParensEnclose(tokens, start, finish) {
        inner := ParsePhysicalGoalRange(tokens, start + 1, finish - 1, memo, state)
        memo[key] := inner
        return inner
    }

    results := []

    if (start = finish && tokens[start].Kind = "Number") {
        value := tokens[start].Text + 0
        results.Push({Value: value, Canon: tokens[start].Text})
        memo[key] := results
        return results
    }

    ; Prefix square root. For a physical Goal, let the radicand be any legal
    ; interpretation of the remaining range. Other top-level splits below also
    ; preserve the default short-root interpretation as one of the possibilities.
    if (tokens[start].Kind = "Root") {
        operandResults := ParsePhysicalGoalRange(tokens, start + 1, finish, memo, state)
        for _, operand in operandResults {
            calc := ApplyRoot(2, operand.Value)
            if calc.OK {
                results.Push({
                    Value: calc.Value,
                    Canon: "sqrt(" . operand.Canon . ")"
                })
                if (results.Length >= ParseResultLimit) {
                    state.Overflow := true
                    break
                }
            }
        }
    }

    if !state.Overflow {
        depth := 0

        loop (finish - start + 1) {
            i := start + A_Index - 1
            tok := tokens[i]

            if (tok.Kind = "LParen") {
                depth += 1
                continue
            }

            if (tok.Kind = "RParen") {
                depth -= 1
                continue
            }

            if (depth != 0)
                continue

            isBinary := (tok.Kind = "Op") || (tok.Kind = "Root" && i > start)
            if !isBinary
                continue

            if (i = start || i = finish)
                continue

            leftResults := ParsePhysicalGoalRange(tokens, start, i - 1, memo, state)
            rightResults := ParsePhysicalGoalRange(tokens, i + 1, finish, memo, state)

            if (leftResults.Length = 0 || rightResults.Length = 0)
                continue

            op := (tok.Kind = "Root") ? "root" : tok.Text

            for _, left in leftResults {
                for _, right in rightResults {
                    calc := (op = "root") ? ApplyRoot(left.Value, right.Value) : ApplyBinary(op, left.Value, right.Value)
                    if !calc.OK
                        continue

                    if (op = "root")
                        canon := "root(" . left.Canon . "," . right.Canon . ")"
                    else
                        canon := "(" . left.Canon . op . right.Canon . ")"

                    results.Push({Value: calc.Value, Canon: canon})

                    if (results.Length >= ParseResultLimit) {
                        state.Overflow := true
                        break 2
                    }
                }
            }

            if state.Overflow
                break
        }
    }

    results := DedupeResults(results)
    memo[key] := results
    return results
}

TokenizeExpression(expr, mode) {
    s := NormalizeExpression(expr)

    if InStr(s, "=")
        return {OK: false, Reason: "Do not type an equals sign here; enter the Solution and Goal in their separate boxes.", Tokens: [], Faces: []}

    if (s = "")
        return {OK: false, Reason: "Expression is empty.", Tokens: [], Faces: []}

    tokens := []
    faces := []
    i := 1
    n := StrLen(s)

    while (i <= n) {
        ch := SubStr(s, i, 1)

        if RegExMatch(ch, "^[0-9]$") {
            start := i
            while (i <= n && RegExMatch(SubStr(s, i, 1), "^[0-9]$"))
                i += 1

            numText := SubStr(s, start, i - start)

            if (mode = "Solution" && StrLen(numText) != 1) {
                return {
                    OK: false,
                    Reason: "Basic Solutions may contain only one-digit numerals. " . numText . " is a multi-digit numeral.",
                    Tokens: [], Faces: []
                }
            }

            if (mode = "Goal" && StrLen(numText) > 2) {
                return {
                    OK: false,
                    Reason: "A Goal numeral may contain only one or two digits. " . numText . " has more than two digits.",
                    Tokens: [], Faces: []
                }
            }

            tokens.Push({Kind: "Number", Text: numText})
            loop StrLen(numText)
                faces.Push(SubStr(numText, A_Index, 1))
            continue
        }

        if (SubStr(s, i, 4) = "sqrt") {
            tokens.Push({Kind: "Root", Text: "sqrt"})
            faces.Push("sqrt")
            i += 4
            continue
        }

        if (ch = "+" || ch = "-" || ch = "x" || ch = "/" || ch = "^") {
            tokens.Push({Kind: "Op", Text: ch})
            faces.Push(ch)
            i += 1
            continue
        }

        if (ch = "(") {
            tokens.Push({Kind: "LParen", Text: "("})
            i += 1
            continue
        }

        if (ch = ")") {
            tokens.Push({Kind: "RParen", Text: ")"})
            i += 1
            continue
        }

        return {
            OK: false,
            Reason: "Unsupported character near '" . SubStr(s, i, 8) . "'. Use digits, +, -, x, /, ^, sqrt, and grouping symbols only.",
            Tokens: [], Faces: []
        }
    }

    return {OK: true, Reason: "", Tokens: tokens, Faces: faces}
}

NormalizeExpression(expr) {
    s := StrLower(Trim(expr))
    s := StrReplace(s, " ", "")
    s := StrReplace(s, "`t", "")
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "")

    ; Common symbols / keyboard alternatives.
    s := StrReplace(s, "×", "x")
    s := StrReplace(s, "÷", "/")
    s := StrReplace(s, "−", "-")
    s := StrReplace(s, "–", "-")
    s := StrReplace(s, "√", "sqrt")
    s := StrReplace(s, "*", "^")

    ; All grouping symbols are treated as ordinary grouping.
    s := StrReplace(s, "[", "(")
    s := StrReplace(s, "]", ")")
    s := StrReplace(s, "{", "(")
    s := StrReplace(s, "}", ")")

    return s
}

ParenthesesBalanced(tokens) {
    depth := 0

    for _, tok in tokens {
        if (tok.Kind = "LParen")
            depth += 1
        else if (tok.Kind = "RParen") {
            depth -= 1
            if (depth < 0)
                return false
        }
    }

    return (depth = 0)
}

ParseRange(tokens, start, finish, memo, state) {
    global ParseResultLimit

    if (start > finish)
        return []

    key := start . ":" . finish
    if memo.Has(key)
        return memo[key]

    ; Strip one pair of parentheses only when that pair encloses the entire
    ; current range. The grouping still affects the resulting parse tree by
    ; preventing operators outside it from splitting through the group.
    if OuterParensEnclose(tokens, start, finish) {
        inner := ParseRange(tokens, start + 1, finish - 1, memo, state)
        memo[key] := inner
        return inner
    }

    results := []

    ; Single numeral.
    if (start = finish && tokens[start].Kind = "Number") {
        value := tokens[start].Text + 0
        results.Push({Value: value, Canon: tokens[start].Text})
        memo[key] := results
        return results
    }

    ; Prefix radical. Without explicit grouping, sqrt applies only to the
    ; immediate numeral/group/radical term behind it, not an entire +,-,x,/
    ; expression. This handles sqrt9, sqrt(4+5), and sqrtsqrt9.
    if (tokens[start].Kind = "Root") {
        operandResults := ParsePrefixRootOperand(tokens, start + 1, finish, memo, state)
        for _, operand in operandResults {
            calc := ApplyRoot(2, operand.Value)
            if calc.OK {
                results.Push({
                    Value: calc.Value,
                    Canon: "sqrt(" . operand.Canon . ")"
                })
                if (results.Length >= ParseResultLimit) {
                    state.Overflow := true
                    break
                }
            }
        }
    }

    if !state.Overflow {
        depth := 0

        loop (finish - start + 1) {
            i := start + A_Index - 1
            tok := tokens[i]

            if (tok.Kind = "LParen") {
                depth += 1
                continue
            }

            if (tok.Kind = "RParen") {
                depth -= 1
                continue
            }

            if (depth != 0)
                continue

            isBinary := (tok.Kind = "Op") || (tok.Kind = "Root" && i > start)
            if !isBinary
                continue

            if (i = start || i = finish)
                continue

            leftResults := ParseRange(tokens, start, i - 1, memo, state)
            if (tok.Kind = "Root")
                rightResults := ParsePrefixRootOperand(tokens, i + 1, finish, memo, state)
            else
                rightResults := ParseRange(tokens, i + 1, finish, memo, state)

            if (leftResults.Length = 0 || rightResults.Length = 0)
                continue

            op := (tok.Kind = "Root") ? "root" : tok.Text

            for _, left in leftResults {
                for _, right in rightResults {
                    calc := (op = "root") ? ApplyRoot(left.Value, right.Value) : ApplyBinary(op, left.Value, right.Value)
                    if !calc.OK
                        continue

                    if (op = "root")
                        canon := "root(" . left.Canon . "," . right.Canon . ")"
                    else
                        canon := "(" . left.Canon . op . right.Canon . ")"

                    results.Push({Value: calc.Value, Canon: canon})

                    if (results.Length >= ParseResultLimit) {
                        state.Overflow := true
                        break 2
                    }
                }
            }

            if state.Overflow
                break
        }
    }

    results := DedupeResults(results)
    memo[key] := results
    return results
}

ParsePrefixRootOperand(tokens, start, finish, memo, state) {
    if (start > finish)
        return []

    ; A grouped expression is one immediate radical operand.
    if OuterParensEnclose(tokens, start, finish)
        return ParseRange(tokens, start, finish, memo, state)

    ; A single numeral is one immediate radical operand.
    if (start = finish && tokens[start].Kind = "Number")
        return ParseRange(tokens, start, finish, memo, state)

    ; A chain such as sqrtsqrt9 is allowed.
    if (tokens[start].Kind = "Root")
        return ParseRange(tokens, start, finish, memo, state)

    return []
}

OuterParensEnclose(tokens, start, finish) {
    if (start >= finish)
        return false

    if (tokens[start].Kind != "LParen" || tokens[finish].Kind != "RParen")
        return false

    depth := 0

    loop (finish - start + 1) {
        i := start + A_Index - 1
        tok := tokens[i]

        if (tok.Kind = "LParen")
            depth += 1
        else if (tok.Kind = "RParen")
            depth -= 1

        if (depth = 0 && i < finish)
            return false
    }

    return (depth = 0)
}

DedupeResults(results) {
    seen := Map()
    out := []

    for _, item in results {
        if !seen.Has(item.Canon) {
            seen[item.Canon] := true
            out.Push(item)
        }
    }

    return out
}

ApplyBinary(op, a, b) {
    global Division

    if (op = "+")
        return ValidNumber(a + b)

    if (op = "-")
        return ValidNumber(a - b)

    if (op = "x")
        return ValidNumber(a * b)

    if (op = "/") {
        if NearlyZero(b)
            return {OK: false}
        return ValidNumber(a / b)
    }

    if (op = "^") {
        ; 2026-27 Elementary General Rule: both base and exponent must be
        ; whole numbers. Middle/Junior/Senior retain the v4.4 real-number rules.
        if (Division = "Elementary" && (!IsWholeNumberValue(a) || !IsWholeNumberValue(b)))
            return {OK: false}
        return SafePower(a, b)
    }

    return {OK: false}
}

ApplyRoot(index, radicand) {
    global Division

    if NearlyZero(index)
        return {OK: false}

    if (Division = "Elementary") {
        ; Elementary requires a counting-number index and a whole-number
        ; radicand/base. The resulting root must also be a whole number.
        if (!IsCountingNumberValue(index) || !IsWholeNumberValue(radicand))
            return {OK: false}
    }

    exponent := 1 / index
    result := SafePower(radicand, exponent)
    if !result.OK
        return result

    if (Division = "Elementary" && !IsWholeNumberValue(result.Value))
        return {OK: false}

    return result
}

IsWholeNumberValue(value) {
    if (value < 0)
        return false
    return NearlyEqual(value, Round(value))
}

IsCountingNumberValue(value) {
    if (value < 1)
        return false
    return NearlyEqual(value, Round(value))
}

SafePower(base, exponent) {
    if NearlyZero(base) && exponent <= 0
        return {OK: false}

    if (base < 0) {
        frac := ApproxFraction(exponent)
        if !frac.OK
            return {OK: false}

        if (Mod(Abs(frac.Den), 2) = 0)
            return {OK: false}

        try {
            ; Force floating-point arithmetic. AutoHotkey integer exponentiation can
            ; overflow signed 64-bit values (for example 8 ** 30 wrapped to 0).
            magnitude := ((Abs(base) + 0.0) ** exponent)
        } catch {
            return {OK: false}
        }

        sign := (Mod(Abs(frac.Num), 2) = 1) ? -1 : 1
        return ValidNumber(sign * magnitude)
    }

    try {
        ; Force floating-point arithmetic so legal large powers do not silently
        ; overflow AutoHotkey's 64-bit integer path.
        value := ((base + 0.0) ** exponent)
    } catch {
        return {OK: false}
    }

    return ValidNumber(value)
}

ApproxFraction(value, maxDen := 200) {
    tol := 1.0e-10 * Max(1, Abs(value))
    bestErr := 1.0e100
    bestNum := 0
    bestDen := 1

    loop maxDen {
        den := A_Index
        num := Round(value * den)
        err := Abs(value - (num / den))

        if (err < bestErr) {
            bestErr := err
            bestNum := num
            bestDen := den
        }

        if (err <= tol) {
            g := GCD(Abs(num), den)
            if (g = 0)
                g := 1
            return {OK: true, Num: num // g, Den: den // g}
        }
    }

    return {OK: false, Num: bestNum, Den: bestDen}
}

GCD(a, b) {
    a := Abs(Round(a))
    b := Abs(Round(b))

    while (b != 0) {
        t := Mod(a, b)
        a := b
        b := t
    }

    return a
}

ValidNumber(value) {
    ; NaN is the only number that is not equal to itself.
    if (value != value)
        return {OK: false}

    ; Keep accidental overflow / absurd values from destabilizing the UI.
    if (Abs(value) > 1.0e100)
        return {OK: false}

    return {OK: true, Value: value}
}

NearlyZero(value) {
    return Abs(value) <= 1.0e-12
}

NearlyEqual(a, b) {
    tolerance := 1.0e-9 * Max(1, Abs(a), Abs(b))
    return Abs(a - b) <= tolerance
}

FormatNumber(value) {
    ; Round() may itself overflow when asked to coerce a huge floating-point
    ; integer into AutoHotkey's integer range. Keep ordinary values pretty, but
    ; leave large values on the floating-point/scientific-notation path.
    if (Abs(value) <= 9.0e15 && NearlyEqual(value, Round(value)))
        return Round(value) . ""
    return Format("{:.10g}", value)
}

; ============================================================================
; CUBE / FACE VALIDATION HELPERS
; ============================================================================

GoalRawExpression() {
    global GoalOrder, Cubes
    text := ""

    for _, idx in GoalOrder
        text .= Cubes[idx].Face

    return text
}

GoalFaceSequence() {
    global GoalOrder, Cubes
    out := []

    for _, idx in GoalOrder
        out.Push(Cubes[idx].Face)

    return out
}

FacesEqualSequence(a, b) {
    if (a.Length != b.Length)
        return false

    loop a.Length {
        if (a[A_Index] != b[A_Index])
            return false
    }

    return true
}

CountFaces(faces) {
    counts := Map()

    for _, face in faces
        counts[face] := MapGet(counts, face) + 1

    return counts
}

ZoneFaceCounts(zone) {
    global Cubes
    counts := Map()

    for _, cube in Cubes {
        if (cube.Zone = zone)
            counts[cube.Face] := MapGet(counts, cube.Face) + 1
    }

    return counts
}

AddFaceCounts(target, source) {
    for symbol, count in source
        target[symbol] := MapGet(target, symbol) + count
}

MapGet(mapObj, key, defaultValue := 0) {
    if mapObj.Has(key)
        return mapObj[key]
    return defaultValue
}

SetDefaultChallenger() {
    global ChallengeDDL, LastMover, GoalSetter

    if !IsObject(ChallengeDDL)
        return

    if (LastMover > 0)
        ChallengeDDL.Choose(NextPlayer(LastMover))
    else if (GoalSetter > 0)
        ChallengeDDL.Choose(NextPlayer(GoalSetter))
}

; ============================================================================
; SCORING / PENALTIES
; ============================================================================

ManualPenalty(*) {
    global Phase, ChallengeDDL

    if (Phase != "GoalSetting" && Phase != "Play" && Phase != "Forceout") {
        MsgBox("A manual penalty can be entered only during an active shake.", "Penalty")
        return
    }

    player := ChallengeDDL.Value
    if (player < 1)
        player := 1

    reasonResult := InputBox(
        "Enter a short reason for the -1 penalty.`nExamples: time limit, illegal challenge, illegal BONUS move.",
        "Penalty for " . PlayerName(player),
        "w470 h180",
        "Time / procedure penalty"
    )

    if (reasonResult.Result != "OK")
        return

    reason := Trim(reasonResult.Value)
    if (reason = "")
        reason := "Manual penalty"

    AddPenalty(player, reason)
}

AddPenalty(player, reason) {
    global ShakeDelta

    ShakeDelta[player] -= 1
    AddLog(PlayerName(player) . " receives -1: " . reason . ".")
    UpdateGui()
}

FinalizeShake(baseScores, reason) {
    global PlayerCount, ShakeDelta, Totals, Phase, CurrentPlayer
    global SelectedCube, BonusUsedThisTurn, ForceoutStartTick, BotAutoRun

    SetTimer(ForceoutCutoffReached, 0)
    ResetBoardTimer()
    ForceoutStartTick := 0

    loop PlayerCount {
        p := A_Index
        ShakeDelta[p] += baseScores[p]
        Totals[p] += ShakeDelta[p]
    }

    finalText := []
    loop PlayerCount
        finalText.Push(PlayerName(A_Index) . " " . Signed(ShakeDelta[A_Index]))

    AddLog("Shake ends by " . reason . ". Final shake scores including penalties: " . JoinArray(finalText, ", ") . ".")

    Phase := "BetweenShakes"
    CurrentPlayer := 0
    SelectedCube := 0
    BonusUsedThisTurn := false
    UpdateGui()

    if !BotAutoRun {
        MsgBox(
            "Shake complete.`n`n" . JoinArray(finalText, "`n") . "`n`nUse Next Shake to continue, or End Match to calculate match points.",
            "Shake complete"
        )
    }

    ScheduleBotController()
}

NextShake(*) {
    global Phase

    if (Phase != "BetweenShakes")
        return

    StartShake(true)
}

EndMatch(*) {
    global Phase, PlayerCount, Totals, MatchPoints

    if (Phase != "BetweenShakes") {
        MsgBox("Finish the current shake before ending the match.", "End Match")
        return
    }

    MatchPoints := []
    loop PlayerCount
        MatchPoints.Push(0)

    if (PlayerCount = 2) {
        if (Totals[1] = Totals[2]) {
            MatchPoints[1] := 5
            MatchPoints[2] := 5
        } else if (Totals[1] > Totals[2]) {
            MatchPoints[1] := 6
            MatchPoints[2] := 4
        } else {
            MatchPoints[1] := 4
            MatchPoints[2] := 6
        }
    } else {
        a := Totals[1]
        b := Totals[2]
        c := Totals[3]

        if (a = b && b = c) {
            MatchPoints[1] := 4
            MatchPoints[2] := 4
            MatchPoints[3] := 4
        } else {
            maxScore := Max(a, b, c)
            minScore := Min(a, b, c)

            topPlayers := []
            bottomPlayers := []
            loop 3 {
                if (Totals[A_Index] = maxScore)
                    topPlayers.Push(A_Index)
                if (Totals[A_Index] = minScore)
                    bottomPlayers.Push(A_Index)
            }

            if (topPlayers.Length = 2) {
                for _, p in topPlayers
                    MatchPoints[p] := 5
                loop 3 {
                    if (Totals[A_Index] = minScore)
                        MatchPoints[A_Index] := 2
                }
            } else if (bottomPlayers.Length = 2) {
                loop 3 {
                    if (Totals[A_Index] = maxScore)
                        MatchPoints[A_Index] := 6
                    else
                        MatchPoints[A_Index] := 3
                }
            } else {
                loop 3 {
                    if (Totals[A_Index] = maxScore)
                        MatchPoints[A_Index] := 6
                    else if (Totals[A_Index] = minScore)
                        MatchPoints[A_Index] := 2
                    else
                        MatchPoints[A_Index] := 4
                }
            }
        }
    }

    lines := []
    loop PlayerCount {
        lines.Push(PlayerName(A_Index) . ": " . Totals[A_Index] . " shake points -> " . MatchPoints[A_Index] . " match points")
    }

    AddLog("MATCH ENDED. " . JoinArray(lines, " | "))
    Phase := "MatchOver"
    UpdateGui()

    MsgBox(JoinArray(lines, "`n"), "Final EQUATIONS match points")
}

; ============================================================================
; RULE / STATE HELPERS
; ============================================================================

CanBonus(player) {
    global PlayerCount

    playerScore := EffectiveScore(player)

    loop PlayerCount {
        if (A_Index = player)
            continue

        if (playerScore <= EffectiveScore(A_Index))
            return true
    }

    return false
}

EffectiveScore(player) {
    global Totals, ShakeDelta
    return Totals[player] + ShakeDelta[player]
}

NextPlayer(player) {
    global PlayerCount
    return (player >= PlayerCount) ? 1 : player + 1
}

PlayerName(player) {
    global Players
    if (player < 1 || player > Players.Length)
        return "(none)"
    return Players[player]
}

ResourceCount() {
    return CountZone("Resources")
}

CountZone(zone) {
    global Cubes
    count := 0

    for _, cube in Cubes {
        if (cube.Zone = zone)
            count += 1
    }

    return count
}

IsDigitFace(face) {
    return RegExMatch(face, "^\d$") ? true : false
}

CubeCode(cube) {
    global ColorShort
    return ColorShort[cube.Color] . ":" . cube.Face
}

CubeButtonText(cube) {
    global ColorShort
    return ColorShort[cube.Color] . "`n" . cube.Face
}

ZoneString(zone) {
    global Cubes, GoalOrder
    parts := []

    if (zone = "Goal") {
        for _, idx in GoalOrder
            parts.Push(CubeCode(Cubes[idx]))
    } else {
        for _, cube in Cubes {
            if (cube.Zone = zone)
                parts.Push(CubeCode(cube))
        }
    }

    return parts.Length ? JoinArray(parts, "   ") : "(empty)"
}

ZoneFaceOnlyString(zone) {
    global Cubes, GoalOrder
    parts := []

    if (zone = "Goal") {
        for _, idx in GoalOrder
            parts.Push(Cubes[idx].Face)
    } else {
        for _, cube in Cubes {
            if (cube.Zone = zone)
                parts.Push(cube.Face)
        }
    }

    return parts.Length ? JoinArray(parts, " ") : "(empty)"
}

Signed(value) {
    if (value > 0)
        return "+" . value
    return value . ""
}

JoinArray(arr, separator := ", ") {
    text := ""

    for i, item in arr {
        if (i > 1)
            text .= separator
        text .= item
    }

    return text
}

; ============================================================================
; TABLETOP DISPLAY / TIMER / HISTORY
; ============================================================================


SolutionMatClicked(*) {
    global Phase
    if (Phase = "Forceout")
        ScoreForceout()
}

CancelSelection(*) {
    global SelectedCube
    if SelectedCube {
        SelectedCube := 0
        UpdateGui()
    }
}

DisplayFace(face) {
    if (face = "x")
        return "×"
    if (face = "/")
        return "÷"
    if (face = "sqrt")
        return "√"
    return face
}

ShuffleArray(arr) {
    i := arr.Length
    while (i > 1) {
        j := Random(1, i)
        temp := arr[i]
        arr[i] := arr[j]
        arr[j] := temp
        i -= 1
    }
}

FindIndexInArray(arr, value) {
    for pos, item in arr {
        if (item = value)
            return pos
    }
    return 0
}

FallbackZonePosition(idx, zone) {
    global Cubes
    pos := 0
    loop idx {
        if (Cubes[A_Index].Zone = zone)
            pos += 1
    }
    return Max(pos, 1)
}

GetResourceSlotPosition(slot, selected := false) {
    col := Mod(slot - 1, 12)
    row := Floor((slot - 1) / 12)
    x := 64 + (col * 68)
    y := 174 + (row * 72)
    size := selected ? 56 : 50

    if selected {
        x -= 3
        y -= 3
    }

    return {X: x, Y: y, W: size, H: size}
}

GetMiddleZonePosition(zone, pos) {
    baseX := (zone = "Forbidden") ? 57 : (zone = "Permitted") ? 347 : 637
    col := Mod(pos - 1, 5)
    row := Floor((pos - 1) / 5)
    return {X: baseX + (col * 50), Y: 397 + (row * 50), W: 46, H: 46}
}

GetGoalZonePosition(pos) {
    return {X: 518 + ((pos - 1) * 58), Y: 730, W: 52, H: 52}
}

RenderBoardCubes() {
    global Cubes, CubeButtons, SelectedCube, GoalOrder, ZoneOrder, ColorShort

    for i, ctrl in CubeButtons {
        cube := Cubes[i]

        ; A native button is our entire cube. Color is encoded by the standard
        ; EQUATIONS color initial (R/B/G/K) so the face remains unambiguous even
        ; though Windows themed buttons do not reliably accept custom fills.
        prefix := ColorShort[cube.Color]
        if (i = SelectedCube)
            prefix := ">" . prefix . "<"

        ctrl.Text := prefix . "`n" . DisplayFace(cube.Face)
        ctrl.Enabled := true

        if (i = SelectedCube)
            ctrl.SetFont("s12 bold", "Segoe UI")
        else
            ctrl.SetFont("s11 bold", "Segoe UI")

        if (cube.Zone = "Resources") {
            p := GetResourceSlotPosition(cube.HomeSlot, i = SelectedCube)
        } else if (cube.Zone = "Goal") {
            pos := FindIndexInArray(GoalOrder, i)
            if !pos
                pos := 1
            p := GetGoalZonePosition(pos)
        } else if (cube.Zone = "Required" || cube.Zone = "Permitted" || cube.Zone = "Forbidden") {
            pos := FindIndexInArray(ZoneOrder[cube.Zone], i)
            if !pos
                pos := FallbackZonePosition(i, cube.Zone)
            p := GetMiddleZonePosition(cube.Zone, pos)
        } else {
            ctrl.Visible := false
            continue
        }

        ctrl.Move(p.X, p.Y, p.W, p.H)
        ctrl.Visible := true
    }
}


SetZoneVisual(zone, color, active := false) {
    global ZoneLabels

    ; Destination headers are native Buttons in v4.2. Do not recolor them:
    ; Windows themes can ignore or repaint custom button colors. Selection is
    ; indicated only by the label, which is reliable on every standard theme.
    if ZoneLabels.Has(zone) {
        if active
            ZoneLabels[zone].Text := ">> " . StrUpper(zone) . " <<"
        else
            ZoneLabels[zone].Text := StrUpper(zone)
    }
}

RefreshZoneVisuals() {
    global Phase, SelectedCube, GoalOrder, Cubes

    SetZoneVisual("Forbidden", "F8E9E9")
    SetZoneVisual("Permitted", "EAF1FA")
    SetZoneVisual("Required", "EAF5EA")
    SetZoneVisual("Goal", "FFF1D5")

    if !SelectedCube
        return

    selectedObj := Cubes[SelectedCube]
    if (selectedObj.Zone != "Resources")
        return

    if (Phase = "GoalSetting") {
        if (GoalOrder.Length < 6)
            SetZoneVisual("Goal", "FFE2A8", true)
    } else if (Phase = "Play") {
        SetZoneVisual("Required", "CDEBCB", true)
        SetZoneVisual("Permitted", "CFE1F6", true)

        if (ResourceCount() > 1)
            SetZoneVisual("Forbidden", "F3CACA", true)
    }
}

ForceoutImpossibleOpen() {
    global Phase, ForceoutStartTick

    if (Phase != "Forceout" || ForceoutStartTick = 0)
        return false

    elapsed := A_TickCount - ForceoutStartTick
    if (elapsed < 0)
        elapsed += 0x100000000

    return (elapsed <= 60000)
}

ForceoutCutoffReached(*) {
    global Phase, ImpossibleBtn

    if (Phase != "Forceout")
        return

    ImpossibleBtn.Enabled := false
    AddLog("First minute of last-cube writing has ended. IMPOSSIBLE against the last-cube Mover is now illegal.")
}

StartManualTimer(seconds, *) {
    global TimerPurpose, TimerOwner, TimerRuleManaged, TimerPenaltyEligible, TimerPenaltyStage
    global TimerGraceRemaining, TimerTaskToken

    TimerTaskToken += 1
    TimerPurpose := "Manual timer"
    TimerOwner := 0
    TimerRuleManaged := false
    TimerPenaltyEligible := false
    TimerPenaltyStage := 0
    TimerGraceRemaining := 0
    StartBoardTimer(seconds)
}

StartRuleTimer(seconds, purpose, owner := 0, penaltyEligible := true, penaltyStage := 0) {
    global TimerPurpose, TimerOwner, TimerRuleManaged, TimerPenaltyEligible, TimerPenaltyStage
    global TimerGraceRemaining, TimerTaskToken

    TimerTaskToken += 1
    TimerPurpose := purpose
    TimerOwner := owner
    TimerRuleManaged := true
    TimerPenaltyEligible := penaltyEligible
    TimerPenaltyStage := penaltyStage
    TimerGraceRemaining := 0
    StartBoardTimer(seconds)
    UpdateTimerControls()
}

StartBoardTimer(seconds, *) {
    global TimerRemaining, TimerRunning, TimerGraceRemaining

    TimerRemaining := seconds
    TimerGraceRemaining := 0
    TimerRunning := true
    UpdateTimerText()
    SetTimer(BoardTimerTick, 1000)
}

StopBoardTimer() {
    global TimerRunning, TimerGraceRemaining, TimerTaskToken

    TimerTaskToken += 1
    TimerRunning := false
    TimerGraceRemaining := 0
    SetTimer(BoardTimerTick, 0)
    UpdateTimerText()
    UpdateTimerControls()
}

ResetBoardTimer(*) {
    global TimerRemaining, TimerRunning, TimerPurpose, TimerOwner
    global TimerRuleManaged, TimerPenaltyEligible, TimerPenaltyStage, TimerGraceRemaining, TimerTaskToken

    TimerTaskToken += 1
    TimerRunning := false
    TimerRemaining := 60
    TimerPurpose := "Manual timer"
    TimerOwner := 0
    TimerRuleManaged := false
    TimerPenaltyEligible := false
    TimerPenaltyStage := 0
    TimerGraceRemaining := 0
    SetTimer(BoardTimerTick, 0)
    UpdateTimerText()
    UpdateTimerControls()
}

BoardTimerTick(*) {
    global TimerRemaining, TimerRunning, TimerGraceRemaining
    global TimerRuleManaged, TimerPenaltyEligible, TimerPenaltyStage, TimerOwner, TimerPurpose, TimerTaskToken
    global Phase, ImpossibleBtn

    if !TimerRunning
        return

    if (TimerGraceRemaining > 0) {
        TimerGraceRemaining -= 1

        if (TimerGraceRemaining <= 0) {
            TimerGraceRemaining := 0
            TimerRunning := false
            SetTimer(BoardTimerTick, 0)
            SoundBeep(950, 160)
            SoundBeep(1150, 180)

            if (TimerRuleManaged && TimerPenaltyEligible && TimerOwner > 0) {
                owner := TimerOwner
                purpose := TimerPurpose
                token := TimerTaskToken
                stage := TimerPenaltyStage
                SetTimer(OfferTimePenalty.Bind(owner, purpose, token, stage), -10)
            }
        }

        UpdateTimerText()
        return
    }

    TimerRemaining -= 1

    if (Phase = "Forceout" && !ForceoutImpossibleOpen())
        ImpossibleBtn.Enabled := false

    if (TimerRemaining = 10)
        SoundBeep(850, 90)

    if (TimerRemaining <= 0) {
        TimerRemaining := 0

        if (TimerRuleManaged && TimerPenaltyEligible && TimerOwner > 0) {
            ; Tournament rule: announce time, then allow the required 10-second
            ; countdown before a one-point time penalty can be imposed.
            TimerGraceRemaining := 10
            SoundBeep(950, 160)
            AddLog("Time limit reached for " . PlayerName(TimerOwner) . " (" . TimerPurpose . "). Ten-second countdown begins.")
        } else {
            TimerRunning := false
            SetTimer(BoardTimerTick, 0)
            SoundBeep(950, 160)
            SoundBeep(1150, 180)
        }
    }

    UpdateTimerText()
}

OfferTimePenalty(player, purpose, token, stage, *) {
    global TimerTaskToken, TimerRuleManaged, Division

    if (token != TimerTaskToken || !TimerRuleManaged)
        return

    judgeNote := ""
    if (Division = "Elementary" || Division = "Middle")
        judgeNote := "`n`nElementary/Middle: a judge must approve each one-point time penalty."

    answer := MsgBox(
        PlayerName(player) . " did not complete '" . purpose . "' by the end of the rule time plus the 10-second countdown." . judgeNote . "`n`nApply the -1 penalty?",
        "Time-limit penalty",
        "YesNo"
    )

    if (token != TimerTaskToken)
        return

    if (answer = "Yes") {
        AddPenalty(player, "Time limit - " . purpose)

        if (stage = 0) {
            AddLog(PlayerName(player) . " receives the additional one minute allowed after the first time penalty.")
            StartRuleTimer(60, purpose . " - additional minute", player, true, 1)
            return
        }

        ; After the second time penalty, the tournament rule says the player
        ; loses the turn or may not complete the task. The simulator does not
        ; guess which context-specific board action a judge would use; it stops
        ; the clock and tells the table to end that task.
        TimerRuleManaged := false
        UpdateTimerControls()
        AddLog(PlayerName(player) . " reached the second time penalty for " . purpose . "; the task must now end under the tournament time-limit rule.")
        MsgBox(
            "Second time penalty applied to " . PlayerName(player) . ".`n`nUnder the tournament rule, the player now loses the turn or is not allowed to complete the task. Resolve the table state with the normal game controls; no automatic cube move is invented.",
            "Time limit - task ends"
        )
        return
    }

    TimerRuleManaged := false
    UpdateTimerControls()
}

UpdateTimerControls() {
    global OneMinBtn, TwoMinBtn, ResetTimerBtn, Phase, TimerRuleManaged, TimerRunning

    if !IsObject(OneMinBtn)
        return

    ; Manual controls must not overwrite an official automatic clock. Forceout
    ; stays locked even after its display reaches zero because the 60-second
    ; IMPOSSIBLE cutoff is tied to the original Last Cube timestamp.
    locked := (Phase = "Forceout" || (TimerRuleManaged && TimerRunning))
    OneMinBtn.Enabled := !locked
    TwoMinBtn.Enabled := !locked
    ResetTimerBtn.Enabled := !locked
}

UpdateTimerText() {
    global TimerText, TimerPurposeText, TimerRemaining, TimerRunning
    global TimerGraceRemaining, TimerPurpose, TimerOwner, TimerRuleManaged

    if !IsObject(TimerText)
        return

    if (TimerGraceRemaining > 0) {
        TimerText.Text := "+0:" . Format("{:02}", TimerGraceRemaining)
    } else {
        minutes := Floor(TimerRemaining / 60)
        seconds := Mod(TimerRemaining, 60)
        TimerText.Text := minutes . ":" . Format("{:02}", seconds)
    }

    if IsObject(TimerPurposeText) {
        ownerText := (TimerOwner > 0) ? " - " . PlayerName(TimerOwner) : ""
        TimerPurposeText.Text := TimerPurpose . ownerText
        if (TimerGraceRemaining > 0)
            TimerPurposeText.Text := TimerPurposeText.Text . " | TIME UP: 10-second countdown"
    }

    if (TimerGraceRemaining > 0 || TimerRemaining = 0)
        TimerText.Opt("+BackgroundF4CCCC")
    else if (TimerRunning && TimerRemaining <= 10)
        TimerText.Opt("+BackgroundFFF2CC")
    else
        TimerText.Opt("+BackgroundFFFFFF")
}

ShowHistory(*) {
    global MainGui, LogLines

    dlg := Gui("+Owner" . MainGui.Hwnd, "EQUATIONS - Game History")
    dlg.SetFont("s10", "Segoe UI")
    history := LogLines.Length ? JoinArray(LogLines, "`r`n") : "No game history yet."
    dlg.Add("Edit", "x15 y15 w790 h525 ReadOnly VScroll HScroll -Wrap", history)
    closeBtn := dlg.Add("Button", "x685 y552 w120 h36 Default", "Close")
    closeBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show("w820 h605")
}

; ============================================================================
; DISPLAY / LOG
; ============================================================================

UpdateGui() {
    global PlayerCount, Players, PlayerTypes, Division, Totals, ShakeDelta, MatchPoints
    global GoalSetter, CurrentPlayer, LastMover, LastAction, Phase, ShakeNumber
    global Cubes, CubeButtons, SelectedCube, ScoreText, StatusText, ResourcesText, SelectedText
    global GoalGroupingEdit, FinishGoalBtn, GoalLeftBtn, GoalRightBtn, BonusBtn, NoGoalBtn
    global ChallengeDDL, NowBtn, ImpossibleBtn, ForceoutBtn, PenaltyBtn
    global NextShakeBtn, EndMatchBtn, HistoryBtn, GoalOrder, BonusUsedThisTurn
    global ZoneCountTexts, SolutionMatText, GoalWasGrouped
    global GoalZoneBtn, RequiredZoneBtn, PermittedZoneBtn, ForbiddenZoneBtn
    global OneMinBtn, TwoMinBtn, ResetTimerBtn

    scoreParts := []
    loop PlayerCount {
        p := A_Index
        part := Players[p] . ": " . Totals[p]
        if (PlayerTypes[p] != "Human")
            part .= " [" . PlayerTypes[p] . "]"

        if (Phase != "MatchOver")
            part .= "  [shake " . Signed(ShakeDelta[p]) . "]"
        else
            part .= "  [match pts " . MatchPoints[p] . "]"

        scoreParts.Push(part)
    }
    ScoreText.Text := Division . " Division   |   " . JoinArray(scoreParts, "      |      ")

    if (Phase = "GoalSetting") {
        StatusText.Text := "Shake " . ShakeNumber . " | GOAL SETTER: " . PlayerName(GoalSetter) . (IsBotPlayer(GoalSetter) ? " [" . PlayerTypeName(GoalSetter) . "]" : "") . " | Place 1-6 cubes in GOAL. Goal cubes may be rearranged but cannot be removed."
        SolutionMatText.Text := "SOLUTION`n`nwritten after a challenge / forceout"
        SolutionMatText.Opt("BackgroundF5F5F3")
    } else if (Phase = "Play") {
        status := "Shake " . ShakeNumber . " | TURN: " . PlayerName(CurrentPlayer) . (IsBotPlayer(CurrentPlayer) ? " [" . PlayerTypeName(CurrentPlayer) . "]" : "")
        if (LastMover > 0)
            status .= " | Last Mover: " . PlayerName(LastMover) . " (" . LastAction . ")"
        StatusText.Text := status
        SolutionMatText.Text := "SOLUTION`n`nwritten after a challenge / forceout"
        SolutionMatText.Opt("BackgroundF5F5F3")
    } else if (Phase = "Forceout") {
        StatusText.Text := "Shake " . ShakeNumber . " | FORCEOUT: two-minute writing period running. IMPOSSIBLE is legal only through the first minute."
        SolutionMatText.Text := "SOLUTION`n`nCLICK HERE TO WRITE"
        SolutionMatText.Opt("BackgroundFFF2CC")
    } else if (Phase = "BetweenShakes") {
        StatusText.Text := "Shake " . ShakeNumber . " complete. Start the next shake or end the match."
        SolutionMatText.Text := "SOLUTION`n`nshake complete"
        SolutionMatText.Opt("BackgroundF5F5F3")
    } else if (Phase = "MatchOver") {
        StatusText.Text := "MATCH COMPLETE. Final match points are shown above."
        SolutionMatText.Text := "SOLUTION`n`nmatch complete"
        SolutionMatText.Opt("BackgroundF5F5F3")
    }

    ; v4.1 has no full-size Resources background control. The board uses only
    ; thin borders and a non-overlapping header strip, so cube repainting is
    ; independent of the decorative mat.
    ZoneCountTexts["Goal"].Text := GoalOrder.Length . " / 6"
    ZoneCountTexts["Required"].Text := CountZone("Required") . " cubes"
    ZoneCountTexts["Permitted"].Text := CountZone("Permitted") . " cubes"
    ZoneCountTexts["Forbidden"].Text := CountZone("Forbidden") . " cubes"

    if SelectedCube {
        cube := Cubes[SelectedCube]
        if (Phase = "GoalSetting" && cube.Zone = "Goal")
            hint := "Goal cube selected. Use ← / → to rearrange it; it cannot return to Resources."
        else if (Phase = "GoalSetting")
            hint := "Click the GOAL header to place it, or BONUS if eligible."
        else if (Phase = "Play")
            hint := "Click the REQUIRED, PERMITTED, or FORBIDDEN header."
        else
            hint := ""
        SelectedText.Text := "Selected: " . cube.Color . " " . DisplayFace(cube.Face) . "  |  " . hint . "  |  Resources remaining: " . ResourceCount()
    } else {
        if (Phase = "GoalSetting")
            hint := "Click a rolled cube, then click the GOAL header. Goal: " . GoalOrder.Length . "/6 cubes."
        else if (Phase = "Play")
            hint := "Click a Resource cube, then click a destination header. Resources remaining: " . ResourceCount()
        else
            hint := "Resources remaining: " . ResourceCount()
        SelectedText.Text := hint
    }

    RefreshZoneVisuals()
    RenderBoardCubes()

    ; Destination buttons are the ONLY board placement targets in v4.2.
    ; Keep them disabled unless the currently selected cube can legally go there.
    GoalZoneBtn.Enabled := false
    RequiredZoneBtn.Enabled := false
    PermittedZoneBtn.Enabled := false
    ForbiddenZoneBtn.Enabled := false

    if SelectedCube {
        selectedObj := Cubes[SelectedCube]
        if (selectedObj.Zone = "Resources") {
            if (Phase = "GoalSetting" && GoalOrder.Length < 6) {
                GoalZoneBtn.Enabled := true
            } else if (Phase = "Play") {
                RequiredZoneBtn.Enabled := true
                PermittedZoneBtn.Enabled := true
                ForbiddenZoneBtn.Enabled := (ResourceCount() > 1)
            }
        }
    }

    ; Disable action buttons first; then enable only what fits the current phase.
    GoalGroupingEdit.Enabled := false
    FinishGoalBtn.Enabled := false
    GoalLeftBtn.Enabled := false
    GoalRightBtn.Enabled := false
    BonusBtn.Enabled := false
    NoGoalBtn.Enabled := false
    NowBtn.Enabled := false
    ImpossibleBtn.Enabled := false
    ForceoutBtn.Enabled := false
    PenaltyBtn.Enabled := false
    NextShakeBtn.Enabled := false
    EndMatchBtn.Enabled := false
    ChallengeDDL.Enabled := (Phase = "GoalSetting" || Phase = "Play" || Phase = "Forceout")
    HistoryBtn.Enabled := true

    if (Phase = "GoalSetting") {
        GoalGroupingEdit.Enabled := true
        PenaltyBtn.Enabled := true
        FinishGoalBtn.Enabled := (GoalOrder.Length >= 1)
        NoGoalBtn.Enabled := (GoalOrder.Length = 0 && !BonusUsedThisTurn)

        if SelectedCube {
            selectedObj := Cubes[SelectedCube]
            if (selectedObj.Zone = "Goal") {
                goalPos := FindIndexInArray(GoalOrder, SelectedCube)
                GoalLeftBtn.Enabled := (goalPos > 1)
                GoalRightBtn.Enabled := (goalPos > 0 && goalPos < GoalOrder.Length)
            } else if (selectedObj.Zone = "Resources") {
                BonusBtn.Enabled := (
                    GoalOrder.Length = 0
                    && !BonusUsedThisTurn
                    && CanBonus(GoalSetter)
                )
            }
        }
    } else if (Phase = "Play") {
        PenaltyBtn.Enabled := true

        if SelectedCube {
            BonusBtn.Enabled := (
                !BonusUsedThisTurn
                && ResourceCount() > 1
                && CanBonus(CurrentPlayer)
            )
        }

        NowBtn.Enabled := (
            LastMover > 0
            && ResourceCount() >= 2
            && (CountZone("Required") + CountZone("Permitted") > 0)
        )

        ImpossibleBtn.Enabled := (LastMover > 0)
    } else if (Phase = "Forceout") {
        PenaltyBtn.Enabled := true
        ImpossibleBtn.Enabled := (LastMover > 0 && ForceoutImpossibleOpen())
        ForceoutBtn.Enabled := true
    } else if (Phase = "BetweenShakes") {
        NextShakeBtn.Enabled := true
        EndMatchBtn.Enabled := true
    }

    ; A bot seat owns the normal move/Goal controls during its turn. Challenge
    ; controls stay available so a human opponent can still challenge a bot.
    if (Phase = "GoalSetting" && IsBotPlayer(GoalSetter)) {
        GoalGroupingEdit.Enabled := false
        FinishGoalBtn.Enabled := false
        GoalLeftBtn.Enabled := false
        GoalRightBtn.Enabled := false
        BonusBtn.Enabled := false
        NoGoalBtn.Enabled := false
        GoalZoneBtn.Enabled := false
        for _, ctrl in CubeButtons
            ctrl.Enabled := false
    } else if (Phase = "Play" && IsBotPlayer(CurrentPlayer)) {
        RequiredZoneBtn.Enabled := false
        PermittedZoneBtn.Enabled := false
        ForbiddenZoneBtn.Enabled := false
        BonusBtn.Enabled := false
        for _, ctrl in CubeButtons
            ctrl.Enabled := false
    }

    UpdateTimerControls()
}


RunRegressionTests(*) {
    global Division, PhysicalCubeFaces, ColorFaces, PlayerCount, PlayerTypes, Cubes, BotCachedEquationEntries

    originalDivision := Division
    failures := []
    passed := 0

    tests := [
        {Div: "Elementary", Expr: "3^2", Mode: "Solution", OK: true, Name: "Elementary whole-number power"},
        {Div: "Elementary", Expr: "4^(1/2)", Mode: "Solution", OK: false, Name: "Elementary fractional exponent rejected"},
        {Div: "Elementary", Expr: "(2-5)^4", Mode: "Solution", OK: false, Name: "Elementary negative base rejected"},
        {Div: "Elementary", Expr: "sqrt9", Mode: "Solution", OK: true, Name: "Elementary exact square root"},
        {Div: "Elementary", Expr: "sqrt5", Mode: "Solution", OK: false, Name: "Elementary irrational root rejected"},
        {Div: "Elementary", Expr: "3sqrt8", Mode: "Solution", OK: true, Name: "Elementary exact cube root"},
        {Div: "Elementary", Expr: "3sqrt9", Mode: "Solution", OK: false, Name: "Elementary non-whole root rejected"},
        {Div: "Middle", Expr: "4^(1/2)", Mode: "Solution", OK: true, Name: "Middle fractional exponent retained"},
        {Div: "Middle", Expr: "(2-5)^4", Mode: "Solution", OK: true, Name: "Middle negative base retained"},
        {Div: "Middle", Expr: "sqrt5", Mode: "Solution", OK: true, Name: "Middle irrational root retained"},
        {Div: "Middle", Expr: "8/0", Mode: "Solution", OK: false, Name: "Division by zero rejected"},
        {Div: "Middle", Expr: "0^0", Mode: "Solution", OK: false, Name: "Zero to zero rejected"},
        {Div: "Middle", Expr: "12", Mode: "Solution", OK: false, Name: "Multi-digit Basic Solution rejected"},
        {Div: "Middle", Expr: "12", Mode: "Goal", OK: true, Name: "Two-digit Goal numeral retained"}
    ]

    for _, test in tests {
        Division := test.Div
        result := ParseExpression(test.Expr, test.Mode)
        if (result.OK = test.OK)
            passed += 1
        else
            failures.Push(test.Name . " [" . test.Div . ": " . test.Expr . "] expected OK=" . test.OK . " got OK=" . result.OK)
    }

    ; Physical cube-table invariants: four colors, six physical cubes per color,
    ; and six faces per physical cube. Also verify every physical cube preserves
    ; the standard v4.4 face multiset for its color.
    for _, color in ["Red", "Blue", "Green", "Black"] {
        cubeSets := PhysicalCubeFaces[color]
        if (cubeSets.Length != 6) {
            failures.Push(color . " physical cube count expected 6, got " . cubeSets.Length)
        } else {
            passed += 1
        }

        for cubeNo, faces in cubeSets {
            if (faces.Length != 6) {
                failures.Push(color . " cube " . cubeNo . " face count expected 6, got " . faces.Length)
                continue
            }

            if !SameFaceMultiset(faces, ColorFaces[color])
                failures.Push(color . " cube " . cubeNo . " does not match the standard face set")
            else
                passed += 1
        }
    }

    ; v4.6 controller/parser bridge smoke tests.
    typeCases := Map(
        "H", "Human", "P", "Practice Bot", "V", "Very Hard Bot",
        "R", "Rules Fuzzer", "F", "Parser Fuzzer", "C", "Chaos Fuzzer"
    )
    for input, expected in typeCases {
        if (NormalizePlayerType(input) = expected)
            passed += 1
        else
            failures.Push("Player-type normalization failed for " . input)
    }

    converted := BotCanonToInput("root(3,8)")
    convertedAnalysis := ParseExpression(converted, "Goal")
    if (convertedAnalysis.OK && convertedAnalysis.Results.Length = 1 && NearlyEqual(convertedAnalysis.Results[1].Value, 2))
        passed += 1
    else
        failures.Push("Canonical nth-root conversion failed: " . converted)

    Division := "Middle"
    ; Test the arithmetic primitives directly. ParseExpression is intentionally
    ; ambiguity-aware and may retain multiple internal parses/canonical forms, so
    ; requiring Results.Length = 1 made the v4.6.2 regression itself unreliable.
    hugePower := SafePower(8, 30)
    zeroRoot := ApplyRoot(32, 0)
    expectedHugePower := 1.2379400392853803e27
    if (hugePower.OK && zeroRoot.OK
        && NearlyEqual(hugePower.Value, expectedHugePower)
        && NearlyZero(zeroRoot.Value)
        && !NearlyEqual(hugePower.Value, zeroRoot.Value)) {
        passed += 1
    } else {
        powerText := hugePower.OK ? FormatNumber(hugePower.Value) : "INVALID"
        rootText := zeroRoot.OK ? FormatNumber(zeroRoot.Value) : "INVALID"
        failures.Push(
            "High-power/root sanity failed: 8^30=" . powerText
            . " (expected about 1.23794e27), 32nd root of 0=" . rootText
        )
    }

    if (BotTopLevelComma("3,(4+5)") = 2)
        passed += 1
    else
        failures.Push("Bot canonical comma scanner failed")

    if (PlayerTypes.Length = PlayerCount)
        passed += 1
    else
        failures.Push("PlayerTypes array length does not match PlayerCount")

    savedCubes := Cubes
    try {
        Cubes := [
            {Face: "2"},
            {Face: "+"},
            {Face: "3"}
        ]
        built := BotBuildExpressionFromIndices([1, 2, 3])
        builtAnalysis := built.OK ? ParseExpression(built.Expr, "Solution") : {OK: false}
        if (built.OK && NearlyEqual(built.Value, 5) && builtAnalysis.OK && builtAnalysis.Results.Length = 1 && NearlyEqual(builtAnalysis.Results[1].Value, 5))
            passed += 1
        else
            failures.Push("Bot physical-cube expression builder failed on 2,+,3")

        Cubes := [
            {Face: "sqrt"},
            {Face: "9"}
        ]
        rootBuilt := BotBuildExpressionFromIndices([1, 2])
        rootAnalysis := rootBuilt.OK ? ParseExpression(rootBuilt.Expr, "Solution") : {OK: false}
        if (rootBuilt.OK && NearlyEqual(rootBuilt.Value, 3) && rootAnalysis.OK && rootAnalysis.Results.Length = 1 && NearlyEqual(rootAnalysis.Results[1].Value, 3))
            passed += 1
        else
            failures.Push("Bot unary-root expression builder failed on sqrt,9")
    } finally {
        Cubes := savedCubes
    }

    savedCache := BotCachedEquationEntries
    try {
        BotCachedEquationEntries := Map()
        testEntry := {Submitted: true, Solution: "(2+3)", Goal: "5"}
        BotCacheEquation(99, "NOW", testEntry)
        cachedTest := BotTakeCachedEquation(99, "NOW")
        secondTake := BotTakeCachedEquation(99, "NOW")
        if (cachedTest.Found && cachedTest.Entry.Solution = "(2+3)" && !secondTake.Found)
            passed += 1
        else
            failures.Push("Bot challenge Equation cache round-trip failed")
    } finally {
        BotCachedEquationEntries := savedCache
    }

    Division := originalDivision

    if (failures.Length = 0) {
        MsgBox("All " . passed . " v4.6.4 regression checks passed.", "EQUATIONS v4.6.4 self-test")
    } else {
        MsgBox(
            passed . " checks passed; " . failures.Length . " failed.`n`n" . JoinArray(failures, "`n"),
            "EQUATIONS v4.6.4 self-test - FAILURES"
        )
    }
}

SameFaceMultiset(a, b) {
    if (a.Length != b.Length)
        return false

    counts := Map()
    for _, face in a
        counts[face] := MapGet(counts, face) + 1

    for _, face in b {
        if (MapGet(counts, face) <= 0)
            return false
        counts[face] := MapGet(counts, face) - 1
    }

    for _, count in counts {
        if (count != 0)
            return false
    }

    return true
}

^+t::RunRegressionTests()
^+b::ShowBotDiagnostics()

AddLog(message) {
    global LogLines, LogEdit

    LogLines.Push(message)

    while (LogLines.Length > 300)
        LogLines.RemoveAt(1)

    if IsObject(LogEdit)
        LogEdit.Value := JoinArray(LogLines, "`r`n")
}
