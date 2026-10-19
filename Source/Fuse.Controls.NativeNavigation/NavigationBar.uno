using Uno;
using Uno.Collections;
using Uno.UX;

using Fuse;
using Fuse.Elements;
using Fuse.Resources;

namespace Fuse.Controls
{
	/**
		Describes the navigation bar of the template it is placed in: title, colours, translucency, hidden,
		large title, back button title, content inset, and `ToolbarItem` children.

		```xml
		<NativeNavigationView ux:Name="nav">
			<Panel ux:Template="Home">
				<NavigationBarConfig Navigation="nav" Title="Home" BackgroundColor="#333" ForegroundColor="#fff">
					<ToolbarItem Title="New" Clicked="{newClicked}" />
				</NavigationBarConfig>
				<Text>Home Page</Text>
			</Panel>
		</NativeNavigationView>
		```
	*/
	public class NavigationBarConfig : NodeGroup
	{
		// The appearance a bar has when nothing is set.
		static readonly float4 DefaultBackgroundColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
		static readonly float4 DefaultForegroundColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

		string _title;
		/**
			The title to display in the navigation bar.
		*/
		public string Title
		{
			get { return _title; }
			set
			{
				if (_title != value)
				{
					_title = value;
					OnPropertyChanged();
				}
			}
		}

		float4 _backgroundColor = DefaultBackgroundColor;
		/**
			The background color of the navigation bar.
		*/
		public float4 BackgroundColor
		{
			get { return _backgroundColor; }
			set
			{
				if (_backgroundColor != value)
				{
					_backgroundColor = value;
					OnPropertyChanged();
				}
			}
		}

		float4 _foregroundColor = DefaultForegroundColor;
		/**
			The foreground color (text and button color) of the navigation bar.
		*/
		public float4 ForegroundColor
		{
			get { return _foregroundColor; }
			set
			{
				if (_foregroundColor != value)
				{
					_foregroundColor = value;
					OnPropertyChanged();
				}
			}
		}

		bool _largeTitle = false;
		/** Whether to display the title in large format (iOS 11+; ignored elsewhere). */
		public bool LargeTitle
		{
			get { return _largeTitle; }
			set
			{
				if (_largeTitle != value)
				{
					_largeTitle = value;
					OnPropertyChanged();
				}
			}
		}

		bool _translucent = false;
		/**
			Whether the navigation bar should be translucent.
			When false, content will not appear behind the navigation bar.
		*/
		public bool Translucent
		{
			get { return _translucent; }
			set
			{
				if (_translucent != value)
				{
					_translucent = value;
					OnPropertyChanged();
				}
			}
		}

		bool _hidden = false;
		/**
			Whether to hide the navigation bar for this template. The config is still present, so its content
			inset (and, for a modal, its presence) follow the same rules as a visible bar.
		*/
		public bool Hidden
		{
			get { return _hidden; }
			set
			{
				if (_hidden != value)
				{
					_hidden = value;
					OnPropertyChanged();
				}
			}
		}

		string _backButtonTitle;
		/**
			Custom title for the back button. If not set, uses default behavior.
		*/
		public string BackButtonTitle
		{
			get { return _backButtonTitle; }
			set
			{
				if (_backButtonTitle != value)
				{
					_backButtonTitle = value;
					OnPropertyChanged();
				}
			}
		}

		bool _applyInsets = false;
		/**
			Whether the page content is inset to keep it clear of the navigation bar and system bars.
			Defaults to false, laying the content out edge to edge; set it to true to inset it.
		*/
		public bool ApplyInsets
		{
			get { return _applyInsets; }
			set
			{
				if (_applyInsets != value)
				{
					_applyInsets = value;
					OnPropertyChanged();
				}
			}
		}

		float4 _tintColor;
		bool _hasTintColor = false;
		/**
			The tint colour for interactive elements (buttons, icons) in the bar; falls back to
			`ForegroundColor` when unset.
		*/
		public float4 TintColor
		{
			get { return _hasTintColor ? _tintColor : _foregroundColor; }
			set
			{
				if (!_hasTintColor || _tintColor != value)
				{
					_tintColor = value;
					_hasTintColor = true;
					OnPropertyChanged();
				}
			}
		}

		/**
			Gets whether `TintColor` was explicitly set.
		*/
		public bool HasTintColor
		{
			get { return _hasTintColor; }
		}

		NativeNavigationView _navigation;

		List<ToolbarItem> GetToolbarItems()
		{
			return NodeGroupChildren.OfType<ToolbarItem>(this);
		}

		/**
			The `NativeNavigationView` to configure; falls back to the containing view.
		*/
		public NativeNavigationView Navigation
		{
			get { return _navigation; }
			set
			{
				_navigation = value;
				OnPropertyChanged();
			}
		}

		string _templateName;
		Element _visualParent;

		protected override void OnRooted()
		{
			base.OnRooted();

			if (_navigation == null)
				_navigation = Fuse.Navigation.Navigation.GetNativeNavigation(Parent) as NativeNavigationView;

			if (_navigation == null)
			{
				Fuse.Diagnostics.UserError("NativeNavigationView is not found", this);
				return;
			}

			_templateName = GetTemplateName();
			if (string.IsNullOrEmpty(_templateName))
				Fuse.Diagnostics.UserWarning("Could not determine template name for NavigationBarConfig", this);

			_visualParent = Parent as Element;
			ApplyNavigationBarSettings();
		}

