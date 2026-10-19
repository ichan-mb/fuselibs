using Uno;

using Fuse;
using Fuse.Triggers.Actions;

namespace Fuse.Controls
{
	/**
		Base class for the navigation actions. Resolves the `NativeNavigationView` to act on: `Navigation` when
		set, otherwise the nearest one in the target's parent hierarchy.
	*/
	public abstract class NativeNavigationAction : TriggerAction
	{
		/** The view to act on; when unset, the nearest `NativeNavigationView` ancestor is used. */
		public NativeNavigationView Navigation { get; set; }

		/** The receiver for the action, or null (having reported an error) when none was found. */
		protected NativeNavigationView FindNavigation(Node target, string action)
		{
			var navigation = Navigation;
			if (navigation == null)
				navigation = target.FindByType<NativeNavigationView>();
			if (navigation == null)
				navigation = FindInPage(target);

			if (navigation == null)
				Fuse.Diagnostics.UserError(action + " requires a 'Navigation' property or NativeNavigationView in parent hierarchy", this);

			return navigation;
		}

		/**
			The view a page visual belongs to (see `NativeNavigationView.CreateViewControllerContext`). A page is
			rendered in its own context, so the view is not a Fuse ancestor of the action; the page visual carries
			the association instead.
		*/
		static NativeNavigationView FindInPage(Node target)
		{
			// The action's target is the trigger node, not a visual, so walk the node chain and check every
			// visual on the way.
			var node = target;
			while (node != null)
			{
				var visual = node as Visual;
				if (visual != null)
				{
					var navigation = Fuse.Navigation.Navigation.GetNativeNavigation(visual) as NativeNavigationView;
					if (navigation != null)
						return navigation;
				}
				node = node.Parent;
			}
			return null;
		}
	}

	/**
		Pushes a new view onto the native navigation stack.

		```xml
		<Click><PushView To="Details" Navigation="nav" /></Click>
		```
	*/
	public class PushView : NativeNavigationAction
	{
		/** The name of the template to push. */
		public string To { get; set; }

		protected override void Perform(Node target)
		{
			if (string.IsNullOrEmpty(To))
			{
				Fuse.Diagnostics.UserError("PushView requires a 'To' property specifying the template name", this);
				return;
			}

			var navigation = FindNavigation(target, "PushView");
			if (navigation != null)
				navigation.PushTemplate(To);
		}
	}

	/**
		Pops the current view from the native navigation stack.

		```xml
		<Click><PopView Navigation="nav" /></Click>
		```
	*/
	public class PopView : NativeNavigationAction
	{
		protected override void Perform(Node target)
		{
			var navigation = FindNavigation(target, "PopView");
			if (navigation != null)
				navigation.PopTemplate();
		}
	}

	/**
		Presents a template modally (a sheet or full-screen cover).

		```xml
		<Click><PresentView To="Edit" Navigation="nav" /></Click>
		```
	*/
	public class PresentView : NativeNavigationAction
	{
		/** The name of the template to present. */
		public string To { get; set; }

		/** How the template is shown. Defaults to `ModalPresentationStyle.FullScreen`. */
		public ModalPresentationStyle Style { get; set; }

		bool _dragToDismiss = true;
		/**
			Whether the user can drag a sheet down to dismiss it, and whether the sheet has a grabber. Defaults
			to true; with it off, close the sheet with `DismissView` / `DismissModal`.
		*/
		public bool DragToDismiss
		{
			get { return _dragToDismiss; }
			set { _dragToDismiss = value; }
		}

		bool _expandable = true;
		/**
			Whether the user can drag a `Sheet` up to fill the screen. Defaults to true; with it off the sheet
			keeps its own height (useful when the content is laid out for one height). `ExpandModal` does the
			same from code.
		*/
		public bool Expandable
		{
			get { return _expandable; }
			set { _expandable = value; }
		}

		protected override void Perform(Node target)
		{
			if (string.IsNullOrEmpty(To))
			{
				Fuse.Diagnostics.UserError("PresentView requires a 'To' property specifying the template name", this);
				return;
			}

			var navigation = FindNavigation(target, "PresentView");
			if (navigation != null)
				navigation.PresentTemplate(To, null, Style, DragToDismiss, Expandable);
		}
	}

	/**
		Gives the top-most modal its expanded size, or the size of its own presentation style back. Only a
		modal presented with `Expandable` has two sizes.

		```xml
		<Click><ExpandModal Navigation="nav" /></Click>
		```
	*/
	public class ExpandModal : NativeNavigationAction
	{
		bool _value = true;
		/** True (the default) to expand the modal, false to give it its own size back. */
		public bool Value
		{
			get { return _value; }
			set { _value = value; }
		}

		protected override void Perform(Node target)
		{
			var navigation = FindNavigation(target, "ExpandModal");
			if (navigation != null)
				navigation.SetModalExpanded(Value);
		}
	}

	/**
		Dismisses the top-most modally presented template.

		```xml
		<Click><DismissView Navigation="nav" /></Click>
		```
	*/
	public class DismissView : NativeNavigationAction
	{
		protected override void Perform(Node target)
		{
			var navigation = FindNavigation(target, "DismissView");
			if (navigation != null)
				navigation.DismissModal();
		}
	}
}
