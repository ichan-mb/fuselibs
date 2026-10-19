using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.IO;

using Fuse.Controls.Native;

namespace Fuse.Controls.Android
{
	/**
		Android implementation of `INativeTabNavigationView`: a `FrameLayout` holding the selected tab's
		page above a bottom tab bar (`TabBar`). All tab pages are created up front; selection only changes
		which one is visible.
	*/
	extern(Android) internal class NativeTabNavigationViewImpl : Fuse.Controls.Native.Android.LeafView, INativeTabNavigationView
	{
		Java.Object _contentView;
		Java.Object _tabBar;
		readonly List<Java.Object> _tabViews = new List<Java.Object>();
		Action<int> _selectedCallback;
		Action<float4> _contentInsetsCallback;

		public NativeTabNavigationViewImpl() : base(CreateContainer())
		{
			_contentView = CreateContentView(Handle);
			_tabBar = CreateTabBar(GetSymbolsFontPath());
			InstallListener(_tabBar);
			AddTabBar(Handle, _tabBar);

			ObserveInsets(Handle);
			ReportContentInsets(Handle);
		}

		public void SetSelectedCallback(Action<int> callback)
		{
			_selectedCallback = callback;
		}

		public void SetContentInsetsCallback(Action<float4> callback)
		{
			_contentInsetsCallback = callback;
		}

		public override void Dispose()
		{
			_tabViews.Clear();
			_tabBar = null;
			_contentView = null;
			_selectedCallback = null;
			_contentInsetsCallback = null;
			base.Dispose();
		}

		public void AddTab(object nativeHandle, string templateName, TabProps props)
		{
			if (_contentView == null)
				return;

			// A lazy tab is added with no page (null); SetTabContent attaches it on first show.
			var view = nativeHandle as Java.Object;
			_tabViews.Add(view);
			if (view != null)
				AddPageView(_contentView, view);
			AddTabItem(_tabBar, props.Title ?? "", props.Symbols, props.IsFilled,
				props.AccessibilityLabel, (int)props.Placement);
			SetTabBadge(_tabBar, _tabViews.Count - 1, props.Badge,
				(int)Uno.Color.ToArgb(props.BadgeColor), (int)Uno.Color.ToArgb(props.BadgeTextColor));
			SetTabEnabled(_tabBar, _tabViews.Count - 1, props.Enabled);
			SetTabColors(_tabBar, _tabViews.Count - 1,
				props.HasColor, (int)Uno.Color.ToArgb(props.Color),
				props.HasSelectedColor, (int)Uno.Color.ToArgb(props.SelectedColor));
		}

		public void SetTabProps(int index, TabProps props)
		{
			if (_tabBar == null)
				return;

			SetTabItem(_tabBar, index, props.Title ?? "", props.Symbols, props.IsFilled, props.AccessibilityLabel);
			SetTabPlacement(_tabBar, index, (int)props.Placement);
			SetTabBadge(_tabBar, index, props.Badge,
				(int)Uno.Color.ToArgb(props.BadgeColor), (int)Uno.Color.ToArgb(props.BadgeTextColor));
			SetTabEnabled(_tabBar, index, props.Enabled);
			SetTabColors(_tabBar, index,
				props.HasColor, (int)Uno.Color.ToArgb(props.Color),
				props.HasSelectedColor, (int)Uno.Color.ToArgb(props.SelectedColor));
		}

		public void SetTabContent(int index, object nativeHandle)
		{
			var view = nativeHandle as Java.Object;
			if (view == null || index < 0 || index >= _tabViews.Count || _contentView == null)
				return;

			_tabViews[index] = view;
			AddPageView(_contentView, view);
		}

		public void RemoveTab(int index)
		{
			if (index < 0 || index >= _tabViews.Count)
				return;

			var view = _tabViews[index];
			if (view != null)
				RemovePageView(_contentView, view);
			RemoveTabItem(_tabBar, index);
			_tabViews.RemoveAt(index);
		}

		public void SelectTab(int index)
		{
			if (index < 0 || index >= _tabViews.Count)
				return;

			for (int i = 0; i < _tabViews.Count; i++)
			{
				if (_tabViews[i] != null)
					SetPageVisible(_tabViews[i], i == index);
			}

			SetBarSelected(_tabBar, index);
		}

		public void ConfigureTabBar(TabBarProps props)
		{
			if (_tabBar == null)
				return;

			SetBarColors(_tabBar,
				(int)Uno.Color.ToArgb(props.BackgroundColor),
				(int)Uno.Color.ToArgb(props.TintColor),
				(int)Uno.Color.ToArgb(props.SelectedTintColor));
			SetBarHidden(Handle, _contentView, _tabBar, props.Hidden);
			SetBarLabels(_tabBar, (int)props.ShowLabels);
		}

		/** Called by the layout listener: the status-bar insets can change with rotation or window changes. */
		void NotifyContentInsets(float left, float top, float right, float bottom)
		{
			if (_contentInsetsCallback != null)
				_contentInsetsCallback(float4(left, top, right, bottom));
		}

		void OnTabSelected(int index)
		{
			if (_selectedCallback != null)
				_selectedCallback(index);
		}

		/**
			Reports the status-bar insets, in points. Only the part that overlaps this view counts, so an
			embedded view that starts below the status bar is not padded twice. The bottom is omitted:
			the tab bar owns that area.
		*/
		[Foreign(Language.Java)]
		void ReportContentInsets(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			android.content.Context context = v.getContext();
			float density = context.getResources().getDisplayMetrics().density;

			android.graphics.Rect insets =
				com.fuse.controls.nativenavigation.NavigationUi.systemBars(context, v.getRootWindowInsets());

			// `systemBars` is relative to the window; convert it to the part that overlaps this view.
			int[] location = new int[2];
			v.getLocationOnScreen(location);
			int screenWidth = context.getResources().getDisplayMetrics().widthPixels;
			int left = Math.max(0, insets.left - location[0]);
			int top = Math.max(0, insets.top - location[1]);
			int right = Math.max(0, insets.right - (screenWidth - (location[0] + v.getWidth())));

			@{global::Fuse.Controls.Android.NativeTabNavigationViewImpl:of(_this).NotifyContentInsets(float,float,float,float):call(left / density, top / density, right / density, 0.0f)};
		@}

		[Foreign(Language.Java)]
		void ObserveInsets(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			v.addOnLayoutChangeListener(new android.view.View.OnLayoutChangeListener() {
				public void onLayoutChange(android.view.View view, int left, int top, int right, int bottom,
						int oldLeft, int oldTop, int oldRight, int oldBottom)
				{
					@{global::Fuse.Controls.Android.NativeTabNavigationViewImpl:of(_this).ReportContentInsets(Java.Object):call(view)};
				}
			});
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateContainer()
		@{
			android.widget.FrameLayout root = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			root.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return root;
		@}

		/** The page container; its bottom padding keeps page content clear of the tab bar. */
		[Foreign(Language.Java)]
		static Java.Object CreateContentView(Java.Object root)
		@{
			android.content.Context context = com.fuse.Activity.getRootActivity();
			int inset = com.fuse.controls.nativetabnavigation.TabBar.bottomInset(context, (android.view.View)root);

			android.widget.FrameLayout content = new android.widget.FrameLayout(context);
			content.setPadding(0, 0, 0,
				com.fuse.controls.nativetabnavigation.TabBar.barHeight(context) + inset);
			((android.view.ViewGroup)root).addView(content, new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return content;
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateTabBar(string fontPath)
		@{
			return new com.fuse.controls.nativetabnavigation.TabBar(com.fuse.Activity.getRootActivity(), fontPath);
		@}

		[Foreign(Language.Java)]
		static void AddTabBar(Java.Object root, Java.Object tabBar)
		@{
			android.view.View bar = (android.view.View)tabBar;
			int inset = com.fuse.controls.nativetabnavigation.TabBar.bottomInset(bar.getContext(), bar);

			// Extend the bar's background to the screen edge, keeping its items above the navigation bar.
			bar.setPadding(0, 0, 0, inset);
			int height = com.fuse.controls.nativetabnavigation.TabBar.barHeight(bar.getContext()) + inset;
			((android.view.ViewGroup)root).addView(bar, new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT, height, android.view.Gravity.BOTTOM));
		@}

		[Foreign(Language.Java)]
		static void AddPageView(Java.Object content, Java.Object page)
		@{
			android.view.View view = (android.view.View)page;
			view.setVisibility(android.view.View.GONE);
			((android.view.ViewGroup)content).addView(view, new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
		@}

		[Foreign(Language.Java)]
		static void SetPageVisible(Java.Object page, bool visible)
		@{
			((android.view.View)page).setVisibility(visible ? android.view.View.VISIBLE : android.view.View.GONE);
		@}

		[Foreign(Language.Java)]
		static void AddTabItem(Java.Object tabBar, string title, string ligature, bool filled,
			string accessibilityLabel, int placement)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).addItem(
				title, ligature, filled, accessibilityLabel, placement);
		@}

		[Foreign(Language.Java)]
		static void SetTabPlacement(Java.Object tabBar, int index, int placement)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setItemPlacement(index, placement);
		@}

		[Foreign(Language.Java)]
		static void SetTabItem(Java.Object tabBar, int index, string title, string ligature, bool filled, string accessibilityLabel)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setItem(index, title, ligature, filled, accessibilityLabel);
		@}

