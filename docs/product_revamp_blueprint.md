# The Bit and Bond Product Revamp Blueprint

Last updated: 2026-03-09

This document is the new product, UX, and system blueprint for `The Bit and Bond`.
It supersedes the old "RPG guild / tavern" direction as the primary design reference.

Use this file as the source of truth for:
- product positioning,
- new UI/UX direction,
- information architecture,
- family-first and social expansion roadmap,
- habit system design,
- system language strategy,
- future implementation phases.

## 1. Product Positioning

### 1.1 Core Product Statement

`The Bit and Bond` is a pixel-styled life gamification app that helps people turn daily life into a playful shared experience.

It starts with families:
- parents create structure,
- children complete tasks and earn rewards,
- families interact in a shared space.

It then expands into friends and communities:
- social voice rooms,
- direct messages,
- habit accountability,
- photo dumps and memory sharing.

### 1.2 What The Product Is Not

The product is not primarily:
- an RPG,
- a tavern simulator,
- a fantasy guild management game.

The product may borrow game-like language, progression, and visual charm, but its true category is:

`Gamify your life`

### 1.3 Product Pillars

The product should be built around five pillars:

1. Daily Life Gamification
2. Family Structure and Motivation
3. Social Accountability and Bonding
4. Memory and Lifestyle Sharing
5. Pixel-identity and playful emotional design

## 2. Audience And Expansion Path

### 2.1 Phase 1 Audience

Primary audience:
- parents
- children
- families who want playful structure for habits, chores, learning, and rewards

Key use cases:
- assign chores
- review completion
- reward children
- create positive routines
- check family progress in one shared app

### 2.2 Phase 2 Audience

Secondary audience:
- friends
- couples
- roommates
- accountability partners

Key use cases:
- friend-to-friend habit challenges
- voice hangouts
- DM conversations
- shared life progress

### 2.3 Phase 3 Audience

Lifestyle and memory users:
- people who want to keep playful visual records of life
- users who want to share photo dumps or personal progress moments

## 3. New Product Language

### 3.1 Naming Direction

The product language should move away from tavern and guild terminology.

Current or legacy terms should gradually migrate:

| Legacy term | New direction |
| --- | --- |
| Tavern | Life Space / Home Space / Bond Space |
| Guild Master Desk | Family Center |
| Guild Board / Quest Board | Task Board |
| Quest | Task / Mission / Challenge |
| Guild Shop | Rewards Shelf / Rewards Store |
| Campfire Voice Bar | Voice Room / Hangout |
| Inventory | Collection / Rewards Bag |
| Tavern Map | Space Map |

### 3.2 Tone

Desired tone:
- warm
- encouraging
- playful
- emotionally safe
- family-friendly
- social but not noisy

Avoid tone that feels:
- overly fantasy-RPG,
- overly corporate productivity tool,
- overly childish in a toy-like way.

## 4. Visual Direction

### 4.1 Core Visual Goal

Everything should feel consistently pixel-styled.

Not just characters.
Not just icons.
Not just a few decorative panels.

The entire interface should feel intentionally pixel-built.

### 4.2 Pixel Design Principles

The design system should follow:

1. Pixel-first shapes
   - jagged edges
   - stepped corners
   - crisp silhouettes

2. Consistent panel language
   - pixel frames
   - chunky borders
   - shallow depth shadows

3. Controlled information density
   - fewer always-visible controls
   - more contextual surfaces

4. Strong iconography
   - pixel icons instead of generic Material icons

5. Readability before purity
   - the interface should look pixelated
   - text should remain readable in all supported languages

### 4.3 Pixelization Scope

The following surfaces should all be redesigned into the same pixel system:
- onboarding
- sign-in panels
- HUD
- buttons
- sheets and dialogs
- room labels
- joystick
- settings
- chat bubbles
- photo dump frames
- badges
- progress boards

### 4.4 Typography Strategy

Pixel style is required, but readability must remain high.

The app should use layered typography:

