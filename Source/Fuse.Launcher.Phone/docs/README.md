# Fuse.Launcher.Phone

Launches phone calls and SMS messages using the native capabilities of
Android and iOS.

- Android: `ACTION_DIAL` by default, `ACTION_CALL` when requested, and
  `ACTION_SENDTO` for SMS.
- iOS: `tel:`, `sms:` and FaceTime URLs, with an
  `MFMessageComposeViewController` composer for subject and attachments.
- Supports availability checks, launch results, Android package targeting,
  chooser titles, FaceTime and number normalization.

For recipes, migration notes and troubleshooting, see [GUIDE.md](GUIDE.md).

## Installation

Add a reference to `Fuse.Launcher.Phone` in your project file:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Phone"
  ]
}
```

You can also reference the aggregate `Fuse.Launcher` package, which includes the
phone launcher.

## JavaScript API

```js
var Phone = require("FuseJS/Phone");
```

### `Phone.canCall()`

Returns `true` when the platform can launch a phone call.

- Android: checks for a handler for `tel:` / `DIAL` intents.
- iOS: checks whether `tel:` can be opened.
- Other platforms: returns `false`.

### `Phone.canSendSms()`

Returns `true` when the platform can compose an SMS message.

- Android: checks for a handler for `smsto:` / `SENDTO` intents.
- iOS: checks `MFMessageComposeViewController.canSendText()` or whether `sms:`
  can be opened.
- Other platforms: returns `false`.

### `Phone.canFaceTime()`

Returns `true` when the platform can launch FaceTime. Always `false` outside
iOS.

### `Phone.call(number, options)`

Returns a `Promise` that resolves when the platform has handed the request to a
phone application.

```js
Phone.call("+47 123 45 678", {
    mode: "dial"
}).then(function(result) {
    // result.status is "opened"
}).catch(function(error) {
    // user-facing error message
});
```

Options:

| Option | Type | Description |
|---|---|---|
| `mode` | string | `"dial"` (default) opens the dialer. `"call"` places the call directly. |
| `androidPackage` | string | Android package to target, for example `"com.android.dialer"`. Android only. |
| `faceTime` | bool | Launch FaceTime instead of a phone call. iOS only. |
| `faceTimeAudioOnly` | bool | Launch FaceTime audio. Implies `faceTime`. iOS only. |

`mode: "call"` requires the `CALL_PHONE` permission on Android. If the
permission is denied, the launcher falls back to the dialer instead of failing.

`number` can also be an Apple ID email address when `faceTime` is set.

### `Phone.sms(number, body)` / `Phone.sms(options)`

Returns a `Promise` that resolves when the message has been handed to a
messaging application or the iOS composer has finished.

```js
Phone.sms({
    to: ["+47 123 45 678"],
    body: "Hi there"
}).then(function(result) {
    // result.status is "opened", "sent" or "cancelled"
}).catch(function(error) {
    // user-facing error message
});
```

The legacy positional form is still supported:

```js
Phone.sms("+47 123 45 678", "Hi there");
```

Options:

| Option | Type | Description |
|---|---|---|
| `to` | string or string[] | Recipient numbers. `number` is accepted as an alias. |
| `body` | string | Message body. |
| `subject` | string | Message subject. iOS in-app composer only; ignored on Android. |
| `attachments` | string[] | File paths to attach. iOS in-app composer and iOS 14+ only; ignored on Android. |
| `preferInAppComposer` | bool | Use the iOS in-app composer. Automatically enabled when `subject` or `attachments` is set. |
| `androidPackage` | string | Android package to target, for example `"com.google.android.apps.messaging"`. Android only. |
| `chooserTitle` | string | Title of the Android chooser when no `androidPackage` is set. Android only. |

### Result statuses

| Status | Meaning |
|---|---|
| `opened` | The request was handed to a phone or messaging application. |
| `sent` | The iOS in-app composer reported that the message was sent. |
| `cancelled` | The iOS in-app composer was cancelled. |

Failures reject the promise with a user-facing message.

## UX triggers

### `<Call>`

```xml
<Call
    Number="+47 123 45 678"
    Mode="Dial"
    AndroidPackage="com.android.dialer" />
```

| Property | Type | Description |
|---|---|---|
| `Number` | string | The number to call. |
| `Mode` | `Dial` or `Call` | `Dial` (default) opens the dialer; `Call` places the call directly. |
| `AndroidPackage` | string | Android package to target. |
| `FaceTime` | bool | Launch FaceTime instead of a phone call. iOS only. |
| `FaceTimeAudioOnly` | bool | Launch FaceTime audio. Implies `FaceTime`. |

### `<Sms>`

```xml
<Sms
    Number="+47 123 45 678"
    Body="Hi there"
    Subject="Greeting"
    ChooserTitle="Send message" />
