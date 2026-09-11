#Requires AutoHotkey v1
#SingleInstance Force
#NoEnv
SetBatchLines, -1
SetWinDelay, -1
SetKeyDelay, -1
SetMouseDelay, -1
ListLines, Off
CoordMode, Mouse, Screen

; ============================================================
; COMPUTER BALLPIT - COMPACT TABBED MENU
; ============================================================
; Hotkeys:
;   Numpad /      Spawn balls
;   Numpad *      Despawn balls
;   F1            Hide/show control menu
;   F2            Pause/resume physics
;   F3            Cycle cursor force mode
;   NumpadEnter   Reload
;   Esc           Exit
;
; Cursor modes:
;   Repel     = balls run away from cursor
;   Attract   = balls get pulled toward cursor
;   Orbit     = balls circle around cursor
;   Tornado   = balls spiral around and upward
;
; Features:
;   - Compact tabbed menu
;   - Lots of balls
;   - Balls always on top
;   - Cursor force modes
;   - Spatial grid collision
;   - Click-through balls
;   - Physics sliders
; ============================================================

; ============================================================
; DEFAULT PHYSICS VALUES
; ============================================================

GRAVITY := 0.65
AIR_FRICTION := 1.007
FLOOR_FRICTION := 1.05
BOUNCINESS := 0.7
WALL_BOUNCINESS := 0.76
COLLISION_STRENGTH := 0.82
MAX_SPEED := 48
BALL_SIZE := 34

; Cursor hand / magnet force.
CURSOR_FORCE_ON := true
CURSOR_MODE := "Repel"
CURSOR_RADIUS := 145
CURSOR_FORCE := 2.35

; Always-on-top behavior.
BALLS_ALWAYS_ON_TOP := true
TOPMOST_REFRESH_MS := 1000

TIMER_MS := 16
STARTING_BALLS := 75
SPAWN_AMOUNT := 25
DESPAWN_AMOUNT := 25
MAX_BALLS := 500

GRID_CELL_SIZE := BALL_SIZE * 2

REST_Y_SPEED := 0.65
REST_X_SPEED := 0.18
DRAW_EPSILON := 0.35

Balls := []
NextBallId := 1
MenuVisible := true
PhysicsPaused := false
OldBallSize := BALL_SIZE

GravitySlider := Round(GRAVITY * 100)
AirFrictionSlider := Round((AIR_FRICTION - 1) * 10000)
FloorFrictionSlider := Round((FLOOR_FRICTION - 1) * 1000)
BouncinessSlider := Round(BOUNCINESS * 100)
WallBouncinessSlider := Round(WALL_BOUNCINESS * 100)
CollisionSlider := Round(COLLISION_STRENGTH * 100)
MaxSpeedSlider := MAX_SPEED
BallSizeSlider := BALL_SIZE
MaxBallsSlider := MAX_BALLS
CursorRadiusSlider := CURSOR_RADIUS
CursorForceSlider := Round(CURSOR_FORCE * 100)
CursorForceCheck := CURSOR_FORCE_ON ? 1 : 0
TopmostCheck := BALLS_ALWAYS_ON_TOP ? 1 : 0

CreateControlMenu()
SpawnBalls(STARTING_BALLS)
SetTimer, PhysicsTick, %TIMER_MS%
SetTimer, EnforceTopmostTick, %TOPMOST_REFRESH_MS%

Return

; ============================================================
; HOTKEYS
; ============================================================

NumpadDiv::
	SpawnBalls(SPAWN_AMOUNT)
Return

NumpadMult::
	DespawnBalls(DESPAWN_AMOUNT)
Return

NumpadEnter::Reload
Esc::ExitApp

F1::
	ToggleMenu()
Return

F2::
	TogglePause()
Return

F3::
	CycleCursorMode()
Return

; ============================================================
; COMPACT CONTROL MENU
; ============================================================

