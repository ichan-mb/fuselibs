# Fuse.Launcher.Phone Guide

Recipes, platform details, migration notes and troubleshooting for the
`Fuse.Launcher.Phone` package. For the API summary, see [README.md](README.md).

## 1. Setup

Reference the package in your project:

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Phone"
  ]
}
```

You can also reference `Fuse.Launcher`, which includes the phone launcher.

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

### `PhoneCallOptions`

`PhoneCallOptions` describes a call:

```csharp
var call = new PhoneCallOptions
{
    Number = "+47 123 45 678",
    Mode = PhoneCallMode.Dial,
    AndroidPackage = "com.android.dialer"
};
```

### `SmsMessage`

`SmsMessage` describes a message:

```csharp
var sms = new SmsMessage
{
    Recipients = new [] { "+47 123 45 678" },
    Body = "Hi there"
};
```

### `PhoneLaunchStatus`

| Value | Platform | Meaning |
|---|---|---|
| `Opened` | Android, iOS URL launch | The request was handed to a phone or messaging application. |
| `Sent` | iOS in-app SMS composer | The message was sent. |
| `Cancelled` | iOS in-app SMS composer | The composer was cancelled. |

Failures do not produce a status; the returned future or promise rejects with
an exception or user-facing message.

### Availability

Check availability before showing an action:

```js
if (Phone.canCall()) {
    // show the call button
}

if (Phone.canSendSms()) {
    // show the message button
}

if (Phone.canFaceTime()) {
    // show the FaceTime button
}
```

```csharp
if (Fuse.Launcher.CanCall()) { /* ... */ }
if (Fuse.Launcher.CanSendSms()) { /* ... */ }
if (Fuse.Launcher.CanFaceTime()) { /* ... */ }
```

On unsupported platforms these return `false`.

## 3. Recipes

### Open the dialer

```js
Phone.call("+47 123 45 678", { mode: "dial" });
```

```csharp
Fuse.Launcher.LaunchCall(new PhoneCallOptions
{
    Number = "+47 123 45 678",
    Mode = PhoneCallMode.Dial
});
```

This is the safest option: it needs no permissions and the user confirms the
call.

### Place the call directly (Android)

```js
Phone.call("+47 123 45 678", { mode: "call" });
```

This requests `CALL_PHONE`. If the user denies the permission, the launcher opens
the dialer instead.

### Compose an SMS

```js
Phone.sms({
    to: ["+47 123 45 678"],
    body: "Hi there"
});
```

```csharp
Fuse.Launcher.LaunchSms(new SmsMessage
{
    Recipients = new [] { "+47 123 45 678" },
    Body = "Hi there"
});
```

### Multiple SMS recipients

```js
Phone.sms({
    to: ["+47 123 45 678", "+47 987 65 432"],
    body: "Hi both"
});
```

### Android chooser

```js
Phone.sms({
    to: ["+47 123 45 678"],
    body: "Hi there",
    chooserTitle: "Send message"
});
```

If `androidPackage` is also set, the package wins and the chooser is skipped.

### Target a specific Android app

```js
Phone.call("+47 123 45 678", {
    androidPackage: "com.android.dialer"
});

