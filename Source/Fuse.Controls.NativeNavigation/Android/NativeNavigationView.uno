using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.IO;

using Fuse.Controls.Native;
using Fuse.Resources;

namespace Fuse.Controls.Android
{
	/**
		Android implementation of `INativeNavigationView`: a `FrameLayout` holding a fragment page container and
		an overlaid appcompat `Toolbar`. `FuseNavigationFragment` owns the back stack and system back handling.
	*/
	extern(Android) internal class NativeNavigationViewImpl : Fuse.Controls.Native.Android.LeafView, INativeNavigationView
	{
		// Menu ids also become action-item view ids, so they must stay above View.generateViewId()'s range:
		// a collision makes FragmentManager find the menu view instead of the page container.
		const int ToolbarItemIdBase = 10000;
		const int MenuItemIdBase = 20000;

		// Fallback wait for a transition that reports no animation (appcompat transitions are ~300ms).
		const int TransitionFallbackMs = 400;

		Java.Object _containerView;
		Java.Object _toolbar;
		Java.Object _contentView;
		int _containerId;
		Java.Object _fragmentManager;
		Fuse.Controls.NativeNavigationView _fuseHost;
		Action<string, int, bool> _navigationChangeCallback;
		Action<string, int, bool> _navigationStartedCallback;
		Action _modalDismissedCallback;
		Action<float2> _modalContentSizeCallback;
		float _toolbarHeightPoints;
		// Presented modals, bottom to top; mirrors the shared layer's stack.
		readonly List<PresentedModal> _presentedModals = new List<PresentedModal>();

		/** A presented dialog, with what its bar and its insets need to be answered for it. */
		class PresentedModal
		{
			public Java.Object Dialog;
			public string Template;
			public ModalPresentationStyle Style;
		}

		/** The modal on top of the stack, or null when none is presented. */
		PresentedModal CurrentModal { get { return _presentedModals.Count > 0 ? _presentedModals[_presentedModals.Count - 1] : null; } }

		// Set while a pop waits for its exit animation; also makes the reconcile run only once.
		bool _exitReconcilePending;

		// Page stack (bottom to top); mirrors the fragment back stack and answers synchronous queries.
		readonly List<string> _stack = new List<string>();

		// Per-template bar configuration, applied to the single Toolbar as pages are shown.
		readonly Dictionary<string, NavigationBarProps> _navigationBarConfigs = new Dictionary<string, NavigationBarProps>();
		readonly Dictionary<string, ToolbarItemProps[]> _toolbarItemConfigs = new Dictionary<string, ToolbarItemProps[]>();
		readonly Dictionary<string, ToolbarMenuItemProps[]> _toolbarMenuConfigs = new Dictionary<string, ToolbarMenuItemProps[]>();

		// Pinned images, one per source: reused by every apply pass and released on Dispose.
		readonly Dictionary<string, ImageHandle> _imageIconHandles = new Dictionary<string, ImageHandle>();

		// Sources being downloaded, so each URL is requested only once.
		readonly HashSet<string> _pendingImageIcons = new HashSet<string>();

		static string _symbolsFontPath;
		static bool _symbolsFontPathResolved;

		public NativeNavigationViewImpl() : base(CreateContainer())
		{
			_containerView = Handle;
			// Create the page container first, then the toolbar, so the toolbar is drawn on top of it.
			_contentView = CreateContentView(_containerView);
			_toolbar = CreateToolbar(_containerView);
			_containerId = SetContainerId(_contentView);
			_toolbarHeightPoints = GetToolbarHeightPoints();

			_fragmentManager = GetFragmentManager();
			if (_fragmentManager != null)
			{
				RegisterBackStackListener(_fragmentManager);
				RegisterBackHandler(_fragmentManager);
			}
		}

		public void SetHost(Fuse.Controls.NativeNavigationView host)
		{
			_fuseHost = host;
		}

		public override void Dispose()
		{
			DismissAllModals();
			ReleaseImageIcons();
			_containerView = null;
			_toolbar = null;
			_contentView = null;
			_fragmentManager = null;
			_fuseHost = null;
			_navigationChangeCallback = null;
			_navigationStartedCallback = null;
			_modalDismissedCallback = null;
			_modalContentSizeCallback = null;
			_exitReconcilePending = false;
			_stack.Clear();
			_navigationBarConfigs.Clear();
			_toolbarItemConfigs.Clear();
			_toolbarMenuConfigs.Clear();
			base.Dispose();
		}

		public void SetNavigationChangeCallback(Action<string,int,bool> callback)
		{
			_navigationChangeCallback = callback;
		}

		public void SetNavigationStartedCallback(Action<string,int,bool> callback)
		{
			_navigationStartedCallback = callback;
		}

		public void SetModalDismissedCallback(Action callback)
		{
			_modalDismissedCallback = callback;
		}

		public void SetModalLaidOutCallback(Action<float2> callback)
		{
			_modalContentSizeCallback = callback;
		}

		/** Called with the dialog content's size, before it is shown and whenever it changes. */
		void NotifyModalLaidOut(int widthPx, int heightPx)
		{
			if (_modalContentSizeCallback != null)
				_modalContentSizeCallback(float2(widthPx, heightPx));
		}

		public void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop)
		{
			if (_contentView == null || _fragmentManager == null)
				return;

			var view = nativeHandle as Java.Object;
			if (view == null)
				return;

			var fragment = CreateFragment(view);

			if (isPush)
			{
				_stack.Add(templateName);
				PushFragment(_fragmentManager, _containerId, fragment, templateName);
			}
			else if (isPop)
			{
				// Return to a page that is already on the stack, dropping everything above it.
				int target = -1;
				for (int i = _stack.Count - 1; i >= 0; i--)
				{
					if (_stack[i] == templateName)
					{
						target = i;
						break;
					}
				}

				if (target < 0)
					return;

				while (_stack.Count > target + 1)
				{
					_stack.RemoveAt(_stack.Count - 1);
					PopFragment(_fragmentManager);
				}

				// The caller reports the start; reconcile after the outgoing pages finish animating.
				ReconcileAfterTransition();
			}
			else
			{
				_stack.Clear();
				_stack.Add(templateName);
				SetRootFragment(_fragmentManager, _containerId, fragment);
			}

			ApplyNavigationBarForCurrentPage();
		}