CreateControlMenu() {
	global

	Gui, MENU:New, +AlwaysOnTop +ToolWindow +HwndMENU_HWND
	Gui, MENU:Color, F7F7F7
	Gui, MENU:Margin, 12, 10
	Gui, MENU:Font, s10, Segoe UI

	Gui, MENU:Add, Text, xm ym w360 Center c222222, Computer Ballpit Controls
	Gui, MENU:Font, s8, Segoe UI
	Gui, MENU:Add, Text, xm y+3 w360 Center c666666, / = +balls     * = -balls     F1 = menu     F2 = pause     F3 = mode

	Gui, MENU:Font, s9, Segoe UI
	Gui, MENU:Add, Tab2, xm y+8 w360 h280 vMenuTabs, Main|Cursor|Physics|Limits

	; ========================================================
	; MAIN TAB
	; ========================================================

	Gui, MENU:Tab, Main
	Gui, MENU:Add, Checkbox, x24 y83 vTopmostCheck gUpdatePhysics Checked%TopmostCheck%, Balls always on top

	Gui, MENU:Add, Button, x24 y116 w100 h30 gSpawnButton, Spawn 25
	Gui, MENU:Add, Button, x132 y116 w100 h30 gDespawnButton, Despawn 25
	Gui, MENU:Add, Button, x240 y116 w100 h30 gClearButton, Clear

	Gui, MENU:Add, Button, x24 y156 w154 h30 gResetPhysicsButton, Reset Physics
	Gui, MENU:Add, Button, x186 y156 w154 h30 gChaosButton, Chaos Toss

	Gui, MENU:Add, Button, x24 y196 w316 h30 gPauseButton vPauseButtonText, Pause Physics

	Gui, MENU:Add, Text, x24 y238 w316 vBallCountText Center c444444, Balls: 0

	; ========================================================
	; CURSOR TAB
	; ========================================================

	Gui, MENU:Tab, Cursor
	Gui, MENU:Add, Checkbox, x24 y83 vCursorForceCheck gUpdatePhysics Checked%CursorForceCheck%, Cursor force on

	Gui, MENU:Add, Text, x24 y113 w316 vCursorModeText, Cursor mode: %CURSOR_MODE%
	Gui, MENU:Add, DropDownList, x24 y135 w316 vCursorModeChoice gUpdatePhysics Choose1, Repel|Attract|Orbit|Tornado

	Gui, MENU:Add, Text, x24 y172 w316 vCursorRadiusText, Cursor radius: %CURSOR_RADIUS%
	Gui, MENU:Add, Slider, x24 y193 w316 Range20-450 TickInterval25 AltSubmit vCursorRadiusSlider gUpdatePhysics, %CursorRadiusSlider%

	Gui, MENU:Add, Text, x24 y228 w316 vCursorForceText, Cursor force: %CURSOR_FORCE%
	Gui, MENU:Add, Slider, x24 y249 w316 Range0-800 TickInterval50 AltSubmit vCursorForceSlider gUpdatePhysics, %CursorForceSlider%

	; ========================================================
	; PHYSICS TAB
	; ========================================================

	Gui, MENU:Tab, Physics
	Gui, MENU:Add, Text, x24 y83 w150 vGravityText, Gravity: %GRAVITY%
	Gui, MENU:Add, Slider, x174 y80 w166 Range0-250 TickInterval25 AltSubmit vGravitySlider gUpdatePhysics, %GravitySlider%

	Gui, MENU:Add, Text, x24 y122 w150 vAirFrictionText, Air friction: %AIR_FRICTION%
	Gui, MENU:Add, Slider, x174 y119 w166 Range0-180 TickInterval10 AltSubmit vAirFrictionSlider gUpdatePhysics, %AirFrictionSlider%

	Gui, MENU:Add, Text, x24 y161 w150 vFloorFrictionText, Floor friction: %FLOOR_FRICTION%
	Gui, MENU:Add, Slider, x174 y158 w166 Range0-200 TickInterval10 AltSubmit vFloorFrictionSlider gUpdatePhysics, %FloorFrictionSlider%

	Gui, MENU:Add, Text, x24 y200 w150 vBouncinessText, Floor bounce: %BOUNCINESS%
	Gui, MENU:Add, Slider, x174 y197 w166 Range0-100 TickInterval10 AltSubmit vBouncinessSlider gUpdatePhysics, %BouncinessSlider%

	Gui, MENU:Add, Text, x24 y239 w150 vWallBouncinessText, Wall bounce: %WALL_BOUNCINESS%
	Gui, MENU:Add, Slider, x174 y236 w166 Range0-100 TickInterval10 AltSubmit vWallBouncinessSlider gUpdatePhysics, %WallBouncinessSlider%

	; ========================================================
	; LIMITS TAB
	; ========================================================

	Gui, MENU:Tab, Limits
	Gui, MENU:Add, Text, x24 y83 w316 vCollisionText, Ball collision strength: %COLLISION_STRENGTH%
	Gui, MENU:Add, Slider, x24 y104 w316 Range0-120 TickInterval10 AltSubmit vCollisionSlider gUpdatePhysics, %CollisionSlider%

	Gui, MENU:Add, Text, x24 y141 w316 vMaxSpeedText, Max speed: %MAX_SPEED%
	Gui, MENU:Add, Slider, x24 y162 w316 Range5-160 TickInterval5 AltSubmit vMaxSpeedSlider gUpdatePhysics, %MaxSpeedSlider%

	Gui, MENU:Add, Text, x24 y199 w316 vBallSizeText, Ball size: %BALL_SIZE%
	Gui, MENU:Add, Slider, x24 y220 w316 Range10-80 TickInterval5 AltSubmit vBallSizeSlider gUpdatePhysics, %BallSizeSlider%

	Gui, MENU:Add, Text, x24 y255 w316 vMaxBallsText, Max balls: %MAX_BALLS%
	Gui, MENU:Add, Slider, x24 y276 w316 Range50-1000 TickInterval50 AltSubmit vMaxBallsSlider gUpdatePhysics, %MaxBallsSlider%

	Gui, MENU:Tab

	Gui, MENU:Show, x30 y30 AutoSize, Computer Ballpit
}

