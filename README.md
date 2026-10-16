# FamilieKurv v0.9 — private QR member approval

## Before deployment (IMPORTANT)
1. Back up your Supabase database if you have valuable family-list data.
2. In Supabase **Authentication → Providers → Anonymous Sign-Ins**, enable anonymous sign-ins. This allows your family members to use a persistent device session without email. The family admin should continue signing in with the existing email account.
3. In Supabase **SQL Editor**, run `supabase-v09.sql` ONCE. This retains existing families and shopping lists. It creates short-lived, single-use invitations, approval requests, admin functions and disables the previous `join_family(code)` instant-join function. If any query fails, do not deploy the new HTML until resolved.
4. In GitHub, replace your existing `index.html` with the v0.9 `index.html`. **Keep the existing `api/prej.js` and `api/config.js` unchanged**, and keep the environment variables in Vercel. Commit and let Vercel deploy.
5. On the deployed site, hard-refresh. Sign in as the **original creator** of the family, open Family sharing, and use **Create QR invitation**.
6. Scan from another phone. Tap **Continue on this device (no email)**; enter a name, and request approval. The admin taps **Refresh requests & members → Approve**. The new member may wait up to ~12 seconds or refresh after approval.
7. Click **Remove** on a non-admin member to revoke their database membership. Row-level security blocks subsequent family-list reads/writes with that device's old token. Note that a previously cached list may still remain on the device until its local browser storage is cleared; remote access is denied. An administrator cannot remove themselves.

## Security / limitations
- This is a first prototype, not independently security-audited. Test approval and removal with two devices before relying on it.
- The QR is an invitation, **not** a login token; random 48-character hex code, hashed in the database, 10-minute expiry, one-time use, requires admin approval.
- Anyone who sees an unexpired QR may submit *one request* first; admin must approve only recognized family members. Generate a new QR if it was used by an unknown person.
- Anonymous device sessions may be lost if browser storage is cleared or private browsing is used. Removing a member prevents database access but cannot wipe items previously downloaded onto their device. Reinstalls require reapproval.
- Existing email family sign-in remains for admin and earlier members.
- Uses QRCode.js from a CDN for drawing the QR; generating the QR does not send the invitation URL to the QR service. Avoid screenshots containing your live QR.
- This update does NOT centralize Prej data or change pricing logic.
- The existing `family_lists` implementation uses last-write-wins updates and might lose simultaneous edits.