Phone.sms({
    to: ["+47 123 45 678"],
    body: "Hi there",
    androidPackage: "com.google.android.apps.messaging"
});
```

If the package is not installed or does not handle the intent, the launcher
falls back to the default application.

### FaceTime

```js
Phone.call("+47 123 45 678", { faceTime: true });
Phone.call("+47 123 45 678", { faceTimeAudioOnly: true });
```

`faceTimeAudioOnly` implies `faceTime`. Apple ID email addresses are accepted:

```js
Phone.call("user@example.com", { faceTime: true });
```

Always check `canFaceTime()` first; it is `false` outside iOS.

### Handle the result

```js
Phone.sms({
    to: ["+47 123 45 678"],
    body: "Hi there",
    preferInAppComposer: true
}).then(function(result) {
    if (result.status === "sent") {
        // the user sent the message
    } else if (result.status === "cancelled") {
        // the user dismissed the composer
    }
}).catch(function(error) {
    // show the error to the user
});
```

### Show a fallback when a provider is missing

```js
if (!Phone.canSendSms()) {
    // hide the message button or show an explanation
}
```

## 4. Platform details

### Android

- `Mode = Dial` uses `ACTION_DIAL` and requires no permission.
- `Mode = Call` requests `CALL_PHONE` and uses `ACTION_CALL`. If the permission
  is denied or revoked, the launcher falls back to `ACTION_DIAL`.
- SMS uses `ACTION_SENDTO` with `smsto:` and both `sms_body` and `EXTRA_TEXT`
  extras.
- The package declares package-visibility queries for `tel` and `smsto`, so
  availability checks work on Android 11+.
- `AndroidPackage` is applied with `Intent.setPackage`. If the package cannot
  handle the intent, the launcher retries without a package.
- `ChooserTitle` shows an SMS chooser when no package is set.

### iOS

- Calls use `tel:`. iOS always asks the user to confirm.
- FaceTime uses `facetime:` and `facetime-audio:`.
- Plain SMS uses `sms:<numbers>&body=`.
- The in-app composer is used when `preferInAppComposer`, `subject` or
  `attachments` is set.
- The composer reports `sent` and `cancelled`.
- A subject requires a device that supports message subjects.
- Attachments require iOS 14+ and a device that supports message attachments.
- If the composer is unavailable and no composer-only content was requested, the
  launcher falls back to `sms:`.

### Other platforms

`CanCall()`, `CanSendSms()` and `CanFaceTime()` return `false`. `LaunchCall` and
`LaunchSms` reject with a user-facing message.

## 5. Number normalization

Numbers are normalized before being placed in a URI:

```text
+47 (123) 45-678  ->  +4712345678
1-800-FLOWERS     ->  18003569377
*123#             ->  *123#
```

The normalization keeps `+`, `*`, `#`, `,` and `;` so international prefixes,
USSD codes and DTMF pauses continue to work. `#` is percent-encoded as `%23` in
the final URI because it starts a fragment in a URL.

## 6. Migration

The original API still compiles:

```csharp
Fuse.Launcher.LaunchCall("+47 123 45 678");
Fuse.Launcher.LaunchSms("+47 123 45 678", "Hi there");
```

Behavior change: `LaunchCall(string)` now opens the dialer instead of placing
the call directly. This avoids requiring `CALL_PHONE` for a simple call button.

To place the call directly:

```csharp
Fuse.Launcher.LaunchCall(new PhoneCallOptions
{
    Number = "+47 123 45 678",
    Mode = PhoneCallMode.Call
});
```

The JavaScript `phone.call(number)` also opens the dialer by default. Pass
`{ mode: "call" }` for a direct call.

## 7. Troubleshooting

### Nothing happens on a tablet or emulator

There may be no telephony or SMS application. Check `canCall()` or
`canSendSms()` first.

### `mode: "call"` opens the dialer instead

The `CALL_PHONE` permission was denied or revoked. This is intentional: the
launcher falls back to the dialer rather than failing silently.

### The SMS body is missing on iOS

Use the in-app composer (`preferInAppComposer: true`) and make sure the device
can send text messages. Third-party SMS applications may ignore the `body`
parameter of the `sms:` URL.

### Attachments are rejected on iOS

Attachments require the in-app composer, iOS 14+, and a device that supports
message attachments. Check `canSendSms()` first.

### FaceTime does nothing

FaceTime is iOS-only. `canFaceTime()` returns `false` on Android and other
platforms.

### Android package targeting does not work

The package may not be installed or may not handle the intent. The launcher
falls back to the default application. Package visibility on Android 11+ is
handled by the package's `<queries>` declaration.

### The manual test page

`Tests/ManualTests/ManualTestingApp/Singles/Launchers.ux` contains the launcher
smoke tests. Run the unit tests with:

```sh
cd fuselibs
uno test Source/Fuse.Launcher/Tests/Fuse.Launcher.Test.unoproj
```