UpdatePhysics:
	Gui, MENU:Submit, NoHide

	BALLS_ALWAYS_ON_TOP := TopmostCheck ? true : false
	CURSOR_FORCE_ON := CursorForceCheck ? true : false

	if (CursorModeChoice != "")
		CURSOR_MODE := CursorModeChoice

	CURSOR_RADIUS := CursorRadiusSlider
	CURSOR_FORCE := Round(CursorForceSlider / 100, 2)

	GRAVITY := Round(GravitySlider / 100, 2)
	AIR_FRICTION := Round(1 + AirFrictionSlider / 10000, 4)
	FLOOR_FRICTION := Round(1 + FloorFrictionSlider / 1000, 3)
	BOUNCINESS := Round(BouncinessSlider / 100, 2)
	WALL_BOUNCINESS := Round(WallBouncinessSlider / 100, 2)
	COLLISION_STRENGTH := Round(CollisionSlider / 100, 2)
	MAX_SPEED := MaxSpeedSlider
	BALL_SIZE := BallSizeSlider
	MAX_BALLS := MaxBallsSlider
	GRID_CELL_SIZE := BALL_SIZE * 2

	GuiControl, MENU:, CursorModeText, Cursor mode: %CURSOR_MODE%
	GuiControl, MENU:, CursorRadiusText, Cursor radius: %CURSOR_RADIUS%
	GuiControl, MENU:, CursorForceText, Cursor force: %CURSOR_FORCE%
	GuiControl, MENU:, GravityText, Gravity: %GRAVITY%
	GuiControl, MENU:, AirFrictionText, Air friction: %AIR_FRICTION%
	GuiControl, MENU:, FloorFrictionText, Floor friction: %FLOOR_FRICTION%
	GuiControl, MENU:, BouncinessText, Floor bounce: %BOUNCINESS%
	GuiControl, MENU:, WallBouncinessText, Wall bounce: %WALL_BOUNCINESS%
	GuiControl, MENU:, CollisionText, Ball collision strength: %COLLISION_STRENGTH%
	GuiControl, MENU:, MaxSpeedText, Max speed: %MAX_SPEED%
	GuiControl, MENU:, BallSizeText, Ball size: %BALL_SIZE%
	GuiControl, MENU:, MaxBallsText, Max balls: %MAX_BALLS%

	if (BALL_SIZE != OldBallSize) {
		ResizeAllBalls(BALL_SIZE)
		OldBallSize := BALL_SIZE
	}

	ApplyTopmostToAllBalls()
	UpdateBallCount()
