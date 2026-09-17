#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; ACADEMIC GAMES EQUATIONS - LOCAL HOT-SEAT PRACTICE v4.4
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
;   - Includes a manual 1-minute / 2-minute tournament timer.
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
global TimerRemaining := 0
global TimerRunning := false
global ForceoutStartTick := 0

; --------------------------------- START -----------------------------------

if !SetupPlayers()
    ExitApp()

BuildGui()
GoalSetter := DetermineFirstGoalSetter()

 ; Show the stable v4.0 board, then render the first shake.
MainGui.Show("w1320 h900")
StartShake(false)
return

; ============================================================================
; PLAYER / MATCH SETUP
; ============================================================================

SetupPlayers() {
    global PlayerCount, Players, Totals, ShakeDelta, MatchPoints

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

    Players := []
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

        Players.Push(name)
    }

    Totals := []
    ShakeDelta := []
    MatchPoints := []

    loop PlayerCount {
        Totals.Push(0)
        ShakeDelta.Push(0)
        MatchPoints.Push(0)
    }

    return true
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
    global CubeColors, CubeTextColors, TimerText

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

    ; Tournament timer. It is deliberately manual: it never invents a penalty.
    MainGui.Add("GroupBox", "x960 y515 w340 h120", "Table Timer")
    TimerText := MainGui.Add("Text", "x978 y542 w85 h38 Center Border BackgroundFFFFFF", "1:00")
    TimerText.SetFont("s18 bold", "Segoe UI")
    oneMinBtn := MainGui.Add("Button", "x1076 y542 w64 h38", "1 min")
    twoMinBtn := MainGui.Add("Button", "x1148 y542 w64 h38", "2 min")
    resetTimerBtn := MainGui.Add("Button", "x1220 y542 w60 h38", "Reset")
    oneMinBtn.OnEvent("Click", StartBoardTimer.Bind(60))
    twoMinBtn.OnEvent("Click", StartBoardTimer.Bind(120))
    resetTimerBtn.OnEvent("Click", ResetBoardTimer)
    MainGui.Add("Text", "x978 y588 w302 h34", "Use 1 or 2 minutes as the rule situation requires. The clock only alerts; players still make rulings.")

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
}

