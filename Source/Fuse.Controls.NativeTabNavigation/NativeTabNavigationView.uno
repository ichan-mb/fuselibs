using Uno;
using Uno.Collections;
using Uno.UX;

using Fuse;
using Fuse.Controls.Native;

namespace Fuse.Controls
{
	/**
		A native tab bar with one native page per tab: a `UITabBarController` on iOS, and a bottom tab bar
		with a page container on Android.

		Each `ux:Template` child is a tab. Its content may be any visual -- a `Page`, a `Panel`, or even a
		`NativeNavigationView` (which gives that tab its own navigation stack). `TabConfig` sets a tab's
		title and icon; a template without one is titled with its template name. `DefaultTab` chooses the
		initial tab, and `SelectedIndex` / `SelectedTab` follow the platform's selection.

		```xml
		<NativeTabNavigationView ux:Name="tabs" DefaultTab="Home">
			<Page ux:Template="Home">
				<TabConfig Navigation="tabs" Title="Home" Symbols="house" />
				<Text Value="Home" />
			</Page>
			<Page ux:Template="Search">
				<TabConfig Navigation="tabs" Title="Search" Symbols="magnifyingglass" />
				<Text Value="Search" />
			</Page>
		</NativeTabNavigationView>
		```
	*/
	public class NativeTabNavigationView : Panel
	{
		// The most recently rooted instance; used by the FuseJS "NativeTabNavigation" module.
		static readonly List<NativeTabNavigationView> _activeInstances = new List<NativeTabNavigationView>();
		internal static NativeTabNavigationView Active
		{
			get { return _activeInstances.Count > 0 ? _activeInstances[_activeInstances.Count - 1] : null; }
		}

		readonly List<TabContext> _tabs = new List<TabContext>();

		// A tab's props can be set by its TabConfig before the native side has the tab.
		readonly Dictionary<string, TabProps> _pendingProps = new Dictionary<string, TabProps>();

		INativeTabNavigationView _nativeImpl;
		int _selectedIndex = -1;

		class TabContext
		{
			public string TemplateName;
			public Visual Instance;
			/** Wraps the page so its content can be inset without touching the page's own padding. */
			public Panel Host;
			public ViewControllerRoot Root;

			public TabContext(string templateName, Visual instance, Panel host, ViewControllerRoot root)
			{
				TemplateName = templateName;
				Instance = instance;
				Host = host;
				Root = root;
			}
		}

		/** The template shown initially. When not set, the first template is used. */
		public string DefaultTab { get; set; }

		/** The selected tab's index; setting it selects that tab. */
		public int SelectedIndex
		{
			get { return _selectedIndex; }
			set
			{
				if (!IsRootingStarted)
					_selectedIndex = value;
				else
					SelectIndex(value);
			}
		}

		/** The selected tab's template name, or null when the view is empty. */
		public string SelectedTab
		{
			get
			{
				if (_selectedIndex < 0 || _selectedIndex >= _tabs.Count)
					return null;
				return _tabs[_selectedIndex].TemplateName;
			}
		}

		/** The number of tabs currently shown. */
		public int TabCount { get { return _tabs.Count; } }

		/** The template name of a tab, or null when the index is out of range. */
		public string GetTabTemplate(int index)
		{
			if (index < 0 || index >= _tabs.Count)
				return null;
			return _tabs[index].TemplateName;
		}

		float4 _backgroundColor = float4(1);
		/** The tab bar's background colour. */
		public float4 BackgroundColor
		{
			get { return _backgroundColor; }
			set
			{
				if (_backgroundColor != value)
				{
					_backgroundColor = value;
					ApplyTabBar();
				}
			}
		}

		float4 _tintColor = float4(0.42f, 0.45f, 0.5f, 1);
		/** The colour of unselected tabs (icon and title). */
		public float4 TintColor
		{
			get { return _tintColor; }
			set
			{
				if (_tintColor != value)
				{
					_tintColor = value;
					ApplyTabBar();
				}
			}
		}

