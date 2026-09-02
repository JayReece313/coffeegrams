# CoffeeGrams — v1.2 App Store Submission Runbook

> **Status: 🟡 not yet submitted.** This is a plan, not an as-built record —
> unlike `submission_1.1.md`, which was written after the fact. Steps marked
> **[me]** are done as of this draft; everything marked **[you]** is a real
> App Store Connect / Xcode action nobody but the account owner can perform,
> and is unchecked until you've actually done it. Fill in §5 as-built notes
> once this ships, matching the 1.0/1.1 pattern.

`MARKETING_VERSION` **1.2** · `CURRENT_PROJECT_VERSION` **3** · Bundle ID
`com.jrlabapps.CoffeeGrams` · **Universal — iPhone + iPad**, portrait-only
on iPhone, all orientations on iPad. First release where `TARGETED_DEVICE_FAMILY`
is `"1,2"`.

## What makes this different from 1.1

Same shape as 1.1: a version update to an existing, approved app with no new
IAP, so it's the four-step flow, not 1.0's eight. Two things are genuinely
new this time, both worth reading before you start:

| New this release | Why it matters |
|---|---|
| **A second screenshot set** — iPad, at the **13" Display** size (2064×2752) | This project has picked the wrong ASC screenshot *slot* twice before (6.5" instead of 6.9" for 1.1's upload; nearly the legacy 12.9" instead of the current 13" while researching this release). See §3 — pick the slot by device selector, not by whichever one ASC shows first. |
| **Rule 2205425 gets its first real test** | The Qodo compliance rule that falsely flagged the submission runbook as missing (documented in memory since 1.1) was edited cloud-side on 2026-08-13, but no PR since then has touched a `Releases/submission_*.md` or `release_*.md` file — the only trigger condition observed so far. **This PR does.** Watch for whether it fires; see §1. |

Everything 1.1 already established still holds and does **not** need
repeating:

| Skip | Why |
|---|---|
| §5 of the 1.0 runbook (create the IAP) | `com.jrlabapps.coffeegrams.pro` already exists and is approved. Neither iPad support nor the rating prompt touches IAP. |
| App-level settings (Category, Price, Age Rating, DSA trader) | Persist across versions; 1.2 changes none of them. |
| **App Privacy questionnaire** | 1.2 adds `UserDefaults` (rating-prompt state) and a StoreKit review-request call, both on-device / Apple-framework — no data leaves the device, so "Data Not Collected" still holds. Don't re-open the questionnaire; re-opening it only risks contradicting the hosted privacy policy over nothing. |

---

## Order of operations