		[Foreign(Language.Java)]
		static void SetTabBadge(Java.Object tabBar, int index, string text, int backgroundArgb, int foregroundArgb)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setBadge(index, text, backgroundArgb, foregroundArgb);
		@}

		[Foreign(Language.Java)]
		static void SetTabColors(Java.Object tabBar, int index, bool hasColor, int colorArgb,
			bool hasSelectedColor, int selectedColorArgb)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setItemColors(index,
				hasColor, colorArgb, hasSelectedColor, selectedColorArgb);
		@}

		[Foreign(Language.Java)]
		static void SetTabEnabled(Java.Object tabBar, int index, bool enabled)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setItemEnabled(index, enabled);
		@}

		[Foreign(Language.Java)]
		static void RemoveTabItem(Java.Object tabBar, int index)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).removeItem(index);
		@}

		[Foreign(Language.Java)]
		static void RemovePageView(Java.Object content, Java.Object page)
		@{
			((android.view.ViewGroup)content).removeView((android.view.View)page);
		@}

		[Foreign(Language.Java)]
		static void SetBarHidden(Java.Object root, Java.Object content, Java.Object tabBar, bool hidden)
		@{
			android.content.Context context = ((android.view.View)tabBar).getContext();
			int inset = com.fuse.controls.nativetabnavigation.TabBar.bottomInset(context, (android.view.View)root);
			int padding = hidden
				? inset
				: com.fuse.controls.nativetabnavigation.TabBar.barHeight(context) + inset;

			((android.view.View)tabBar).setVisibility(hidden ? android.view.View.GONE : android.view.View.VISIBLE);
			((android.view.View)content).setPadding(0, 0, 0, padding);
		@}

		[Foreign(Language.Java)]
		static void SetBarLabels(Java.Object tabBar, int mode)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setLabelVisibility(mode);
		@}

		[Foreign(Language.Java)]
		static void SetBarSelected(Java.Object tabBar, int index)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setSelected(index);
		@}

		[Foreign(Language.Java)]
		static void SetBarColors(Java.Object tabBar, int backgroundArgb, int tintArgb, int selectedTintArgb)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setColors(backgroundArgb, tintArgb, selectedTintArgb);
		@}

		[Foreign(Language.Java)]
		void InstallListener(Java.Object tabBar)
		@{
			((com.fuse.controls.nativetabnavigation.TabBar)tabBar).setListener(
				new com.fuse.controls.nativetabnavigation.TabBar.Listener() {
					public void onTabSelected(int index) {
						@{global::Fuse.Controls.Android.NativeTabNavigationViewImpl:of(_this).OnTabSelected(int):call(index)};
					}
				});
		@}

		// -------- Symbols font --------

		static string _symbolsFontPath;
		static bool _symbolsFontPathResolved;

		/** The asset path of the Material Symbols font bundled by Fuse.Controls.Native, or null. */
		static string GetSymbolsFontPath()
		{
			if (_symbolsFontPathResolved)
				return _symbolsFontPath;

			_symbolsFontPathResolved = true;
			foreach (var file in Bundle.AllFiles)
			{
				if (file.SourcePath.EndsWith("MaterialSymbols.ttf"))
				{
					_symbolsFontPath = GetBundlePath(file);
					break;
				}
			}
			return _symbolsFontPath;
		}

		[Foreign(Language.Java)]
		static string GetBundlePath(BundleFile bundleFile)
		@{
			return @{BundleFile:of(bundleFile).BundlePath:get()};
		@}
	}

	extern(Android) internal static class NativeTabNavigationViewFactory
	{
		internal static Fuse.Controls.Native.IView Create()
		{
			return new NativeTabNavigationViewImpl();
		}
	}
}