		float4 _selectedTintColor = float4(0.0f, 0.48f, 1.0f, 1);
		/** The colour of the selected tab (icon and title). */
		public float4 SelectedTintColor
		{
			get { return _selectedTintColor; }
			set
			{
				if (_selectedTintColor != value)
				{
					_selectedTintColor = value;
					ApplyTabBar();
				}
			}
		}

		bool _translucent;
		/**
			Whether the bar is blurred rather than opaque. On Android, use the background colour's alpha
			instead; this property is iOS-only.
		*/
		public bool Translucent
		{
			get { return _translucent; }
			set
			{
				if (_translucent != value)
				{
					_translucent = value;
					ApplyTabBar();
				}
			}
		}

		/** What the system back button does on a tab other than the first (Android). */
		public TabBackBehavior BackBehavior { get; set; }

		bool _hidden;
		/** Whether the tab bar is hidden; the tab pages then fill the view. */
		public bool Hidden
		{
			get { return _hidden; }
			set
			{
				if (_hidden != value)
				{
					_hidden = value;
					ApplyTabBar();
				}
			}
		}

		TabBarLabelVisibility _showLabels = TabBarLabelVisibility.Always;
		/** When a tab's title is shown under its icon. Defaults to always. */
		public TabBarLabelVisibility ShowLabels
		{
			get { return _showLabels; }
			set
			{
				if (_showLabels != value)
				{
					_showLabels = value;
					ApplyTabBar();
				}
			}
		}

		bool _lazy;
		/**
			Whether tab pages are created when first selected rather than at startup. The template instance
			is still created up front, to read its `TabConfig`, but it is not rooted and has no native page
			until the tab is first shown. Set it before the view is rooted.
		*/
		public bool Lazy
		{
			get { return _lazy; }
			set { _lazy = value; }
		}

		bool _applyInsets = true;
		/**
			Whether the page content is padded clear of the status bar / safe area. Defaults to true;
			set false for edge-to-edge content.
		*/
		public bool ApplyInsets
		{
			get { return _applyInsets; }
			set
			{
				if (_applyInsets != value)
				{
					_applyInsets = value;
					ApplyPageInsets();
				}
			}
		}

		// The safe-area insets last reported by the platform, in points.
		float4 _contentInsets;

		static readonly Selector _selectedIndexName = "SelectedIndex";

		/** Fires for every change, for the FuseJS module (which is not tied to one view). */
		internal static event Action<int> SelectedIndexChangedGlobal;

		/** Fires when the selected tab changes, whether selected in code or by the user. */
		public event ValueChangedHandler<int> SelectedIndexChanged;

		/** Fires when tabs are added or removed at runtime. */
		public event EventHandler TabsChanged;

		public override VisualContext VisualContext
		{
			get
			{
				// Native tab bars are only implemented on mobile; elsewhere the control renders as a Fuse
				// panel and selection still works.
				return defined(!Android && !iOS) ? VisualContext.Graphics : VisualContext.Native;
			}
		}

		protected override void OnRooted()
		{
			base.OnRooted();

			_nativeImpl = defined(iOS || Android)
				? (INativeTabNavigationView)NativeView
				: NativeTabNavigationViewFactory.CreateNativeImpl();

			if (_nativeImpl == null)
				return;

			_nativeImpl.SetSelectedCallback(OnPlatformSelected);
			_nativeImpl.SetContentInsetsCallback(OnPlatformContentInsets);

			// Create every tab's isolated context first, so a TabConfig rooted with it can set its props.
			for (int i = 0; i < Templates.Count; i++)
			{
				var templateName = Templates[i].Key;
				if (string.IsNullOrEmpty(templateName))
					continue;

				if (_lazy)
				{
					// Read the tab's metadata without rooting it; the page itself is created on first show.
					var instance = CreateTabInstance(templateName);
					if (instance == null)
						continue;

					var props = GetPropsFromInstance(instance, templateName);
					if (!props.AutoAdd)
						continue;

					_pendingProps[templateName] = props;
					_tabs.Add(new TabContext(templateName, instance, null, null));
					continue;
				}

				var context = CreateTabContext(templateName);
				if (context == null)
					continue;

				// A tab can opt out of the initial set and be added later (see TabConfig.AutoAdd).
				if (!GetTabProps(templateName).AutoAdd)
				{
					context.Root.Dispose();
					continue;
				}

				_tabs.Add(context);
			}

			for (int i = 0; i < _tabs.Count; i++)
			{
				var context = _tabs[i];

				// A lazy tab is added without its page; it is attached on first selection.
				var handle = context.Root != null ? context.Root.GetNativeHandle() : null;
				_nativeImpl.AddTab(handle, context.TemplateName, GetTabProps(context.TemplateName));
			}

			ApplyTabBar();

			var initial = GetInitialIndex();
			if (initial >= 0)
			{
				SelectIndex(initial);

				// UIKit can settle its own default selection after the tabs are assigned, so apply the
				// declared initial tab once more on the next frame.
				var initialIndex = initial;
				UpdateManager.AddDeferredAction(() => SelectIndex(initialIndex));
			}

			_activeInstances.Add(this);
			Fuse.Input.Keyboard.KeyPressed.AddGlobalHandler(OnKeyPressed);
		}

