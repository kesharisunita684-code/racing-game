# Racing Game - Milestone 1 (Godot 4.3, GDScript only)

Playable car + closed test track + chase camera + HUD + 3-lap race logic.
**All art is placeholder** (boxes, cylinders, flat colors). No external assets, no plugins.

## Run on PC
1. Godot 4.3 -> Project Manager -> Import -> select `project.godot`.
2. Wait for the first import to finish, then press **F5**.
3. Controls: W/Up gas, S/Down brake + reverse, A/D or Left/Right steer, Space handbrake, R reset, Esc pause.

## Export for Android
1. Install JDK 17 and the Android SDK (cmdline-tools, platform-tools, build-tools 34, platform 34).
2. Godot: Editor > Editor Settings > Export > Android -> set Java SDK path, Android SDK path, debug keystore.
3. Editor > Manage Export Templates -> Download and Install (must match 4.3).
4. Project > Install Android Build Template (needed so Min SDK can be changed).
5. Project > Export > Add... > Android:
   - Gradle Build: **On**, Min SDK: **23**, Target SDK: 34
   - Package > Unique Name: **com.racing.game**
   - Architectures: arm64-v8a
6. Plug in a phone (USB debugging on) and use the one-click Android icon, or Export Project to make an .apk.
Menu names can differ a little between 4.3.x versions.

## Scene hierarchies (to reproduce by hand)

### sports_car.tscn  (origin is 1.35 m above the road)
```
SportsCar  VehicleBody3D   script car_controller.gd
  Mass 1500 | Center Of Mass Mode = Custom | Center Of Mass (0,-0.9,0)
  Collision Layer = 2 (Car) | Collision Mask = 1 + 3 (Track, Barriers)
  Can Sleep off | Continuous CD on | Linear Damp 0.05 | Angular Damp 0.3
  BodyCollision  CollisionShape3D  Box 1.7 x 0.6 x 4.2   at (0,-0.75,0)
  CabinCollision CollisionShape3D  Box 1.4 x 0.5 x 1.8   at (0,-0.2,0.3)
  BodyMesh       MeshInstance3D    BoxMesh 1.7 x 0.6 x 4.2  at (0,-0.75,0)  red, roughness 0.2
  CabinMesh      MeshInstance3D    BoxMesh 1.4 x 0.5 x 1.8  at (0,-0.2,0.3) dark
  HeadlightL/R   MeshInstance3D    BoxMesh 0.35 x 0.15 x 0.06 at (+-0.55,-0.6,-2.11)
  WheelFL  VehicleWheel3D at (-1,-0.8,-1.3)  Use As Steering ON
  WheelFR  VehicleWheel3D at ( 1,-0.8,-1.3)  Use As Steering ON
  WheelRL  VehicleWheel3D at (-1,-0.8, 1.3)  Use As Traction ON
  WheelRR  VehicleWheel3D at ( 1,-0.8, 1.3)  Use As Traction ON
    all wheels: Radius 0.4 | Rest Length 0.15 | Friction Slip 1.2 | Roll Influence 0.1
                Suspension Travel 0.25 | Stiffness 60 | Max Force 30000
                Damping Compression 3.5 | Damping Relaxation 3.5
    each wheel has: Tire MeshInstance3D (CylinderMesh r 0.4, h 0.3, rotated 90 deg on Z)
                    Hub  MeshInstance3D (BoxMesh 0.34 x 0.12 x 0.7, light grey - makes spin visible)
```
The car drives toward its **-Z** (front = headlights side). Left wheels are at -X.
Why the origin is high: the car's centre of mass is (0,-0.9,0) as requested, so the body is built
around an origin 1.35 m above the road. That puts the centre of mass about 0.45 m above the road,
which is realistic. (If the origin were at road level, -0.9 would be under the ground.)

