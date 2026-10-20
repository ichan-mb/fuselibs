# Fuse.Alerts manual tests

This app exercises every `Fuse.Alerts` dialog type and cancellation path on a
real Android or iOS device/simulator.

## Run

From the repository root:

```sh
uno build android Tests/ManualTests/FuseAlerts/FuseAlerts.unoproj --run
```

```sh
uno build ios-sim Tests/ManualTests/FuseAlerts/FuseAlerts.unoproj --run
```

Desktop is not supported by the package; the dialogs are no-ops there.

## Checklist

- **Alert**
  - Default labels show the platform-localized OK label.
  - Custom label is shown.
  - Android Back and outside tap resolve `false`.
- **Confirm**
  - Positional confirm resolves `true` / `false`.
  - Three-button confirm shows OK, neutral and Cancel.
  - Three-button result is `0` / `1` / `2`; dismissal is `-1`.
  - Destructive OK is styled as destructive.
  - Non-cancelable confirm ignores Android Back and outside taps.
- **Prompt**
  - Text is returned on OK.
  - Secure prompt hides the input.
  - Cancel and Back return `null`.
  - `required` and `minLength` keep OK disabled until the input is valid.
- **Action sheet**
  - All items are visible.
  - Destructive items are styled.
  - Disabled items cannot be selected.
  - Selecting an item returns its index.
  - Cancel, Back and outside tap return `-1`.
  - iPad popover is anchored to the origin element.
- **Queue**
  - The second dialog opens only after the first is dismissed.
- **Dismiss all**
  - The active dialog closes and resolves `false`.
- **UX triggers**
  - `ShowAlert`, `ShowConfirm` with a neutral button, `ShowPrompt` and
    `ShowActionSheet` all report their result through `AlertArgs`.
  - `AlertArgs.index` is present for confirm and action-sheet selections.
  - `AlertArgs.text` is present for prompt OK.
