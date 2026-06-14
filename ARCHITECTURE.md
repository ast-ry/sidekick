# Sidekick Architecture

## Overview

Sidekick is a macOS desktop companion app that:

- captures the current screen periodically
- analyzes the screen with a local LLM/VLM via LM Studio
- shows lightweight feedback in a persistent overlay
- lets the user jump into a chat in the same overlay when desired
- exposes a separate dashboard window for configuration, status, and logs

The app is designed around `overlay-first` usage.

## Product Intent

The current product shape is:

- everyday surface: overlay window
- configuration and inspection surface: dashboard window
- optional deep interaction: chat mode inside the overlay
- menu bar surface: quick controls and app termination

The overlay now also acts as a lightweight recent-history browser for the latest feedback items.

The overlay is intended to stay present and rotate through feedback over time. The user only enters chat when a specific feedback item is interesting enough to continue.

## Core UX Model

### Primary flow

1. App launches
2. Welcome overlay is shown
3. Monitoring loop captures the screen on an interval
4. Sidekick classifies the current situation
5. If feedback should be emitted, the existing overlay content is updated
6. User may press `チャットする`
7. Monitoring is paused and the current topic is pinned
8. User chats in the expanded overlay
9. User presses `元に戻す`
10. Monitoring resumes later, but only after Sidekick is no longer the active front app / overlay interaction target

### Recent-history flow

The overlay keeps up to five recent feedback items in memory.

Primary behavior:

1. A new feedback item arrives
2. It is added to the recent conversation history
3. The overlay shows the latest item by default
4. The user can browse older / newer items via arrow buttons beside the primary action button
5. Pressing `チャットする` while browsing a historical item resumes that item’s chat context

### Overlay close behavior

The overlay includes a top-right close control.

Current behavior:

- pressing the close control quits the entire app
- it does not merely hide the overlay

### Secondary flow

The dashboard is opened from the menu bar and is used for:

- UI / output language switching
- prompt editing
- status inspection
- capture / ask / test actions
- logs

## Main Components

### App Shell

File:
- [Sources/SidekickApp.swift](/Users/ast-ry/work/sidekick/Sources/SidekickApp.swift)

Responsibilities:

- declares the SwiftUI `App`
- owns `AppDelegate`
- owns the shared `SidekickViewModel`
- provides the dashboard `WindowGroup`
- provides the menu bar entry
- starts in overlay-first mode by showing the welcome overlay

### AppDelegate

File:
- [Sources/SidekickApp.swift](/Users/ast-ry/work/sidekick/Sources/SidekickApp.swift)

Responsibilities:

- wires the app-level services into the `SidekickViewModel`
- configures notification permission and categories
- shows the welcome overlay on first launch
- opens the dashboard window
- opens the standalone chat window
- routes notification actions to chat
- routes overlay close action to app termination

### ViewModel

File:
- [Sources/SidekickViewModel.swift](/Users/ast-ry/work/sidekick/Sources/SidekickViewModel.swift)

Responsibilities:

- owns app state
- owns monitoring state
- owns latest capture / OCR / latest response
- runs capture -> classify -> respond pipeline
- owns chat state
- owns editable prompts
- owns UI language and output language settings
- exposes overlay status signals
- coordinates pause / resume behavior around chat

This is currently the main orchestration layer.

### Overlay Window Manager

File:
- [Sources/SidekickApp.swift](/Users/ast-ry/work/sidekick/Sources/SidekickApp.swift)

Responsibilities:

- owns the persistent overlay `NSPanel`
- updates the same overlay window instead of creating a new one per feedback
- resizes the panel between collapsed and chat-expanded modes
- keeps Sidekick’s own UI excluded from becoming the main interaction path
- reports whether the overlay is still actively being used, so monitoring resume can be delayed

### Overlay UI

File:
- [Sources/FeedbackOverlayView.swift](/Users/ast-ry/work/sidekick/Sources/FeedbackOverlayView.swift)

Responsibilities:

- renders the primary user-facing overlay
- shows the latest feedback text
- shows lightweight status
- expands into chat mode inside the same window
- allows the user to pin the current topic via `チャットする`
- exposes the app quit control in the overlay header
- provides recent-history navigation beside the primary action button

### Dashboard UI

File:
- [Sources/ContentView.swift](/Users/ast-ry/work/sidekick/Sources/ContentView.swift)