Return

SpawnButton:
	SpawnBalls(25)
Return

DespawnButton:
	DespawnBalls(25)
Return

ClearButton:
	ClearBalls()
Return

ResetPhysicsButton:
	ResetPhysicsDefaults()
Return

ChaosButton:
	ChaosToss()
Return

PauseButton:
	TogglePause()
Return

MENUGuiClose:
	MenuVisible := false
	Gui, MENU:Hide
Return

ToggleMenu() {
	global MenuVisible

	if (MenuVisible) {
		Gui, MENU:Hide
		MenuVisible := false
	} else {
		Gui, MENU:Show
		MenuVisible := true
	}
}

TogglePause() {
	global PhysicsPaused

	PhysicsPaused := !PhysicsPaused

	if (PhysicsPaused)
		GuiControl, MENU:, PauseButtonText, Resume Physics
	else
		GuiControl, MENU:, PauseButtonText, Pause Physics

	UpdateBallCount()
}

CycleCursorMode() {
	global CURSOR_MODE

	if (CURSOR_MODE = "Repel")
		CURSOR_MODE := "Attract"
	else if (CURSOR_MODE = "Attract")
		CURSOR_MODE := "Orbit"
	else if (CURSOR_MODE = "Orbit")
		CURSOR_MODE := "Tornado"
	else
		CURSOR_MODE := "Repel"

	SetCursorModeDropDown(CURSOR_MODE)
	GuiControl, MENU:, CursorModeText, Cursor mode: %CURSOR_MODE%
	UpdateBallCount()
}

SetCursorModeDropDown(mode) {
	if (mode = "Repel")
		GuiControl, MENU:Choose, CursorModeChoice, 1
	else if (mode = "Attract")
		GuiControl, MENU:Choose, CursorModeChoice, 2
	else if (mode = "Orbit")
		GuiControl, MENU:Choose, CursorModeChoice, 3
	else if (mode = "Tornado")
		GuiControl, MENU:Choose, CursorModeChoice, 4
}