1. Merge to `main` with Qodo clean, confirm the version numbers
2. Archive + upload the build
3. Version page (What's New, build, **two screenshot sets**, manual release)
4. Review Submission — one item, same as 1.1

---

## 1. Pre-flight

- [x] **[me]** `MARKETING_VERSION` bumped to **1.2**, `CURRENT_PROJECT_VERSION`
      to **3**, across every build config (verified uniform before the bump —
      6 occurrences each, app target and both test targets):
      ```sh
      grep -c "MARKETING_VERSION = 1.2;" CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj      # 6
      grep -c "CURRENT_PROJECT_VERSION = 3;" CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj  # 6
      ```
- [x] **[me]** All suites green + warning-free, verified on this branch
      (`release/1.2-submission-runbook`) after the version bump: Core
      **61/61** in 5 suites, app `** TEST SUCCEEDED **` on iPhone 17 and iPad
      Pro 13-inch (M5), Release build clean (the only build output is the
      usual `appintentsmetadataprocessor` "no AppIntents.framework" info
      note, not a compiler warning). **Re-run once this branch is merged to
      `main`** — nothing should differ, but that's what "re-run" means, not
      "assume":
      ```sh
      (cd CoffeeGramsCore && swift test)
      (cd CoffeeGrams && COFFEEGRAMS_SWIFTDATA_TESTS=1 xcodebuild test -scheme CoffeeGrams \
         -destination 'platform=iOS Simulator,name=<latest available iPhone>')
      (cd CoffeeGrams && xcodebuild build -scheme CoffeeGrams -configuration Release \
         -destination 'generic/platform=iOS Simulator')
      ```
- [ ] **[you]** **Merge this PR to `main`**, then `git pull` so you archive
      the merged code, not this branch.
- [ ] **[you]** **Watch this PR's Qodo review for rule 2205425.** If it
      fires again, the 2026-08-13 cloud-side edit didn't hold — dismiss the
      finding on the PR (per the existing guidance, don't contorting the
      docs to appease it) and flag it for another look, rather than
      re-editing the same instructions a second time. If it *doesn't* fire,
      that's the confirmation this has been waiting on since 1.1 — note it
      in §5 below either way.
- [ ] **[you]** **Build number must be higher than any build already
      uploaded.** Check TestFlight first — ASC rejects a duplicate only
      *after* the whole archive uploads, wasting the attempt. This is a
      fresh bump (build **3** has never been used), so it should be clean,
      but check anyway.

## 2. Archive → upload

Same as 1.0 §4 and 1.1 §2 — signing, certificate, and App ID are all already
in place, and nothing about iPad support changes this (no new capability,
entitlement, or provisioning needed — `TARGETED_DEVICE_FAMILY` is a build
setting, not a signing concern).

- [ ] **[you]** Xcode → destination **Any iOS Device (arm64)** (you cannot
      archive against a simulator).
- [ ] **[you]** **Product → Archive**.
- [ ] **[you]** Organizer → **Distribute App** → **App Store Connect** →
      **Upload**.
- [ ] **[you]** Wait for the "processing" email, or watch ASC →
      **TestFlight**. A build that never appears has almost always failed
      processing — check email for the reason.
- [ ] **[you]** **TestFlight sanity pass on a real device before
      submitting** — this time on **both an iPhone and an iPad**, since
      iPad is genuinely new hardware for this app, not just a new code path
      tested only in Simulator. Walk: the iPad sidebar + detail pane
      (select a method, confirm the calculator shows beside the list, not
      instead of it), a full French Press brew end to end, and — if you
      happen to have a build already past 7 days old with 3+ brews logged —
      rating a brew 4–5 stars to see whether the system review sheet
      appears (informational only; nothing in this runbook depends on it
      firing, since the API gives no feedback and Simulator never rendered
      it during development either).

## 3. Version page

- [ ] **[you]** ASC → the app → **+ Version or Platform** → **iOS** → enter
      **1.2**.
- [ ] **[you]** **What's New in This Version** — copy from
      [`release_1.2.md`](release_1.2.md#whats-new-draft-copy) (also
      reproduced below).
- [ ] **[you]** **Build** — select the build you just uploaded.
- [ ] **[you]** ⚠️ **iPhone screenshots — re-verified for 1.2, ready to
      upload as-is.** Audited 2026-09-01 against the actual shipped 1.2
      code (not assumed from the 1.1 notes — this project has shipped a
      screenshot miss before): `01-home.png`, `02-calculator.png`,
      `03-guided-timer.png`, and `04-paywall.png` were all recaptured fresh
      and visually confirmed unchanged (iPad support and the rating prompt
      are both no-ops on iPhone's visible UI). `05-brew-log.png` stays as
      the existing asset, same reasoning 1.1 already recorded — the log
      screen didn't meaningfully change again. Nothing here needs
      recapturing before upload; these are current.
- [ ] **[you]** ⚠️ **iPad screenshots — a new set, uploaded for the first
      time. Get the slot right.** In *App Previews and Screenshots*, use
      the device-size selector to pick **13" Display** — do **not** use
      whichever slot ASC happens to show first, and do **not** use the
      legacy **12.9" Display** slot (that one is optional; Apple scales the
      13" set down for it automatically if you skip it, per Apple's current
      screenshot-specifications documentation). This is the same mistake
      class as 1.1's 6.5"-vs-6.9" mixup, on a slot this app has never
      populated before, so there's no existing correct upload to copy the
      pattern from — slow down here specifically.

      Upload all five from `Releases/screenshots/ipad/`, in order:

      | # | File | Screen |
      |---|------|--------|
      | 1 | `01-home.png` | Home — sidebar method list + empty detail pane |
      | 2 | `02-calculator.png` | Calculator for French Press, shown in the detail pane |
      | 3 | `03-guided-timer.png` | Guided brew running, in the detail pane |
      | 4 | `04-paywall.png` | CoffeeGrams Pro paywall |
      | 5 | `05-brew-log.png` | Brew log — one plain entry (see `screenshots/README.md` for why this is plainer than the iPhone set) |

      **Recapturing, if you ever need to redo them** — one command from the
      repo root, same harness as iPhone, parameterized by platform:
      ```sh
      CG_PLATFORM=ipad ./Releases/screenshots/capture.sh                  # all five
      CG_PLATFORM=ipad ./Releases/screenshots/capture.sh 05-brew-log      # just one
      ```
      Full detail on the harness, override variables, and the
      iPhone/iPad asymmetry around `05-brew-log`:
      [`screenshots/README.md`](screenshots/README.md).
- [ ] **[you]** **Description / keywords / promotional text** — unchanged
      from 1.1 unless you want to work "now on iPad" into the description.
- [ ] **[you]** **Version Release** → **Manually release this version**.
- [ ] **[you]** **Review notes** — no demo account needed, same as 1.1; Pro
      is a one-time IAP and the reviewer can exercise French Press without
      it. Worth a one-line note that the app is now universal, so the
      reviewer knows to expect iPad testing.

## 4. Review Submission

- [ ] **[you]** ASC → **Review Submission** → **Add to Review** → the
      **1.2 app version only**.
- [ ] **[you]** ⚠️ **Do not add the IAP as a second item.** Same trap 1.1's
      runbook warned about — re-adding an already-approved IAP is the most
      likely mistake on this step.
- [ ] **[you]** **Submit to App Review**.

## After submitting

- Status goes **Waiting for Review** → **In Review** → **Pending Developer
  Release** (because release is Manual).
- [ ] **[you]** Record the submission date here once you've submitted.
- [ ] **[you]** Record the approval date and any reviewer notes.
- [ ] **[you]** Click **Release This Version** when ready, and record that
      date.
- [ ] **[you]** Update this file to **AS-BUILT** — status banner, dates, and
      §5 below — matching how `submission_1.1.md` was closed out.
- [ ] **[you]** Per the Retrospective Standard, add the 1.2 notes to
      `CoffeeGrams_Summary.md` in the private `Summary` repo, including the
      **AI-agent process review** checkpoint.

---

## 5. As-built notes — what differed

*Fill in once submitted. Carry forward anything from 1.1's own §5 that
proves relevant again (the screenshot-slot mixup mode in particular — see
whether the 13" slot warning above actually prevented a repeat).*

---

## Copy-paste metadata

### What's New in This Version

```
CoffeeGrams now runs great on iPad.

• A new sidebar layout shows your brew methods and the calculator side by side — no more switching back and forth.
• Every screen — calculator, guided timers, brew log, and the paywall — is redesigned to use the extra space instead of stretching thin.
• Under the hood: small reliability and performance improvements.
```

### Unchanged from 1.1 — for reference

- **Support URL:** https://jayreece313.github.io/coffeegrams/support/
- **Privacy Policy URL:** https://jayreece313.github.io/coffeegrams/privacy/
- **Support email:** info@jrlabapps.com
- **Category:** Food & Drink · **Age rating:** 4+
- **IAP:** `com.jrlabapps.coffeegrams.pro` — $4.99, non-consumable, already approved
- **App Privacy:** Data Not Collected (no third-party SDKs, no tracking — still true in 1.2; see the table in §*What makes this different* above for why the new `UserDefaults` use doesn't change this)

---

## Carry these into the next release

Everything 1.1 carried forward still applies (screenshot slot discipline,
archiving from `main` after merge, checking TestFlight before archiving, one
item in the Review Submission, not re-answering App Privacy). Add, once this
one closes out:

- **Whatever §5 above records about rule 2205425** — this is the release
  that either confirms the cloud-side fix held, or tells us it needs another
  look.
- **The 13" screenshot slot**, now that this app has populated it once
  correctly (assuming it went well) — future iPad-affecting releases have a
  known-good pattern to repeat instead of research from scratch.
