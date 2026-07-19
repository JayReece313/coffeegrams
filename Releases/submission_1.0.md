# CoffeeGrams — v1.0 App Store Submission Runbook

Everything needed to submit v1.0. Follow the steps in order. Copy-paste metadata
is at the bottom. Anything marked **[you]** happens in App Store Connect (ASC) or
Xcode on your Mac; there's no code left to write.

Bundle ID: `com.jrlabs.CoffeeGrams` · IAP: `com.jrlabs.coffeegrams.pro` ($4.99,
non-consumable) · Category: **Food & Drink** · Age rating: **4+**

---

## Order of operations

1. Prerequisites (agreement, URLs, support email)
2. Xcode: signing team + archive
3. ASC: create the app record
4. ASC: create the in-app purchase
5. ASC: metadata + screenshots + privacy label + age rating
6. Upload the build, attach it + the IAP, submit for review

---

## 1. Prerequisites **[you]**

- [ ] **Paid Applications Agreement** — ASC → **Business** → sign it, and enter
      **banking + tax** info. *Until this is active, in-app purchases don't work
      and the app can't be submitted with an IAP.*
- [ ] **Support email** — pick one you'll monitor, then replace
      `[replace with your support email]` in `docs/privacy-policy.md` and
      `docs/support.md`.
- [x] **Docs hosted** (GitHub Pages, live):
      - Privacy Policy: **https://jayreece313.github.io/coffeegrams/privacy/**
      - Support: **https://jayreece313.github.io/coffeegrams/support/**

## 2. Xcode — signing & archive **[you]**

1. Open `CoffeeGrams.xcodeproj`. Select the **CoffeeGrams** target →
   **Signing & Capabilities** → check **Automatically manage signing** → choose
   your **Team**.
2. Set the run destination to **Any iOS Device (arm64)** (not a simulator).
3. **Product → Archive.** When it finishes, the **Organizer** opens.
4. Keep the Organizer open — you'll upload after the ASC record exists (step 6).

*Version is already `1.0` (build `1`).*

## 3. App Store Connect — create the app **[you]**

ASC → **Apps → +** → **New App**:
- Platform: **iOS**
- Name: **CoffeeGrams** (must be unique on the store — if taken, try
  "CoffeeGrams: Brew Calculator")
- Primary language: **English (U.S.)**
- Bundle ID: **com.jrlabs.CoffeeGrams**
- SKU: anything unique, e.g. `coffeegrams-1`
- User access: Full

## 4. App Store Connect — create the in-app purchase **[you]**

In the app → **Monetization → In-App Purchases → +**:
- Type: **Non-Consumable**
- Reference Name: `CoffeeGrams Pro`
- Product ID: **`com.jrlabs.coffeegrams.pro`** (must match exactly)
- Price: **$4.99** (Tier)
- Localization (English): Display Name `CoffeeGrams Pro`, Description
  `Unlock all brewing methods and features — one-time purchase.`
