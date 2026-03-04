# Chen-Leveling UI Handoff (Auth + Cozy Guild Board)

This document is the design/development handoff for the current Flutter implementation.
Use this as the source of truth for:
- design tokens (color, typography, spacing, radius, border, motion),
- auth flow pages (Landing / Master / Hunter),
- Cozy Guild Board polish states.

## 1. Visual Direction
- Theme: `Cozy Guild`
- Feel: warm, tactile, physical cards, wood frame, parchment, gemstones
- Avoid: neon glow, thin flat web dashboard look, pure black text

## 2. Global Design Tokens

### 2.1 Color Tokens
Source: `lib/core/theme/app_colors.dart`

- `parchment`: `#F4ECE1`
- `grassBase`: `#7CB342`
- `inkBrown`: `#3E2723`
- `navyBlue`: `#1A237E`
- `hpRuby`: `#D32F2F`
- `apSapphire`: `#1976D2`
- `stampGreen`: `#388E3C`
- `woodFrame`: `#5D4037`
- `woodButton`: `#8D6E63`
- `woodButtonEdge`: `#5D4037`
- `submitGreen`: `#43A047`
- `submitGreenEdge`: `#1B5E20`
- `joystickBase`: `#3E2723`
- `joystickGemLight`: `#64B5F6`
- `joystickGem`: `#1976D2`
- `hpTrack`: `#3E2723`
- `softWood`: `#D7CCC8`
- `shadowHard`: `#403E2723`

### 2.2 Typography Tokens
Source: `lib/core/theme/app_theme.dart`

- Font family: `Nunito`
- Headline large: `34 / w900 / inkBrown`
- Headline medium: `28 / w900 / inkBrown`
- Display large: `32 / w900 / inkBrown`
- Title large: `24 / w900 / inkBrown`
- Title medium: `18 / w800 / inkBrown`
- Body large: `16 / w600 / inkBrown`
- Body medium: `14 / w500 / inkBrown`

### 2.3 Spacing and Shape Tokens
- Major panel padding: `16 - 20`
- Card padding: `12 - 14`
- Button vertical padding: `10 - 12`
- Radius:
  - Large panel: `16`
  - Card/paper section: `12`
  - Button/input: `10`
  - Capsule/chip: `999`
- Border width:
  - Main wood frame: `3`
  - Input/button edge: `2 - 2.6`
  - Pressed depth bottom border: `1.4 - 5`

### 2.4 Shadow Tokens
- Hard paper lift:
  - `color: #403E2723`
  - `offset: (0, 4)`
  - `blurRadius: 0`
- Hover highlight (quest card):
  - `color: stampGreen @ 0.28`
  - `blurRadius: 10`

### 2.5 Motion Tokens
- Button press animation: `70ms - 90ms`
- Card hover lift: `110ms`
- Torch flicker loop: `900ms`, reverse repeat
- Snackbar action feedback: `1200ms`

## 3. Auth Flow UI Spec

### 3.1 Auth Landing (Identity Selection)
Source: `lib/features/auth/auth_landing_page.dart`

- Full-screen grassy background with subtle grid/noise.
- Center layout: two wood signboards in `Wrap`.
- Left sign:
  - Title: `我是公會長 / Master`
  - Icon: crown-like badge (`workspace_premium`)
- Right sign:
  - Title: `我是獵人 / Hunter`
  - Icon: shield
- Interaction:
  - Press animation via `Transform.translate` + `Transform.scale`
  - Hover adds soft green highlight

### 3.2 Master Auth (Register/Login Contract)
Source: `lib/features/auth/master_auth_page.dart`

- Container style: parchment panel + wood frame + hard shadow.
- Segmented mode toggle:
  - `註冊`
  - `登入`
- Register fields:
  - Email
  - Password
  - Guild Name
- Login fields:
  - Email
  - Password
- Input style:
  - stone/wood inset feel (`fillColor #E7DDC9`, border 3)
- Register success:
  - calls `POST /api/v1/auth/master/register`
  - shows invite code modal (`Invite Code: XXXXXX`)
- Login:
  - calls `POST /api/v1/auth/master/login`

### 3.3 Hunter Login (Hunter Card + Custom Keypads)
Source: `lib/features/auth/hunter_login_page.dart`

- No system keyboard for primary flow.
- Two manual code panels:
  - Invite Code: 6 slots
  - PIN: 4 slots (masked dots)
- Focus target switch:
  - active panel border turns navy blue
- Keypads:
  - Invite keypad: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
  - PIN keypad: gemstone circular keys (`1-9,0`)
- Control keys:
  - Back
  - Clear
  - To PIN / To Invite
- Submit button:
  - chunky green physical button
  - enabled only when invite length = 6 and pin length = 4
- API:
  - `POST /api/v1/auth/hunter/login`

## 4. Auth State and Route Guard

### 4.1 Storage
- Package: `flutter_secure_storage`
- Persist key: `chen_leveling_auth_session_v1`
- Data: `access_token`, `role`, `guild_id`, `hunter_id`, `invite_code`

### 4.2 Guard Behavior
Source: `lib/app/app.dart`, `lib/state/auth_controller.dart`

- App start:
  - restore persisted session
  - call `/api/v1/auth/me` to validate token
- If unauthenticated: show `AuthLandingPage`
- If authenticated: show `GameShellPage`
- Logout: clear storage and return to landing

## 5. Cozy Guild Board Polish Spec

### 5.1 Title Torches
Source: `lib/features/game/game_shell_page.dart`

- Add pixel torch on both sides of `Cozy Guild Board` badge.
- Animated flicker using opacity/brightness modulation.

### 5.2 Quest Card Hover
- Quest cards (`_ParchmentSection` when `hoverLift = true`):
  - slight upward lift (`AnimatedSlide`)
  - add glow-like green shadow

### 5.3 Empty State
- If no quests:
  - render pixel chest icon (`_PixelChestPainter`)
  - text: `No quests assigned`
  - subtext: `The guild chest is waiting for new missions.`

### 5.4 Role-sensitive UI
- Hunter role:
  - can submit quests
  - guardian tab hidden
- Guild master role:
  - guardian tab visible
  - review queue visible

## 6. API Mapping (Frontend Contract)

- Register master:
  - `POST /api/v1/auth/master/register`
  - request: `email`, `password`, `guild_name`
  - response includes: `access_token`, `guild_id`, `invite_code`
- Login master:
  - `POST /api/v1/auth/master/login`
  - request: `email`, `password`
  - response includes: `access_token`, `guild_id`, optional `invite_code`
- Login hunter:
  - `POST /api/v1/auth/hunter/login`
  - request: `invite_code`, `pin_code`
  - response includes: `access_token`, `guild_id`, `hunter_id`

## 7. Designer Review Checklist

### 7.1 Must Confirm
- Auth Landing wood sign visual language:
  - board texture, icon style, pressed depth
- Master page parchment treatment:
  - edge burn, paper grain, input frame motif
- Hunter card:
  - invite slot brass style
  - gem keypad material and key states
- Board micro-motion:
  - torch flicker intensity
  - quest hover distance and glow strength

### 7.2 Optional Next Assets
- Pixel torch sprite set (2-4 frames)
- Pixel chest sprite set (closed/idle)
- Pressed dust puff sprite for major CTA buttons
