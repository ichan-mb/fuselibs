using Uno;
using Uno.Collections;

using Fuse;
using Fuse.Resources;

namespace Fuse.Controls
{
	/**
		A button in the navigation bar; giving it `ToolbarMenuItem` children turns it into a pull-down menu.

		```xml
		<NavigationBarConfig Navigation="nav" Title="Home">
			<ToolbarItem Title="Add" Clicked="{addClicked}" />
			<ToolbarItem Title="More" Symbols="ellipsis.circle">
				<ToolbarMenuItem Title="Sort" Clicked="{sort}" />
			</ToolbarItem>
		</NavigationBarConfig>
		```
	*/
	public class ToolbarItem : ToolbarEntry
	{
		ToolbarItemPosition _position = ToolbarItemPosition.Right;
		/** The position where the toolbar item appears in the navigation bar. */
		public ToolbarItemPosition Position
		{
			get { return _position; }
			set
			{
				if (_position != value)
				{
					_position = value;
					NotifyOwner();
				}
			}
		}

		float4 _color;
		bool _hasColor;
		/**
			The colour used to tint this item's icon and title; falls back to the bar's tint colour when unset.
		*/
		public float4 Color
		{
			get { return _color; }
			set
			{
				if (!_hasColor || _color != value)
				{
					_color = value;
					_hasColor = true;
					NotifyOwner();
				}
			}
		}

		/**
			Whether `Color` was explicitly set.
		*/
		public bool HasColor
		{
			get { return _hasColor; }
		}

		/** The `ToolbarMenuItem` children, as pull-down menu entries. */
		internal List<ToolbarMenuItem> GetMenuItems()
		{
			return NodeGroupChildren.OfType<ToolbarMenuItem>(this);
		}

		internal void OnMenuChanged()
		{
			NotifyOwner();
		}

		protected override bool NotifyChanged(Node node)
		{
			var navBarConfig = node as NavigationBarConfig;
			if (navBarConfig == null || !navBarConfig.IsRootingCompleted)
				return false;

			navBarConfig.OnToolbarItemChanged();
			return true;
		}
	}

	/**
		The cache key a platform uses for a toolbar icon image, and a way to collect the keys its stored
		configurations still refer to. An icon is pinned once per key and reused across apply passes (see the
		platforms' `CreateFileIconDrawable` / `CreateHttpIconDrawable`), so this is what lets unused images be
		released.
	*/
	internal static class ToolbarIconSource
	{
		/** The cache key for an icon image, or null when the source is not an image this caches. */
		internal static string Key(ImageSource source)
		{
			var file = source as FileImageSource;
			if (file != null)
			{
				var image = file.File;
				return image != null ? image.Name : null;
			}

			var http = source as HttpImageSource;
			if (http != null)
				return http.Url;

			return null;
		}

		/** Adds the key of every image icon used by a configuration to `keys`. */
		internal static void CollectKeys(NavigationBarProps config, HashSet<string> keys)
		{
			if (config == null)
				return;

			if (config.ToolbarItems != null)
			{
				for (int i = 0; i < config.ToolbarItems.Length; i++)
					AddKey(keys, config.ToolbarItems[i].Icon);
			}

			if (config.MenuItems != null)
			{
				for (int i = 0; i < config.MenuItems.Length; i++)
					AddKey(keys, config.MenuItems[i].Icon);
			}
		}

		static void AddKey(HashSet<string> keys, ImageSource source)
		{
			var key = Key(source);
			if (key != null)
				keys.Add(key);
		}
	}

	/**
		Where a toolbar item appears. Positions are logical: `Leading` is the left side in a
		left-to-right layout and the right side in RTL, `Trailing` the reverse. `Left` and `Right` are
		the older names for the same two sides.
	*/
	public enum ToolbarItemPosition
	{
		Left,
		Right,
		Leading,
		Trailing
	}

	internal static class ToolbarItemPositions
	{
		internal static bool IsLeading(ToolbarItemPosition position)
		{
			return position == ToolbarItemPosition.Left || position == ToolbarItemPosition.Leading;
		}
	}

	/**
		Data transfer object for toolbar item properties used by native implementations.
	*/
	internal class ToolbarItemProps
	{
		public string Title { get; set; }
		public bool Enabled { get; set; }
		/** Screen-reader name; falls back to `Title`. */
		public string AccessibilityLabel { get; set; }
		/** Whether the item is shown; a hidden item is not built on the bar. */
		public bool Visible { get; set; }
		public ToolbarItemPosition Position { get; set; }
		/** The original `ToolbarItem`, for click handling. */
		public ToolbarItem Source { get; set; }

		/** Symbol name (resolved for the platform), or null when the item uses an image. */
		public string Symbols { get; set; }
		public bool IsFilled { get; set; }
		/** The image source for the icon, or null when the item uses a symbol or only a title. */
		public ImageSource Icon { get; set; }
		/** Whether `Color` was explicitly set, and its components (floats for the native side). */
		public bool HasColor { get; set; }
		public float ColorR { get; set; }
		public float ColorG { get; set; }
		public float ColorB { get; set; }
		public float ColorA { get; set; }
	}
}