- Add a review screenshot of the paywall (any 6.9"/6.7" paywall screenshot).
- **Important:** you'll attach this IAP to the version in step 6 so it's reviewed
  *with* the app. (A first IAP not submitted with a build stays "Waiting for
  Review" forever.)

## 5. Metadata, screenshots, privacy, age rating **[you]**

In the **1.0 Prepare for Submission** page:

- **Promotional Text / Description / Keywords** — paste from the bottom of this doc.
- **Privacy Policy URL** — `https://jayreece313.github.io/coffeegrams/privacy/`
- **Support URL** — `https://jayreece313.github.io/coffeegrams/support/`
- **Category:** Food & Drink (primary). Secondary optional (Lifestyle).
- **Screenshots** — see the plan below.
- **App Privacy** (Data → App Privacy):
  - "Do you collect data from this app?" → **No** → results in **Data Not Collected**.
- **Age Rating** — complete the questionnaire; all "None" → **4+**.
- **Copyright:** `© 2026 JR Labs LLC`

### Screenshots — ✅ already generated
Five 6.9" screenshots (1320 × 2868, iPhone 17 Pro Max, clean 9:41 status bar) are
in **`Releases/screenshots/`** — just drag them into ASC in order (see that
folder's README):
1. `01-home.png` — branded list with logo + PRO methods
2. `02-calculator.png` — French Press dose → water readout
3. `03-guided-timer.png` — running "RUNNING" countdown
4. `04-paywall.png` — "Unlock Everything · $4.99" (also use as the IAP review screenshot)
5. `05-brew-log.png` — rated brews with notes

Upload under the **6.9"** size. (Raw device frames, no marketing overlays — Apple
accepts these.)

## 6. Upload, attach, submit **[you]**

1. In Xcode **Organizer** → select the archive → **Distribute App** →
   **App Store Connect** → **Upload**. Wait for "processing" to finish in ASC
   (a few–30 min).
2. In ASC 1.0 page → **Build** → select the uploaded build.
3. **Add the in-app purchase to this version** (there's an "In-App Purchases"
   section on the version page — include `CoffeeGrams Pro`).
4. Paste the **Review Notes** (below).
5. **Add for Review → Submit.**

---

## Copy-paste metadata

**App Name (≤30):**
```
CoffeeGrams
```

**Subtitle (≤30):**
```
Coffee brew calculator & timer
```

**Promotional Text (≤170):**
```
Dial in the perfect cup. Dose-and-ratio calculators and guided timers for V60, Chemex, AeroPress, French Press, Cold Brew, and Espresso — no subscription.
```

**Keywords (≤100, comma-separated):**
```
coffee,brew,pour over,v60,chemex,aeropress,french press,espresso,cold brew,ratio,timer,barista,scale,recipe
```

**Description:**
```
CoffeeGrams is a precise, beautifully simple brewing companion. Dial in the perfect cup with dose-and-ratio calculators and guided, step-by-step timers.

FREE
• French Press — full calculator, guided timer, and brew log.

COFFEEGRAMS PRO — one-time purchase, no subscription
Unlock the other five methods:
• V60 & Chemex — pour-over with a bloom and timed pulse pours
• AeroPress — with Hoffmann and Classic Strong presets
• Cold Brew — concentrate or ready-to-drink, with a steep reminder
• Espresso — target yield plus a shot timer with a 25–30s window

FEATURES
• Calculate either way: dose → water, or water → dose, with an adjustable ratio slider
• Guided timers walk you through every pour, bloom, and steep
• A brew log — rate your cups and keep tasting notes
• Reminders so cold brew and French press never over-steep
• Warm, clean design with full Dark Mode and Dynamic Type support

PRIVACY
CoffeeGrams collects no data. No accounts, no tracking, no ads. Your brew log stays on your device.

Brew better coffee, by the gram.
```

**What's New (v1.0):**
```
The first release of CoffeeGrams. Brew better coffee with precise calculators and guided timers for six methods. Thanks for trying it — we'd love your feedback.
```

**Review Notes:**
```
No account or login is required.

Free vs. paid: French Press is fully free (calculator, guided timer, and brew log). The other five methods (V60, Chemex, AeroPress, Cold Brew, Espresso) unlock together via a single one-time non-consumable in-app purchase, "CoffeeGrams Pro" (com.jrlabs.coffeegrams.pro, $4.99).

To test the purchase: tap any method showing a "PRO" lock (e.g., V60) to open the paywall, then tap "Unlock Everything." "Restore Purchase" is available on the same screen.

The app makes no network calls and collects no data.
```

---

## Pre-flight reminders (from our audit)
- Screenshots/description/price must match the app exactly.
- The IAP must be submitted **with** this build (step 6.3).
- Do a **real-device** pass before submitting (StoreKit sandbox, haptics, VoiceOver).
- Export compliance is already handled in the app (`ITSAppUsesNonExemptEncryption = NO`).
- App is **iPhone-only, portrait** for v1 (iPad is planned for 1.1).