RollAllCubes() {
    global Cubes

    Cubes := []
    colors := ["Red", "Blue", "Green", "Black"]
    slots := []
    loop 24
        slots.Push(A_Index)
    ShuffleArray(slots)

    id := 0
    for _, color in colors {
        loop 6 {
            id += 1
            Cubes.Push({
                Id: id,
                Color: color,
                Face: RandomFace(color),
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

    AddLog(PlayerName(CurrentPlayer) . " moves " . CubeCode(cube) . " to " . zone . ".")

    if (ResourceCount() = 0) {
        Phase := "Forceout"
        ForceoutStartTick := A_TickCount
        AddLog("Last cube moved. The automatic two-minute writing period begins now; IMPOSSIBLE remains legal only through the first minute.")
        CurrentPlayer := 0
        BonusUsedThisTurn := false
        StartBoardTimer(120)
        SetTimer(ForceoutCutoffReached, -60000)
    } else {
        CurrentPlayer := NextPlayer(CurrentPlayer)
        BonusUsedThisTurn := false

        if (ResourceCount() = 1)
            AddLog("One Resource cube remains. NOW is no longer legal. The last cube must go to Required or Permitted unless someone challenges IMPOSSIBLE.")
    }

    SetDefaultChallenger()
    UpdateGui()
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
        SetDefaultChallenger()
    }

    UpdateGui()
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

    answer := MsgBox(
        "Do ALL opponents agree that no legal Goal with a correct Solution can be made?`n`nYES = all agree; this shake is void and the same Goal-setter rerolls.`nNO = the opponent selected in Challenger disagrees and challenges the declaration.",
        "NO GOAL declaration",
        "YesNoCancel"
    )

    if (answer = "Cancel")
        return

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

    challengerEntry := PromptNoGoalEquation(challenger, "NO GOAL Challenger - you must show a legal Goal and Solution")
    challengerCheck := CheckNoGoalEquation(challengerEntry)

    thirdCheck := {Correct: false, Reason: "No Equation presented", Submitted: false}
    thirdEntry := {Submitted: false, Solution: "", Goal: ""}

    if thirdWillWrite {
        thirdEntry := PromptNoGoalEquation(third, "NO GOAL Third Party - optional Equation")
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

    writerEntry := PromptEquation(writer, roleText)
    writerCheck := CheckBoardEquation(writerEntry, mode)

    thirdEntry := {Submitted: false, Solution: "", Goal: ""}
    thirdCheck := {Correct: false, Reason: "No Equation presented", Submitted: false}

    if thirdWillWrite {
        thirdEntry := PromptEquation(third, type . " Third Party - optional Equation")
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
        entry := PromptEquation(p, "Last Cube / Forceout - write your Equation")
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

PromptEquation(player, roleText) {
    global MainGui, GoalPhysicalExpr

    result := {Submitted: false, Solution: "", Goal: ""}
    dlg := Gui("+Owner" . MainGui.Hwnd, "Write Equation - " . PlayerName(player))
    dlg.BackColor := "F5F2EA"
    dlg.SetFont("s10", "Segoe UI")

    handoff := dlg.Add("Text", "x15 y15 w750 h48 Center Border BackgroundFFF4CC", "HAND THE COMPUTER TO " . StrUpper(PlayerName(player)) . "`n" . roleText)
    handoff.SetFont("s11 bold", "Segoe UI")

    dlg.Add("Text", "x20 y75 w740 h96 Border BackgroundFFFFFF", BoardSummaryForWriter())
    dlg.Add("Text", "x20 y182 w740 h52", "Write the same Equation you would present on paper. The checker uses the real cube locations and EQUATIONS grouping rules. Previous writers stay hidden until scoring is revealed.")

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

    return result
}

PromptNoGoalEquation(player, roleText) {
    global MainGui

    result := {Submitted: false, Solution: "", Goal: ""}
    dlg := Gui("+Owner" . MainGui.Hwnd, "NO GOAL Equation - " . PlayerName(player))
    dlg.BackColor := "F5F2EA"
    dlg.SetFont("s10", "Segoe UI")

    handoff := dlg.Add("Text", "x15 y15 w750 h48 Center Border BackgroundFFF4CC", "HAND THE COMPUTER TO " . StrUpper(PlayerName(player)) . "`n" . roleText)
    handoff.SetFont("s11 bold", "Segoe UI")
    dlg.Add("Text", "x20 y75 w740 h72 Border BackgroundFFFFFF", "ROLLED RESOURCES`n" . ZoneFaceOnlyString("Resources"))
    dlg.Add("Text", "x20 y158 w740 h58", "For this special NO GOAL challenge, create BOTH sides from different physical cubes in the roll. Goal: 1-6 cubes and one- or two-digit numerals. Solution: at least 2 cubes and one-digit numerals.")

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
    global PlayerCount

    scoreLines := []
    loop PlayerCount
        scoreLines.Push(PlayerName(A_Index) . " scores " . baseScores[A_Index] . " before penalties")

    text := JoinArray(resultLines, "`n`n") . "`n`n--- Shake scoring ---`n" . JoinArray(scoreLines, "`n")
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

    if (op = "^")
        return SafePower(a, b)

    return {OK: false}
}

ApplyRoot(index, radicand) {
    if NearlyZero(index)
        return {OK: false}

    exponent := 1 / index
    return SafePower(radicand, exponent)
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
            magnitude := (Abs(base) ** exponent)
        } catch {
            return {OK: false}
        }

        sign := (Mod(Abs(frac.Num), 2) = 1) ? -1 : 1
        return ValidNumber(sign * magnitude)
    }

    try {
        value := base ** exponent
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
    if NearlyEqual(value, Round(value))
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
    global SelectedCube, BonusUsedThisTurn, ForceoutStartTick

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

    MsgBox(
        "Shake complete.`n`n" . JoinArray(finalText, "`n") . "`n`nUse Next Shake to continue, or End Match to calculate match points.",
        "Shake complete"
    )
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

StartBoardTimer(seconds, *) {
    global TimerRemaining, TimerRunning

    TimerRemaining := seconds
    TimerRunning := true
    UpdateTimerText()
    SetTimer(BoardTimerTick, 1000)
}

ResetBoardTimer(*) {
    global TimerRemaining, TimerRunning

    TimerRunning := false
    TimerRemaining := 60
    SetTimer(BoardTimerTick, 0)
    UpdateTimerText()
}

BoardTimerTick(*) {
    global TimerRemaining, TimerRunning, Phase, ImpossibleBtn

    if !TimerRunning
        return

    TimerRemaining -= 1

    if (Phase = "Forceout" && !ForceoutImpossibleOpen())
        ImpossibleBtn.Enabled := false

    if (TimerRemaining = 10)
        SoundBeep(850, 90)

    if (TimerRemaining <= 0) {
        TimerRemaining := 0
        TimerRunning := false
        SetTimer(BoardTimerTick, 0)
        SoundBeep(950, 160)
        SoundBeep(1150, 180)
    }

    UpdateTimerText()
}

UpdateTimerText() {
    global TimerText, TimerRemaining, TimerRunning

    if !IsObject(TimerText)
        return

    minutes := Floor(TimerRemaining / 60)
    seconds := Mod(TimerRemaining, 60)
    TimerText.Text := minutes . ":" . Format("{:02}", seconds)

    if (TimerRemaining = 0)
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
    global PlayerCount, Players, Totals, ShakeDelta, MatchPoints
    global GoalSetter, CurrentPlayer, LastMover, LastAction, Phase, ShakeNumber
    global Cubes, SelectedCube, ScoreText, StatusText, ResourcesText, SelectedText
    global GoalGroupingEdit, FinishGoalBtn, GoalLeftBtn, GoalRightBtn, BonusBtn, NoGoalBtn
    global ChallengeDDL, NowBtn, ImpossibleBtn, ForceoutBtn, PenaltyBtn
    global NextShakeBtn, EndMatchBtn, HistoryBtn, GoalOrder, BonusUsedThisTurn
    global ZoneCountTexts, SolutionMatText, GoalWasGrouped
    global GoalZoneBtn, RequiredZoneBtn, PermittedZoneBtn, ForbiddenZoneBtn

    scoreParts := []
    loop PlayerCount {
        p := A_Index
        part := Players[p] . ": " . Totals[p]

        if (Phase != "MatchOver")
            part .= "  [shake " . Signed(ShakeDelta[p]) . "]"
        else
            part .= "  [match pts " . MatchPoints[p] . "]"

        scoreParts.Push(part)
    }
    ScoreText.Text := JoinArray(scoreParts, "      |      ")

    if (Phase = "GoalSetting") {
        StatusText.Text := "Shake " . ShakeNumber . " | GOAL SETTER: " . PlayerName(GoalSetter) . " | Place 1-6 cubes in GOAL. Goal cubes may be rearranged but cannot be removed."
        SolutionMatText.Text := "SOLUTION`n`nwritten after a challenge / forceout"
        SolutionMatText.Opt("BackgroundF5F5F3")
    } else if (Phase = "Play") {
        status := "Shake " . ShakeNumber . " | TURN: " . PlayerName(CurrentPlayer)
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
}

AddLog(message) {
    global LogLines, LogEdit

    LogLines.Push(message)

    while (LogLines.Length > 300)
        LogLines.RemoveAt(1)

    if IsObject(LogEdit)
        LogEdit.Value := JoinArray(LogLines, "`r`n")
}
