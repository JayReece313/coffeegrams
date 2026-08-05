# CoffeeGrams — v1.1 App Store Submission Runbook (AS-BUILT)

> **Status: SUBMITTED FOR REVIEW 2026-08-04.** Submitted as **one review item**
> (the app version alone — the approved Pro IAP was correctly left out).
> Release is **manual**, so after approval this parks at *Pending Developer
> Release* until someone clicks **Release This Version**.
>
> This is the as-built record, not a plan. What actually differed from the plan
> is in [§5 As-built notes](#5-as-built-notes--what-differed).

`MARKETING_VERSION` **1.1** · `CURRENT_PROJECT_VERSION` **2** (shipped as build
2 — no second upload was needed) · Bundle ID `com.jrlabapps.CoffeeGrams` ·
**iPhone-only, portrait** (unchanged — iPad is 1.2, see
[`roadmap_future.md`](roadmap_future.md)).

Repo state at submission: `main` at `f89129c`, clean, PRs #2–#6 all merged.
Core **49/49**, app suite `TEST SUCCEEDED`, Release build warning-free.

## What makes this different from 1.0

1.0 was a first submission and needed the whole apparatus: Paid Apps agreement,
App ID registration, distribution certificate, the app record, the first IAP,
and every app-level setting. **None of that recurs here.** 1.1 is a version
update to an existing, approved app with no new IAP, so the flow is four steps
rather than eight.

Three things in particular you do **not** need to touch:

| Skip | Why |
|---|---|
| §5 of the 1.0 runbook (create the IAP) | `com.jrlabapps.coffeegrams.pro` already exists and is approved. A *first* IAP must ride along with a version; a subsequent update must not re-submit it. |
| §6 (Category, Price, App Privacy, Age Rating, DSA trader) | App-level settings persist across versions. 1.1 adds no SDK, no tracking, and no new data collection, so **"Data Not Collected" still holds** — do not re-answer the privacy questionnaire. |
| Screenshots — **the sizing and the set** | 1.1 is iPhone-only and portrait, so the 1290×2796 6.9" set is still the right shape and count. **But two shots must be retaken and a third is worth retaking — see §3.** |

---

## Order of operations

1. Merge to `main` with Qodo clean, confirm the version numbers
2. Archive + upload the build
3. Version page (What's New, build, **refreshed screenshots**, manual release)
4. Review Submission — **one item this time**, not two

---

## 1. Pre-flight **[you]**

- [x] **All 1.1 PRs merged to `main`** — #2 (the fixes), #3 (model guidance),
      #4 (runbook hardening) and #5 (screenshot refresh), with #5's Qodo findings
      resolved. Nothing outstanding in the repo. *(Rule 2205425 stays a known
      false positive — it infers the runbook is missing from `release_1.1.md`'s
      header instead of checking the file tree, so no repo edit can clear it.
      Dismiss it; fix it cloud-side before 1.2.)*
- [x] **`git pull` on `main`** so you archive the merged code, not the branch.
      Archived from `main` at `f89129c` on 2026-08-04.
- [x] **Version numbers** — verified 2026-08-03: `MARKETING_VERSION` **1.1**,
      `CURRENT_PROJECT_VERSION` **2**, consistent across all build configs.
      ```sh
      grep -m1 MARKETING_VERSION CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj      # 1.1
      grep -m1 CURRENT_PROJECT_VERSION CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj # 2
      ```
- [x] **Build number must be higher than any build already uploaded** — App Store
      Connect rejects a duplicate at upload, *after* the whole archive. Checked
      TestFlight first: **build 2 had never been uploaded**, so no bump was
      needed and 1.1 shipped as **1.1 (2)**, accepted on the first upload.
- [x] **All suites green + warning-free** — verified 2026-08-03 **on merged
      `main` (`637fc29`)**, after every 1.1 PR had landed: Core **49/49** in 4
      suites, app `** TEST SUCCEEDED **`, Release build clean. (The only build
      output is three `appintentsmetadataprocessor` "no AppIntents.framework"
      notes — a toolchain info message, not a compiler warning.) Nothing has
      changed in the repo since, so this needs re-running only if you commit
      something further:
      ```sh
      (cd CoffeeGramsCore && swift test)
      (cd CoffeeGrams && xcodebuild test -scheme CoffeeGrams \
         -destination 'platform=iOS Simulator,name=<latest available iPhone>')
      (cd CoffeeGrams && xcodebuild build -scheme CoffeeGrams -configuration Release \
         -destination 'generic/platform=iOS Simulator')
      ```

## 2. Archive → upload **[you]**

Same as 1.0 §4 — signing, certificate, and App ID are all already in place.

- [x] Xcode → destination **Any iOS Device (arm64)** (you cannot archive against a simulator).
- [x] **Product → Archive**.
- [x] Organizer → **Distribute App** → **App Store Connect** → **Upload**.
- [x] Wait for the "processing" email, or watch ASC → **TestFlight**. A build that
      never appears has almost always failed processing — check email for the reason.
- [x] **TestFlight sanity pass** on a real device before submitting. For 1.1
      specifically, walk one full French Press brew: the keypad **Done** button,
      the **Set Up Brew → Start Timer** labels, the count-up on the plunge, and
      **Save to Log** showing planned vs actual.

## 3. Version page **[you]**

- [x] ASC → the app → **+ Version or Platform** → **iOS** → enter **1.1**.
- [x] **What's New in This Version** — copy from the block below. Required for an
      update; this is the one field 1.0 didn't have.
- [x] **Build** — select the build you just uploaded.
- [x] ⚠️ **Screenshots — two MUST be replaced. Not optional, not a judgement
      call.** 1.1 changed the UI in both, so the shots on the listing show
      controls the app no longer has. **Both were recaptured on 2026-08-03** and
      are committed at 1290×2796; they only need uploading.

      | Shot | On the 1.0 screenshot | In the shipped 1.1 build |
      |---|---|---|
      | `02-calculator.png` | Call to action reads **"Start Brew"** | Reads **"Set Up Brew"** (`BrewSessionView.startTitle`) |
      | `03-guided-timer.png` | No total-elapsed readout | A "TOTAL m:ss" count-up under the step timer |
      | `03-guided-timer.png` | **Pause / Skip** buttons | **Pause ⇄ End Brew**, with "Skip step" demoted to tertiary |

      A listing screenshot that doesn't match the built app is a documented
      rejection reason. The calculator one is the easier to miss of the two: the
      change is a single word on one button, but it's the button the whole
      screen exists to lead to.

      **Both new shots include a back chevron** the 1.0 set didn't have, because
      they're captured by walking the real app from the method list rather than
      deep-linking into the screen. That's what a user actually sees, and Apple
      accepts nav chrome in screenshots.

      **Recapturing, if you ever need to redo them.** One command from the repo
      root — it discovers the simulator, pins the status bar to 9:41, drives the
      app, and writes upload-ready files straight over the tracked assets:

      ```sh
      ./Releases/screenshots/capture.sh                  # both
      ./Releases/screenshots/capture.sh 03-guided-timer  # just one
      ```

      How it works, and why it isn't the 1.0 method: the 1.0 set came from a
      temporary `CG_SHOT` switch **inside the app target** that had to be added
      before a capture and deleted afterwards. This drives the real UI from
      `CoffeeGramsUITests/ScreenshotCaptureTests.swift` instead, so no
      capture-only code ever exists in the shipping binary. It builds
      **`-configuration Release`**, so the shots are of the configuration that
      ships rather than a Debug build. Those tests also assert the two 1.1
      strings ("Set Up Brew", the Pause/End Brew pair) on *every* run, so the
      suite now fails if the UI drifts from the screenshots again.

      **Capture size — still a two-step, same as 1.0.** The upload size is
      **1290×2796** (canonical 6.9"), but current Pro Max simulators capture
      *larger* — iPhone 17 Pro Max gives 1320×2868 — and some ASC uploaders
      reject the bigger file, so the script fits every frame down and verifies
      the result before it exits. Canonical sizing guidance:
      [`screenshots/README.md`](screenshots/README.md).

      Per our standards the simulator is discovered, never hardcoded, and
      resolves to a **UDID** rather than a name — names repeat across installed
      runtimes. The version sort is done in `python3` (ships with Xcode) because
      `sort -V` isn't dependable on a stock macOS `sort`.

- [x] **`05-brew-log.png` — decided 2026-08-03: shipping 1.1 with the existing
      shot.** 1.1 added an "`m:ss` actual · `m:ss` planned" line to each log row
      (`LogView.swift`), which the current shot predates, so this was considered
      and deliberately declined — not overlooked. It is **not** inaccurate:
      those fields are nil-defaulted for backward compatibility, so pre-1.1
      records really do render without that line in the shipped 1.1 build.
      Retaking it would only showcase a What's New item, making it a marketing
      call rather than a compliance one. Revisit for 1.2 if the log screen
      changes again. (It isn't scripted either: it needs a populated log, and
      only French Press is free, so seeding varied methods would need Pro
      unlocked first.)
- [x] **`01-home.png` and `04-paywall.png`** — leave as-is. 1.1 stayed
      iPhone-only and portrait and changed neither screen. Don't redo work.
- [x] **Description / keywords / promotional text** — unchanged from 1.0 unless
      you want to work the timer improvements into the description.
- [x] **Version Release** → **Manually release this version**.
- [x] **Review notes** — no demo account needed; Pro is a one-time IAP and the
      reviewer can exercise French Press without it. If they need Pro, say so here.

## 4. Review Submission **[you]**

- [x] ASC → **Review Submission** → **Add to Review** → the **1.1 app version only**.
- [x] ⚠️ **Do not add the IAP as a second item.** That was a 1.0 requirement
      because it was the app's *first* IAP. Re-adding an already-approved IAP
      here is the most likely mistake on this submission.
- [x] **Submit to App Review**.

## After submitting

- Status goes **Waiting for Review** → **In Review** → **Pending Developer Release**
  (because release is Manual).
- [x] **Submitted 2026-08-04**, one item, awaiting review at the time of writing.
- [ ] Click **Release This Version** once approved. *(Still to do — the only
      step between here and 1.1 being live.)*
- [x] Update this file to **AS-BUILT** with the submission date and any
      deviation — done 2026-08-04, see §5.
- [x] Per the Retrospective Standard, add the 1.1 notes to
      `CoffeeGrams_Summary.md` in the private `Summary` repo — including the
      **AI-agent process review** checkpoint. Added as §8 of that document.

---

## 5. As-built notes — what differed

The submission went to plan apart from one snag, which cost about ten minutes
and is worth writing down because it will recur on every future release.

### The screenshot upload rejected the correct files

Dragging `02-calculator.png` and `03-guided-timer.png` (both 1290×2796) into the
version page produced:

> The dimensions of one or more screenshots are wrong. Screenshots dimensions
> should be: 1242 × 2688px, 2688 × 1242px, 1284 × 2778px or 2778 × 1284px

**Nothing was wrong with the files.** Those are the **6.5" Display** sizes; the
files had been dropped into the 6.5" slot. **CoffeeGrams' listing uses the
6.9" Display slot**, where 1290×2796 is correct — the same size and slot the
1.0 set has always used.

**For next time:** in *App Previews and Screenshots*, pick the size slot using
the device selector *first*, and pick the one that **already contains the
existing set**. Don't rely on the first slot ASC happens to show. Recorded so
1.2 doesn't repeat it. Our capture pipeline stays at 1290×2796 — no 6.5"
variant is needed.

### Some version fields appeared greyed out

Cause worth remembering: screenshot and metadata fields are read-only unless
you're on an **editable** version page. The usual reasons are being on the
released 1.0 page rather than 1.1, not having created the 1.1 version yet, or
the version already being submitted (which needs **Remove from Review** to
re-open — safe, no penalty).

### What went exactly to plan

- **Build 2 accepted on the first upload** — the TestFlight pre-check confirmed
  it had never been used, so no bump was needed.
- **One review item.** The approved Pro IAP was correctly left out; the trap the
  runbook warned about did not catch us.
- **App Privacy untouched**, so "Data Not Collected" carried over intact.
- **Three screenshots left alone** (`01-home`, `04-paywall`, `05-brew-log`) —
  the 05 decision is recorded in §3 and still stands.

---

## Copy-paste metadata

### What's New in This Version

```
Fixes and a better brew timer.

• The number pad on the calculator now has a Done button, so it no longer covers the screen.
• Clearer buttons: "Set Up Brew" takes you to the timer, "Start Timer" starts the clock.
• The timer now shows total elapsed time for the whole brew, and counts up if your last step runs long.
• Your brew log now records how long a brew actually took, next to how long it was planned to take.
```

### Unchanged from 1.0 — for reference

- **Support URL:** https://jayreece313.github.io/coffeegrams/support/
- **Privacy Policy URL:** https://jayreece313.github.io/coffeegrams/privacy/
- **Support email:** info@jrlabapps.com
- **Category:** Food & Drink · **Age rating:** 4+
- **IAP:** `com.jrlabapps.coffeegrams.pro` — $4.99, non-consumable, already approved
- **App Privacy:** Data Not Collected (no third-party SDKs, no tracking — still true in 1.1)

---

## Carry these into the next release

All five held up on 1.1 — none of them caught us out, which is the point of
writing them down. Take them into 1.2.

- **Audit *every* screenshot against the code, not against the last release's
  notes.** This runbook originally said the guided-brew shot was the only asset
  1.1 invalidated; it had missed that the calculator's button was renamed too.
  Any release that changes a UI string can invalidate a screenshot.
- **Pick the screenshot size slot before dragging** — the one that already holds
  the existing set (6.9" Display for this listing). See §5.
- **Archive from `main` after the merge**, not from the release branch.
- **Check TestFlight for the build number before archiving** — ASC rejects a
  duplicate only at the end of the upload, wasting the whole archive.
- **One item in the Review Submission**, not two, for any release after the
  first that adds no new IAP.
- **Don't re-answer App Privacy.** No new data collection means re-opening the
  questionnaire only risks contradicting the privacy policy already hosted.