		public int GetNativeStackCount()
		{
			return _stack.Count;
		}

		public string[] GetNativeStackTemplates()
		{
			return _stack.ToArray();
		}

		public void PopFromNativeStack()
		{
			if (_stack.Count <= 1)
				return;

			_stack.RemoveAt(_stack.Count - 1);

			// Report the start before the transition, so page animations run in step with it.
			NotifyNavigationStarted();
			PopFragment(_fragmentManager);
			ApplyNavigationBarForCurrentPage();

			// Reconcile once the outgoing page has finished animating (or the fallback fires).
			ReconcileAfterTransition();
		}

		public void ConfigureNavigationBar(string templateName, NavigationBarProps config)
		{
			if (config == null || string.IsNullOrEmpty(templateName))
				return;

			_navigationBarConfigs[templateName] = config;

			if (config.ToolbarItems != null)
				_toolbarItemConfigs[templateName] = config.ToolbarItems;
			else if (_toolbarItemConfigs.ContainsKey(templateName))
				_toolbarItemConfigs.Remove(templateName);

			if (config.MenuItems != null)
				_toolbarMenuConfigs[templateName] = config.MenuItems;
			else if (_toolbarMenuConfigs.ContainsKey(templateName))
				_toolbarMenuConfigs.Remove(templateName);

			// Apply now if this template is visible; otherwise when it reaches the top of the stack.
			if (_stack.Count > 0 && _stack[_stack.Count - 1] == templateName)
				ApplyToolbarConfiguration(_toolbar, config);
		}

		public void PresentView(object nativeHandle, string templateName, ModalPresentationStyle style, bool dragToDismiss, bool expandable)
		{
			if (_fragmentManager == null)
				return;

			var view = nativeHandle as Java.Object;
			if (view == null)
				return;

			var modal = new PresentedModal
			{
				Dialog = CreateDialogFragment(view, DialogStyle(style), dragToDismiss, expandable),
				Template = templateName,
				Style = style,
			};
			_presentedModals.Add(modal);

			// Only full screen spans the app frame; the other styles follow the size the dialog's content
			// is given (see NotifyModalLaidOut), so the page is re-laid out at it.
			if (style != ModalPresentationStyle.FullScreen)
				ObserveDialogContentSize(modal.Dialog);

			// Let the user drag the sheet styles down to dismiss.
			ObserveDialogDismissByDrag(modal.Dialog);

			ShowDialog(_fragmentManager, modal.Dialog, templateName);

			// The dialog's view (and toolbar) exists only after the transaction runs, so apply its bar later.
			NavigationBarProps config = null;
			if (!string.IsNullOrEmpty(templateName))
				_navigationBarConfigs.TryGetValue(templateName, out config);

			ApplyModalNavigationBar(modal.Dialog, config, templateName, 0);
		}

		/** The `NavigationDialogFragment.STYLE_*` constant for a presentation style. */
		static int DialogStyle(ModalPresentationStyle style)
		{
			switch (style)
			{
				case ModalPresentationStyle.PageSheet: return 1; // STYLE_PAGE_SHEET
				case ModalPresentationStyle.FormSheet: return 2; // STYLE_FORM_SHEET
				case ModalPresentationStyle.Sheet: return 3; // STYLE_SHEET
			}
			return 0; // STYLE_FULL_SCREEN
		}

		public void DismissView()
		{
			var modal = CurrentModal;
			if (modal == null)
				return;

			// Pop it, so the modal below it becomes current again and can itself be dismissed.
			_presentedModals.RemoveAt(_presentedModals.Count - 1);

			// The dialog slides down and reports when gone (see NotifyModalDismissed), so the page is not
			// released while still on screen.
			DismissDialogAnimated(modal.Dialog);
		}

		/**
			Dismisses each dialog immediately and silently. Used when the view is going away: the shared layer
			releases the presented pages itself, and the user-dismiss callback must not re-enter it.
		*/
		public void DismissAllModals()
		{
			for (int i = _presentedModals.Count - 1; i >= 0; i--)
				DismissDialogForTeardown(_presentedModals[i].Dialog);

			_presentedModals.Clear();
		}