		protected override void OnUnrooted()
		{
			Fuse.Input.Keyboard.KeyPressed.RemoveGlobalHandler(OnKeyPressed);
			_activeInstances.Remove(this);

			for (int i = 0; i < _tabs.Count; i++)
			{
				if (_tabs[i].Root != null)
					_tabs[i].Root.Dispose();
			}
			_tabs.Clear();
			_pendingProps.Clear();

			_selectedIndex = -1;
			_nativeImpl = null;
			base.OnUnrooted();
		}

		protected override Fuse.Controls.Native.IView CreateNativeView()
		{
			if defined(iOS)
				return Fuse.Controls.iOS.NativeTabNavigationViewFactory.Create();
			else if defined(Android)
				return Fuse.Controls.Android.NativeTabNavigationViewFactory.Create();
			else
				return null;
		}

		/** Selects the tab with the given template name. */
		public void SelectTab(string templateName)
		{
			if (string.IsNullOrEmpty(templateName))
				return;

			var index = IndexOfTemplate(templateName);
			if (index < 0)
			{
				Fuse.Diagnostics.UserError("Tab '" + templateName + "' not found in NativeTabNavigationView", this);
				return;
			}

			SelectIndex(index);
		}

		/**
			Adds a tab at runtime from a declared template. A template is shown once: adding one that is
			already a tab warns and does nothing.
		*/
		public void AddTab(string templateName)
		{
			if (string.IsNullOrEmpty(templateName))
				return;

			if (IndexOfTemplate(templateName) >= 0)
			{
				Fuse.Diagnostics.UserWarning("Tab '" + templateName + "' is already shown", this);
				return;
			}

			TabContext context;
			if (_lazy)
			{
				var instance = CreateTabInstance(templateName);
				if (instance == null)
					return;

				var props = GetPropsFromInstance(instance, templateName);
				_pendingProps[templateName] = props;
				context = new TabContext(templateName, instance, null, null);
			}
			else
			{
				context = CreateTabContext(templateName);
				if (context == null)
					return;
			}

			_tabs.Add(context);
			if (_nativeImpl != null)
			{
				var handle = context.Root != null ? context.Root.GetNativeHandle() : null;
				_nativeImpl.AddTab(handle, templateName, GetTabProps(templateName));
			}

			if (_tabs.Count == 1)
				SelectIndex(0);

			if (TabsChanged != null)
				TabsChanged(this, EventArgs.Empty);
		}

		/** Removes a tab and disposes its page. */
		public void RemoveTab(string templateName)
		{
			var index = IndexOfTemplate(templateName);
			if (index < 0)
				return;

			var context = _tabs[index];
			if (_nativeImpl != null)
				_nativeImpl.RemoveTab(index);

			_tabs.RemoveAt(index);
			if (context.Root != null)
				context.Root.Dispose();

			if (_tabs.Count == 0)
			{
				if (_selectedIndex >= 0)
				{
					_selectedIndex = -1;
					NotifySelectedIndex();
				}
			}
			else if (index < _selectedIndex)
			{
				_selectedIndex--;
			}
			else if (index == _selectedIndex)
			{
				// Select the tab that took its place (or the new last one) through the normal path.
				_selectedIndex = -1;
				SelectIndex(Math.Min(index, _tabs.Count - 1));
			}

			if (TabsChanged != null)
				TabsChanged(this, EventArgs.Empty);
		}

