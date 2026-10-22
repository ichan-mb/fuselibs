# Fuse.Launcher.Phone

Launches phone calls and SMS messages using the native capabilities of
Android and iOS.

- Calls: `ACTION_DIAL` by default, or `ACTION_CALL` when requested.
- SMS: `ACTION_SENDTO` on Android and `sms:` / `MFMessageComposeViewController`
  on iOS.
- FaceTime video and audio calls on iOS.
- Availability checks, launch results, Android package targeting and number
  normalization.

- [API reference](docs/README.md)
- [Usage guide and troubleshooting](docs/GUIDE.md)

## Quick start

Add a reference to `Fuse.Launcher.Phone` (or the aggregate `Fuse.Launcher`):

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Phone"
  ]
}
```

JavaScript:

```js
var Phone = require("FuseJS/Phone");

if (Phone.canCall()) {
    Phone.call("+47 123 45 678");
}

Phone.sms({
    to: ["+47 123 45 678"],
    body: "Hi there"
}).then(function(result) {
    console.log(result.status);
}).catch(function(error) {
    console.log("SMS failed: " + error);
});
```

C#:

```csharp
Fuse.Launcher.LaunchCall(new PhoneCallOptions
{
    Number = "+47 123 45 678",
    Mode = PhoneCallMode.Dial
});

Fuse.Launcher.LaunchSms(new SmsMessage
{
    Recipients = new [] { "+47 123 45 678" },
    Body = "Hi there"
});
```

See [docs/README.md](docs/README.md) for the full API and
[docs/GUIDE.md](docs/GUIDE.md) for platform behavior, recipes, migration and
troubleshooting.
