[README.md](https://github.com/user-attachments/files/33491171/README.md)
# FamilieKurv v0.3 - price connection fix

This is a **deployable website** (not a standalone HTML file). It needs a small serverless backend because a browser may block cross-origin Prej API requests.

## Beginner-friendly setup (Vercel + GitHub)

1. Create a new private GitHub repository named `familiekurv`.
2. Upload **both** `index.html` and the `api` folder (including `api/prej.js`) from this zip into the repository root.
3. Sign in at https://vercel.com/ with GitHub and choose **Add New > Project**.
4. Import the `familiekurv` repository. Framework preset: **Other**. Leave root directory as `./` and deploy.
5. Open your new HTTPS `*.vercel.app` link on your phone. Enter your personal Prej key and tap **Connect**.

Do NOT open `index.html` directly from your computer: that bypasses the backend and cannot connect.

## Security and limitations

- The personal Prej key is entered in the app, sent to your own Vercel backend on each request via HTTPS, and forwarded to Prej. It is not stored server-side or in localStorage. It remains in browser tab memory until refreshed.
- Use a **private** GitHub repository. Never paste your key in code or into GitHub.
- Do not publicly share a deployed application while the backend remains unauthenticated; for family use, add access control and rate limiting before rollout.
- This prototype is not yet cross-device synchronized and has not been authenticated against a real Prej key.
- A Prej personal key is subject to the provider's current usage terms and quotas.
