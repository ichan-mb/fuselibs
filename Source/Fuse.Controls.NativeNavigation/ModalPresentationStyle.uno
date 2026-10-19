using Uno;

namespace Fuse.Controls
{
	/**
		How a modally presented template (`PresentView` / `NativeNavigationView.PresentTemplate`) is shown.

		The styles map onto the platform's own modal presentation where it has one, and are approximated with
		the dialog window's geometry where it does not (see the notes on each value).
	*/
	public enum ModalPresentationStyle
	{
		/**
			Covers the whole screen, animating up from the bottom. The default.

			iOS: `UIModalPresentationFullScreen`. Android: a full-screen dialog.
		*/
		FullScreen,

		/**
			A card inset from the top of the screen, with the page underneath visible behind it.

			iOS 13+: `UIModalPresentationPageSheet` (rounded top corners, drag to dismiss). Android: a
			full-height dialog inset from the top.
		*/
		PageSheet,

		/**
			A smaller card over a dimmed background.

			iOS: `UIModalPresentationFormSheet`, which needs a regular width class (an iPad, or a Max/Plus in
			landscape); in a compact width it resolves to `PageSheet`. Android: a dialog inset on all sides.
		*/
		FormSheet,

		/**
			A panel covering roughly the lower half of the screen (a bottom sheet).

			iOS 15+: `UIModalPresentationPageSheet` with a medium detent. Below iOS 15 it falls back to
			`PageSheet`. Android: a dialog anchored to the bottom of the screen.
		*/
		Sheet,
	}
}
