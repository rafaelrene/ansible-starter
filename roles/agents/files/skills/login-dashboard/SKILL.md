---
name: login-dashboard
description: Use when a task needs authenticated access to GroupSolver Dashboard in T3Code’s browser, including local, development, and production environments.
disable-model-invocation: false
---

# Sign in to Dashboard

Establish a working Dashboard session in T3Code’s existing Default browser
profile. Reuse valid authentication; open Microsoft SAML sign-in when needed.

Default account: <rrafael@groupsolver.com>. Follow an explicitly requested account
instead.

## Identify the target

Use the URL or backend requested in the task. Otherwise inspect the running
dashboard and preserve its environment. Ask only when the target is unclear.

Use T3Code’s browser tools. Reuse the relevant tab and pass its tabId explicitly.
Keep the existing Default profile. If T3Code’s browser tools are unavailable,
report that limitation.

Determine the frontend origin, user API, auth API, and Firebase project from
the running app’s configuration or network requests. A localhost frontend can
use local, development, or production APIs. Its URL alone does not identify
the backend.

For this repository, the usual commands are:

| Command | Backend | Firebase project |
| --- | --- | --- |
| npm start | Remote development | groupsolver-dev |
| npm run local:prod | Remote production | groupsolver-prod |
| npm run local:backend | localhost:8090 | groupsolver-dev |
| npm run local:backend:prod | localhost:8090 | groupsolver-prod |

Treat these as orientation; verify the running configuration. Do not switch
or restart servers as part of this skill.

## Check the existing session

Send this read-only query to the selected user API from the dashboard tab,
using POST, JSON, and credentials: 'include':

    query SessionCheck { user { idUser } }

Require a successful response containing data.user.idUser without GraphQL
errors. A cookie on disk, a future expiry, or the frontend’s logged-in flag
does not prove the backend accepts the session.

If the session works but the app remains on its login screen, restore its
routing flag:

    localStorage.setItem('api.isLoggedIn', 'true')

Then navigate to the requested page, or /home when no page was requested.

A refused connection or server error is not a reason to log in again. Report
the backend failure. For an authentication failure, continue below.

## Reuse Firebase authentication

Before establishing a new backend session, tell the user that login can
invalidate another session for the same account. Proceed without requesting
additional confirmation.

Local and remote backends can share account data. Their login flow rotates
one account token, so separate saved cookies do not guarantee simultaneous
sessions. Authenticate only the requested environment.

On the login page, this app exposes Firebase as window.firebase. Allow its
authentication state to initialize before treating currentUser as absent.
Wait up to 10 seconds using onAuthStateChanged, then unsubscribe.

If the initialized Firebase project and signed-in account match the target,
try one backend login using currentUser.getIdToken() and:

    mutation LoginByFirebaseToken($sessionToken: String!) {
      user {
        loginByFirebaseToken(sessionToken: $sessionToken) {
          campaign
          campaignReferrer
        }
      }
    }

Send the mutation to the selected auth API with credentials: 'include'.
Keep the Firebase token inside the page evaluation. Return only success or
sanitized error information; never print or persist tokens.

Verify the backend session with SessionCheck before restoring the routing
flag. If Firebase authentication is absent or expired, continue to Microsoft
sign-in. Stop on backend or configuration errors instead of retrying login.

If the running app no longer exposes this Firebase integration, use its
normal login UI rather than extracting credentials from browser storage.

## Open Microsoft sign-in

Inspect the login page before interacting. Fill the intended email address.

T3Code versions have rejected Firebase’s empty popup URL, navigating the
dashboard tab to about:blank instead. Before submitting the login form, apply
this temporary adjustment with preview_evaluate in the same tab:

    (() => {
      if (window.__dashboardLoginRestoreOpen) return

      const originalOpen = window.open

      function patchedOpen(url, ...args) {
        const value = String(url ?? '')
        const targetUrl =
          value === '' || value === 'about:blank'
            ? `${location.origin}/favicon.ico`
            : url

        return originalOpen.call(this, targetUrl, ...args)
      }

      window.open = patchedOpen
      window.__dashboardLoginRestoreOpen = () => {
        if (window.open === patchedOpen) window.open = originalOpen
        delete window.__dashboardLoginRestoreOpen
      }
    })()

This gives Firebase a same-origin HTTP popup that it can navigate to Microsoft.
It does not change repository files, T3Code binaries, or authentication policy.

Submit Continue using the browser click tool. Do not reload between installing
the adjustment and submitting; navigation removes the adjustment.

Tell the user to complete Microsoft sign-in, including password and MFA,
directly in the popup. Never request those credentials in chat. Wait for their
completion or cancellation before continuing.

If no popup appears, inspect the actual tab state and reported error. After
correcting an identified cause, retry once. If it still fails, stop and report
the evidence rather than repeatedly prompting the user.

## Verify and finish

After login:

1. Confirm SessionCheck succeeds against the intended backend.
2. Restore the routing flag only after that check succeeds, if necessary.
3. Open the requested page and verify authenticated content actually loads.
4. Reload once and confirm it remains authenticated.
5. Restore window.open if the temporary adjustment is still present:

       window.__dashboardLoginRestoreOpen?.()

Also restore the adjustment on cancellation or failure when the tab is still
available.

Report the frontend URL, backend environment, and verification performed.
Distinguish login success from a page that fails to load its data.

Do not promise permanent login or restart persistence from a fresh-tab test.
Report a restart as verified only when an actual restart was tested.

This skill handles authentication only. Continue the original task afterward
within its existing scope.
