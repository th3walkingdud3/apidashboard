# API Dashboard

A macOS desktop widget that shows your Claude API spend and token usage, pulled
from Anthropic's [Usage & Cost Admin API](https://platform.claude.com/docs/en/manage-claude/usage-cost-api).

- **Widget** (small/medium/large) shows today's spend, month-to-date spend,
  and today's token usage, refreshing on a timer.
- **Companion app** is where you paste your Admin API key (stored in the
  Keychain, never in code or in the repo) and can force a refresh.

## Requirements

- **Full Xcode** (not just the Command Line Tools) — the widget extension
  target can't be built without it.
- An **Admin API key** (`sk-ant-admin...`) from your Anthropic organization.
  You need the **admin** role to create one: Console → Settings → Admin Keys.
  See [Create an Admin API key](https://platform.claude.com/docs/en/manage-claude/admin-api-keys).

  > ⚠️ **This key is powerful.** It can manage your organization's members,
  > workspaces, and API keys — not just read usage. It's stored in the
  > Keychain (not in this repo, not in UserDefaults), but treat it like any
  > other admin credential: don't share it, and revoke it from the Console if
  > this Mac is ever compromised.

## First-time setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it:

   ```sh
   brew install xcodegen
   ```

2. Generate the Xcode project (this repo intentionally doesn't commit the
   `.xcodeproj` — it's generated from `project.yml`, which is the source of
   truth for both targets, entitlements, and the App Group):

   ```sh
   xcodegen generate
   open APIDashboard.xcodeproj
   ```

3. **Set your Team.** Select the `APIDashboard` project in the navigator →
   for **both** the `APIDashboard` and `APIDashboardWidgetExtension` targets
   → Signing & Capabilities → set your Team. Xcode will offer to fix
   signing issues automatically; let it.

   Both targets need the *same* team, and the App Group
   (`group.com.roblinger.apidashboard`) and keychain access group
   (`com.roblinger.apidashboard.shared`) need to actually exist for your
   team — Xcode's "Automatically manage signing" will register them the
   first time you build, as long as you're signed into your Apple ID in
   Xcode → Settings → Accounts.

   If you'd rather use your own bundle ID prefix instead of
   `com.roblinger`, change `bundleIdPrefix` in `project.yml` and the
   `group.com.roblinger.apidashboard` / `com.roblinger.apidashboard.shared`
   strings in `project.yml`'s two `entitlements.properties` blocks, then
   re-run `xcodegen generate`.

4. Build and run the `APIDashboard` scheme (⌘R). The app window opens —
   paste your Admin API key, hit **Save & Test**. If it's valid you'll see
   your org name and today's/this month's numbers.

5. Add the widget: Notification Center (or desktop, on macOS 14+) → click
   **Edit Widgets** → find **API Dashboard** → drag in the size you want.

## How it works

- `Shared/AnthropicAdminClient.swift` calls two endpoints:
  - `GET /v1/organizations/cost_report` — spend, in cents as a decimal
    string (the client divides by 100 for dollars). Summed from the start
    of the current UTC month for month-to-date, with today's UTC bucket
    pulled out separately for the "today" figure.
  - `GET /v1/organizations/usage_report/messages` — token counts, summed
    for today (UTC).
- `Shared/KeychainHelper.swift` stores the key under a Keychain access
  group shared by both targets, so the widget extension (which runs as a
  separate process) can read it too.
- `Shared/SharedConstants.swift`'s `SharedCache` mirrors the last snapshot
  into the shared App Group's `UserDefaults`, so the widget has something
  to show immediately (and the app shows "last synced" state) before its
  own fetch completes.
- The widget's `Provider` (`Widget/Provider.swift`) does its own network
  fetch on each timeline reload — independent of whether the companion app
  is running — and asks for a reload roughly every 30 minutes. macOS's own
  per-widget refresh budget usually throttles this further; that's normal
  and out of this app's control.

## Regenerating the project

Any time you change `project.yml` (or pull changes that touched it), run:

```sh
xcodegen generate
```

The `.xcodeproj` is gitignored on purpose — don't hand-edit build settings
in Xcode's UI expecting them to persist; put changes in `project.yml`
instead so they survive a regenerate.