- English / numeric / micro labels:
  use a pixel font
- Chinese / Japanese / Korean:
  use a CJK-compatible pixel or pixel-adjacent font
- long paragraphs:
  use a readable pixel-adjacent fallback if necessary

Important rule:

The product should feel pixelized across all languages, but not every language must be forced into the exact same font asset.

## 5. Main Information Architecture

### 5.1 Primary Top-Level Product Areas

The product should be organized into these top-level areas:

1. Home
2. Tasks
3. Habits
4. Rewards
5. Social
6. Memory
7. Settings

### 5.2 Main Room / Home Screen Role

The room is not a fantasy tavern.
It is the player's playful life hub.

It should act as:
- an emotional home base,
- a space to move,
- a place to access systems,
- a surface that can expand into more rooms later.

### 5.3 Main Screen Layout

The main screen should be simplified into:

- Top-left:
  player summary
  - level
  - coins / points
  - current progress snapshot

- Top-center or top-left-center:
  current space label

- Top-right:
  only two always-visible buttons
  - map
  - menu

- Bottom-left:
  fixed pixel joystick

- Bottom-right:
  contextual interact button
  only appears or activates when near a person, portal, object, or station

### 5.4 What Should Not Stay On The Main HUD

The following should not all remain visible as permanent top buttons:
- task board
- family center
- rewards store
- bag
- voice room
- extra utility actions

These should move into the main menu.

## 6. Main Menu Design

### 6.1 Menu Role

The menu is the player's command board.
It should be the primary way to access systems without cluttering the room screen.

### 6.2 Menu Content

The first version of the main menu should contain:

- Tasks
- Habits
- Family Center
- Rewards
- Bag
- Voice Room
- Direct Messages
- Photo Dump
- Profile
- Settings

### 6.3 Menu UI Direction

The menu should be:
- full-screen or large overlay
- pixel panel based
- icon-led first
- minimal scrolling

Recommended layout:
- 2 x 3 or 3 x 3 command grid
- larger cards for core sections
- smaller utility cards for profile and settings

## 7. Settings

### 7.1 Role Of Settings

Settings is not optional.
It is required because the product will support:
- system language,
- audio,
- haptics,
- accessibility,
- future feature toggles.

Settings should be reachable from:
- main menu
- onboarding
- login / contract screens

### 7.2 Initial Settings Scope

Settings v1 should include:

- System Language
- Sound Effects
- Music
- Haptics
- UI Scale
- Pixel FX intensity
- Notifications
- Privacy basics

### 7.3 Future Settings Scope

Later additions:
- account management
- family permissions
- chat privacy
- photo sharing permissions
- data export / backup

## 8. System Language Strategy

### 8.1 Terminology

The app should support `system language switching`, not "translation mode".

That means:
- the user chooses the app language,
- the interface updates accordingly,
- system-generated copy follows that language.

### 8.2 Three Content Types

The system must distinguish between:

1. System UI copy
2. System event copy
3. User-generated content

#### System UI copy

This includes:
- buttons
- labels
- panel titles
- onboarding text
- settings copy

This should be fully localized in the frontend.

#### System event copy

This includes:
- reward approved
- habit proof accepted
- invite received
- task completed

This should not be stored as fixed Chinese or English sentences from the backend.

Recommended backend design:
- send `event_code`
- send `payload`
- frontend renders text using current system language

#### User-generated content

This includes:
- player names
- family names
- custom reward names
- chat messages
- photo captions
- habit titles if created by users

This should remain original and should not be automatically translated by default.

### 8.3 Backend Recommendation

Backend should store:
- `source_text`
- `source_locale` when useful

But should avoid:
- overwriting original user text with translated text
- mixing localized strings into permanent records when a structured event can be used instead

## 9. Core Product Modules

### 9.1 Tasks

Purpose:
- daily structure
- chores
- study missions
- one-off goals

First version:
- assign task
- submit completion
- review
- reward with XP / coins

### 9.2 Rewards