ResetPhysicsDefaults() {
	global

	GRAVITY := 0.65
	AIR_FRICTION := 1.007
	FLOOR_FRICTION := 1.05
	BOUNCINESS := 0.7
	WALL_BOUNCINESS := 0.76
	COLLISION_STRENGTH := 0.82
	MAX_SPEED := 48
	BALL_SIZE := 34
	MAX_BALLS := 500
	CURSOR_FORCE_ON := true
	CURSOR_MODE := "Repel"
	CURSOR_RADIUS := 145
	CURSOR_FORCE := 2.35
	BALLS_ALWAYS_ON_TOP := true
	GRID_CELL_SIZE := BALL_SIZE * 2

	TopmostCheck := BALLS_ALWAYS_ON_TOP ? 1 : 0
	CursorForceCheck := CURSOR_FORCE_ON ? 1 : 0
	CursorRadiusSlider := CURSOR_RADIUS
	CursorForceSlider := Round(CURSOR_FORCE * 100)

	GravitySlider := Round(GRAVITY * 100)
	AirFrictionSlider := Round((AIR_FRICTION - 1) * 10000)
	FloorFrictionSlider := Round((FLOOR_FRICTION - 1) * 1000)
	BouncinessSlider := Round(BOUNCINESS * 100)
	WallBouncinessSlider := Round(WALL_BOUNCINESS * 100)
	CollisionSlider := Round(COLLISION_STRENGTH * 100)
	MaxSpeedSlider := MAX_SPEED
	BallSizeSlider := BALL_SIZE
	MaxBallsSlider := MAX_BALLS

	GuiControl, MENU:, TopmostCheck, %TopmostCheck%
	GuiControl, MENU:, CursorForceCheck, %CursorForceCheck%
	SetCursorModeDropDown(CURSOR_MODE)
	GuiControl, MENU:, CursorRadiusSlider, %CursorRadiusSlider%
	GuiControl, MENU:, CursorForceSlider, %CursorForceSlider%

	GuiControl, MENU:, GravitySlider, %GravitySlider%
	GuiControl, MENU:, AirFrictionSlider, %AirFrictionSlider%
	GuiControl, MENU:, FloorFrictionSlider, %FloorFrictionSlider%
	GuiControl, MENU:, BouncinessSlider, %BouncinessSlider%
	GuiControl, MENU:, WallBouncinessSlider, %WallBouncinessSlider%
	GuiControl, MENU:, CollisionSlider, %CollisionSlider%
	GuiControl, MENU:, MaxSpeedSlider, %MaxSpeedSlider%
	GuiControl, MENU:, BallSizeSlider, %BallSizeSlider%
	GuiControl, MENU:, MaxBallsSlider, %MaxBallsSlider%

	Gosub, UpdatePhysics
}

; ============================================================
; TOPMOST CONTROL
; ============================================================

EnforceTopmostTick:
	if (!BALLS_ALWAYS_ON_TOP)
		Return

	ApplyTopmostToAllBalls()
Return

ApplyTopmostToAllBalls() {
	global Balls
	global BALLS_ALWAYS_ON_TOP

	for i, b in Balls {
		if (BALLS_ALWAYS_ON_TOP) {
			WinSet, AlwaysOnTop, On, % "ahk_id " . b.hwnd
		} else {
			WinSet, AlwaysOnTop, Off, % "ahk_id " . b.hwnd
		}
	}
}

; ============================================================
; BALL MANAGEMENT
; ============================================================

SpawnBalls(count) {
	global Balls
	global NextBallId
	global BALL_SIZE
	global MAX_BALLS
	global BALLS_ALWAYS_ON_TOP

	canSpawn := MAX_BALLS - Balls.Length()

	if (canSpawn <= 0) {
		UpdateBallCount()
		return
	}

	if (count > canSpawn)
		count := canSpawn

	Loop, %count% {
		id := NextBallId
		NextBallId += 1

		size := BALL_SIZE
		guiName := "BALL_" . id
		color := RandomBallColor()

		maxX := A_ScreenWidth - size - 80

		if (maxX < 80)
			maxX := 80

		Random, x, 80, %maxX%
		Random, y, 60, 240
		Random, vx, -140, 140
		Random, vy, -100, 20

		vx := vx / 10
		vy := vy / 10

		Gui, %guiName%:New, -Caption +AlwaysOnTop +ToolWindow +E0x20 +HwndballHwnd
		Gui, %guiName%:Color, %color%
		Gui, %guiName%:Margin, 0, 0
		Gui, %guiName%:Show, % "x" . x . " y" . y . " w" . size . " h" . size . " NoActivate", Ball %id%

		regionOpts := "0-0 W" . size . " H" . size . " E"
		WinSet, Region, %regionOpts%, ahk_id %ballHwnd%

		if (BALLS_ALWAYS_ON_TOP) {
			WinSet, AlwaysOnTop, On, ahk_id %ballHwnd%
		} else {
			WinSet, AlwaysOnTop, Off, ahk_id %ballHwnd%
		}

		Balls.Push({id: id
			, gui: guiName
			, hwnd: ballHwnd
			, x: x
			, y: y
			, lastX: x
			, lastY: y
			, vx: vx
			, vy: vy
			, size: size
			, color: color})
	}

	UpdateBallCount()
}