```

| Property | Type | Description |
|---|---|---|
| `Number` | string | The recipient number. |
| `Body` | string | Message body. |
| `Subject` | string | Message subject. Requires the iOS in-app composer. |
| `Attachment` | string | A single attachment path. |
| `Attachments` | string[] | Multiple attachment paths. |
| `PreferInAppComposer` | bool | Use the iOS in-app composer. |
| `AndroidPackage` | string | Android package to target. |
| `ChooserTitle` | string | Android chooser title. |

The UX triggers are fire-and-forget. Use the JavaScript or C# API when you need
the launch result.

## C# API

```csharp
using Fuse;

Fuse.Launcher.LaunchCall(new PhoneCallOptions
{
    Number = "+47 123 45 678",
    Mode = PhoneCallMode.Dial
}).Then(
    status => { /* PhoneLaunchStatus */ },
    error => { /* Exception */ });

Fuse.Launcher.LaunchSms(new SmsMessage
{
    Recipients = new [] { "+47 123 45 678" },
    Body = "Hi there"
}).Then(
    status => { /* PhoneLaunchStatus */ },
    error => { /* Exception */ });
```

### `Fuse.Launcher.CanCall()`, `CanSendSms()`, `CanFaceTime()`

Return whether the platform can perform the operation.

### `Fuse.Launcher.LaunchCall(PhoneCallOptions)`

Returns `Future<PhoneLaunchStatus>`. Failures reject the future.

### `Fuse.Launcher.LaunchSms(SmsMessage)`

Returns `Future<PhoneLaunchStatus>`. Failures reject the future. On iOS with the
in-app composer the future resolves to `Sent` or `Cancelled`; otherwise it
resolves to `Opened`.

### `PhoneCallOptions`

| Property | Type | Description |
|---|---|---|
| `Number` | string | The number to call, or an Apple ID when `FaceTime` is set. |
| `Mode` | `PhoneCallMode` | `Dial` (default) or `Call`. |
| `AndroidPackage` | string | Android package to target. |
| `FaceTime` | bool | Launch FaceTime. iOS only. |
| `FaceTimeAudioOnly` | bool | Launch FaceTime audio. Implies `FaceTime`. |

### `SmsMessage`

| Property | Type | Description |
|---|---|---|
| `Recipients` | string[] | Recipient numbers. |
| `Body` | string | Message body. |
| `Subject` | string | Message subject. Requires the iOS in-app composer. |
| `Attachments` | string[] | File paths to attach. Requires the iOS in-app composer and iOS 14+. |
| `PreferInAppComposer` | bool | Use the iOS in-app composer. |
| `AndroidPackage` | string | Android package to target. |
| `ChooserTitle` | string | Android chooser title. |

### Legacy C# API

The original signatures are still supported:

```csharp
Fuse.Launcher.LaunchCall("+47 123 45 678");
Fuse.Launcher.LaunchSms("+47 123 45 678", "Hi there");
```

`LaunchCall(string)` opens the dialer. Use the `PhoneCallOptions` overload with
`Mode = PhoneCallMode.Call` to place the call directly.

## Platform behavior

### Android

- `Mode = Dial` uses `ACTION_DIAL` and requires no permissions.
- `Mode = Call` requests `CALL_PHONE` and uses `ACTION_CALL`. If the permission is
  denied or revoked, it falls back to `ACTION_DIAL`.
- SMS uses `ACTION_SENDTO` with an `smsto:` URI and both `sms_body` and
  `EXTRA_TEXT` extras.
- `AndroidPackage` targets a specific package. If the package is not installed
  or does not handle the intent, the launcher falls back to the default
  application.
- `ChooserTitle` shows a chooser for SMS when no package is set.
- Android reports `opened` only; it cannot reliably report whether a message was
  sent.

### iOS

- Calls use `tel:`. iOS always asks the user to confirm, so `Mode` has no effect.
- FaceTime uses `facetime:` or `facetime-audio:`.
- SMS uses the in-app composer when `preferInAppComposer`, `subject` or
  `attachments` is set, and falls back to `sms:` otherwise.
- The in-app composer reports `sent` and `cancelled`.
- Attachments require the in-app composer and iOS 14+.
- A subject requires the in-app composer and a device that supports message
  subjects.

### Other platforms

`CanCall()`, `CanSendSms()` and `CanFaceTime()` return `false`, and the launch
methods reject with a user-facing message.

## Number normalization

Phone numbers are normalized before they are placed in a URI:

- Spaces, `-`, `.`, `(`, `)` and other separators are removed.
- Keypad letters are converted to digits, so `1-800-FLOWERS` becomes
  `18003569377`.
- `+`, `*`, `#`, `,` and `;` are preserved for international prefixes, USSD
  codes and DTMF pauses.

## Limitations

- SMS is composed in the platform messaging application. The package does not
  send SMS in the background or read the inbox.
- Android cannot report whether the user actually sent a message.
- iOS attachments require the in-app composer and iOS 14+.
- MMS and RCS are not supported.
- Call logs and contact lookup are not part of this package.

## Testing

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```

The manual launcher page is
`Tests/ManualTests/ManualTestingApp/Singles/Launchers.ux`.