Purpose:
- make progress tangible
- support family motivation

Examples:
- screen time reward
- dessert token
- outing privilege
- custom item created by parent

### 9.3 Family Center

Purpose:
- family management
- member status
- child progress
- reward and task administration

It replaces the old "guild master desk" concept.

### 9.4 Social

Purpose:
- move the app beyond family
- support friends and accountability partners

First version:
- friends
- voice room
- DMs

Later version:
- shared challenges
- reactions
- group rooms

### 9.5 Memory

Purpose:
- keep life moments
- make progress social and emotionally sticky

First version:
- photo dump
- private / family / friends visibility options
- pixel-framed photo cards

### 9.6 Habits

Purpose:
- long-term behavior building
- accountability
- streak-based progress

This should become one of the product's most differentiated systems.

## 10. Habit System Blueprint

### 10.1 Habit Types

Habit system should support three types:

1. Self Habit
2. Family Habit
3. Friend Challenge Habit

### 10.2 Key Differentiator

The special experience is not only self-tracking.
It is social accountability:

- a friend or parent can assign a habit challenge,
- the user submits proof,
- the reviewer approves or rejects,
- progress and rewards update after approval.

### 10.3 Friend Challenge Flow

1. A friend creates a habit challenge
2. The challenge is assigned to another user
3. The challenged user submits proof
4. The assigning friend reviews the proof
5. If approved:
   - streak increases
   - habit progress updates
   - reward is granted

### 10.4 Habit Challenge Properties

Habit challenge model should include:
- title
- category
- description
- owner / creator
- assignee
- recurrence type
  - daily
  - weekly
- target duration
  - e.g. 7 days, 14 days, 30 days
- proof requirement
  - checkbox only
  - text
  - photo
  - photo plus caption
- review mode
  - auto-complete
  - manual review
- reward
  - XP
  - coins
  - badge
  - custom reward

### 10.5 Habit UX Surfaces

Habit system should have at least:

1. Habit Board
2. Habit Detail
3. Proof Submission Sheet
4. Review Inbox

#### Habit Board

Shows:
- active habits
- today's state
- streaks
- pending review counts
- progress summary

#### Habit Detail

Shows:
- challenge rules
- who assigned it
- reward
- submission history
- progress board

#### Proof Submission Sheet

Must be fast and compact.

Core actions:
- attach photo
- add short note
- submit proof

#### Review Inbox

For parents and friends.

Shows:
- pending submissions
- photo proof
- caption
- approve
- reject
- optional note

### 10.6 Habit Progress Visualization

Do not use a generic business dashboard chart.

Preferred direction:
- pixel habit board
- daily tiles
- weekly strips
- 30-day grids
- streak glow
- milestone badge states

Potential visual metaphors:
- power circuit
- signal lights
- growth chain
- memory wall stamps

### 10.7 Habit Rewards

Habit rewards should exist on three levels:

1. Per completion reward
2. Streak reward
3. Full challenge completion reward

Examples:
- per approval: +10 XP
- 7-day streak: bonus coins
- full completion: badge or unlockable frame

### 10.8 Habit Rules And Abuse Prevention

Initial guardrails:
- one valid submission per day per habit
- review state must be explicit
- allow reject with reason
- optionally allow resubmission
- daily and weekly recurrence first
- proof attachment rules should be simple at first

## 11. Social And Messaging Blueprint

### 11.1 Social Layers

Social should not be a single blob.
It should be separated into:

- Friends
- DMs
- Voice Rooms
- Shared Challenges

### 11.2 DMs

Direct messages should be its own module, not hidden inside voice.

DM v1 should support:
- friend-to-friend text chat
- image sharing later
- habit challenge notifications
- links into proof review or photo dump

### 11.3 Voice Rooms

Voice should remain a lightweight social ambient space.

Good use cases:
- family check-in
- study together
- casual friend hangout

### 11.4 Shared Challenge Feed

Later, habits and tasks can optionally produce feed events:
- completed streak
- approved habit proof
- reward unlocked