### test_track.tscn
```
TestTrack Node3D
  Road        StaticBody3D  Layer 1 (Track), Mask 0
    CollisionShape3D  Box 200 x 2 x 200 at (0,-1,0)
    RoadMesh          PlaneMesh 200 x 200, dark grey, roughness 0.3
  Grass       MeshInstance3D PlaneMesh 1000 x 1000 at (0,-0.1,0)  (visual only)
  Infield     StaticBody3D  at (0,1,0)  Layer 3 (Barriers)
    CollisionShape3D Box 140 x 2 x 140 ; MeshInstance3D BoxMesh 140 x 2 x 140, green
  Barriers    Node3D   (4x StaticBody3D, Layer 3, height 2 m, 2 m thick)
    WallNorth (0,1,-101) Box 204x2x2   WallSouth (0,1,101) Box 204x2x2
    WallEast  (101,1,0)  Box 2x2x204   WallWest  (-101,1,0) Box 2x2x204
  Checkpoints Node3D   (Area3D + script checkpoint.gd, Layer 0, Mask 2, Monitorable off)
    each has CollisionShape3D Box 30 x 6 x 2
    FinishLine  (85,3,20)   yaw 0     index 0, is_finish_line ON  + LineMesh BoxMesh 10 x 0.2 x 1 white at (0,-2.9,0)
    Checkpoint1 (85,3,-45)  yaw 0     index 1   + yellow Marker strip
    Checkpoint2 (0,3,-85)   yaw 90    index 2
    Checkpoint3 (-85,3,0)   yaw 180   index 3
    Checkpoint4 (0,3,85)    yaw -90   index 4
```
Lap direction is counter-clockwise seen from above (up the right side first). Each gate's
front (-Z) must point the way the car drives. The finish *trigger* is 30 m wide so it covers
the whole road; the white line is the 10 m placeholder you asked for (scale its X to 3 to span the road).

### hud.tscn
```
HUD CanvasLayer  (Process Mode = Always)  script race_hud.gd
  LapLabel, PositionLabel (top-left) | TimerLabel (top-center)
  SpeedLabel (bottom-center) | CountdownLabel (center, size 150)
  PauseMenu   Control (hidden) > Dim ColorRect, Center > Panel > Margin > VBox (Title, ResumeButton, RestartButton)
  ResultsMenu Control (hidden) > same layout (Title, ResultTimeLabel, LapTimesLabel, ResultsRestartButton)
  MobileControls CanvasLayer  script mobile_controls.gd   (buttons are built by the script)
```
The scripts find these nodes with "Access as Unique Name" (`%Name`), so every node above
that a script uses must have **Access as Unique Name** turned on (right-click > Access as Unique Name).

### main.tscn
```
Main Node3D
  WorldEnvironment  (Sky background, ProceduralSkyMaterial)
  Sun               DirectionalLight3D, rotation (-50,-30,0), shadows on
  TestTrack         (instance of test_track.tscn)
  SportsCar         (instance of sports_car.tscn) at (85,1.5,32)
  ChaseCamera       Node3D  script chase_camera.gd  target = SportsCar, follow_speed 5
    SpringArm3D     rotation X -20, Spring Length 6, Margin 0.1, Collision Mask = 3 (Barriers only)
      Camera3D      FOV 70, Current on
  HUD               (instance of hud.tscn)
  RaceManager       Node  script race_manager.gd  car = SportsCar, hud = HUD, total_laps 3
```
Keep **RaceManager last** in the list.

## Tuning notes
- With 1500 kg, 1200 engine force per rear wheel gives gentle acceleration (roughly 0-100 km/h in 15+ s). For a punchy
  feel set `Max Engine Force` on the car to about 4000-6000 in the Inspector.
- Camera lag at speed comes from `follow_speed = 5`. Raise it to 8-10 for a tighter camera.
- Shadows: turn off on Sun for weak phones.

## Troubleshooting
- Car drives backwards when you press W: tell me and I will flip the drive direction (one-line change).
- Buttons for phone on PC: tick "Show On Desktop" on MobileControls and enable
  Project Settings > Input Devices > Pointing > Emulate Touch From Mouse.
- Errors about `CarController`/`Checkpoint` not found on first open: close and reopen the project once so Godot builds its class list.

Not tested in the editor on my side: I had no Godot available to run it, so please send me any red error text.
