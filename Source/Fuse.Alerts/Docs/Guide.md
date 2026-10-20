# Fuse.Alerts

`Fuse.Alerts` provides native alert, confirm, prompt and action-sheet dialogs on
Android and iOS. Dialogs are shown one at a time; calls made while another dialog
is open are queued and shown after the current dialog is dismissed.

Add a reference to the package in your project file:

```json
"references": [
    "Fuse.Alerts"
]
```

Then require the module from JavaScript:

```js
var Alerts = require("FuseJS/Alerts");
```

You can also use the UX trigger actions described below without writing any
JavaScript.

## Result semantics

| API | Cancel / Back / outside tap |
| --- | --- |
| `alert(...)` | resolves `false` |
| `confirm(title, ...)` | resolves `false` |
| `confirm(options)` | resolves `-1` |
| `prompt(options)` | resolves `null` |
| `actionSheet(options)` | resolves `-1` |

Promises are rejected only when the native dialog could not be shown, for example
when there is no active Android activity.

## Alert

```js
Alerts.alert(
    "Native Alert",
    "This is a native alert dialog.",
    "OK"
).then(function(ok) {
    console.log("alert resolved: " + ok);
});
```

All arguments after `title` are optional. When labels are omitted the platform's
localized OK and Cancel labels are used.

## Confirm

### Two buttons

```js
Alerts.confirm(
    "Delete item?",
    "This cannot be undone.",
    "Delete",
    "Cancel"
).then(function(ok) {
    if (ok) {
        // Delete
    }
});
```

Resolves `true` for OK and `false` for Cancel, Back or an outside tap.

### Three buttons

```js
Alerts.confirm({
    title: "Unsaved changes",
    message: "Save before leaving?",
    okLabel: "Save",
    neutralLabel: "Don't Save",
    cancelLabel: "Cancel",
    destructive: false,
    cancelable: true
}).then(function(result) {
    // 0 = OK, 1 = neutral, 2 = cancel, -1 = dismissed
});
```

- `destructive` styles the OK action as destructive.
- `cancelable` controls whether Android allows dismissing with Back or an outside
  tap. iOS alert-style dialogs cannot be dismissed that way.
- `neutralLabel` is optional. When omitted the dialog has two buttons.

## Prompt

```js
Alerts.prompt({
    title: "Rename item",
    message: "Enter a new name.",
    placeholder: "Name",
    value: "Untitled",
    okLabel: "Save",
    cancelLabel: "Cancel",
    secure: false,
    keyboardType: "text",
    required: false,
    minLength: 0
}).then(function(text) {
    // string on OK, null on cancel/dismiss
});
```

`keyboardType` can be `"text"`, `"email"`, `"number"`, `"phone"` or `"url"`.
Set `secure: true` for password input. Set `required: true` or a positive
`minLength` to keep OK disabled until the input is long enough.

## Action sheet

```js
Alerts.actionSheet({
    title: "Photo source",
    message: "Choose where to get the photo.",
    items: [
        "Camera",
        "Photo library",
        { label: "Delete", destructive: true },
        { label: "Unavailable", enabled: false }
    ],
    cancelLabel: "Cancel",
    origin: actionSheetOrigin
}).then(function(index) {
    // selected index, or -1 on cancel/dismiss
});
```

- `items` can be strings or objects with `label`, optional `destructive` and
  optional `enabled`.
- Any number of items can be destructive, and disabled items cannot be selected.
- `origin` is optional and is used as the iPad popover anchor. Pass a UX element
  by name, as with `Fuse.Share`.

## Dismiss all

```js
Alerts.dismissAll();
```

Clears all queued dialogs and dismisses the active one. The active promise
resolves as cancelled.

## UX trigger actions

### ShowAlert

```xml
<ShowAlert Title="Alert" Message="Hello!" OkLabelButton="OK" Handler="{onAlert}" />
```

### ShowConfirm

```xml
<ShowConfirm
    Title="Unsaved changes"
    Message="Save before leaving?"
    OkLabelButton="Save"
    NeutralLabelButton="Don't Save"
    CancelLabelButton="Cancel"
    Destructive="false"
    Cancelable="true"
    Handler="{onConfirm}" />
```

`AlertArgs` exposes `buttonLabel`, `index` (0/1/2/-1) and, for prompts, `text`.

### ShowPrompt

```xml
<ShowPrompt
    Title="Rename"
    Message="Enter a new name."
    Placeholder="Name"
    OkLabelButton="Save"
    CancelLabelButton="Cancel"
    Secure="false"
    Required="false"
    MinLength="0"
    KeyboardType="text"
    Handler="{onPrompt}" />
```

### ShowActionSheet

```xml
<ShowActionSheet
    Title="Photo source"
    Message="Choose a source."
    CancelLabelButton="Cancel"
    Handler="{onActionSheet}">
    <ActionSheetItem Label="Camera" />
    <ActionSheetItem Label="Photo library" />
    <ActionSheetItem Label="Delete" Destructive="true" />
    <ActionSheetItem Label="Unavailable" Enabled="false" />
</ShowActionSheet>
```

The iPad popover is anchored to the element that triggered the action.

## Platform behavior

### Android

- Alerts, confirms and prompts use `AlertDialog`.
- Action sheets use a list dialog.
- Back and outside taps resolve the promise with the cancel result when the
  dialog is cancelable.
- When a dialog has both a message and a list, Android does not render the list.
  For action sheets the message is therefore shown as part of the title.
- Default OK/Cancel labels use `android.R.string.ok` and
  `android.R.string.cancel`.

### iOS

- Dialogs use `UIAlertController`.
- Action sheets use `UIAlertControllerStyleActionSheet` and are anchored to the
  provided `origin`, the triggering element, or the presenter center.
- Dismissing an iPad action sheet by tapping outside resolves the promise as
  cancelled.
- Default OK/Cancel labels use `NSLocalizedString`.
- Dialogs are presented from the top-most view controller.

### Desktop

Dialogs are not implemented on desktop. `alert` and `confirm` resolve `true`,
`prompt` resolves `null`, and `actionSheet` resolves `-1`.

## Lifecycle

- Dialogs are shown one at a time and are queued while another is open.
- On Android, an activity recreation (for example a rotation) dismisses the
  active dialog and resolves its promise as cancelled. Dialogs are not
  preserved across the recreation.
- On iOS, dialogs remain presented until dismissed by the user or by
  `Alerts.dismissAll()`.
- Call `Alerts.dismissAll()` when navigating away or when your app should not
  keep a dialog open.

## Examples and tests

- `Tests/ManualTests/FuseAlerts` is a manual regression app that covers every
  dialog type, cancellation path, queuing and `dismissAll`.
- A separate showcase project is available alongside the repository examples.
