# CoffeeGrams — v1.1 App Store Submission Runbook

> **Status: NOT YET SUBMITTED.** This is the plan; update it to AS-BUILT (with
> the real dates and anything that differed) the moment 1.1 goes in, the way
> [`submission_1.0.md`](submission_1.0.md) records the 1.0 flow.

`MARKETING_VERSION` **1.1** · `CURRENT_PROJECT_VERSION` **2** · Bundle ID
`com.jrlabapps.CoffeeGrams` · **iPhone-only, portrait** (unchanged — iPad is
1.2, see [`roadmap_future.md`](roadmap_future.md)).

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
| Screenshots — **most of them** | 1.1 is iPhone-only and portrait, so the existing 1290×2796 set still matches. **One exception: the guided-brew shot must be retaken — see §3.** |

---

## Order of operations

1. Merge to `main` with Qodo clean, confirm the version numbers
2. Archive + upload the build
3. Version page (What's New, build, **new guided-brew screenshot**, manual release)
4. Review Submission — **one item this time**, not two

---

## 1. Pre-flight **[you]**

- [ ] **PR #2 merged to `main`** with Qodo findings at zero.
- [ ] **`git pull` on `main`** so you archive the merged code, not the branch.
- [ ] **Version numbers** — confirm in Xcode (target → General) or:
      ```sh
      grep -m1 MARKETING_VERSION CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj      # 1.1
      grep -m1 CURRENT_PROJECT_VERSION CoffeeGrams/CoffeeGrams.xcodeproj/project.pbxproj # 2
      ```
      **Build number must be higher than any build already uploaded** — App Store
      Connect rejects a duplicate at upload, after the whole archive.
- [ ] **All suites green + warning-free**, from the repo root:
      ```sh
      (cd CoffeeGramsCore && swift test)
      (cd CoffeeGrams && xcodebuild test -scheme CoffeeGrams \
         -destination 'platform=iOS Simulator,name=<latest available iPhone>')
      (cd CoffeeGrams && xcodebuild build -scheme CoffeeGrams -configuration Release \
         -destination 'generic/platform=iOS Simulator')
      ```

## 2. Archive → upload **[you]**

Same as 1.0 §4 — signing, certificate, and App ID are all already in place.

- [ ] Xcode → destination **Any iOS Device (arm64)** (you cannot archive against a simulator).
- [ ] **Product → Archive**.
- [ ] Organizer → **Distribute App** → **App Store Connect** → **Upload**.
- [ ] Wait for the "processing" email, or watch ASC → **TestFlight**. A build that
      never appears has almost always failed processing — check email for the reason.
- [ ] **TestFlight sanity pass** on a real device before submitting. For 1.1
      specifically, walk one full French Press brew: the keypad **Done** button,
      the **Set Up Brew → Start Timer** labels, the count-up on the plunge, and
      **Save to Log** showing planned vs actual.

## 3. Version page **[you]**

- [ ] ASC → the app → **+ Version or Platform** → **iOS** → enter **1.1**.
- [ ] **What's New in This Version** — copy from the block below. Required for an
      update; this is the one field 1.0 didn't have.
- [ ] **Build** — select the build you just uploaded.
- [ ] ⚠️ **Screenshots — the guided-brew shot MUST be replaced. This is not
      optional and not a judgement call.** 1.1 redesigned that screen, so the
      one currently on the listing shows a UI the app no longer has:

      | On the current screenshot (1.0) | In the shipped 1.1 build |
      |---|---|
      | No total-elapsed readout | A "TOTAL m:ss" count-up under the step timer |
      | Countdown only | The final step counts **up** as `+m:ss` |
      | Pause / Skip buttons | Pause/Resume ⇄ End Brew, with "Skip step" demoted to tertiary |

      A listing screenshot that doesn't match the built app is a documented
      rejection reason, and it's the one asset 1.1 genuinely invalidated.

      **To capture it:** run 1.1 on a simulator whose screen is 1290×2796
      (iPhone 16/17 Pro Max class), open **French Press** — the free method, so
      no purchase needed — tap **Set Up Brew → Start Timer**, let it reach a
      step that shows the new controls, then `⌘S` in Simulator (or
      `xcrun simctl io booted screenshot brew.png`). Verify the result is
      exactly 1290×2796 before uploading; ASC rejects off-size images.

- [ ] **Remaining screenshots** — leave as-is. 1.1 stayed iPhone-only and
      portrait, so the rest of the set is still accurate. Don't redo work.
- [ ] **Description / keywords / promotional text** — unchanged from 1.0 unless
      you want to work the timer improvements into the description.
- [ ] **Version Release** → **Manually release this version**.
- [ ] **Review notes** — no demo account needed; Pro is a one-time IAP and the
      reviewer can exercise French Press without it. If they need Pro, say so here.

## 4. Review Submission **[you]**

- [ ] ASC → **Review Submission** → **Add to Review** → the **1.1 app version only**.
- [ ] ⚠️ **Do not add the IAP as a second item.** That was a 1.0 requirement
      because it was the app's *first* IAP. Re-adding an already-approved IAP
      here is the most likely mistake on this submission.
- [ ] **Submit to App Review**.

## After submitting

- Status goes **Waiting for Review** → **In Review** → **Pending Developer Release**
  (because release is Manual).
- Click **Release This Version** when you're ready.
- [ ] Update this file to **AS-BUILT** with the submission date and any deviation.
- [ ] Per the Retrospective Standard, add the 1.1 notes to `CoffeeGrams_Summary.md`
      in the private `Summary` repo — including the **AI-agent process review**
      checkpoint.

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

## Pre-flight reminders

- **Retake the guided-brew screenshot.** The listing's current one shows the 1.0
  timer, which 1.1 replaced. Easiest step to skip, and a rejection reason.
- **Archive from `main` after the merge**, not from the release branch.
- **Bump the build number** if you ever upload a second 1.1 build — ASC rejects duplicates.
- **One item in the Review Submission**, not two.
- **Don't re-answer App Privacy.** 1.1 adds no data collection; re-opening the
  questionnaire risks answering it differently by accident and contradicting the
  privacy policy already hosted.
