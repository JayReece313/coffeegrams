# CoffeeGrams — v1.0 App Store Submission Runbook (AS-BUILT)

Reflects the **actual** App Store Connect + Xcode flow used to submit v1.0 on
**2026-07-19** (both the app version and the IAP went in together — "2 Items
Submitted"). Copy-paste metadata is at the bottom.

> **Status:** SUBMITTED — awaiting App Review. Release is set to **Manual**, so
> after approval it sits at "Pending Developer Release" until you click Release.

Bundle ID: `com.jrlabapps.CoffeeGrams` · IAP: `com.jrlabapps.coffeegrams.pro`
($4.99, non-consumable) · Category: **Food & Drink** · Age rating: **4+** ·
iPhone-only, portrait.

> ⚠️ **Key change from the "classic" flow:** the IAP is **no longer attached on
> the version page**. App Store Connect now uses a **single Review Submission**
> where you add the **app version AND the in-app purchase as two items**, then
> submit them together. A *first* IAP must ride along with an app version. See §8.

---

## Order of operations

1. Prerequisites (Paid Apps agreement Active, hosted URLs, support email)
2. Xcode signing (Apple ID, team, **register App ID**, **register a device**, distribution cert)
3. Create the app **record in the browser first** (so Xcode uploads into it)
4. Archive + upload the build (new "Distribute" = upload)
5. Create the in-app purchase (mind the review-screenshot size)
6. App-level required settings (Category, Price, App Privacy, Age Rating, DSA trader)
7. Version page (metadata, screenshots, build, review notes, manual release)
8. **Review Submission**: add app + IAP as 2 items → Submit

---

## 1. Prerequisites **[you]**

- [x] **Paid Applications Agreement** — ASC → **Business** → sign it + banking + tax.
      Must show **Active** before the IAP can be submitted.
- [x] **Support email** — `info@jrlabapps.com` (in the docs).
- [x] **Docs hosted** (GitHub Pages, live):
      - Privacy Policy: **https://jayreece313.github.io/coffeegrams/privacy/**
      - Support: **https://jayreece313.github.io/coffeegrams/support/**

## 2. Xcode — signing & archive **[you]**

Automatic signing needs several things set up on the developer portal first.
Do these in order or Archive fails.

1. **Add your Apple ID to Xcode:** Xcode → **Settings ⌘, → Accounts → ➕ → Apple
   ID** → sign in with the **JR Labs LLC account-holder** Apple ID. The team
   **JR Labs LLC** then appears.
2. **Select the team:** project → **CoffeeGrams** target → **Signing &
   Capabilities** → *Automatically manage signing* ✔ → **Team = JR Labs LLC**.
   Bundle ID must read **`com.jrlabapps.CoffeeGrams`**.
3. **Register the App ID (identifier)** — automatic signing often fails to do
   this. Do it manually: developer.apple.com/account → **Identifiers → ➕ → App
   IDs → App → Explicit** → `com.jrlabapps.CoffeeGrams`. *(Bundle IDs are
   globally unique across all of Apple; the original `com.jrlabs.*` was owned by
   another developer — that's why we renamed to `com.jrlabapps.*`, matching the
   jrlabapps.com domain.)*
4. **Register a device** — automatic signing insists on creating a **Development**
   provisioning profile, which requires **≥1 registered device**. With zero
   devices, Archive dies instantly ("your team has no devices from which to
   generate a provisioning profile"). Fix: **Window → Devices and Simulators**,
   select your connected iPhone, copy its **Identifier (UDID)**, then
   developer.apple.com → **Devices → ➕** → paste the UDID → Register.
5. **Create the Apple Distribution certificate** — Settings → Accounts →
   **Manage Certificates… → ➕ → Apple Distribution**.
6. **Archive:** destination **Any iOS Device (arm64)** → **Product → Archive** →
   the **Organizer** opens.

> The red "iOS App **Development** provisioning profile" error is only about
> *running on a phone*. It does **not** block archiving once a device is
> registered and a distribution cert exists — the archive uses a **Distribution**
> profile (created automatically, needs no device).

## 3. Create the app record — in the browser, FIRST **[you]**

Do this **before** uploading, so Xcode uploads *into* it (matched by bundle ID).
Don't let Xcode create the record during archive — it defaults to the taken name
"CoffeeGrams" and gets stuck asking for a company name.

ASC → **Apps → ➕ → New App**:
- Platform **iOS** · Name **CoffeeGrams: Brew Calculator** *("CoffeeGrams" alone
  is taken — too similar to an existing "Coffeegram" app; the home-screen name
  still shows "CoffeeGrams")*
- Primary language **English (U.S.)**
- Bundle ID **com.jrlabapps.CoffeeGrams** *(only appears here once the App ID is
  registered — see §2.3; refresh the page if it's blank)*
- SKU `coffeegrams-1` · User Access **Full**

## 4. Archive → upload the build **[you]**

1. Organizer → select the archive → **Distribute App** → **App Store Connect**.
2. Click **Distribute**. *(New Xcode merged the old "Upload"/"Export" steps —
   **"Distribute" IS the upload**. The granular options now live under "Custom".)*
   Let it auto-manage signing (creates the App Store distribution profile).
3. Wait for **"Uploaded"**, then ~10–30 min of **"Processing"** in ASC before the
   build is selectable on the version page.

## 5. Create the in-app purchase **[you]**

**Monetization → In-App Purchases → ➕:**
- Type **Non-Consumable** · Reference Name `CoffeeGrams Pro`
- Product ID **`com.jrlabapps.coffeegrams.pro`** (must match the app code exactly)
- **Price:** USD **4.99**
- **Localization (English):** Display Name `CoffeeGrams Pro`, Description
  `Unlock all brewing methods and features — one-time purchase.`
- **Availability:** all countries/regions
- **Review screenshot:** ⚠️ the IAP uploader **rejects 1320×2868** (and odd
  sizes). Use **`Releases/screenshots/iap-review.png`** (**1242×2688**, 6.5").
- Status should reach **"Ready to Submit."** *(It won't submit on its own — it
  gets added to the app's Review Submission in §8.)*

## 6. App-level required settings **[you]**

These live on **separate left-sidebar pages** (not the version page). ASC blocks
submission until all are set — this is where the "Unable to Add for Review"
errors come from.

- **App Information:**
  - **Primary Category = Food & Drink** (secondary optional: Lifestyle)
  - **Subtitle** = `Dial in every cup by the gram`
  - **Content Rights** = **"does not contain third-party content"** (No — SF
    Symbols/your own art don't count as third-party)
- **Pricing and Availability:** **Price = Free** (the app is free; only the Pro
  IAP costs money) · Availability = all countries
- **App Privacy:**
  - **Privacy Policy URL** = `https://jayreece313.github.io/coffeegrams/privacy/`
  - Data question → **"No, we don't collect data"** → **PUBLISH** it (must click
    Publish, or it stays flagged) → shows **"Data Not Collected"**
- **Age Rating** → questionnaire all **None/No** (incl. new *In-App Controls*:
  Parental Controls **No**, Age Assurance **No**) → **4+**
- **App Store Regulations & Permits → Digital Services Act (DSA):** declare as a
  **Trader** (you sell commercially via JR Labs LLC + a paid IAP) and provide
  **public** business contact info (name / address / email / phone). *Declaring
  "not a trader" removes the app from all EU storefronts.* Use a business /
  registered-agent address, not a private home address.

## 7. Version page (1.0) **[you]**

- **Description / Promotional Text / Keywords / Subtitle** — paste from below.
- **Screenshots** — drag `Releases/screenshots/01`–`05` into the **6.9" Display**
  slot. Use **1290×2796** (some uploaders reject the newer 1320×2868); 6.9"
  auto-scales to smaller iPhones.
- **Support URL** `…/support/` · **Marketing URL** optional (`…/coffeegrams/`)
- **Copyright** `2026 JR Labs LLC` · **Routing file / iMessage screenshots** —
  leave blank (N/A)
- **Sign-In Information** — leave **"Sign-in required" unchecked** (no login)
- **Build** — attach the processed build (§4) once it's out of "Processing"
- **App Store Version Release** — **Manually release this version** (you press
  Release after approval)
- **Review Notes** — paste from below (explains free vs. paid + how to test the IAP)

## 8. Review Submission — add app + IAP as TWO items **[you]**

The IAP is added *here*, not on the version page:

1. On the version, click **Add for Review**.
2. In the **Review Submission**, make sure it includes **both**:
   ☑️ CoffeeGrams (iOS) **1.0** and ☑️ **CoffeeGrams Pro** (in-app purchase).
   *(Or click **Add for Review** on the IAP and include the version.)*
3. **Submit for Review** → aim for **"2 Items Submitted."**

**Recovery — if you accidentally submit the version alone ("1 Item"):** the IAP
can't be added by itself ("add an app version for the selected platform"). Go to
the **1.0 version → Remove from Review** (safe, no penalty, returns it to
editable), then **Add for Review** again and include **both** items.

> The IAP only becomes addable once the **Paid Apps Agreement is Active** and the
> IAP is **Ready to Submit**.

## After submitting

Waiting for Review → In Review → **Pending Developer Release** (because release is
Manual) → **click Release** to go live. If rejected, Apple explains in the
**Resolution Center**; reply or fix + resubmit (no penalty).

---

## Copy-paste metadata

**App Name (≤30):**
```
CoffeeGrams: Brew Calculator
```
*(28/30. Home-screen name remains "CoffeeGrams" — set by the app, not this field.)*

**Subtitle (≤30):**
```
Dial in every cup by the gram
```
*(29/30. Alt if you'd rather have more search keywords here: "Ratios & guided brew timers".)*

**Promotional Text (≤170):**
```
Dial in the perfect cup. Dose-and-ratio calculators and guided timers for V60, Chemex, AeroPress, French Press, Cold Brew, and Espresso — no subscription.
```

**Keywords (≤100, comma-separated):**
```
coffee,pour over,v60,chemex,aeropress,french press,espresso,cold brew,ratio,timer,barista,scale
```
*(95/100. Dropped "brew"/"calculator" — they're already in the app name, and Apple
indexes name words automatically, so repeating them wastes keyword space.)*

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

Free vs. paid: French Press is fully free (calculator, guided timer, and brew log). The other five methods (V60, Chemex, AeroPress, Cold Brew, Espresso) unlock together via a single one-time non-consumable in-app purchase, "CoffeeGrams Pro" (com.jrlabapps.coffeegrams.pro, $4.99).

To test the purchase: tap any method showing a "PRO" lock (e.g., V60) to open the paywall, then tap "Unlock Everything." "Restore Purchase" is available on the same screen.

The app makes no network calls and collects no data.
```

---

## Pre-flight reminders (from our audit)
- Screenshots/description/price must match the app exactly.
- The IAP must be submitted **with** the app version as one Review Submission (§8).
- App-store screenshots **1290×2796**; IAP review screenshot **1242×2688**.
- Do a **real-device** pass (StoreKit sandbox, haptics, VoiceOver) before releasing.
- Export compliance is already handled (`ITSAppUsesNonExemptEncryption = NO`).
- App is **iPhone-only, portrait** for v1 (iPad is planned for 1.1).
