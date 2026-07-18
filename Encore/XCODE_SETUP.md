# Encore — Xcode configuration checklist (current project)

Wiring the staged Widget + Live Activity + App Intents into the **Encore**
project. Concrete identifiers for THIS project:

| Thing | Value |
|---|---|
| App bundle id | `com.abhinav.Encore` |
| Widget extension bundle id | `com.abhinav.Encore.EncoreWidget` (wizard sets this automatically) |
| App Group | `group.com.abhinav.Encore` |
| Dev team | `Y4GRLGKNQ9` (automatic signing) |
| URL scheme | `encore` |
| Deployment target | iOS 26.2 |

Legend: ✅ = already done in code/project · 🖐️ = you, in Xcode GUI · 🤝 = I do it after you create the target.

---

## Already done (in code / project file)

- ✅ **Live Activities switch** — `INFOPLIST_KEY_NSSupportsLiveActivities = YES` is set on the app target.
- ✅ **Calendar + Apple Music usage strings** — set on the app target.
- ✅ **App Group ID fixed** in code → `group.com.abhinav.Encore` ([EncoreSnapshot.swift](Shared/EncoreSnapshot.swift)). (It was still pointing at the old project.)
- ✅ **App entitlements file created + wired** — [Encore.entitlements](Encore.entitlements) declares the App Group; `CODE_SIGN_ENTITLEMENTS` is set on both Debug/Release. With automatic signing this auto-registers the group.
- ✅ **Widget entitlements prepped** — `_EncoreWidgetStaging/EncoreWidget.entitlements`, ready to move in.

---

## STEP 1 — 🖐️ Create the Widget Extension target

This ONE target hosts BOTH the Live Activity and the Home/Lock-screen widget.

1. **File → New → Target…**
2. Choose **Widget Extension** → **Next**.
3. **Product Name:** `EncoreWidget`
4. ✅ Tick **Include Live Activity**. ❌ Leave **Include Configuration App Intent** unchecked.
5. **Finish** → when prompted **"Activate EncoreWidget scheme?"** → **Activate**.

**Then tell me** — I take over the file moves and wiring (Step 2).

---

## STEP 2 — ✅ Real code moved in + target wired (done)

- ✅ Deleted the template files (`EncoreWidget.swift`, `EncoreWidgetBundle.swift`,
  `EncoreWidgetControl.swift`, `EncoreWidgetLiveActivity.swift`); kept `Assets.xcassets` + `Info.plist`.
- ✅ Moved the 3 real files into `EncoreWidget/`: `EncoreWidgetBundle.swift`,
  `EncoreLiveActivity.swift`, `EncoreHomeWidget.swift` (auto-join the widget target).
- ✅ Moved `EncoreWidget.entitlements` in and set `CODE_SIGN_ENTITLEMENTS` on the widget target.
- ✅ Set widget `IPHONEOS_DEPLOYMENT_TARGET = 26.2` (match the app).

---

## STEP 3 — 🖐️ Tick 3 shared files into the widget target

These live in the app folder but the widget must compile them too. For **each** file:
select it → **File Inspector** (⌥⌘1, right panel) → under **Target Membership** tick
**EncoreWidgetExtension** (leave **Encore** ticked):

1. `Encore/Shared/EncoreSnapshot.swift`
2. `Encore/Shared/EncoreActivityAttributes.swift`
3. `Encore/Intents/EncoreIntents.swift`

*(Only these three — the widget code references nothing else from the app.)*

---

## STEP 4 — 🖐️ App Group on the widget (verify)

The entitlements file is already prepped and wired, but confirm provisioning took:
- Select **EncoreWidgetExtension** target → **Signing & Capabilities** → confirm
  **App Groups** shows `group.com.abhinav.Encore` ticked. If a signing error appears,
  click **+ Capability → App Groups** and tick it (same id as the app). Free team supports it.

---

## STEP 5 — 🖐️ URL scheme (deep links from widget / Live Activity)

The app uses generated Info.plist, so this one must be added in the GUI:
- App target **Encore** → **Info** tab → **URL Types** (bottom) → **+**.
- **Identifier:** `com.abhinav.Encore` · **URL Schemes:** `encore` · **Role:** Editor.

*(This is what makes `encore://event?id=…` from the widget/Live Activity open the app.)*

---

## STEP 6 — 🖐️ Build

1. Build the **EncoreWidgetExtension** scheme once (catches membership gaps).
2. Build + run the **Encore** scheme on a **real device**.
3. Book a show → Live Activity should appear. Add the **Encore — For You** widget to
   the Home Screen → it reads the App Group snapshot.

---

## Later, optional — Background refresh

Only for the "wakes while app is closed" story:
- App target → **Signing & Capabilities → + Capability → Background Modes** → tick
  **Background fetch** + **Background processing**.
- Add `BGTaskSchedulerPermittedIdentifiers` (array, one item `com.encore.refresh`).

## Deferred — watchOS

No watch code or target exists yet. It's a from-scratch build (new target + new
SwiftUI watch UI + WatchConnectivity/App Group bridge), tracked separately.

## Paid Apple Developer account?

Nothing here needs it. Notifications, Live Activity, Widget, App Intents, App Groups
all run on a **free** personal team on a real device. Only live MusicKit needs the paid program.