DespawnBalls(count) {
	global Balls

	Loop, %count% {
		if (Balls.Length() <= 0)
			break

		b := Balls.Pop()
		Gui, % b.gui ":Destroy"
	}

	UpdateBallCount()
}

ClearBalls() {
	global Balls

	while (Balls.Length() > 0) {
		b := Balls.Pop()
		Gui, % b.gui ":Destroy"
	}

	UpdateBallCount()
}

ResizeAllBalls(newSize) {
	global Balls

	for i, b in Balls {
		oldSize := b.size
		centerX := b.x + oldSize / 2
		centerY := b.y + oldSize / 2

		b.size := newSize
		b.x := centerX - newSize / 2
		b.y := centerY - newSize / 2

		KeepBallOnScreen(b)

		regionOpts := "0-0 W" . newSize . " H" . newSize . " E"
		WinSet, Region, %regionOpts%, % "ahk_id " . b.hwnd
		WinMove, % "ahk_id " . b.hwnd,, % Round(b.x), % Round(b.y), % newSize, % newSize

		b.lastX := b.x
		b.lastY := b.y
	}

	ApplyTopmostToAllBalls()
	UpdateBallCount()
}

UpdateBallCount() {
	global Balls
	global MAX_BALLS
	global PhysicsPaused
	global CURSOR_FORCE_ON
	global CURSOR_MODE
	global BALLS_ALWAYS_ON_TOP

	count := Balls.Length()

	if (PhysicsPaused)
		state := "paused"
	else
		state := "running"

	if (CURSOR_FORCE_ON)
		hand := CURSOR_MODE
	else
		hand := "force off"

	if (BALLS_ALWAYS_ON_TOP)
		topState := "top on"
	else
		topState := "top off"

	GuiControl, MENU:, BallCountText, Balls: %count% / %MAX_BALLS%  -  %state%  -  %hand%  -  %topState%
}

ChaosToss() {
	global Balls

	for i, b in Balls {
		Random, vx, -600, 600
		Random, vy, -700, -120
		b.vx := vx / 10
		b.vy := vy / 10
	}
}

RandomBallColor() {
	Random, choice, 1, 16

	if (choice = 1)
		return "FF6B6B"
	else if (choice = 2)
		return "FFD93D"
	else if (choice = 3)
		return "6BCB77"
	else if (choice = 4)
		return "4D96FF"
	else if (choice = 5)
		return "B983FF"
	else if (choice = 6)
		return "FF9F1C"
	else if (choice = 7)
		return "FF85A1"
	else if (choice = 8)
		return "7BDFF2"
	else if (choice = 9)
		return "C3F584"
	else if (choice = 10)
		return "F7A8B8"
	else if (choice = 11)
		return "A0C4FF"
	else if (choice = 12)
		return "CAFFBF"
	else if (choice = 13)
		return "FDFFB6"
	else if (choice = 14)
		return "FFC6FF"
	else if (choice = 15)
		return "9BF6FF"
	else
		return "BDB2FF"
}

; ============================================================
; PHYSICS
; ============================================================

PhysicsTick:
	if (PhysicsPaused) {
		UpdateBallCount()
		Return
	}

	if (Balls.Length() <= 0)
		Return

	ApplyBallPhysics()
	ApplyCursorForce()
	ApplyBallCollisionsGrid()
	DrawBalls()
Return

