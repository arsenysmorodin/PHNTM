# Gesture recognition

PHNTM recognizes deliberate static poses. Directional Safari commands do not depend on hand movement or swipe distance. The brightness command is the only multi-phase gesture: two open palms must transition into two fists.

## Camera framing

For reliable recognition:

- keep both hands fully inside the camera frame;
- face the palms generally toward the camera;
- leave visible separation between fingers for open-palm detection;
- avoid covering one hand with the other;
- use even front lighting and avoid strong backlight;
- keep the hands far enough from the camera for the wrist and fingertips to remain visible;
- watch the main window for `TWO HANDS DETECTED` and up to `42 / 42 POINTS`.

Vision can return fewer than 21 reliable points per hand. PHNTM represents those points as missing landmarks and waits rather than guessing.

## Directional Safari gestures

Directional commands require two different hands:

1. **Safety hand:** hold an open palm.
2. **Command hand:** extend the index finger and point left, right, up, or down.
3. Hold the pose briefly until the command appears.
4. Release the pointing pose before issuing another command.

The same physical hand can serve either role. PHNTM identifies roles from the current pose, not handedness.

| Direction | Safari action | macOS event |
| --- | --- | --- |
| Left | Previous tab | Control-Shift-Tab |
| Right | Next tab | Control-Tab |
| Up | Scroll page down | Page Down |
| Down | Scroll page up | Page Up |

Safari commands are sent only when:

- **Control Safari** is enabled;
- Accessibility permission is available;
- Safari is the active frontmost application.

Recognition still reports a gesture when Safari control is disabled, but no browser event is posted.

### Directional stabilization

`DirectionGestureEngine` uses the following safeguards:

| Rule | Value |
| --- | --- |
| Stable pose before firing | `0.18 s` |
| Clear release before rearming | `0.18 s` |
| Dominant-axis ratio | `1.35` |
| Absolute minimum finger vector | `0.08` normalized units |
| Palm-relative minimum | `1.05 ×` palm width |

A diagonal pose that does not meet the axis ratio produces no command. Holding a valid pose produces exactly one event; keeping the safety palm visible does not cause repetition.

## Display dimming gesture

The display gesture is designed to be difficult to trigger accidentally.

1. Show **two open palms**.
2. Hold them until the interface says **CLOSE BOTH HANDS** or the menu bar reports **Two palms detected**.
3. Close both hands into fists within the transition window.
4. Hold both fists until the interface reports **DISPLAY DIMMED**.
5. Release the fists before starting again.

No inward hand motion is required. The required change is the pose transition from two open palms to two fists.

### Brightness state machine

| Phase | Requirement | Transition |
| --- | --- | --- |
| `idle` | Wait for two open palms | Start arming |
| `arming` | Keep two palms open for `0.24 s` | Ready to close |
| `readyToClose` | Begin closing both hands | Start fist stabilization |
| `closing` | Keep two fists for `0.18 s` | Emit one `dimDisplay` event |
| `waitingForRelease` | Stop seeing two fists for `0.25 s` | Return to idle |

The closing transition must complete within `1.6 s`. If confidence is lost for too long, the sequence resets without changing brightness.

When the sequence fires, PHNTM sends brightness-down events until macOS reaches its lower bound, then sends one brightness-up event. The result is approximately one standard macOS brightness step above minimum.

## Pose classifiers

### Open palm

All four non-thumb fingers must appear extended. Extension is measured from the PIP joint angle and segment length, making the check less dependent on hand size in the camera image.

### Pointing hand

The index finger must be extended. At most one of the middle, ring, or little fingers may be ambiguously extended. A fully open palm is therefore not accepted as a pointing hand.

### Fist

At least three non-thumb fingers must be confidently curled toward the palm, and no non-thumb finger may appear extended. The three-of-four rule tolerates one fingertip temporarily disappearing while the hand closes.

The thumb is not required because thumb landmark visibility varies significantly across fist orientations.

## Gesture priority

Brightness recognition runs before directional recognition on every analyzed frame.

Once two open palms begin the brightness sequence, `BrightnessGestureEngine` owns both hands until the sequence completes, resets, or is released. During that time the directional engine is reset. This prevents a partially closing hand from producing a Safari command.

## Visible feedback

The main window shows:

- detected hand count;
- recognized landmark count;
- whether any open palm is present;
- whether a pointing hand is present;
- the last directional event;
- current brightness-sequence instruction;
- open-palm and fist counts.

The menu bar mirrors higher-level permission, ready, armed, detected, and error states. Use these indicators to distinguish recognition problems from Safari focus or Accessibility problems.

## Manual verification matrix

After changing recognition code, verify at least these cases:

| Scenario | Expected result |
| --- | --- |
| Pointing hand without open palm | No Safari event |
| Open palm without pointing hand | Guard-ready status only |
| Valid direction held continuously | One event only |
| Direction released and shown again | A second event after release |
| Safari not frontmost | Gesture shown; no shortcut sent |
| Safari control disabled | Gesture shown; no shortcut sent |
| Two fists without two open palms first | No brightness event |
| Two open palms kept open | Armed status; no brightness event |
| Two palms followed by stable fists | One brightness event |
| Fists kept closed | No repeated brightness event |
| Fists released, sequence repeated | One new brightness event |