		TabContext CreateTabContext(string templateName)
		{
			var instance = CreateTabInstance(templateName);
			if (instance == null)
				return null;

			var context = new TabContext(templateName, instance, null, null);
			MaterializeContent(context);
			return context;
		}

		/** Creates the template instance, unrooted, and associates it with this view. */
		Visual CreateTabInstance(string templateName)
		{
			var tpl = FindTemplate(templateName);
			if (tpl == null)
			{
				Fuse.Diagnostics.UserError("Template '" + templateName + "' not found in NativeTabNavigationView", this);
				return null;
			}

			var instance = tpl.New() as Visual;
			if (instance == null)
			{
				Fuse.Diagnostics.UserError("Template '" + templateName + "' did not produce a Visual", this);
				return null;
			}

			instance.Name = templateName;

			// A tab is rendered in its own context, so this is how a TabConfig inside it finds this view.
			TabNavigationLocator.SetNavigation(instance, this);
			return instance;
		}

		/**
			Creates the tab's isolated rendering context. The wrapper carries the page insets, so the page's
			own padding is left alone.
		*/
		void MaterializeContent(TabContext context)
		{
			if (context.Root != null)
				return;

			var host = new Panel();
			host.Padding = PagePadding();
			host.Children.Add(context.Instance);

			var root = new ViewControllerRoot(this);
			root.SetContent(host);

			context.Host = host;
			context.Root = root;
		}

		/** Makes sure a lazy tab's page exists before the platform shows it. */
		void EnsureContent(int index)
		{
			var context = _tabs[index];
			if (context.Root != null)
				return;

			MaterializeContent(context);
			if (_nativeImpl != null)
				_nativeImpl.SetTabContent(index, context.Root.GetNativeHandle());
		}

		/** The metadata a `TabConfig` in an unrooted instance provides. */
		TabProps GetPropsFromInstance(Visual instance, string templateName)
		{
			var config = FindTabConfig(instance);
			if (config == null)
				return new TabProps { Title = templateName, Enabled = true, AutoAdd = true };

			return CreateTabProps(config, templateName);
		}

		/** Finds the `TabConfig` in a template instance without rooting it. */
		static TabConfig FindTabConfig(Node node)
		{
			var config = node as TabConfig;
			if (config != null)
				return config;

			var visual = node as Visual;
			if (visual != null)
			{
				var children = visual as IList<Node>;
				for (int i = 0; i < children.Count; i++)
				{
					var found = FindTabConfig(children[i]);
					if (found != null)
						return found;
				}
			}

			return null;
		}

		TabProps GetTabProps(string templateName)
		{
			TabProps props;
			if (_pendingProps.TryGetValue(templateName, out props) && props != null)
				return props;

			return new TabProps { Title = templateName, Enabled = true, AutoAdd = true };
		}

		/** Called by `TabConfig`: stores the tab's props and applies them if the tab exists. */
		internal void OnTabConfigChanged(string templateName, TabProps props)
		{
			if (string.IsNullOrEmpty(templateName) || props == null)
				return;

			_pendingProps[templateName] = props;

			var index = IndexOfTemplate(templateName);
			if (index >= 0 && _nativeImpl != null)
				_nativeImpl.SetTabProps(index, props);
		}

		/** Resolves a config's title and icon for the current platform. */
		internal TabProps CreateTabProps(TabConfig config, string templateName)
		{
			var props = new TabProps
			{
				Title = string.IsNullOrEmpty(config.Title) ? templateName : config.Title,
				Enabled = config.Enabled,
				Placement = config.Placement,
				AutoAdd = config.AutoAdd,
				IsFilled = config.IsFilled,
				AccessibilityLabel = config.AccessibilityLabel,
				HasColor = config.HasColor,
				Color = config.Color,
				HasSelectedColor = config.HasSelectedColor,
				SelectedColor = config.SelectedColor,
				Badge = config.Badge,
				BadgeColor = config.BadgeColor,
				BadgeTextColor = config.BadgeTextColor,
			};

			if (!string.IsNullOrEmpty(config.Symbols))
				props.Symbols = Fuse.Controls.Primitives.SymbolProvider.GetPlatformSymbol(config.Symbols, config.IsFilled).Name;

			return props;
		}

