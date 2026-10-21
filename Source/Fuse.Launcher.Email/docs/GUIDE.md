# Fuse.Launcher.Email Guide

Recipes, platform details, migration notes and troubleshooting for the
`Fuse.Launcher.Email` package. For the API summary, see [README.md](README.md).

## 1. Setup

Reference the package in your project:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Email"
  ]
}
```

You can also reference `Fuse.Launcher`, which includes the email launcher.

When working from a local `fuselibs` checkout, rebuild the library caches after
changing the package:

```sh
cd fuselibs
npm run build
```

or:

```sh
cd fuselibs
uno doctor Source -c debug
```

## 2. Core concepts

### `EmailMessage`

`EmailMessage` describes the message. Recipients and attachments are arrays.
Comma- and semicolon-separated strings are accepted for compatibility and are
normalized by the URI builder.

```csharp
var message = new EmailMessage
{
    To = new [] { "to@example.com" },
    CarbonCopy = new [] { "cc@example.com" },
    BlindCarbonCopy = new [] { "bcc@example.com" },
    Subject = "Subject",
    Body = "Plain text body",
    HtmlBody = "<b>HTML body</b>",
    Attachments = new [] { "/path/to/file.pdf" }
};
```

### `EmailLaunchStatus`

| Value | Platform | Meaning |
|---|---|---|
| `Opened` | Android, iOS `mailto:` fallback | The message was handed to an email application. |
| `Sent` | iOS in-app composer | The message was sent. |
| `Saved` | iOS in-app composer | A draft was saved. |
| `Cancelled` | iOS in-app composer | The composer was cancelled. |

Failures do not produce a status; the returned future/promise rejects with an
exception or user-facing message.

### Availability

Check availability before offering an email action:

```js
if (Email.isAvailable()) {
    // show the compose button
}
```

```csharp
if (Fuse.Launcher.IsEmailAvailable()) {
    // show the compose button
}
```

On unsupported platforms `IsEmailAvailable()` returns `false`.

## 3. Recipes

### Plain email

JavaScript:

```js
Email.compose({
    to: ["to@example.com"],
    subject: "Hello",
    body: "Plain text body"
});
```

C#:

```csharp
Fuse.Launcher.LaunchEmail(new EmailMessage
{
    To = new [] { "to@example.com" },
    Subject = "Hello",
    Body = "Plain text body"
});
```

### Multiple recipients

```js
Email.compose({
    to: ["a@example.com", "b@example.com"],
    cc: ["cc@example.com"],
    bcc: ["bcc@example.com"],
    subject: "Hello",
    body: "Message"
});
```

Arrays are preferred. Existing comma- or semicolon-separated strings also work.

### HTML with a plain-text fallback

```js
Email.compose({
    to: ["to@example.com"],
    subject: "HTML message",
    body: "Plain text fallback",
    htmlBody: "<b>Hello</b> from <i>Fuse.Launcher.Email</i>"
});
```

On Android, `htmlBody` is passed as `EXTRA_HTML_TEXT`. Support varies between
email clients, so always provide `body`.

On iOS, HTML uses the in-app composer. If Mail is not configured but `body` is
provided, the launcher falls back to `mailto:` with the plain text body.

> When embedding JavaScript in a `.ux` file, raw `<` and `>` cannot appear in the
> script text. Use JavaScript hex escapes such as `\x3Cb\x3EHello\x3C/b\x3E`, or
> put the JavaScript in an external file. XML entities such as `&lt;b&gt;` are
> not decoded inside `<JavaScript>` blocks and will show up literally.

### Attachments

```js
Email.compose({
    to: ["to@example.com"],
    subject: "Attachment",
    body: "See the attached file.",
    attachments: ["/path/to/file.pdf"]
});
```

Android accepts plain paths, `file://` paths and `content://` URIs. Files are
staged into the app cache and shared through a `FileProvider`.

iOS reads the file data and attaches it to `MFMailComposeViewController`.
A configured Mail account is required.

Missing or unreadable attachments reject with a clear error.

### iOS in-app composer

```js
Email.compose({
    to: ["to@example.com"],
    subject: "In-app composer",
    body: "This opens MFMailComposeViewController.",
    preferInAppComposer: true
});
```

The composer is enabled automatically when `attachments` or `htmlBody` is set.
It is the only path that reports `sent`, `saved` or `cancelled`.

### Android package targeting

```js
Email.compose({
    to: ["to@example.com"],
    subject: "Hello",
    body: "Message",
    androidPackage: "com.google.android.gm"
});
```

If the package is not installed, the launcher falls back to the regular chooser.

### Error handling

```js
Email.compose({
    to: ["to@example.com"],
    subject: "Attachment",
    body: "See the attached file.",
    attachments: ["/path/that/does/not/exist.pdf"]
}).then(function(result) {
    console.log("Status: " + result.status);
}).catch(function(error) {
    console.log("Could not compose email: " + error);
});
```

C#:

```csharp
Fuse.Launcher.LaunchEmail(message).Then(
    status => { /* ... */ },
    error => { /* ... */ });
```

## 4. Platform details

### Android

- Plain messages: `ACTION_SENDTO` with a `mailto:` URI.
- Attachments or HTML: `ACTION_SEND` / `ACTION_SEND_MULTIPLE` with
  `message/rfc822`.
