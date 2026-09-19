---
name: Serene Clinical
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#3d4947'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#6d7a77'
  outline-variant: '#bcc9c6'
  surface-tint: '#006a61'
  primary: '#00685f'
  on-primary: '#ffffff'
  primary-container: '#008378'
  on-primary-container: '#f4fffc'
  inverse-primary: '#6bd8cb'
  secondary: '#006b5f'
  on-secondary: '#ffffff'
  secondary-container: '#6df5e1'
  on-secondary-container: '#006f64'
  tertiary: '#006947'
  on-tertiary: '#ffffff'
  tertiary-container: '#00855b'
  on-tertiary-container: '#f5fff6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#89f5e7'
  primary-fixed-dim: '#6bd8cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#005049'
  secondary-fixed: '#71f8e4'
  secondary-fixed-dim: '#4fdbc8'
  on-secondary-fixed: '#00201c'
  on-secondary-fixed-variant: '#005048'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  margin-tablet: 2rem
  margin-desktop: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system delivers a calm, authoritative, and anxiety-reducing digital healthcare experience. Designed primarily for patients managing routine to complex medication schedules, caregivers, and clinicians, the interface balances medical-grade clarity with approachable warmth. 

The aesthetic blends **Modern Clinical Minimalism** with soft tactile elements. Interfaces must remain visually uncluttered, eliminating cognitive friction for users who may be fatigued, visually impaired, or experiencing high stress. Reassurance, precision, and frictionless confirmation underpin every interaction. The emotional goal is quiet competence: reducing panic, preventing missed doses, and instilling absolute confidence in regimen adherence.

## Colors

The palette establishes clinical trust while maintaining softness:

- **Primary Clinical Teal (`#0D9488`)**: Anchor color for key navigation, brand signifiers, and high-priority primary actions.
- **Secondary Vivid Teal (`#14B8A6`)**: Used for active states, interactive progress meters, and secondary accents.
- **Tertiary & Adherence Emerald (`#10B981`)**: Dedicated to confirmed actions, positive tracking loops, and "Taken" dose states.
- **Neutral Deep Slate (`#0F172A`)**: Primary typography baseline, providing AAA contrast on white and muted backgrounds.
- **Subdued Slate (`#334155`, `#64748B`)**: Secondary instructional text, dosage metadata, and subtle border dividers (`#E2E8F0`).
- **Canvas Base (`#F8FAFC`)**: Soft, anti-glare tinted background reducing eye strain during early morning or night logging.
- **Surface Elevation (`#FFFFFF`)**: Pure white reserved for cards, sheets, and interactable modals.
- **Functional Warning Amber (`#F59E0B`)**: Low refill levels, schedule conflicts, and food-intake advisories.
- **Functional Alert Coral (`#F43F5E`)**: Missed doses, drug interaction alerts, and critical contraindications.

## Typography

Typographic scale is structured around extreme clarity, numerical distinction, and rapid scannability:

- **Plus Jakarta Sans** provides open counters and geometric balance for headings, dosage times, and day selectors.
- **Inter** ensures medical names, instructions (e.g., "Take with food"), and metrics retain maximum legibility at smaller scales.
- Numeric weights for medication schedules and milligram indications should consistently use medium or semi-bold weights with tabular figures (`tnum`) enabled to prevent layout jitter during dynamic time updates.

## Layout & Spacing

The layout is built on an adaptive mobile-first fluid grid optimized for rapid one-handed interactions:

- **Touch Safety & Margins**: Base margin of `1.25rem` (20px) on mobile viewports ensures touch targets sit safely inside device bezels. Transitions to `2rem` on tablets and `3rem` on larger screen sizes with max-width content constraining at `640px` for mobile app shells.
- **Vertical Spacing Cadence**: Follows an 8pt baseline rhythm (`0.5rem`, `1rem`, `1.5rem`, `2rem`). Micro-spacings (`space-xs` = 4px) are reserved strictly for connecting pill metadata to primary drug labels.
- **Accessibility Enclosures**: Touch targets strictly observe an absolute minimum interactive area of `44x44px`, regardless of the visual boundary of the trigger.