ApplyBallPhysics() {
	global Balls
	global GRAVITY
	global AIR_FRICTION
	global FLOOR_FRICTION
	global BOUNCINESS
	global WALL_BOUNCINESS
	global REST_X_SPEED
	global REST_Y_SPEED

	screenW := A_ScreenWidth
	screenH := A_ScreenHeight

	for i, b in Balls {
		b.vy += GRAVITY

		b.vx /= AIR_FRICTION
		b.vy /= AIR_FRICTION

		CapBallSpeed(b)

		b.x += b.vx
		b.y += b.vy

		if (b.x < 0) {
			b.x := 0
			b.vx := Abs(b.vx) * WALL_BOUNCINESS
		}

		if (b.x + b.size > screenW) {
			b.x := screenW - b.size
			b.vx := -Abs(b.vx) * WALL_BOUNCINESS
		}

		if (b.y < 0) {
			b.y := 0
			b.vy := Abs(b.vy) * WALL_BOUNCINESS
		}

		if (b.y + b.size > screenH) {
			b.y := screenH - b.size

			if (Abs(b.vy) < REST_Y_SPEED) {
				b.vy := 0
			} else {
				b.vy := -Abs(b.vy) * BOUNCINESS
			}

			b.vx /= FLOOR_FRICTION

			if (Abs(b.vx) < REST_X_SPEED)
				b.vx := 0
		}

		if (b.y + b.size >= screenH - 1) {
			if (Abs(b.vy) < REST_Y_SPEED)
				b.vy := 0

			if (Abs(b.vx) < REST_X_SPEED)
				b.vx := 0
		}
	}
}

ApplyCursorForce() {
	global Balls
	global CURSOR_FORCE_ON
	global CURSOR_MODE
	global CURSOR_RADIUS
	global CURSOR_FORCE

	if (!CURSOR_FORCE_ON)
		return

	MouseGetPos, mx, my

	radiusSq := CURSOR_RADIUS * CURSOR_RADIUS

	for i, b in Balls {
		cx := b.x + b.size / 2
		cy := b.y + b.size / 2

		dx := cx - mx
		dy := cy - my

		distSq := dx * dx + dy * dy

		if (distSq <= 0.001) {
			Random, tinyX, -10, 10
			Random, tinyY, -10, 10

			if (tinyX = 0 && tinyY = 0)
				tinyX := 1

			dx := tinyX
			dy := tinyY
			distSq := dx * dx + dy * dy
		}

		if (distSq < radiusSq) {
			dist := Sqrt(distSq)
			nx := dx / dist
			ny := dy / dist

			tx := -ny
			ty := nx

			falloff := 1 - (dist / CURSOR_RADIUS)
			push := CURSOR_FORCE * falloff * falloff

			if (CURSOR_MODE = "Repel") {
				b.vx += nx * push
				b.vy += ny * push
				b.x += nx * push * 0.8
				b.y += ny * push * 0.8
			} else if (CURSOR_MODE = "Attract") {
				b.vx -= nx * push
				b.vy -= ny * push
			} else if (CURSOR_MODE = "Orbit") {
				b.vx += tx * push * 1.15
				b.vy += ty * push * 1.15

				; Very small inward pull keeps orbit from flying apart instantly.
				b.vx -= nx * push * 0.18
				b.vy -= ny * push * 0.18
			} else if (CURSOR_MODE = "Tornado") {
				b.vx += tx * push * 1.35
				b.vy += ty * push * 0.95

				; Pull inward and lift upward for the tornado feel.
				b.vx -= nx * push * 0.45
				b.vy -= ny * push * 0.45
				b.vy -= push * 0.85
			}

			CapBallSpeed(b)
			KeepBallOnScreen(b)
		}
	}
}

