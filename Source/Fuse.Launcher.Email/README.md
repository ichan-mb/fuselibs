# Fuse.Launcher.Email

Composes email using the native capabilities of Android and iOS.

- [API reference](docs/README.md)
- [Usage guide and troubleshooting](docs/GUIDE.md)

## Quick start

Add a reference to `Fuse.Launcher.Email` (or the aggregate `Fuse.Launcher`):

```json
{
  "references": [
    "Fuse",
    "Fuse.Launcher.Email"
  ]
}
```

JavaScript:

```js
var Email = require("FuseJS/Email");

Email.compose({
    to: ["to@example.com"],
    subject: "Hello",
    body: "Plain text body"
}).then(function(result) {
    console.log(result.status);
}).catch(function(error) {
    console.log("Email failed: " + error);
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

See [docs/README.md](docs/README.md) for the full API and
[docs/GUIDE.md](docs/GUIDE.md) for platform behavior, recipes, migration and
troubleshooting.