Responsibilities:

- language switching
- settings editing
- current status display
- logs
- manual test actions
- prompt editing

### Separate Chat Window

File:
- [Sources/ChatWindowView.swift](/Users/ast-ry/work/sidekick/Sources/ChatWindowView.swift)

Responsibilities:

- standalone chat surface
- still available even though overlay chat is now the primary flow

This remains a secondary interaction surface.

## Monitoring Pipeline

### Capture path

Main entry:
- `runCapturePipeline(trigger:)`

High-level flow:

1. refresh frontmost context
2. optionally skip if Sidekick is frontmost and trigger is monitoring
3. capture screen via `ScreenCaptureService`
4. optionally OCR via `OCRService`
5. compute visual fingerprint
6. compare against previous observation
7. classify situation
8. decide whether feedback should be generated
9. if yes, call LM Studio
10. update overlay or notification depending on delivery mode

### Capture sources

`ScreenCaptureService` supports:

- frontmost window capture
- main display capture

When capturing the main display, Sidekick attempts to exclude its own app windows using `ScreenCaptureKit` application exclusion.

### OCR

OCR is handled with Apple Vision and can be switched off.

### Analysis modes

Supported modes:

- OCR only
- image only
- OCR + image

Current default:

- image only

## Agent Logic

The pipeline is split into two LLM steps.

### 1. Classification

Purpose:

- infer user state
- infer likely intent
- choose response mode
- decide whether the app should interrupt

Output shape:

- `user_state`
- `user_intent`
- `response_mode`
- `should_interrupt`
- `confidence`
- `reason`

### 2. Feedback generation

Purpose:

- generate the actual natural-language response shown to the user

The generated feedback depends on:

- monitoring prompt
- tone prompt
- companion style prompt
- current classification result
- current screen context
- estimated continuous session duration
- output language setting

Before feedback is shown, the app also sanitizes obvious markdown separator artifacts such as `---` and `***` so they do not leak into the overlay or chat UI.

## Chat Behavior

### Overlay chat

When the user presses `チャットする`:

- monitoring is paused
- the current topic is pinned
- the overlay expands vertically
- subsequent monitoring results are discarded while the topic is pinned

If the user is browsing a historical feedback item instead of the latest one:

- `チャットする` resumes that historical conversation snapshot
- the related chat history, topic context, and latest capture reference are restored

This prevents:

- overlay feedback being replaced while chatting
- latest capture / response being overwritten by an in-flight monitoring cycle

### Resume behavior

When the user presses `元に戻す`:

- overlay conversation pin is released
- monitoring resume is scheduled after `Resume Delay`
- monitoring will not resume while:
  - Sidekick is still frontmost
  - the overlay is still actively being interacted with

### Chat capture reuse

Chat can optionally include the latest captured screenshot.

State:

- `includeLatestCaptureInChat`

### Recent conversation snapshots

The ViewModel keeps a small in-memory history:

- `recentConversations`
- `selectedConversationIndex`
- `activeConversationID`

Each snapshot contains:

- feedback text
- topic context
- chat messages
- preview image
- screenshot PNG data
- app name
- window title
- feedback label / timestamp text

History policy:

- newest-first ordering
- maximum of 5 items
- chat replies update the currently active snapshot in place

## Overlay Status Model

Overlay header shows a lightweight status pill.

States:

- idle
- working
- warning

Examples:

- `画面を確認中`
- `応答を待っています`
- `更新しました`
- `返信中`
- `応答に失敗しました`

Detailed errors are not rendered directly in the overlay body. Instead they are exposed via hover tooltip.

The overlay body also includes:

- a primary action button
- optional recent-history arrows and position indicator beside that button

## Prompt Editing Model

Editable from dashboard:

- Interface language
- Output language
- Monitoring prompt
- Chat prompt
- Classification prompt
- Welcome prompt
- Tone prompt: neutral
- Tone prompt: casual
- Companion prompt: quiet
- Companion prompt: chatty
- Companion prompt: insight / small-tidbit style

These values are backed by `@Published` state and persisted with `UserDefaults`.

The dashboard also provides preset actions for prompt content:

- apply Japanese defaults
- apply English defaults

These overwrite the current prompt values immediately and are saved for future launches.

### Language split

Language behavior is split into two separate controls:

- `InterfaceLanguage`
  affects UI-facing labels and visible controls
- `OutputLanguage`
  affects the language instruction passed into monitoring and chat generation

This allows mixed setups such as:

- English UI + Japanese output
- Japanese UI + English output
- system-following behavior

### Persistence

Prompt edits and major runtime settings are reflected immediately for future requests and persisted across app restarts with `UserDefaults`.

Persisted values include:

- endpoint and model name
- UI and output language
- API format, analysis mode, capture scope, delivery mode, and agent style controls
- monitoring interval, heartbeat, resume delay, overlay opacity, and chat capture inclusion
- editable prompt text

## Current Defaults

Current runtime defaults include:

- delivery mode: overlay
- capture scope: main display
- analysis mode: image only
- monitoring interval: 60 seconds
- resume delay: 10 seconds
- overlay opacity: 1.0
- interface language: system
- output language: system
- recent conversation history size: 5 items

## Data Handling

Captured images are not written to disk as screenshot files.

Current handling:

- latest capture image is held in memory
- latest PNG data is held in memory for reuse in chat
- previous observation metadata is held for diffing
- up to 5 recent conversation snapshots are held in memory
- settings and editable prompts are written to `UserDefaults`
- logs are written to:
  - `~/Library/Logs/Sidekick/sidekick.log`
  - `/tmp/sidekick.log`
  - in-app log state

No persistent screenshot archive currently exists.

## Notification vs Overlay

Two delivery modes exist:

- notification
- overlay

The current product direction is overlay-first, but notification mode still exists.

On launch, the app explicitly switches to overlay delivery and shows the welcome overlay before the dashboard is used.

## Important State Flags

Notable ViewModel flags:

- `isMonitoring`
- `isOverlayChatExpanded`
- `isOverlayConversationPinned`
- `shouldResumeMonitoringAfterChat`
- `shouldDelayMonitoringResumeHandler`
- `isChatBusy`
- `recentConversations`
- `selectedConversationIndex`
- `activeConversationID`

These drive most of the interaction lifecycle.

## Known Constraints

### 1. Conversation persistence

Recent conversation history is in-memory only and is lost on app exit.

### 2. Fallback capture path

When capture falls back to `CGDisplayCreateImage`, Sidekick self-exclusion is not guaranteed.

### 3. Heuristic session tracking

Long-work detection is approximate. It is inferred from repeated observations of the same app/window over time.

### 4. Auto-scroll behavior

Chat views auto-scroll to bottom on new content, but there is no advanced “user manually scrolled upward” lockout behavior yet.

## Suggested Next Steps

If continuing development, the most useful next improvements are:

1. Persist recent conversation history when appropriate
2. Add more precise work-session tracking
3. Add stronger self-exclusion when fallback capture is used
4. Add tests around prompt construction and agent decision parsing
5. Add a signed and notarized release flow

## File Map

- [Package.swift](/Users/ast-ry/work/sidekick/Package.swift)
- [Sources/SidekickApp.swift](/Users/ast-ry/work/sidekick/Sources/SidekickApp.swift)
- [Sources/SidekickViewModel.swift](/Users/ast-ry/work/sidekick/Sources/SidekickViewModel.swift)
- [Sources/ScreenCaptureService.swift](/Users/ast-ry/work/sidekick/Sources/ScreenCaptureService.swift)
- [Sources/LMStudioService.swift](/Users/ast-ry/work/sidekick/Sources/LMStudioService.swift)
- [Sources/AgentDecisionParser.swift](/Users/ast-ry/work/sidekick/Sources/AgentDecisionParser.swift)
- [Sources/LogStore.swift](/Users/ast-ry/work/sidekick/Sources/LogStore.swift)
- [Sources/SettingsStore.swift](/Users/ast-ry/work/sidekick/Sources/SettingsStore.swift)
- [Sources/ContentView.swift](/Users/ast-ry/work/sidekick/Sources/ContentView.swift)
- [Sources/FeedbackOverlayView.swift](/Users/ast-ry/work/sidekick/Sources/FeedbackOverlayView.swift)
- [Sources/ChatWindowView.swift](/Users/ast-ry/work/sidekick/Sources/ChatWindowView.swift)
- [Scripts/build_app.sh](/Users/ast-ry/work/sidekick/Scripts/build_app.sh)