		void NotifySelectedIndex()
		{
			OnPropertyChanged(_selectedIndexName, null);

			if (SelectedIndexChanged != null)
				SelectedIndexChanged(this, new ValueChangedArgs<int>(_selectedIndex));

			if (SelectedIndexChangedGlobal != null)
				SelectedIndexChangedGlobal(_selectedIndex);
		}

		void OnPlatformSelected(int index)
		{
			// iOS before 18.4 has no `UITab.enabled`, so a tapped disabled tab can still be reported.
			// Put the platform back on the current tab instead of selecting it.
			if (index >= 0 && index < _tabs.Count && !GetTabProps(_tabs[index].TemplateName).Enabled)
			{
				if (_nativeImpl != null && _selectedIndex >= 0)
					_nativeImpl.SelectTab(_selectedIndex);
				return;
			}

			SelectIndex(index);
		}

		void SelectIndex(int index)
		{
			if (index < 0 || index >= _tabs.Count)
				return;

			EnsureContent(index);

			// Keep the platform in step even for a selection it reported itself: on Android that is what
			// shows the tab's page and marks the tab selected (setting it again is idempotent).
			if (_nativeImpl != null)
				_nativeImpl.SelectTab(index);

			if (index == _selectedIndex)
				return;

			_selectedIndex = index;
			NotifySelectedIndex();
		}

		void OnKeyPressed(object sender, Fuse.Input.KeyEventArgs args)
		{
			// Only the most recently rooted view handles Back, as NativeNavigationView does.
			if (args.Key != Uno.Platform.Key.BackButton || Active != this || args.IsHandled)
				return;

			if (BackBehavior != TabBackBehavior.ReturnToFirst)
				return;

			// A NativeNavigationView inside the active tab handles Back first while it can pop.
			var nested = NativeNavigationView.Active;
			if (nested != null && nested.CanGoBack)
				return;

			if (_tabs.Count > 1 && _selectedIndex != 0)
			{
				SelectIndex(0);
				args.IsHandled = true;
			}
		}

		void OnPlatformContentInsets(float4 insets)
		{
			_contentInsets = insets;
			ApplyPageInsets();
		}

		float4 PagePadding()
		{
			return _applyInsets ? _contentInsets : float4(0);
		}

		void ApplyPageInsets()
		{
			var padding = PagePadding();
			for (int i = 0; i < _tabs.Count; i++)
			{
				if (_tabs[i].Host != null)
					_tabs[i].Host.Padding = padding;
			}
		}

		void ApplyTabBar()
		{
			if (_nativeImpl == null)
				return;

			_nativeImpl.ConfigureTabBar(new TabBarProps
			{
				BackgroundColor = _backgroundColor,
				TintColor = _tintColor,
				SelectedTintColor = _selectedTintColor,
				Translucent = _translucent,
				Hidden = _hidden,
				ShowLabels = _showLabels,
			});
		}

		int IndexOfTemplate(string templateName)
		{
			for (int i = 0; i < _tabs.Count; i++)
			{
				if (_tabs[i].TemplateName == templateName)
					return i;
			}
			return -1;
		}

		int GetInitialIndex()
		{
			if (_tabs.Count == 0)
				return -1;

			if (_selectedIndex >= 0 && _selectedIndex < _tabs.Count)
				return _selectedIndex;

			if (!string.IsNullOrEmpty(DefaultTab))
			{
				var index = IndexOfTemplate(DefaultTab);
				if (index >= 0)
					return index;

				Fuse.Diagnostics.UserWarning("DefaultTab not found, using the first tab", this);
			}

			return 0;
		}

	}
}