- Recipients are passed through both the URI and `EXTRA_EMAIL`, `EXTRA_CC` and
  `EXTRA_BCC` so clients that ignore one form still see them.
- Subject, plain body and HTML body use `EXTRA_SUBJECT`, `EXTRA_TEXT` and
  `EXTRA_HTML_TEXT`.
- Attachment URIs are shared with `FLAG_GRANT_READ_URI_PERMISSION` and a
  `ClipData` entry.
- The package declares a `<queries>` entry for `mailto:` and `message/rfc822`, so
  availability checks work on Android 11+.
- The package does not request the `INTERNET` permission; `mailto:` does not need
  it.

### iOS

- The in-app composer is presented from the key window's view controller.
- `MFMailComposeViewController.canSendMail` must be `true`. A configured Gmail or
  Outlook app does not satisfy this; the system Mail account does.
- Attachments are added with `addAttachmentData:mimeType:fileName:`. The MIME
  type is inferred from the file extension and falls back to
  `application/octet-stream`.
- The composer delegate reports `sent`, `saved`, `cancelled` or an error.
- The `mailto:` fallback uses `openURL:options:completionHandler:` and reports
  `opened` or an error.

### Unsupported platforms

`IsEmailAvailable()` returns `false`. `LaunchEmail` rejects with
`"Email is not supported on this platform."`. The legacy fire-and-forget
`LaunchEmail(string, ...)` does nothing.

## 5. Migration from the original API

The original API is still supported:

```js
Email.compose(to, cc, bcc, subject, message);
```

```csharp
Fuse.Launcher.LaunchEmail(to, cc, bcc, subject, message);
```

```xml
<LaunchEmail To="..." CarbonCopy="..." BlindCarbonCopy="..." Subject="..." Message="..." />
```

Behavior changes:

- `Email.compose` now returns a `Promise` instead of nothing. Existing callers
  that ignore the return value are unaffected.
- Recipients are normalized and percent-encoded. `+`, `&`, `#`, spaces and
  Unicode no longer break the URI.
- `mailto:` URIs no longer contain a trailing `?` or `?&` when optional fields
  are empty.
- The Android `INTERNET` permission request was removed.
- Android errors are reported instead of being allowed to crash the app.
- The C# legacy overload still throws `ArgumentNullException` when `to` is null.

## 6. Limitations

- `mailto:` cannot carry attachments. Use the in-app composer on iOS and the
  intent attachment path on Android.
- Long bodies embedded in a `mailto:` URI may be truncated or rejected by some
  clients. Use the iOS in-app composer for long messages.
- Android reports `opened` only. It cannot reliably distinguish “compose screen
  opened” from “message sent”.
- iOS attachments and HTML require a configured Mail account.
- Display-name addresses such as `"Doe, John" <john@example.com>` are not part of
  RFC 6068. Pass plain addresses.
- Inbound email is not supported.
- There is no draft API beyond the iOS composer result.

## 7. Troubleshooting

### “No app is available to compose email.”

Android could not resolve an email intent. Install or enable an email app, and
verify the device has a handler for `mailto:`.

### “Attachments require a configured Mail account.”

On iOS, attachments use `MFMailComposeViewController`, which requires the system
Mail account. A Gmail/Outlook app alone is not enough. Configure Mail, or use a
share sheet that supports attachments.

### HTML tags appear literally in the message

Pass raw HTML to `htmlBody`. If the JavaScript is embedded in a `.ux` file, use
`\x3C` and `\x3E` for `<` and `>`, or move the script to an external `.js` file.
Do not use `&lt;` inside `<JavaScript>` blocks.

### “The file does not exist: …”

The attachment path is invalid or unreadable. On Android, app-private files must
be readable by the process; the launcher stages them into the FileProvider cache.
On iOS, the file must exist in a readable location.

### Android package target does not open

The requested package is not installed or has no matching activity. The launcher
falls back to the chooser; verify the package name.

### iOS composer does not appear

Check that Mail is configured (`MFMailComposeViewController.canSendMail`). If it
is not, the launcher falls back to `mailto:` when possible.

### `opened` is reported but the message was not sent

Expected on Android. `opened` only confirms that the compose screen was launched.

## 8. Testing

Unit tests for the URI builder:

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

Manual testing:

- `Tests/ManualTests/ManualTestingApp/Singles/Launchers.ux` in `fuselibs`
- A dedicated test app can exercise the JavaScript, UX and C# APIs with plain
  messages, multiple recipients, HTML, attachments, errors and Android package
  targeting.

## 9. Implementation notes

The package is organized as follows:

- `Email/EmailMessage.uno` — public message and status types.
- `Email/EmailUriHelper.uno` — `mailto:` construction and recipient encoding.
- `Email/EmailLauncher.uno` — platform-independent API and legacy overload.
- `Email/EmailPlatformAndroid.uno` — Android foreign layer.
- `Email/EmailPlatformIOS.uno` — iOS foreign layer.
- `Email/EmailUI.h` / `Email/EmailUI.m` — `MFMailComposeViewController` and
  `mailto:` fallback.
- `Email/EmailTrigger.uno` — UX `LaunchEmail` action.
- `Email/JS.uno` — `FuseJS/Email` module.
- `android/` — intent builder, FileProvider, file staging and Android manifest
  extensions.