This should be opt-in and privacy-aware.

## 12. Photo Dump / Memory Blueprint

### 12.1 Purpose

Photo Dump is not just media upload.
It is lifestyle memory capture.

It should support:
- personal memory keeping
- family sharing
- friend sharing

### 12.2 First Version

Photo Dump v1 should support:
- upload one or multiple photos
- optional caption
- visibility control
  - private
  - family
  - friends
- pixel-styled frame templates

### 12.3 Design Direction

The visual direction should be:
- scrapbook-like
- pixel framed
- warm and personal
- not a generic social feed

Possible UI metaphors:
- Memory Wall
- Sticker Album
- Bond Frames

### 12.4 Future Extensions

Later versions can add:
- reactions
- comments
- themed photo frames
- milestone memory reels

## 13. Room And Space Strategy

### 13.1 Space Direction

The room should evolve from tavern to life space.

Suggested initial spaces:
- Home Hub
- Task Corner
- Rewards Shelf
- Family Center
- Voice Room
- Memory Wall

### 13.2 Multi-room Expansion

Map and portals still make sense, but the theme changes:
- not fantasy rooms,
- but functional life spaces.

The space map should show:
- room layout
- current room
- future expansion slots

### 13.3 Future Growth Hook

The app can later support:
- unlocking new rooms,
- buying room expansion,
- themed room skins,
- feature-specific rooms.

## 14. Current Feature Mapping

The repo already has several features that can be reused under the new direction.

### 14.1 Can Be Reused

- auth
- progression
- XP and coins
- reward granting flow
- shop backend
- inventory backend
- voice room stack
- realtime room presence
- chat persistence foundation

### 14.2 Should Be Renamed Or Reframed

- quest -> task
- guild master desk -> family center
- guild shop -> rewards
- inventory -> collection / reward bag
- tavern room -> life space

### 14.3 Will Need New Product And Data Design

- habits
- proof submission and review
- DM system
- photo dump
- memory wall
- settings and locale infrastructure

## 15. Implementation Phases

### Phase 1: Product And UX Reframe

Goals:
- remove tavern-first product identity
- establish new app information architecture
- establish pixel UI system
- add settings and system language foundation

Deliverables:
- new design system
- new onboarding direction
- new room HUD
- menu and settings

### Phase 2: Family-first Functional Reframe

Goals:
- rename and reposition current systems
- make family usage feel coherent

Deliverables:
- tasks
- rewards
- family center
- family member role clarity

### Phase 3: Habit System

Goals:
- launch differentiated social accountability feature

Deliverables:
- habit board
- challenge creation
- proof submission
- review inbox
- habit progression UI

### Phase 4: Social Expansion

Goals:
- deepen user retention and connection

Deliverables:
- DMs
- refined voice rooms
- richer friend features

### Phase 5: Memory Layer

Goals:
- support lifestyle sharing and emotional stickiness

Deliverables:
- photo dump
- memory wall
- sharing and visibility controls

## 16. Immediate Design Priorities

Before large implementation work, the next design priorities should be:

1. Remove remaining tavern-first UX assumptions
2. Redesign main HUD and main menu
3. Create a consistent pixel component system
4. Define settings and system language model
5. Define habit system object model and review flow

## 17. Decision Checklist For Future Implementation

Before implementing any new screen, confirm:

- Does this still support "Gamify your life"?
- Is this family-first or friend-first, and is that explicit?
- Is the UI fully pixel-styled and visually consistent?
- Is the system language switchable?
- Is user-generated content kept separate from system UI copy?
- Does the surface reduce clutter instead of adding always-visible controls?
- Does the feature strengthen habit, family, social, or memory value?

## 18. Working Rule For Future Changes

From this point forward:

- UI and product changes should reference this blueprint first
- new features should fit one of the defined product modules
- old tavern / RPG metaphors should be treated as temporary legacy language unless deliberately retained
- design decisions should favor clarity, warmth, and pixel consistency over novelty
