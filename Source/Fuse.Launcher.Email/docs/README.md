# Fuse.Launcher.Email

Composes email using the native capabilities of Android and iOS.

- Android: `ACTION_SENDTO` for plain messages, `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
  for attachments and HTML.
- iOS: `MFMailComposeViewController` when the in-app composer is needed, otherwise
  a `mailto:` link.
- Supports multiple recipients, plain text, HTML, attachments, Android package
  targeting, availability checks and launch results.

For recipes, migration notes and troubleshooting, see [GUIDE.md](GUIDE.md).

## Installation

Add a reference to `Fuse.Launcher.Email` in your project file:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Email"
  ]
}
```

You can also reference the aggregate `Fuse.Launcher` package, which includes the
email launcher.

## JavaScript API

```js
var Email = require("FuseJS/Email");

var available = Email.isAvailable();
```

### `Email.isAvailable()`

Returns `true` when the platform can launch an email application.

- Android: checks for a handler for `mailto:` or an email sharing intent.
- iOS: checks `MFMailComposeViewController.canSendMail` or whether `mailto:` can
  be opened.
- Other platforms: returns `false`.

### `Email.compose(options)`

Returns a `Promise` that resolves when the message has been handed to an email
application or the iOS composer has finished.

```js
Email.compose({
    to: ["to@example.com", "second@example.com"],
    cc: ["cc@example.com"],
    bcc: ["bcc@example.com"],
    subject: "Subject",
    body: "Plain text body",
    htmlBody: "<b>HTML body</b>",
    attachments: ["/path/to/file.pdf"]
}).then(function(result) {
    // result.status is "opened", "sent", "saved" or "cancelled"
}).catch(function(error) {
    // user-facing error message
});
```

Options:

| Option | Type | Description |
|---|---|---|
| `to` | string or string[] | Recipient addresses. |
| `cc` | string or string[] | Carbon copy addresses. |
| `bcc` | string or string[] | Blind carbon copy addresses. |
| `subject` | string | Subject line. |
| `body` | string | Plain text body. |
| `htmlBody` | string | HTML body. |
| `attachments` | string[] | File paths to attach. |
| `chooserTitle` | string | Android chooser title. |
| `androidPackage` | string | Android package to target, for example `"com.google.android.gm"`. |
| `preferInAppComposer` | bool | Use the iOS in-app composer. Automatically enabled when `attachments` or `htmlBody` is set. |

The legacy positional form is still supported:

```js
Email.compose(
    "to@example.com",
    "cc@example.com",
    "bcc@example.com",
    "subject",
    "message"
);
```

### Result statuses

| Status | Meaning |
|---|---|
| `opened` | The message was handed to an email application. |
| `sent` | The iOS in-app composer reported that the message was sent. |
| `saved` | The iOS in-app composer saved a draft. |
| `cancelled` | The iOS in-app composer was cancelled. |

Failures reject the promise with a user-facing message. There is no `failed` or
`unavailable` status; those paths reject instead.

## UX trigger

```xml
<LaunchEmail
    To="to@example.com, second@example.com"
    CarbonCopy="cc@example.com"
    BlindCarbonCopy="bcc@example.com"
    Subject="Subject"
    Message="Plain text body"
    HtmlMessage="&lt;b&gt;HTML body&lt;/b&gt;"
    Attachment="/path/to/file.pdf"
    ChooserTitle="Send email" />
```

Properties:

| Property | Type | Description |
|---|---|---|
| `To` | string | Recipient addresses. Comma- and semicolon-separated values are normalized. |
| `CarbonCopy` | string | Carbon copy addresses. |
| `BlindCarbonCopy` | string | Blind carbon copy addresses. |
| `Subject` | string | Subject line. |
| `Message` | string | Plain text body. |
| `HtmlMessage` | string | HTML body. |
| `Attachment` | string | A single attachment path. |
| `Attachments` | string[] | Multiple attachment paths. |
| `ChooserTitle` | string | Android chooser title. |
| `AndroidPackage` | string | Android package to target. |
| `PreferInAppComposer` | bool | Use the iOS in-app composer. |

The UX trigger is fire-and-forget. Use the JavaScript or C# API when you need the
launch result.

## C# API

```csharp
using Fuse;

var message = new EmailMessage
{
    To = new [] { "to@example.com" },
    CarbonCopy = new [] { "cc@example.com" },
    Subject = "Subject",
    Body = "Plain text body",
    HtmlBody = "<b>HTML body</b>",
    Attachments = new [] { "/path/to/file.pdf" }
};

Fuse.Launcher.LaunchEmail(message).Then(
    status => { /* EmailLaunchStatus */ },
    error => { /* Exception */ });
```

### `Fuse.Launcher.IsEmailAvailable()`

Returns whether the platform can launch an email application.

### `Fuse.Launcher.LaunchEmail(EmailMessage)`

Returns `Future<EmailLaunchStatus>`. Failures reject the future.

### `EmailMessage`

| Property | Type | Description |
|---|---|---|
| `To` | string[] | Recipient addresses. |
| `CarbonCopy` | string[] | Carbon copy addresses. |
| `BlindCarbonCopy` | string[] | Blind carbon copy addresses. |
| `Subject` | string | Subject line. |
| `Body` | string | Plain text body. |
| `HtmlBody` | string | HTML body. |
| `Attachments` | string[] | File paths to attach. |
| `ChooserTitle` | string | Android chooser title. |
| `AndroidPackage` | string | Android package to target. |
| `PreferInAppComposer` | bool | Use the iOS in-app composer. |

### Legacy C# API

The original signature is still supported:

```csharp
Fuse.Launcher.LaunchEmail(to, carbonCopy, blindCarbonCopy, subject, message);
```

It is fire-and-forget, throws `ArgumentNullException` when `to` is null, and uses
the same encoding and platform behavior as the new API.

## Platform behavior

### Android

- Plain messages use `ACTION_SENDTO` with a `mailto:` URI and intent extras.
- Messages with attachments or HTML use `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
  with the `message/rfc822` MIME type.
- Attachments are staged in the app cache and exposed through a `FileProvider`.
  `file://` paths, plain file paths and `content://` URIs are accepted.
- `androidPackage` targets a specific package. If the package is not installed,
  the launcher falls back to the regular chooser.
- `chooserTitle` is used for the chooser shown for attachments and HTML.
- Android reports `opened` only; it cannot reliably report whether the message
  was sent.

### iOS

- The in-app composer is used when the message has attachments, has HTML, or
  `preferInAppComposer` is set.
- `MFMailComposeViewController` requires a configured Mail account. If Mail is
  not configured:
  - attachments reject with an error;
  - HTML with no plain text body rejects;
  - HTML with a plain text body falls back to `mailto:` using the plain body;
  - plain messages fall back to `mailto:`.
- The in-app composer reports `sent`, `saved` and `cancelled`.
- The `mailto:` fallback reports `opened`.

### Other platforms

`IsEmailAvailable()` returns `false` and `LaunchEmail` rejects with
`"Email is not supported on this platform."`.

## Limitations

- `mailto:` does not support attachments on either platform.
- iOS attachments and HTML through the in-app composer require a configured Mail
  account.
- Android cannot report whether the user actually sent the message.
- Inbound email is not supported.
- Draft management is not exposed beyond the iOS composer result.

## Testing

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The manual launcher page is `Tests/ManualTests/ManualTestingApp/Singles/Launchers.ux`.
