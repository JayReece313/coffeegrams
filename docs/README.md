# CoffeeGrams — Public docs (Privacy Policy & Support)

App Store Connect **requires** a Privacy Policy URL and a Support URL. These two
Markdown pages provide that content; you just need to host them somewhere with a
public URL.

- `privacy-policy.md` — required **Privacy Policy URL**
- `support.md` — required **Support URL**

## Before hosting

Replace **`[replace with your support email]`** in both files with a real
address you'll monitor (a dedicated alias like `support@yourdomain` is nicer than
a personal inbox, but any monitored email is accepted).

## Easiest way to host (free): GitHub Pages

1. In the `coffeegrams` repo on GitHub: **Settings → Pages**.
2. Set **Source** to the `main` branch and folder to `/docs` (or `/root`), Save.
3. GitHub serves them at, e.g.,
   `https://<user>.github.io/coffeegrams/privacy-policy` and `.../support`.
   (GitHub renders `.md` as a page; or add a tiny `index.html` if you prefer.)

Any static host works too (Netlify, Cloudflare Pages, a Notion public page, a
Google Site, etc.) — paste in the same content and use those URLs in App Store
Connect.
