# Quieto Native design kit

## Direction

Quieto is calm, editorial and native to iOS: one dark navy canvas, raised
surfaces with restrained borders, mint only for the primary action, and no
permanent glow or decorative glass effect. System materials are reserved for
transient sheets and menus.

## Type

- Display and section titles: **Cormorant Garamond**, bundled in the target.
- Body, controls, metadata and accessibility labels: **Hanken Grotesk**, bundled
  in the target.
- Token sizes are exposed through `QuietoFont.display`, `.title`, `.section`,
  `.body` and `.caption`; controls should not introduce arbitrary sizes.

## Layout

- Content horizontal inset: `QuietoSpacing.md`.
- Maximum readable content width: `QuietoMetrics.contentMaxWidth`.
- Minimum interactive target: `QuietoMetrics.minimumTapTarget`.
- Standard control height: `QuietoMetrics.controlHeight`.
- Cards use one shared continuous radius and one-pixel quiet borders.
- Every root screen fills the window and respects the system safe area through
  the shared `RootView` shell.

## Interaction

Use a single primary action per card. Secondary actions are outline buttons or
SF Symbols. Sheets, alerts, error states and loading states must use native
SwiftUI behavior and remain accessible to VoiceOver and Dynamic Type.