		[Foreign(Language.Java)]
		static void DismissDialogForTeardown(Java.Object dialog)
		@{
			com.fuse.controls.nativenavigation.NavigationDialogFragment d =
				(com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog;
			if (d == null) return;

			d.setOnDismissedByUser(null);
			d.dismissAllowingStateLoss();
		@}

		/** Called by the dialog once its dismissal animation has finished. */
		void NotifyModalDismissed()
		{
			if (_modalDismissedCallback != null)
				_modalDismissedCallback();
		}

		public void SetModalExpanded(bool expanded)
		{
			var modal = CurrentModal;
			if (modal == null)
				return;

			SetDialogExpanded(modal.Dialog, expanded);
		}

		/** Gives the dialog the page sheet's size, or its own back (see setExpanded). */
		[Foreign(Language.Java)]
		static void SetDialogExpanded(Java.Object dialog, bool expanded)
		@{
			((com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog).setExpanded(expanded, true);
		@}

		public float4 GetModalSafeAreaInsets()
		{
			if (_containerView == null)
				return float4(0);

			// A modal whose template declares no bar is not inset for one (see ModalHasNavigationBar).
			float barHeight = ModalHasNavigationBar() ? _toolbarHeightPoints : 0;

			// Only a full-screen cover reaches under the system bars; a sheet or card sits inside them,
			// so only its own bar has to be cleared at the top.
			var modal = CurrentModal;
			if (modal != null && modal.Style != ModalPresentationStyle.FullScreen)
				return float4(0, barHeight, 0, 0);

			// The modal page is laid out at the app frame, whose origin is below the status bar, so its
			// inset is bar height on top and status bar + navigation bar at the bottom.
			float l = GetSystemInsetLeft(_containerView);
			float t = GetSystemInsetTop(_containerView);
			float r = GetSystemInsetRight(_containerView);
			float b = GetSystemInsetBottom(_containerView);

			return float4(l, barHeight, r, t + b);
		}

		/** Whether the top modal's template declares a bar and does not hide it. */
		bool ModalHasNavigationBar()
		{
			var modal = CurrentModal;
			if (modal == null || string.IsNullOrEmpty(modal.Template))
				return false;

			NavigationBarProps config = null;
			if (!_navigationBarConfigs.TryGetValue(modal.Template, out config))
				return false;

			return !config.Hidden;
		}

		/**
			Applies the modal's bar config once its view exists, retrying over a few frames. A null config
			leaves the modal with no bar, as for a page.
		*/
		void ApplyModalNavigationBar(Java.Object dialog, NavigationBarProps config, string templateName, int attempt)
		{
			if (dialog == null)
				return;

			var toolbar = GetDialogToolbar(dialog);
			if (toolbar == null)
			{
				if (attempt < 5)
					UpdateManager.PerformNextFrame(() => ApplyModalNavigationBar(dialog, config, templateName, attempt + 1));
				return;
			}

			if (config == null)
			{
				SetToolbarHidden(toolbar, true);
				return;
			}

			ApplyToolbarConfiguration(toolbar, config);
		}

		public float4 GetNavigationSafeInsets(string templateName)
		{
			if (_containerView == null)
				return float4(0);

			// The modal's own bar (when this template is on top) uses the modal insets.
			var modal = CurrentModal;
			if (modal != null && !string.IsNullOrEmpty(templateName) && templateName == modal.Template)
				return GetModalSafeAreaInsets();

			float l = GetSystemInsetLeft(_containerView);
			float t = GetSystemInsetTop(_containerView);
			float r = GetSystemInsetRight(_containerView);
			float b = GetSystemInsetBottom(_containerView);

			// A hidden bar consumes no space and does not cover the status bar.
			NavigationBarProps config = null;
			if (!string.IsNullOrEmpty(templateName))
				_navigationBarConfigs.TryGetValue(templateName, out config);
			if (config == null && _stack.Count > 0)
				_navigationBarConfigs.TryGetValue(_stack[_stack.Count - 1], out config);

			if (config != null && config.Hidden)
				return float4(l, t, r, b);

			// The bar overlays the content, so its height plus the status bar is the top inset.
			return float4(l, t + _toolbarHeightPoints, r, b);
		}

		void ApplyNavigationBarForCurrentPage()
		{
			if (_toolbar == null)
				return;

			string templateName = _stack.Count > 0 ? _stack[_stack.Count - 1] : null;

			NavigationBarProps config = null;
			if (templateName != null)
				_navigationBarConfigs.TryGetValue(templateName, out config);

			UpdateToolbarNavigation(_toolbar, _stack.Count > 1,
				config != null ? (config.BackButtonTitle ?? "Back") : "Back");

			if (templateName == null)
				return;

			if (config != null)
				ApplyToolbarConfiguration(_toolbar, config);
			else
			{
				// No config means no bar: without a NavigationBarConfig nothing applies the content inset
				// (see GetNavigationSafeInsets), so a bar would cover uninset content.
				SetToolbarHidden(_toolbar, true);
			}
		}

		void ApplyToolbarConfiguration(Java.Object toolbar, NavigationBarProps config)
		{
			if (toolbar == null || config == null)
				return;

			SetToolbarTitle(toolbar, config.Title ?? "");
			SetToolbarHidden(toolbar, config.Hidden);

			// A translucent bar keeps its colour, but a fully opaque background is reduced so the content
			// under the overlaid bar stays visible.
			var background = config.BackgroundColor;
			if (config.Translucent && background.W >= 1.0f)
				background.W = 0.8f;

			int foregroundArgb = (int)Uno.Color.ToArgb(config.ForegroundColor);
			SetToolbarColors(toolbar, (int)Uno.Color.ToArgb(background), foregroundArgb);

			var items = config.ToolbarItems ?? new ToolbarItemProps[0];
			var menuItems = config.MenuItems ?? new ToolbarMenuItemProps[0];
			var iconColor = (int)Uno.Color.ToArgb(config.TintColor);
			var icons = LoadToolbarIcons(items, iconColor);
			var menuIcons = LoadMenuIcons(menuItems, iconColor);

			BeginToolbarItems(toolbar);
			var leadingItems = BeginLeadingItems(toolbar, NeedsLeadingItems(items, menuItems));

			for (int i = 0; i < items.Length; i++)
			{
				var item = items[i];
				var icon = icons[i];
				bool hasChildren = HasMenuChildren(menuItems, i);

				// Hidden items are not built, and an item's id carries its index (see OnToolbarActionClicked),
				// so hiding one does not move the others.
				if (!item.Visible)
					continue;

				if (string.IsNullOrEmpty(item.Title) && icon == null && !hasChildren)
					continue;

				// Leading items that are not menus become leading buttons; everything else lives in the toolbar menu
				// (which is laid out on the trailing side by the Toolbar itself).
				if (ToolbarItemPositions.IsLeading(item.Position) && !hasChildren)
				{
					var textColor = item.HasColor
						? (int)Uno.Color.ToArgb(float4(item.ColorR, item.ColorG, item.ColorB, item.ColorA))
						: foregroundArgb;
					AddLeadingItem(leadingItems, ToolbarItemIdBase + i, item.Title ?? "", item.Enabled, icon, textColor, item.AccessibilityLabel);
					continue;
				}

				if (hasChildren)
				{
					var sub = AddToolbarSubMenuEntry(toolbar, ToolbarItemIdBase + i, item.Title ?? "", item.Enabled, icon, item.AccessibilityLabel);
					for (int k = 0; k < menuItems.Length; k++)
					{
						if (menuItems[k].ToolbarIndex != i || !menuItems[k].Visible)
							continue;

						// The id carries the flattened menu index back to OnToolbarActionClicked.
						AddSubMenuEntry(sub, MenuItemIdBase + k, menuItems[k].Title ?? "", menuItems[k].Enabled, menuIcons[k], menuItems[k].AccessibilityLabel);
					}
				}
				else
				{
					AddToolbarEntry(toolbar, ToolbarItemIdBase + i, item.Title ?? "", item.Enabled, icon, item.AccessibilityLabel);
				}
			}

			ReleaseUnusedImageIcons();
		}

		/** Whether any toolbar item is declared on the leading side and renders as a leading button. */
		static bool NeedsLeadingItems(ToolbarItemProps[] items, ToolbarMenuItemProps[] menuItems)
		{
			for (int i = 0; i < items.Length; i++)
			{
				if (items[i].Visible && ToolbarItemPositions.IsLeading(items[i].Position) && !HasMenuChildren(menuItems, i))
					return true;
			}
			return false;
		}

		/** Whether the item at `itemIndex` has any pull-down entry that is shown. */
		static bool HasMenuChildren(ToolbarMenuItemProps[] menuItems, int itemIndex)
		{
			for (int k = 0; k < menuItems.Length; k++)
			{
				if (menuItems[k].Visible && menuItems[k].ToolbarIndex == itemIndex)
					return true;
			}
			return false;
		}

		void ReleaseImageIcons()
		{
			foreach (var handle in _imageIconHandles.Values)
				handle.Dispose();

			_imageIconHandles.Clear();
			_pendingImageIcons.Clear();
		}

		/**
			Releases pinned images no stored configuration refers to, so reconfiguring a template does not
			keep its old icons pinned for the life of the view.
		*/
		void ReleaseUnusedImageIcons()
		{
			if (_imageIconHandles.Count == 0)
				return;

			var used = new HashSet<string>();
			foreach (var config in _navigationBarConfigs.Values)
				ToolbarIconSource.CollectKeys(config, used);

			// Collect before removing: the map cannot be modified while it is enumerated.
			List<string> unused = null;
			foreach (var key in _imageIconHandles.Keys)
			{
				if (used.Contains(key))
					continue;

				if (unused == null)
					unused = new List<string>();
				unused.Add(key);
			}

			if (unused == null)
				return;

			for (int i = 0; i < unused.Count; i++)
			{
				_imageIconHandles[unused[i]].Dispose();
				_imageIconHandles.Remove(unused[i]);
			}
		}

		Java.Object[] LoadToolbarIcons(ToolbarItemProps[] items, int defaultColorArgb)
		{
			var icons = new Java.Object[items.Length];
			for (int i = 0; i < items.Length; i++)
			{
				var item = items[i];
				var color = item.HasColor
					? (int)Uno.Color.ToArgb(float4(item.ColorR, item.ColorG, item.ColorB, item.ColorA))
					: defaultColorArgb;
				icons[i] = LoadToolbarIcon(item.Symbols, item.IsFilled, item.Icon, color);
			}
			return icons;
		}

		Java.Object[] LoadMenuIcons(ToolbarMenuItemProps[] items, int defaultColorArgb)
		{
			var icons = new Java.Object[items.Length];
			for (int i = 0; i < items.Length; i++)
				icons[i] = LoadToolbarIcon(items[i].Symbols, items[i].IsFilled, items[i].Icon, defaultColorArgb);
			return icons;
		}

		Java.Object LoadToolbarIcon(string symbols, bool isFilled, ImageSource source, int colorArgb)
		{
			if (!string.IsNullOrEmpty(symbols))
				return CreateSymbolDrawable(symbols, isFilled, colorArgb);

			if (source == null)
				return null;

			var file = source as FileImageSource;
			if (file != null)
				return CreateFileIconDrawable(file, colorArgb);

			var http = source as HttpImageSource;
			if (http != null)
				return CreateHttpIconDrawable(http, colorArgb);

			Fuse.Diagnostics.UserWarning("Unsupported toolbar icon source: " + source, _fuseHost);
			return null;
		}

		/** A drawable for an icon bundled with the app, loading (and pinning) the image on first use only. */
		Java.Object CreateFileIconDrawable(FileImageSource file, int colorArgb)
		{
			var key = ToolbarIconSource.Key(file);
			if (key == null)
				return null;

			ImageHandle handle;
			if (!_imageIconHandles.TryGetValue(key, out handle))
			{
				handle = ImageLoader.Load(file.File);
				if (handle == null)
					return null;

				_imageIconHandles.Add(key, handle);
			}

			return CreateBitmapDrawable(handle.Handle as Java.Object, colorArgb);
		}

		/**
			A drawable for a URL icon, or null while it downloads. The URL is requested once; the bar is
			re-applied when the image arrives (see OnToolbarIconLoaded).
		*/
		Java.Object CreateHttpIconDrawable(HttpImageSource http, int colorArgb)
		{
			var key = ToolbarIconSource.Key(http);
			if (key == null)
				return null;

			ImageHandle handle;
			if (_imageIconHandles.TryGetValue(key, out handle))
				return CreateBitmapDrawable(handle.Handle as Java.Object, colorArgb);

			if (_pendingImageIcons.Add(key))
				ImageLoader.Load(http).Then(OnToolbarIconLoaded, OnToolbarIconFailed);

			return null;
		}

		Java.Object CreateSymbolDrawable(string symbols, bool isFilled, int colorArgb)
		{
			return CreateSymbolDrawableImpl(GetSymbolsFontPath(), symbols, GetIconSizePx(), isFilled, colorArgb);
		}

		void OnToolbarIconLoaded(ImageHandle handle)
		{
			if (handle == null)
				return;

			// The handle is named after its URL, which is the icon's key; pin it like a bundled icon.
			_pendingImageIcons.Remove(handle.Name);
			_imageIconHandles[handle.Name] = handle;
			ApplyNavigationBarForCurrentPage();
		}

		void OnToolbarIconFailed(Exception e)
		{
			// The URL is left marked as pending, so it is not requested again on every later apply pass.
			Fuse.Diagnostics.UserWarning("Failed to load toolbar icon: " + e.Message, _fuseHost);
		}

		/**
			The asset path of the Material Symbols font bundled by Fuse.Controls.Native, or null.
		*/
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

		/**
			Routes a click by the menu id: leading/action items use ToolbarItemIdBase, pull-down entries
			MenuItemIdBase.
		*/
		void OnToolbarActionClicked(int itemId)
		{
			if (itemId <= 0)
				return;

			if (itemId >= MenuItemIdBase)
			{
				OnMenuItemClicked(itemId - MenuItemIdBase);
				return;
			}

			if (itemId >= ToolbarItemIdBase)
				OnToolbarItemClicked(itemId - ToolbarItemIdBase);
		}

		/** The template whose bar is currently shown (the modal takes precedence when one is presented). */
		string CurrentBarTemplate()
		{
			var modal = CurrentModal;
			if (modal != null && !string.IsNullOrEmpty(modal.Template))
				return modal.Template;

			return _stack.Count > 0 ? _stack[_stack.Count - 1] : null;
		}

		void OnToolbarItemClicked(int itemIndex)
		{
			string templateName = CurrentBarTemplate();
			if (templateName == null)
				return;

			ToolbarItemProps[] items;
			if (!_toolbarItemConfigs.TryGetValue(templateName, out items) || items == null)
				return;

			if (itemIndex < 0 || itemIndex >= items.Length)
				return;

			var item = items[itemIndex];
			if (item != null && item.Source != null)
				item.Source.TriggerClicked();
		}

		void OnMenuItemClicked(int menuIndex)
		{
			string templateName = CurrentBarTemplate();
			if (templateName == null)
				return;

			ToolbarMenuItemProps[] menuItems;
			if (!_toolbarMenuConfigs.TryGetValue(templateName, out menuItems) || menuItems == null)
				return;

			if (menuIndex < 0 || menuIndex >= menuItems.Length)
				return;

			var item = menuItems[menuIndex];
			if (item != null && item.Source != null)
				item.Source.TriggerClicked();
		}

		void OnBackClicked()
		{
			// The back arrow pops like the shared layer's GoBack, keeping `_stack` authoritative.
			PopFromNativeStack();
		}

		void NotifyNavigationChanged()
		{
			if (_navigationChangeCallback != null && _stack.Count > 0)
				_navigationChangeCallback(_stack[_stack.Count - 1], _stack.Count, true);
		}

		/**
			Reports that a navigation is starting, so page animations run with the native transition; the
			reconcile follows once it has finished (see ReconcileAfterTransition).
		*/
		void NotifyNavigationStarted()
		{
			if (_navigationStartedCallback != null && _stack.Count > 0)
				_navigationStartedCallback(_stack[_stack.Count - 1], _stack.Count, true);
		}

		/**
			Reconciles once the outgoing page's exit animation has finished, so it is not disposed mid-animation;
			the timer covers platforms that run no animation.
		*/
		void ReconcileAfterTransition()
		{
			if (_exitReconcilePending)
				return;

			_exitReconcilePending = true;
			PostFragmentExited(_containerView, TransitionFallbackMs);
		}

		/**
			Called when a popped fragment's view finished its exit animation; guarded so the real signal and
			the fallback reconcile only once.
		*/
		void OnFragmentExited()
		{
			if (!_exitReconcilePending)
				return;

			_exitReconcilePending = false;
			NotifyNavigationChanged();
		}

		/**
			Called when the fragment back stack changes. Our own push/pop already updated `_stack`, so this
			only reacts to a system back or swipe pop, where the stack has shrunk.
		*/
		void OnBackStackChanged()
		{
			if (_fragmentManager == null)
				return;

			int nativeCount = 1 + GetBackStackEntryCount(_fragmentManager);
			if (nativeCount >= _stack.Count)
				return;

			while (_stack.Count > nativeCount)
				_stack.RemoveAt(_stack.Count - 1);

			// Report the new page right away, so animations run with the fragment transition.
			NotifyNavigationStarted();
			ApplyNavigationBarForCurrentPage();
			ReconcileAfterTransition();
		}

		// -------- Structure --------

		[Foreign(Language.Java)]
		static Java.Object CreateContainer()
		@{
			android.widget.FrameLayout root = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			root.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			return root;
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateToolbar(Java.Object root)
		@{
			androidx.appcompat.widget.Toolbar toolbar =
				com.fuse.controls.nativenavigation.NavigationUi.createOverlayToolbar(com.fuse.Activity.getRootActivity());
			// Shown once a NavigationBarConfig is applied to the visible page.
			toolbar.setVisibility(android.view.View.GONE);
			((android.widget.FrameLayout)root).addView(toolbar);
			((android.widget.FrameLayout)root).bringChildToFront(toolbar);
			return toolbar;
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateContentView(Java.Object root)
		@{
			android.widget.FrameLayout content = new android.widget.FrameLayout(com.fuse.Activity.getRootActivity());
			content.setLayoutParams(new android.widget.FrameLayout.LayoutParams(
				android.view.ViewGroup.LayoutParams.MATCH_PARENT,
				android.view.ViewGroup.LayoutParams.MATCH_PARENT));
			((android.widget.FrameLayout)root).addView(content);
			return content;
		@}

		[Foreign(Language.Java)]
		static int SetContainerId(Java.Object container)
		@{
			int id = android.view.View.generateViewId();
			((android.view.View)container).setId(id);
			return id;
		@}

		// -------- Fragments --------

		[Foreign(Language.Java)]
		static Java.Object GetFragmentManager()
		@{
			androidx.fragment.app.FragmentActivity activity =
				(androidx.fragment.app.FragmentActivity)com.fuse.Activity.getRootActivity();
			return activity.getSupportFragmentManager();
		@}

		[Foreign(Language.Java)]
		static int GetBackStackEntryCount(Java.Object fragmentManager)
		@{
			return ((androidx.fragment.app.FragmentManager)fragmentManager).getBackStackEntryCount();
		@}

		[Foreign(Language.Java)]
		Java.Object CreateFragment(Java.Object content)
		@{
			return new com.fuse.controls.nativenavigation.FuseNavigationFragment(
				(android.view.View)content,
				new java.lang.Runnable() { public void run() {
					@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).OnFragmentExited():call()};
				}});
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateDialogFragment(Java.Object content, int style, bool dragToDismiss, bool expandable)
		@{
			return new com.fuse.controls.nativenavigation.NavigationDialogFragment((android.view.View)content, style, dragToDismiss, expandable);
		@}

		[Foreign(Language.Java)]
		static void ShowDialog(Java.Object fragmentManager, Java.Object dialog, string tag)
		@{
			((com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog)
				.show((androidx.fragment.app.FragmentManager)fragmentManager, tag);
		@}

		/**
			Reports the content's size before the modal slides in and whenever it changes (a sheet dragged
			up to the page sheet size), so the page is laid out at it.
		*/
		[Foreign(Language.Java)]
		void ObserveDialogContentSize(Java.Object dialog)
		@{
			final com.fuse.controls.nativenavigation.NavigationDialogFragment d =
				(com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog;
			java.lang.Runnable report = new java.lang.Runnable() { public void run() {
				android.view.View content = d.getContent();
				if (content == null)
					return;
				@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).NotifyModalLaidOut(int,int):call(content.getWidth(), content.getHeight())};
			}};
			d.setOnLaidOut(report);
			d.setOnContentSizeChanged(report);
		@}

		/** Lets the user drag the modal's card down to dismiss it (see NavigationDialogFragment). */
		[Foreign(Language.Java)]
		void ObserveDialogDismissByDrag(Java.Object dialog)
		@{
			((com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog).setOnDismissedByUser(
				new java.lang.Runnable() { public void run() {
					@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).NotifyModalDismissedByUser():call()};
				}});
		@}

		/**
			Called when the user dragged the modal away; the dismissal goes through the shared layer so the page
			is released and the navigation state stays in step.
		*/
		void NotifyModalDismissedByUser()
		{
			if (_fuseHost != null)
				_fuseHost.DismissModal();
		}

		/** Slides the dialog down, dismisses it, and reports completion through `NotifyModalDismissed`. */
		[Foreign(Language.Java)]
		void DismissDialogAnimated(Java.Object dialog)
		@{
			((com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog).dismissAnimated(
				new java.lang.Runnable() { public void run() {
					@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).NotifyModalDismissed():call()};
				}});
		@}

		[Foreign(Language.Java)]
		static Java.Object GetDialogToolbar(Java.Object dialog)
		@{
			if (dialog == null) return null;
			return ((com.fuse.controls.nativenavigation.NavigationDialogFragment)dialog).getToolbar();
		@}

		[Foreign(Language.Java)]
		static void SetRootFragment(Java.Object fragmentManager, int containerId, Java.Object fragment)
		@{
			androidx.fragment.app.FragmentManager fm = (androidx.fragment.app.FragmentManager)fragmentManager;
			fm.beginTransaction()
				.replace(containerId, (androidx.fragment.app.Fragment)fragment)
				.commit();
		@}

		[Foreign(Language.Java)]
		static void PushFragment(Java.Object fragmentManager, int containerId, Java.Object fragment, string name)
		@{
			androidx.fragment.app.FragmentManager fm = (androidx.fragment.app.FragmentManager)fragmentManager;
			// appcompat's default open/close animations, so pages animate like a native stack.
			fm.beginTransaction()
				.setCustomAnimations(
					androidx.fragment.R.animator.fragment_open_enter,
					androidx.fragment.R.animator.fragment_open_exit,
					androidx.fragment.R.animator.fragment_close_enter,
					androidx.fragment.R.animator.fragment_close_exit)
				.replace(containerId, (androidx.fragment.app.Fragment)fragment)
				.addToBackStack(name)
				.commit();
		@}

		[Foreign(Language.Java)]
		static void PopFragment(Java.Object fragmentManager)
		@{
			((androidx.fragment.app.FragmentManager)fragmentManager).popBackStack();
		@}

		[Foreign(Language.Java)]
		void RegisterBackStackListener(Java.Object fragmentManager)
		@{
			((androidx.fragment.app.FragmentManager)fragmentManager).addOnBackStackChangedListener(
				new androidx.fragment.app.FragmentManager.OnBackStackChangedListener() {
					public void onBackStackChanged() {
						@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).OnBackStackChanged():call()};
					}
				});
		@}

		/** Runs `OnFragmentExited` after a delay, as a fallback for transitions without an animation. */
		[Foreign(Language.Java)]
		void PostFragmentExited(Java.Object view, int delayMs)
		@{
			android.view.View v = (android.view.View)view;
			if (v == null) return;
			v.postDelayed(new Runnable() { public void run() {
				@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).OnFragmentExited():call()};
			}}, delayMs);
		@}

		[Foreign(Language.Java)]
		void RegisterBackHandler(Java.Object fragmentManager)
		@{
			final androidx.fragment.app.FragmentManager fm =
				(androidx.fragment.app.FragmentManager)fragmentManager;
			if (fm == null) return;

			androidx.activity.ComponentActivity activity =
				(androidx.activity.ComponentActivity)com.fuse.Activity.getRootActivity();

			activity.getOnBackPressedDispatcher().addCallback(new androidx.activity.OnBackPressedCallback(true) {
				public void handleOnBackPressed() {
					if (fm.getBackStackEntryCount() > 0) {
						fm.popBackStack();
						return;
					}
					// Nothing of ours to pop -- let the app (Fuse) handle the back press.
					setEnabled(false);
					((androidx.activity.ComponentActivity)com.fuse.Activity.getRootActivity())
						.getOnBackPressedDispatcher().onBackPressed();
					setEnabled(true);
				}
			});
		@}

		// -------- Toolbar: appearance --------

		[Foreign(Language.Java)]
		static void SetToolbarTitle(Java.Object toolbar, string title)
		@{
			((androidx.appcompat.widget.Toolbar)toolbar).setTitle(title);
		@}

		[Foreign(Language.Java)]
		static void SetToolbarHidden(Java.Object toolbar, bool hidden)
		@{
			((androidx.appcompat.widget.Toolbar)toolbar).setVisibility(
				hidden ? android.view.View.GONE : android.view.View.VISIBLE);
		@}

		[Foreign(Language.Java)]
		static void SetToolbarColors(Java.Object toolbar, int backgroundArgb, int foregroundArgb)
		@{
			androidx.appcompat.widget.Toolbar t = (androidx.appcompat.widget.Toolbar)toolbar;
			t.setBackgroundColor(backgroundArgb);
			t.setTitleTextColor(foregroundArgb);
		@}

		[Foreign(Language.Java)]
		static float GetToolbarHeightPoints()
		@{
			return com.fuse.controls.nativenavigation.NavigationUi.actionBarHeightPoints();
		@}

		// -------- System insets --------
		// Java foreign code cannot return a `float4`, so the insets are read one component at a time.

		[Foreign(Language.Java)]
		static float GetSystemInsetLeft(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			if (v == null || android.os.Build.VERSION.SDK_INT < 23) return 0.0f;
			android.graphics.Rect r = com.fuse.controls.nativenavigation.NavigationUi.systemBars(v.getContext(), v.getRootWindowInsets());
			return r.left / v.getResources().getDisplayMetrics().density;
		@}

		[Foreign(Language.Java)]
		static float GetSystemInsetTop(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			if (v == null || android.os.Build.VERSION.SDK_INT < 23) return 0.0f;
			android.graphics.Rect r = com.fuse.controls.nativenavigation.NavigationUi.systemBars(v.getContext(), v.getRootWindowInsets());
			return r.top / v.getResources().getDisplayMetrics().density;
		@}

		[Foreign(Language.Java)]
		static float GetSystemInsetRight(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			if (v == null || android.os.Build.VERSION.SDK_INT < 23) return 0.0f;
			android.graphics.Rect r = com.fuse.controls.nativenavigation.NavigationUi.systemBars(v.getContext(), v.getRootWindowInsets());
			return r.right / v.getResources().getDisplayMetrics().density;
		@}

		[Foreign(Language.Java)]
		static float GetSystemInsetBottom(Java.Object view)
		@{
			android.view.View v = (android.view.View)view;
			if (v == null || android.os.Build.VERSION.SDK_INT < 23) return 0.0f;
			android.graphics.Rect r = com.fuse.controls.nativenavigation.NavigationUi.systemBars(v.getContext(), v.getRootWindowInsets());
			return r.bottom / v.getResources().getDisplayMetrics().density;
		@}

		// -------- Toolbar: items --------

		[Foreign(Language.Java)]
		void BeginToolbarItems(Java.Object toolbar)
		@{
			final androidx.appcompat.widget.Toolbar t = (androidx.appcompat.widget.Toolbar)toolbar;
			t.getMenu().clear();
			t.setOnMenuItemClickListener(new androidx.appcompat.widget.Toolbar.OnMenuItemClickListener() {
				public boolean onMenuItemClick(android.view.MenuItem mi) {
					final int itemId = mi.getItemId();
					// Post the action: dismissing a dialog from inside its own menu-item click event leaves
					// the input focus in a bad state.
					t.post(new Runnable() { public void run() {
						@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).OnToolbarActionClicked(int):call(itemId)};
					}});
					return true;
				}
			});
		@}

		/**
			Replaces the bar's leading (`Position="Left"`) items with an empty container, or removes it when
			none are needed. Returns the container to add the items to, or null.
		*/
		[Foreign(Language.Java)]
		Java.Object BeginLeadingItems(Java.Object toolbar, bool needed)
		@{
			android.view.View t = (android.view.View)toolbar;
			if (!(t instanceof com.fuse.controls.nativenavigation.NavigationUi.InsetToolbar))
				return null;

			com.fuse.controls.nativenavigation.NavigationUi.InsetToolbar bar =
				(com.fuse.controls.nativenavigation.NavigationUi.InsetToolbar)t;

			if (!needed) {
				bar.setLeadingItems(null);
				return null;
			}

			com.fuse.controls.nativenavigation.LeadingToolbarItems leading =
				new com.fuse.controls.nativenavigation.LeadingToolbarItems(t.getContext());
			bar.setLeadingItems(leading);
			return leading;
		@}

		/** Adds one leading toolbar item, routing its click the same way as a menu action item. */
		[Foreign(Language.Java)]
		void AddLeadingItem(Java.Object container, int itemId, string title, bool enabled, Java.Object icon, int textColorArgb, string accessibilityLabel)
		@{
			if (container == null) return;

			android.view.View button =
				((com.fuse.controls.nativenavigation.LeadingToolbarItems)container)
					.addItem(itemId, title, enabled, (android.graphics.drawable.Drawable)icon, textColorArgb);

			String a11y = accessibilityLabel != null && !accessibilityLabel.isEmpty()
				? accessibilityLabel
				: (title != null && !title.isEmpty() ? title : null);
			if (a11y != null) button.setContentDescription(a11y);

			button.setOnClickListener(new android.view.View.OnClickListener() {
				public void onClick(android.view.View v) {
					final int itemId = v.getId();
					// Defer out of the click dispatch, as for the menu items above.
					v.post(new Runnable() { public void run() {
						@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).OnToolbarActionClicked(int):call(itemId)};
					}});
				}
			});
		@}

		/** Adds a top-level toolbar item. `icon` may be null. */
		[Foreign(Language.Java)]
		static void AddToolbarEntry(Java.Object toolbar, int id, string title, bool enabled, Java.Object icon, string accessibilityLabel)
		@{
			android.view.MenuItem entry = ((androidx.appcompat.widget.Toolbar)toolbar).getMenu()
				.add(android.view.Menu.NONE, id, android.view.Menu.NONE, title);
			entry.setShowAsAction(android.view.MenuItem.SHOW_AS_ACTION_ALWAYS);
			entry.setEnabled(enabled);
			if (icon != null) entry.setIcon((android.graphics.drawable.Drawable)icon);

			String a11y = accessibilityLabel != null && !accessibilityLabel.isEmpty()
				? accessibilityLabel
				: (title != null && !title.isEmpty() ? title : null);
			if (a11y != null) androidx.core.view.MenuItemCompat.setContentDescription(entry, a11y);
		@}

		/** Adds a top-level item that opens a pull-down, returning the sub-menu for its entries. */
		[Foreign(Language.Java)]
		static Java.Object AddToolbarSubMenuEntry(Java.Object toolbar, int id, string title, bool enabled, Java.Object icon, string accessibilityLabel)
		@{
			android.view.SubMenu sub = ((androidx.appcompat.widget.Toolbar)toolbar).getMenu()
				.addSubMenu(android.view.Menu.NONE, id, android.view.Menu.NONE, title);
			android.view.MenuItem entry = sub.getItem();
			entry.setShowAsAction(android.view.MenuItem.SHOW_AS_ACTION_ALWAYS);
			entry.setEnabled(enabled);
			if (icon != null) entry.setIcon((android.graphics.drawable.Drawable)icon);

			String a11y = accessibilityLabel != null && !accessibilityLabel.isEmpty()
				? accessibilityLabel
				: (title != null && !title.isEmpty() ? title : null);
			if (a11y != null) androidx.core.view.MenuItemCompat.setContentDescription(entry, a11y);
			return sub;
		@}

		/** Adds an entry to a pull-down created by AddToolbarSubMenuEntry. */
		[Foreign(Language.Java)]
		static void AddSubMenuEntry(Java.Object subMenu, int id, string title, bool enabled, Java.Object icon, string accessibilityLabel)
		@{
			android.view.MenuItem entry = ((android.view.SubMenu)subMenu)
				.add(android.view.Menu.NONE, id, android.view.Menu.NONE, title);
			entry.setEnabled(enabled);
			if (icon != null) entry.setIcon((android.graphics.drawable.Drawable)icon);

			String a11y = accessibilityLabel != null && !accessibilityLabel.isEmpty()
				? accessibilityLabel
				: (title != null && !title.isEmpty() ? title : null);
			if (a11y != null) androidx.core.view.MenuItemCompat.setContentDescription(entry, a11y);
		@}

		[Foreign(Language.Java)]
		void UpdateToolbarNavigation(Java.Object toolbar, bool showBack, string backTitle)
		@{
			androidx.appcompat.widget.Toolbar t = (androidx.appcompat.widget.Toolbar)toolbar;

			if (showBack) {
				t.setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material);
				t.setNavigationContentDescription((backTitle != null && backTitle.length() > 0) ? backTitle : "Back");
				final androidx.appcompat.widget.Toolbar bt = t;
				t.setNavigationOnClickListener(new android.view.View.OnClickListener() {
					public void onClick(android.view.View v) {
						// Defer out of the click dispatch, as above.
						bt.post(new Runnable() { public void run() {
							@{global::Fuse.Controls.Android.NativeNavigationViewImpl:of(_this).OnBackClicked():call()};
						}});
					}
				});
			} else {
				t.setNavigationIcon(null);
				t.setNavigationOnClickListener(null);
			}
		@}

		// -------- Icons --------

		[Foreign(Language.Java)]
		static string GetBundlePath(BundleFile bundleFile)
		@{
			return @{BundleFile:of(bundleFile).BundlePath:get()};
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateSymbolDrawableImpl(string fontPath, string ligature, int sizePx, bool filled, int colorArgb)
		@{
			return com.fuse.controls.nativenavigation.NavigationIcons.symbolDrawable(fontPath, ligature, sizePx, filled, colorArgb);
		@}

		[Foreign(Language.Java)]
		static Java.Object CreateBitmapDrawable(Java.Object bitmap, int colorArgb)
		@{
			return com.fuse.controls.nativenavigation.NavigationIcons.bitmapDrawable(bitmap, colorArgb);
		@}

		[Foreign(Language.Java)]
		static int GetIconSizePx()
		@{
			float density = com.fuse.Activity.getRootActivity().getResources().getDisplayMetrics().density;
			return (int)(24 * density + 0.5f);
		@}
	}

	extern(Android) internal static class NativeNavigationViewFactory
	{
		internal static Fuse.Controls.Native.IView Create(Fuse.Controls.NativeNavigationView host)
		{
			var impl = new NativeNavigationViewImpl();
			impl.SetHost(host);
			return impl;
		}
	}
}
