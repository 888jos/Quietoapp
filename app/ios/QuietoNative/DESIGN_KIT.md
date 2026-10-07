# Quieto Native design kit

## Direction

Quieto is calm, editorial and native to iOS, set under a night sky. Every
screen sits on `QuietoBackground`: dusk indigo at the top fading into deep
navy, a faint violet and mint glow, and a sparse star field in the upper half
(a few stars breathe slowly; static when Reduce Motion is on). Mint is reserved
for the primary action, filled with the `QuietoColor.mintFill` sheen and lifted
by a soft `quietoGlow()` halo on the main play and purchase buttons only.

## Surfaces

- Cards use `.quietoSurface(cornerRadius:)`: a translucent, top-lit fill that
  lets the sky through and a hairline border catching the light on its upper
  edge. Do not stack an extra stroke on top.
- `QuietoColor.surface` and `.surfaceRaised` are translucent; floating elements
  over scrolling content (mini players) use the opaque `surfaceSolid`.
- The full player tints the sky with a blurred copy of the session artwork.
- Custom buttons use `QuietoPressStyle` for a slight sink on press.

## Type

Two typefaces only: **Faro** for titles, **Hanken Grotesk** for everything
else. Screens pick a step of the scale, never a raw size.

| Step | Font | Use |
|---|---|---|
| `heading(.display)` / `QuietoFont.display` | Faro 34 | Tab titles (Bonsoir, Programme, Séances, Louane, Ton espace) |
| `heading(.title)` | Faro 28 | Sheet, player and paywall titles |
| `heading(.section)` / `quietoSectionTitle()` | Faro 21 | Section titles |
| `heading(.card)` | Faro 18 | Card and row titles |
| `heading(.hero)` / `heading(.numeral)` | Faro 44 / 72 | One word or one number shown alone |
| `sans(.body)` | Hanken 16 | Running text, primary buttons |
| `sans(.callout)` | Hanken 15 | Rows, secondary buttons, descriptions |
| `sans(.subhead)` | Hanken 13 | Metadata |
| `sans(.caption)` | Hanken 12 | Small print |
| `quietoOverline()` | Hanken 11, spaced caps | Labels above a block |
| `sans(.figure)` | Hanken 28 | Timers and counts |

Hanken is a variable font: `sans(_, weight:)` applies the weight on its axis.
UIKit chrome (tab bar, navigation bars) uses the same faces through
`QuietoAppearance`. No `.font(.headline)`-style system text styles.

## Shapes and controls

- Radii: `QuietoRadius.small` (12), `.card` (18), `.hero` (26), or `Capsule()`.
- Round mint play buttons: `QuietoMetrics.playSmall` (40, rows),
  `.playMedium` (56, cards), `.playLarge` (72, players).
- Buttons: `QuietoPrimaryButton` and `QuietoOutlineButton`, both
  `QuietoMetrics.controlHeight` (54) high. Square header icons: `LibraryButton`.
- Colours: the `QuietoColor` palette only. `danger` for destructive actions
  and errors, `coral` for favourites and health.

## Layout

- Content horizontal inset: `QuietoSpacing.md`.
- Maximum readable content width: `QuietoMetrics.contentMaxWidth`.
- Minimum interactive target: `QuietoMetrics.minimumTapTarget`.
- Standard control height: `QuietoMetrics.controlHeight`.
- Every root screen fills the window and respects the system safe area through
  the shared `RootView` shell.

## Interaction

Use a single primary action per card. Secondary actions are outline buttons or
SF Symbols. Sheets, alerts, error states and loading states must use native
SwiftUI behavior and remain accessible to VoiceOver and Dynamic Type.