## Elevation & Depth

Visual hierarchy uses ambient diffusion rather than harsh shadows to maintain a clean, clinical feel:

- **Level 0 (Flat Canvas)**: `#F8FAFC` base layer. No shadow.
- **Level 1 (Dose Cards & Containers)**: `#FFFFFF` resting on `#F8FAFC`, framed by a soft border (`1px solid #E2E8F0`) and an ambient tinted blur: `0px 2px 8px -2px rgba(15, 23, 42, 0.04), 0px 4px 16px -4px rgba(15, 23, 42, 0.06)`.
- **Level 2 (Active/Selected Card & Floating Controls)**: Elevated during drag, scroll, or focus. Casts `0px 8px 24px -4px rgba(13, 148, 136, 0.12)`.
- **Level 3 (Modal Sheets & Confirmation Dialogs)**: Deep protective elevation with a clinical back-scrim (`rgba(15, 23, 42, 0.4)`): `0px 20px 32px -8px rgba(15, 23, 42, 0.16)`.

## Shapes

The design uses a rounded aesthetic (`roundedness: 2`, base 8px, cards 16px, large surfaces 24px) to soften clinical delivery:

- **Cards & Surfaces**: Use `rounded-lg` (16px) for scheduled medication cards, adherence summaries, and notification alerts.
- **Action Sheets & Bottom Sheets**: Use `rounded-xl` (24px) top corners for medication intake confirmation sheets.
- **Badges, Pills & Loggers**: Use fully rounded pill geometries (`rounded-full` / 9999px) for dose status tags, day pickers, and primary confirmation buttons to visually mirror tangible pills.

## Components

### Buttons
- **Primary ("Take Dose")**: Height 52px (min 44px), background `#0D9488`, label `#FFFFFF` in `label-lg`. Roundedness 16px or full pill. Active feedback: scales to 0.98 with subtle depth press.
- **Secondary ("Snooze / Skip")**: Outlined `1.5px solid #E2E8F0`, background `#FFFFFF`, label `#334155`. 
- **Destructive ("Missed Dose")**: Soft background `rgba(244, 63, 94, 0.08)`, text `#F43F5E`, border `1px solid rgba(244, 63, 94, 0.2)`.

### Dose Cards
- Elevated Level 1 surface, `#FFFFFF` background, 16px padding.
- Left edge or leading visual: Time indicator in `headline-md` paired with a colored pill icon or medication shape indicator.
- Core content: Drug name (`headline-sm`), strength and dosage form (`body-md`), instruction pill tag (`body-sm`).
- Trailing control: Fast-action checkmark or adherence state button (minimum target 48x48px).

### Status Badges & Chips
- **Taken**: Background `#ECFDF5`, text `#065F46`, leading checkmark in `#10B981`.
- **Due**: Background `#F0FDFA`, text `#0F766E`, subtle pulse indicator in `#0D9488`.
- **Missed**: Background `#FFF1F2`, text `#9F1239`, border `1px solid #FECDD3`.
- **Low Refill**: Background `#FFFBEB`, text `#92400E`, leading alert in `#F59E0B`.

### Checkboxes & Radio Selectors
- Custom 24x24px rounded targets (6px radius for check, circular for radio) centered within a minimum 44x44px touch container.
- Selected state fills `#0D9488` with a clean white vector glyph. Unselected border uses `#CBD5E1`.

### Input Fields (Medication & Rx Entry)
- Height 48px, background `#FFFFFF`, border `1px solid #CBD5E1`, text `#0F172A`, placeholder `#94A3B8`.
- Focus state transition: border `#0D9488`, subtle teal glow `0 0 0 3px rgba(20, 184, 166, 0.15)`.

### Additional Domain Components
- **Weekly Adherence Strip**: Horizontal day-selector showing calendar days with completion rings (`#10B981`), skipped rings (`#F43F5E`), or pending empty slots.
- **Pill Visualizer**: Physical medication form shapes (capsule, round tablet, oval, liquid) rendered with distinct identifying colors to help patients confirm physical pills match screen directives.