		protected override void OnUnrooted()
		{
			// Give the page its own padding back, unless it has changed it since our last apply.
			if (_visualParent != null && _hasAppliedPadding && _visualParent.Padding == _appliedPadding)
				_visualParent.Padding = _basePadding;

			_hasAppliedPadding = false;
			_templateName = null;
			_visualParent = null;
			base.OnUnrooted();
		}

		/** Called by `ToolbarItem` when its properties change. */
		internal void OnToolbarItemChanged()
		{
			OnPropertyChanged();
		}

		/** The name of the template this config is inside (the nearest named parent). */
		string GetTemplateName()
		{
			var current = Parent;
			while (current != null)
			{
				if (!string.IsNullOrEmpty(current.Name))
					return current.Name;
				current = current.Parent;
			}
			return null;
		}

		float4 _basePadding = float4(0);
		float4 _appliedPadding = float4(0);
		bool _hasAppliedPadding;

		void ApplyNavigationBarSettings()
		{
			if (_navigation == null)
				return;

			var nativeImpl = _navigation.GetNativeImplementation();
			if (nativeImpl == null || _visualParent == null)
				return;

			nativeImpl.ConfigureNavigationBar(_templateName, CreateNavigationBarConfig());

			// The page's own padding is whatever it has when we did not set it. If it changed since our
			// last apply, that change came from the page and becomes the new base.
			var current = _visualParent.Padding;
			if (!_hasAppliedPadding || current != _appliedPadding)
				_basePadding = current;

			var padding = _basePadding;
			if (!_hidden && _applyInsets)
			{
				var insets = nativeImpl.GetNavigationSafeInsets(_templateName);
				padding = float4(padding.X + insets.X, padding.Y + insets.Y, padding.Z + insets.Z, padding.W + insets.W);
			}

			_visualParent.Padding = padding;
			_appliedPadding = padding;
			_hasAppliedPadding = true;
		}

		void OnPropertyChanged()
		{
			if (IsRootingCompleted)
				ApplyNavigationBarSettings();
		}

		NavigationBarProps CreateNavigationBarConfig()
		{
			// Convert ToolbarItems to ToolbarItemProps
			var toolbarItems = GetToolbarItems();
			var toolbarItemCount = toolbarItems.Count;
			var toolbarItemProps = new ToolbarItemProps[toolbarItemCount];
			var menuItems = new List<ToolbarMenuItemProps>();
			for (int i = 0; i < toolbarItemCount; i++)
			{
				var item = toolbarItems[i];
				item.VisualParent = Parent;
				toolbarItemProps[i] = new ToolbarItemProps
				{
					Title = item.Title,
					Enabled = item.Enabled,
					AccessibilityLabel = item.AccessibilityLabel,
					Visible = item.Visible,
					Position = item.Position,
					Source = item,
					Symbols = ResolveSymbolName(item.Symbols, item.IsFilled),
					IsFilled = item.IsFilled,
					Icon = ResolveIconSource(item.Source, item.File, item.Url, item.Symbols),
					HasColor = item.HasColor,
					ColorR = item.Color.X,
					ColorG = item.Color.Y,
					ColorB = item.Color.Z,
					ColorA = item.Color.W
				};

				var itemMenu = item.GetMenuItems();
				for (int m = 0; m < itemMenu.Count; m++)
				{
					var menuItem = itemMenu[m];
					menuItem.VisualParent = Parent;
					menuItems.Add(new ToolbarMenuItemProps
					{
						ToolbarIndex = i,
						Title = menuItem.Title,
						Enabled = menuItem.Enabled,
						AccessibilityLabel = menuItem.AccessibilityLabel,
						Visible = menuItem.Visible,
						Source = menuItem,
						Symbols = ResolveSymbolName(menuItem.Symbols, menuItem.IsFilled),
						IsFilled = menuItem.IsFilled,
						Icon = ResolveIconSource(menuItem.Source, menuItem.File, menuItem.Url, menuItem.Symbols)
					});
				}
			}

			return new NavigationBarProps
			{
				Title = _title,
				BackgroundColor = _backgroundColor,
				ForegroundColor = _foregroundColor,
				TintColor = TintColor, // Uses property to get fallback behavior
				LargeTitle = _largeTitle,
				Translucent = _translucent,
				Hidden = _hidden,
				BackButtonTitle = _backButtonTitle,
				ToolbarItems = toolbarItemProps,
				MenuItems = menuItems.ToArray()
			};
		}

		static string ResolveSymbolName(string symbols, bool isFilled)
		{
			if (string.IsNullOrEmpty(symbols))
				return null;

			return Fuse.Controls.Primitives.SymbolProvider.GetPlatformSymbol(symbols, isFilled).Name;
		}

		/**
			Resolves a `ToolbarItem` or `ToolbarMenuItem`'s icon to an `ImageSource`, or null when it uses a
			symbol or only a title.
		*/
		static ImageSource ResolveIconSource(ImageSource source, FileSource file, string url, string symbols)
		{
			if (!string.IsNullOrEmpty(symbols))
				return null;

			if (source != null)
				return source;
			if (file != null)
				return new FileImageSource { File = file };
			if (!string.IsNullOrEmpty(url))
				return new HttpImageSource { Url = url };

			return null;
		}
	}
}