ApplyBallCollisionsGrid() {
	global Balls
	global GRID_CELL_SIZE

	count := Balls.Length()

	if (count < 2)
		return

	grid := {}

	for i, b in Balls {
		cx := Floor((b.x + b.size / 2) / GRID_CELL_SIZE)
		cy := Floor((b.y + b.size / 2) / GRID_CELL_SIZE)
		key := cx . "," . cy

		if (!grid.HasKey(key))
			grid[key] := []

		grid[key].Push(i)
	}

	checked := {}

	for key, list in grid {
		StringSplit, parts, key, `,
		baseCx := parts1
		baseCy := parts2

		for a, i in list {
			Loop, 3 {
				ox := A_Index - 2

				Loop, 3 {
					oy := A_Index - 2
					neighborKey := (baseCx + ox) . "," . (baseCy + oy)

					if (!grid.HasKey(neighborKey))
						continue

					neighborList := grid[neighborKey]

					for bIndex, j in neighborList {
						if (j <= i)
							continue

						pairKey := i . ":" . j

						if (checked.HasKey(pairKey))
							continue

						checked[pairKey] := true
						ResolveBallCollision(Balls[i], Balls[j])
					}
				}
			}
		}
	}
}

ResolveBallCollision(ByRef b1, ByRef b2) {
	global COLLISION_STRENGTH

	r1 := b1.size / 2
	r2 := b2.size / 2

	x1 := b1.x + r1
	y1 := b1.y + r1
	x2 := b2.x + r2
	y2 := b2.y + r2

	dx := x2 - x1
	dy := y2 - y1

	distSq := dx * dx + dy * dy
	minDist := r1 + r2

	if (distSq <= 0.001) {
		Random, tinyDx, -10, 10
		Random, tinyDy, -10, 10

		if (tinyDx = 0 && tinyDy = 0)
			tinyDx := 1

		dx := tinyDx / 10
		dy := tinyDy / 10
		distSq := dx * dx + dy * dy
	}

	if (distSq >= minDist * minDist)
		return

	dist := Sqrt(distSq)
	nx := dx / dist
	ny := dy / dist

	overlap := minDist - dist

	push := overlap / 2
	b1.x -= nx * push
	b1.y -= ny * push
	b2.x += nx * push
	b2.y += ny * push

	rvx := b2.vx - b1.vx
	rvy := b2.vy - b1.vy
	velAlongNormal := rvx * nx + rvy * ny

	if (velAlongNormal < 0) {
		impulse := -(1 + COLLISION_STRENGTH) * velAlongNormal / 2

		ix := impulse * nx
		iy := impulse * ny

		b1.vx -= ix
		b1.vy -= iy
		b2.vx += ix
		b2.vy += iy
	}

	KeepBallOnScreen(b1)
	KeepBallOnScreen(b2)
	CapBallSpeed(b1)
	CapBallSpeed(b2)
}

DrawBalls() {
	global Balls
	global DRAW_EPSILON

	for i, b in Balls {
		if (Abs(b.x - b.lastX) < DRAW_EPSILON && Abs(b.y - b.lastY) < DRAW_EPSILON)
			continue

		x := Round(b.x)
		y := Round(b.y)
		s := Round(b.size)

		WinMove, % "ahk_id " . b.hwnd,, %x%, %y%, %s%, %s%

		b.lastX := b.x
		b.lastY := b.y
	}
}

KeepBallOnScreen(ByRef b) {
	screenW := A_ScreenWidth
	screenH := A_ScreenHeight

	if (b.x < 0) {
		b.x := 0
		if (b.vx < 0)
			b.vx *= -0.5
	}

	if (b.x + b.size > screenW) {
		b.x := screenW - b.size
		if (b.vx > 0)
			b.vx *= -0.5
	}

	if (b.y < 0) {
		b.y := 0
		if (b.vy < 0)
			b.vy *= -0.5
	}

	if (b.y + b.size > screenH) {
		b.y := screenH - b.size
		if (b.vy > 0)
			b.vy *= -0.5
	}
}

CapBallSpeed(ByRef b) {
	global MAX_SPEED

	if (b.vx > MAX_SPEED)
		b.vx := MAX_SPEED

	if (b.vx < -MAX_SPEED)
		b.vx := -MAX_SPEED

	if (b.vy > MAX_SPEED)
		b.vy := MAX_SPEED

	if (b.vy < -MAX_SPEED)
		b.vy := -MAX_SPEED
}