# Pushing pop-up messages to players (Firebase Remote Config)

You can show a pop-up to players without releasing a new app version. You edit one Remote Config parameter in
the Firebase console and publish it. No code changes and no new app release are needed for each message.

## How it works
- The parameter is named `announcement` and holds a small piece of JSON (below). Empty means "no message".
- The app reads it when the home screen opens and when the app returns from the background, and shows it as a
  dialog if it applies to that player. Code: `lib/announcements.dart`.
- By default a message shows **once per device**. The app remembers each message's `id`; change the `id` and
  everyone sees the new message once.
- A broken, empty or incomplete value shows nothing and never crashes the app.

## Publishing a message
1. Firebase console > your project > **Run > Remote Config**.
2. First time only: **Add parameter**, name `announcement`, type **String**, default value empty.
3. Set the value to JSON like this, then **Publish changes**:

```json
{
  "id": "2026-12-winter-event",
  "title": "Winter event",
  "message": "New scavenger hunt questions are live. Thanks for playing!",
  "button": "Got it"
}
```

### Fields
| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique name for this message. **Use a new id for every new message**, or players who saw the old one will not see it. |
| `message` | yes | The body text. |
| `title` | no | Heading. Left out = no heading. |
| `button` | no | Button label. Default `OK`. |
| `audience` | no | `all` (default), `guests`, or `registered` (signed-in accounts). |
| `platform` | no | `all` (default), `android`, or `ios`. |
| `show` | no | `once` (default) or `always` (every time the home screen shows, until `end`). |
| `start`, `end` | no | When it may appear, as UTC like `2026-11-20T00:00:00Z`. Use `end` with `show: "always"` so it stops. |

JSON must be valid: double quotes, no trailing commas. Paste it into a JSON validator first if unsure. Use `\n`
for a line break inside `message`.

## Taking a message down
Clear the parameter value (or set `end` to a past time) and publish. Players who already saw a `once` message
are unaffected.

## When players see it
- Real users: the app asks for new values **at most once an hour**, so a message can take up to an hour after
  they next open the app. Players who are offline see it after they next connect.
- Debug builds (running from your computer) fetch every time, so you can test immediately: publish, then close
  and reopen the app.
- To re-test the same message, change its `id`, or clear the app's data.

## Targeting and testing safely
- Remote Config has its own targeting. In the console, use **Add new > Conditional value** to give a different
  `announcement` to a subset (percentage of users, app version, country, platform, or a user property). This
  also works for A/B tests.
- To test on yourself first, create a condition for one device by its Firebase installation ID, or use
  `platform` / `audience` to narrow it, publish, and check it, then widen it.
- Remote Config values are readable by anyone who has the app. **Never put anything private in a message.**

## Limits to know
- It is a text dialog with one button. There is no link, image or button that opens a page yet.
- One message at a time. If you publish a new `id` before someone saw the old one, they see only the new one.
- It does not appear over a game or another page, only on the home screen (when opening, or coming back to it).
- Messages are not sent while the app is closed. For that you would use push notifications (Firebase Cloud
  Messaging), which the app already requests permission for.
