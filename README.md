# FamilieKurv v0.5 — request-saving update

## Install
Update only the `index.html` file in your existing GitHub repository and commit it. Vercel should redeploy automatically. Keep `api/prej.js` unchanged; your existing backend connection remains intact.

## What changed
- Product search responses cached in the browser for 24 hours (same device/browser only).
- Basket comparisons use cached batch results and only hit the API on refresh or cache expiry.
- Cached results are labeled with time; older data may be used if requests fail, with an explicit stale warning.
- A manual Refresh prices button forces a new Prej request.
- Shows API calls *initiated from this browser today*; this is NOT your actual Prej remaining allowance, and other users/devices count separately.
- Clear saved search cache button.

## Limitations
No cross-device shared cache: that requires persistent storage, e.g. Vercel KV/Redis and authentication. This version does not install a shared backend cache. Do not commit any API key to GitHub. The Prej account daily quota cannot be inferred from local counts. API key is kept in memory per browser tab. The app is suitable for a personal prototype, not public production use.
