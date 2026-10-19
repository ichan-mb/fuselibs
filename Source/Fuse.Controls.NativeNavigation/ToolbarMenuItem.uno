using Uno;

using Fuse;
using Fuse.Resources;

namespace Fuse.Controls
{
	/**
		An entry in a `ToolbarItem`'s pull-down menu.

		The containing `ToolbarItem` shows as a button that opens a native menu (a `UIMenu` on iOS 14+, a
		`SubMenu` on Android); selecting an entry raises its `Clicked`.

		Usage:
		```xml
		<ToolbarItem Title="More">
			<ToolbarMenuItem Title="Sort" Clicked="{sort}" />
			<ToolbarMenuItem Symbols="trash" Clicked="{clearAll}" />
		</ToolbarItem>
		```
	*/
	public class ToolbarMenuItem : ToolbarEntry
	{
		protected override bool NotifyChanged(Node node)
		{
			// The containing ToolbarItem is our context parent (it roots us into the page while keeping
			// its own context).
			var item = node as ToolbarItem;
			if (item == null || !item.IsRootingCompleted)
				return false;

			item.OnMenuChanged();
			return true;
		}
	}

	/**
		Data transfer object for toolbar menu item properties used by native implementations.
	*/
	internal class ToolbarMenuItemProps
	{
		public int ToolbarIndex { get; set; }
		public string Title { get; set; }
		public bool Enabled { get; set; }
		/** Screen-reader name; falls back to `Title`. */
		public string AccessibilityLabel { get; set; }
		/** Whether the entry is listed at all (see `ToolbarEntry.Visible`). */
		public bool Visible { get; set; }
		public ToolbarMenuItem Source { get; set; }

		/** Symbol name (already resolved for the current platform), or null when the entry uses an image. */
		public string Symbols { get; set; }
		public bool IsFilled { get; set; }
		/** The image source for the icon, or null when the entry uses a symbol or only a title. */
		public ImageSource Icon { get; set; }
	}
}
