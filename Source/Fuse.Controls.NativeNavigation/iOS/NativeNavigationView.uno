using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;

using Fuse.Controls.Native;
using Fuse.Resources;

namespace Fuse.Controls.iOS
{
	[ForeignInclude(Language.ObjC, "iOS/ModalNavigationController.h")]
	[ForeignInclude(Language.ObjC, "iOS/ToolbarActionHandler.h")]
	extern(iOS) internal class NativeNavigationViewImpl : Fuse.Controls.Native.iOS.LeafView, INativeNavigationView
	{
		ObjC.Object _navigationController;
		ObjC.Object _containerView;
		ObjC.Object _navigationDelegate;
		ObjC.Object _toolbarActionHandler;
		ObjC.Object _modalDismissHandler;
		// Presented navigation controllers, bottom to top; the top one is current. The shared layer
		// keeps the same stack.
		readonly List<PresentedModal> _presentedModals = new List<PresentedModal>();

		/** A presented modal and its presentation style (for bar and insets). */
		class PresentedModal
		{
			public ObjC.Object Controller;
			public ModalPresentationStyle Style;
		}

		/** The modal on top of the stack, or null when none is presented. */
		PresentedModal CurrentModal { get { return _presentedModals.Count > 0 ? _presentedModals[_presentedModals.Count - 1] : null; } }
		Fuse.Controls.NativeNavigationView _fuseHost;

		// Per-template bar configuration.
		Dictionary<string, NavigationBarProps> _navigationBarConfigs = new Dictionary<string, NavigationBarProps>();

		// Flattened menu entries per template, used to route clicks.
		Dictionary<string, ToolbarMenuItemProps[]> _toolbarMenuConfigs = new Dictionary<string, ToolbarMenuItemProps[]>();

		// Callbacks into the shared layer.
		Action<string, int, bool> _navigationChangeCallback;
		Action<string, int, bool> _navigationStartedCallback;
		Action _modalDismissedCallback;
		Action<float2> _modalContentSizeCallback;

		public NativeNavigationViewImpl() : base(CreateContainer())
		{
			Initialize();
		}

		public void SetHost(Fuse.Controls.NativeNavigationView host)
		{
			_fuseHost = host;
		}

		void Initialize()
		{
			// No initial root controller.
			_navigationController = CreateNavigationController();

			// Transition delegate; installed for the controller's lifetime.
			_navigationDelegate = NativeNavigationDelegate.Create(
				OnWillShowViewController,
				OnDidShowViewController
			);
			NativeNavigationDelegate.SetAsDelegate(_navigationController, _navigationDelegate);

			_toolbarActionHandler = ToolbarActionHandler.Create(OnToolbarItemClicked, OnMenuItemClicked);

			// Held strongly: the presentation controller's delegate is weak (see ModalDismissHandler).
			_modalDismissHandler = ModalDismissHandler.Create(OnModalDismissedByPlatform);

			_containerView = GetNavigationView(_navigationController);
			AddNavigationViewToContainer(Handle, _containerView);
		}

		public override void Dispose()
		{
			DismissAllModals();

			if (_navigationDelegate != null)
			{
				NativeNavigationDelegate.Destroy(_navigationDelegate);
				_navigationDelegate = null;
			}

			if (_toolbarActionHandler != null)
			{
				ToolbarActionHandler.Destroy(_toolbarActionHandler);
				_toolbarActionHandler = null;
			}

			if (_modalDismissHandler != null)
			{
				ModalDismissHandler.Destroy(_modalDismissHandler);
				_modalDismissHandler = null;
			}

			ReleaseImageIcons();
			_lastBarNavigationController = null;
			_lastBarViewController = null;
			_lastBarConfig = null;
			_navigationChangeCallback = null;
			_navigationStartedCallback = null;
			_modalDismissedCallback = null;
			_modalContentSizeCallback = null;

			if (_navigationController != null)
			{
				ReleaseNavigationController(_navigationController);
				_navigationController = null;
			}

			_containerView = null;
		}

		public void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop)
		{
			if (_navigationController == null || nativeHandle == null)
				return;

			if (isPop)
			{
				// Nothing to pop below the root page.
				if (GetNativeStackCount() > 1)
					PopViewController(_navigationController);
			}
			else if (isPush)
			{
				// Each page has its own rendering context, so create its controller from the native view.
				var viewController = CreateViewControllerWithNativeHandle(nativeHandle, templateName);
				PushViewController(_navigationController, viewController);
			}
			else
			{
				// Initial navigation replaces the stack with a single root page.
				var viewController = CreateViewControllerWithNativeHandle(nativeHandle, templateName);
				SetRootViewController(_navigationController, viewController);

				// UIKit does not report a non-animated root change, so apply the bar here too (idempotent).
				ApplyBarForTemplate(templateName);
			}
		}

		public int GetNativeStackCount()
		{
			if (_navigationController != null)
			{
				return GetNavigationStackCount(_navigationController);
			}
			return 0;
		}

		public string[] GetNativeStackTemplates()
		{
			if (_navigationController != null)
			{
				ObjC.Object[] templateNames = GetNavigationStackTemplateNames(_navigationController);
				var result = new string[templateNames.Length];
				for (int i = 0; i < templateNames.Length; ++i)
				{
					result[i] = GetTemplateName(templateNames[i]);
				}
				return result;
			}
			return new string[0];
		}

		public void PopFromNativeStack()
		{
			if (_navigationController != null)
			{
				var stackCount = GetNativeStackCount();
				if (stackCount > 1)
				{
					PopViewController(_navigationController);
				}
			}
		}

		public void SetNavigationChangeCallback(Action<string, int, bool> callback)
		{
			_navigationChangeCallback = callback;
		}

		public void SetNavigationStartedCallback(Action<string, int, bool> callback)
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

		/** Called once the modal's content has been laid out, with its size in pixels. */
		void NotifyModalLaidOut(int widthPx, int heightPx)
		{
			if (_modalContentSizeCallback != null)
				_modalContentSizeCallback(float2(widthPx, heightPx));
		}

		ObjC.Object CreateViewControllerWithNativeHandle(object nativeHandle, string templateName)
		{
			var nativeView = nativeHandle as ObjC.Object;
			if (nativeView == null)
			{
				return CreatePlaceholderViewController(templateName, "Native handle is null");
			}

			try
			{
				return CreateViewControllerWithNativeView(nativeView, templateName);
			}
			catch (Exception e)
			{
				Fuse.Diagnostics.UserError("Failed to create view controller: " + e.Message, _fuseHost);
				return CreatePlaceholderViewController(templateName, "Failed to create view controller: " + e.Message);
			}
		}

		public void ConfigureNavigationBar(string templateName, NavigationBarProps config)
		{
			if (config == null || string.IsNullOrEmpty(templateName))
				return;

			// UIKit presents bar menus from the hierarchy, so the controller must be in it.
			EnsureInViewControllerHierarchy(_navigationController);

			_navigationBarConfigs[templateName] = config;

			// Keep toolbar items and menu entries for click routing.
			if (config.ToolbarItems != null)
			{
				_toolbarItemConfigs[templateName] = config.ToolbarItems;
			}
			else if (_toolbarItemConfigs.ContainsKey(templateName))
			{
				_toolbarItemConfigs.Remove(templateName);
			}

			if (config.MenuItems != null)
				_toolbarMenuConfigs[templateName] = config.MenuItems;
			else if (_toolbarMenuConfigs.ContainsKey(templateName))
				_toolbarMenuConfigs.Remove(templateName);

			// If this template is the top modal, apply to its bar.
			var modal = CurrentModal;
			var modalViewController = modal != null ? GetPresentedModalRootViewController(modal.Controller) : null;
			if (modalViewController != null && GetViewControllerAccessibilityIdentifier(modalViewController) == templateName)
			{
				ApplyNavigationBarConfiguration(modal.Controller, modalViewController, config);
				return;
			}

			// Otherwise apply now if this is the visible page.
			var currentViewController = GetCurrentViewController(_navigationController);
			if (currentViewController != null && GetViewControllerAccessibilityIdentifier(currentViewController) == templateName)
			{
				ApplyNavigationBarConfiguration(_navigationController, currentViewController, config);
			}
		}

		void ApplyNavigationBarConfiguration(ObjC.Object navigationController, ObjC.Object viewController, NavigationBarProps config)
		{
			if (navigationController == null || viewController == null || config == null)
				return;

			// Remember the bar so an async icon load can re-apply it.
			_lastBarNavigationController = navigationController;
			_lastBarViewController = viewController;
			_lastBarConfig = config;

			SetNavigationBarAppearance(navigationController, viewController, config.Title ?? "",
							config.BackgroundColor.X, config.BackgroundColor.Y, config.BackgroundColor.Z, config.BackgroundColor.W,
							config.ForegroundColor.X, config.ForegroundColor.Y, config.ForegroundColor.Z, config.ForegroundColor.W,
							config.TintColor.X, config.TintColor.Y, config.TintColor.Z, config.TintColor.W,
							config.LargeTitle, config.Translucent, config.Hidden, config.BackButtonTitle ?? "");

			if (config.ToolbarItems != null && config.ToolbarItems.Length > 0)
			{
				var menuItems = config.MenuItems ?? new ToolbarMenuItemProps[0];
				SetNavigationBarButtons(viewController, config.ToolbarItems, menuItems,
					LoadToolbarIcons(config.ToolbarItems), LoadMenuIcons(menuItems));
			}
			else
			{
				ClearNavigationBarButtons(viewController);
			}

			ReleaseUnusedImageIcons();
		}

		/** Called by the navigation delegate before a page is shown. */
		void OnWillShowViewController(string templateName)
		{
			ApplyBarForTemplate(templateName);

			// Report before the native transition so page animations run in step with it; the stack is
			// reconciled when navigation settles (OnDidShowViewController).
			if (_navigationStartedCallback != null)
				_navigationStartedCallback(templateName, GetNativeStackCount(), true);
		}

		/**
			Applies the bar for the template that just became the top page; a template with no stored
			config hides the bar, since its content is not inset for one (as on Android).
		*/
		void ApplyBarForTemplate(string templateName)
		{
			if (!string.IsNullOrEmpty(templateName) && _navigationBarConfigs.ContainsKey(templateName))
			{
				var viewController = GetCurrentViewController(_navigationController);
				if (viewController != null)
					ApplyNavigationBarConfiguration(_navigationController, viewController, _navigationBarConfigs[templateName]);
				return;
			}

			SetNavigationBarHidden(_navigationController, true);
		}

		void OnDidShowViewController(string templateName)
		{
			if (_navigationChangeCallback != null)
			{
				var stackCount = GetNativeStackCount();
				_navigationChangeCallback(templateName, stackCount, true);
			}
		}

		public void PresentView(object nativeHandle, string templateName, ModalPresentationStyle style, bool dragToDismiss, bool expandable)
		{
			if (_navigationController == null || nativeHandle == null)
				return;

			var viewController = CreateViewControllerWithNativeHandle(nativeHandle, templateName);
			if (viewController == null)
				return;

			// Wrap the page in its own navigation controller so it gets a separate bar.
			var modalNav = CreateModalNavigationController(viewController);
			var modal = new PresentedModal
			{
				Controller = PresentModal(_navigationController, modalNav, style, dragToDismiss, expandable),
				Style = style,
			};
			_presentedModals.Add(modal);

			// The modal reports each layout so its page follows the container (a sheet can grow to full
			// height). Installed after presentation so UIKit's presenting layout is not misreported.
			if (modal.Controller != null)
				SetModalLayoutCallback(modal.Controller, () => ReportModalLayout());

			// The config was applied while the template was still rooting, so apply it to the modal bar now.
			// A template with no config has no bar (same rule as a page) and is not inset for one.
			if (modal.Controller != null)
			{
				NavigationBarProps config = null;
				if (!string.IsNullOrEmpty(templateName) && _navigationBarConfigs.TryGetValue(templateName, out config))
					ApplyNavigationBarConfiguration(modal.Controller, viewController, config);
				else
					SetNavigationBarHidden(modal.Controller, true);
			}

			// Report once UIKit has laid the modal out, so the page's size and insets apply before it is
			// visible; waiting for the presentation to finish would show the content moving.
			ReportModalLaidOutWhenReady(0);
		}

		/**
			Called when the modal's view is laid out again (sheet expansion, rotation). Unchanged sizes
			are a no-op in the shared layer (see OnModalLaidOut), so they are not filtered here.
		*/
		void ReportModalLayout()
		{
			TryReportModalLaidOut();
		}

		public void SetModalExpanded(bool expanded)
		{
			var modal = CurrentModal;
			if (modal == null)
				return;

			SetModalControllerExpanded(modal.Controller, expanded);
		}

		/**
			Moves the sheet to its expanded size, or back. Before iOS 16 the selected detent cannot be
			set, so it is given only the detent it should be at (and cannot then be dragged back).
		*/
		[Foreign(Language.ObjC)]
		static void SetModalControllerExpanded(ObjC.Object modal, bool expanded)
		@{
			UIViewController* modalController = (UIViewController*)modal;
			if (modalController == nil) return;

			if (@available(iOS 15.0, *))
			{
				UISheetPresentationController* sheet = modalController.sheetPresentationController;
				if (sheet == nil) return;

				if (@available(iOS 16.0, *))
				{
					[sheet animateChanges:^{
						sheet.selectedDetentIdentifier = expanded
							? UISheetPresentationControllerDetentIdentifierLarge
							: UISheetPresentationControllerDetentIdentifierMedium;
					}];
				}
				else
				{
					[sheet animateChanges:^{
						sheet.detents = expanded
							? @[UISheetPresentationControllerDetent.largeDetent]
							: @[UISheetPresentationControllerDetent.mediumDetent];
					}];
				}
			}
		@}

		/**
			Reports the modal's geometry once UIKit has laid it out (its view is in a window), retrying a
			few frames; the presentation completion is the fallback. Reporting twice is harmless.
		*/
		void ReportModalLaidOutWhenReady(int attempt)
		{
			if (CurrentModal == null)
				return;

			if (!TryReportModalLaidOut() && attempt < 5)
				UpdateManager.PerformNextFrame(() => ReportModalLaidOutWhenReady(attempt + 1));
		}

		/** Reports the modal content size in pixels; false while its view has no window yet. */
		bool TryReportModalLaidOut()
		{
			var modal = CurrentModal;
			if (modal == null || modal.Controller == null)
				return true;

			int widthPx, heightPx;
			if (!GetModalContentPixelSize(modal.Controller, out widthPx, out heightPx))
				return false;

			NotifyModalLaidOut(widthPx, heightPx);
			return true;
		}

		/** Reports a user-dragged dismissal so the shared layer can release the page. */
		void OnModalDismissedByPlatform()
		{
			if (_fuseHost != null)
				_fuseHost.OnModalDismissedByPlatform();
		}

		public void DismissView()
		{
			var modal = CurrentModal;
			if (modal == null)
				return;

			// Pop it, so the modal below it becomes current again and can itself be dismissed.
			_presentedModals.RemoveAt(_presentedModals.Count - 1);

			// Release the page only once the animated dismissal has finished (see NotifyModalDismissed).
			DismissModal(modal.Controller);
		}

		/**
			Dismisses each presented controller immediately and silently. Used when the view is going away: the
			shared layer releases the presented pages itself.
		*/
		public void DismissAllModals()
		{
			for (int i = _presentedModals.Count - 1; i >= 0; i--)
			{
				var modal = _presentedModals[i];
				if (modal != null && modal.Controller != null)
					DismissModalForTeardown(modal.Controller);
			}

			_presentedModals.Clear();
		}

		[Foreign(Language.ObjC)]
		static void DismissModalForTeardown(ObjC.Object controller)
		@{
			UIViewController* vc = (UIViewController*)controller;
			if (vc == nil)
				return;

			UIViewController* presenter = vc.presentingViewController;
			if (presenter != nil)
				[presenter dismissViewControllerAnimated:NO completion:nil];
		@}

		/** Called by the dismissal once it has finished animating. */
		void NotifyModalDismissed()
		{
			if (_modalDismissedCallback != null)
				_modalDismissedCallback();
		}

		// Last applied bar, for re-applying after an async icon load.
		ObjC.Object _lastBarNavigationController;
		ObjC.Object _lastBarViewController;
		NavigationBarProps _lastBarConfig;

		// Pinned image handles per source, reused while the view lives and released on Dispose.
		readonly Dictionary<string, ImageHandle> _imageIconHandles = new Dictionary<string, ImageHandle>();

		// Sources still downloading. Each URL is requested once, or the apply pass after it arrives
		// would request it again forever.
		readonly HashSet<string> _pendingImageIcons = new HashSet<string>();

		void ReleaseImageIcons()
		{
			foreach (var handle in _imageIconHandles.Values)
				handle.Dispose();

			_imageIconHandles.Clear();
			_pendingImageIcons.Clear();
		}

		/**
			Releases pinned icons no stored toolbar config refers to any more (its template was
			reconfigured or removed). Called after a bar is applied.
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

		/**
			Resolves toolbar icons to UIImage, or null for symbol/title-only items. HTTP icons arrive
			asynchronously and re-apply the bar when ready.
		*/
		ObjC.Object[] LoadToolbarIcons(ToolbarItemProps[] items)
		{
			var icons = new ObjC.Object[items.Length];
			for (int i = 0; i < items.Length; i++)
				icons[i] = LoadToolbarIcon(items[i].Icon);
			return icons;
		}

		ObjC.Object[] LoadMenuIcons(ToolbarMenuItemProps[] items)
		{
			var icons = new ObjC.Object[items.Length];
			for (int i = 0; i < items.Length; i++)
				icons[i] = LoadToolbarIcon(items[i].Icon);
			return icons;
		}

		ObjC.Object LoadToolbarIcon(ImageSource source)
		{
			if (source == null)
				return null;

			var file = source as FileImageSource;
			if (file != null)
				return CreateFileIconImage(file);

			var http = source as HttpImageSource;
			if (http != null)
				return CreateHttpIconImage(http);

			Fuse.Diagnostics.UserWarning("Unsupported toolbar icon source: " + source, _fuseHost);
			return null;
		}

		/** An image for an icon bundled with the app, loading (and pinning) it on first use only. */
		ObjC.Object CreateFileIconImage(FileImageSource file)
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

			return handle.Handle as ObjC.Object;
		}

		/** A URL icon, or null while downloading; each URL is requested once and re-applies the bar. */
		ObjC.Object CreateHttpIconImage(HttpImageSource http)
		{
			var key = ToolbarIconSource.Key(http);
			if (key == null)
				return null;

			ImageHandle handle;
			if (_imageIconHandles.TryGetValue(key, out handle))
				return handle.Handle as ObjC.Object;

			if (_pendingImageIcons.Add(key))
				ImageLoader.Load(http).Then(OnToolbarIconLoaded, OnToolbarIconFailed);

			return null;
		}

		void OnToolbarIconLoaded(ImageHandle handle)
		{
			if (handle == null)
				return;

			// The handle is keyed by its URL and pinned for the view's lifetime, like a bundled icon.
			_pendingImageIcons.Remove(handle.Name);
			_imageIconHandles[handle.Name] = handle;
			ReapplyLastNavigationBar();
		}

		void OnToolbarIconFailed(Exception e)
		{
			// Leave the URL pending so it is not requested again on every apply pass.
			Fuse.Diagnostics.UserWarning("Failed to load toolbar icon: " + e.Message, _fuseHost);
		}

		void ReapplyLastNavigationBar()
		{
			if (_lastBarConfig != null)
				ApplyNavigationBarConfiguration(_lastBarNavigationController, _lastBarViewController, _lastBarConfig);
		}

		public float4 GetNavigationSafeInsets(string templateName)
		{
			// The top modal's template gets the modal's own insets (see GetModalSafeAreaInsets).
			var modal = CurrentModal;
			var modalRoot = modal != null ? GetPresentedModalRootViewController(modal.Controller) : null;
			if (modalRoot != null && GetViewControllerAccessibilityIdentifier(modalRoot) == templateName)
				return GetModalSafeAreaInsets();

			float l, t, r, b;
			GetSafeAreaInsets(_navigationController, out l, out t, out r, out b);

			// The navigation bar is drawn inside the safe area, so add its height to the top inset.
			float navBarHeight = GetNavigationBarHeight(_navigationController);

			return float4(l, t + navBarHeight, r, b);
		}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetPresentedModalRootViewController(ObjC.Object modal)
		@{
			UIViewController* controller = (UIViewController*)modal;
			if (controller == nil)
				return nil;
			if ([controller isKindOfClass:[UINavigationController class]])
				return ((UINavigationController*)controller).topViewController;
			return controller;
		@}

		// Space UIKit leaves above a sheet's content for its grabber; the bar sits roughly this far
		// below the card top. Fixed, so insets do not move once the modal has been laid out.
		const float CardGrabberAllowancePoints = 16;

		public float4 GetModalSafeAreaInsets()
		{
			// Window safe area (status bar/home indicator): the app stack sits inside it, but a modal is
			// presented over the whole window and does sit under them.
			float l, t, r, b;
			GetWindowSafeAreaInsets(_navigationController, out l, out t, out r, out b);

			float barHeight = GetModalNavigationBarHeight(CurrentModal != null ? CurrentModal.Controller : null);

			var modalStyle = CurrentModal != null ? CurrentModal.Style : ModalPresentationStyle.FullScreen;

			if (modalStyle == ModalPresentationStyle.FullScreen)
			{
				// A full-screen cover fills the window; only its own bar has to be added.
				return float4(l, t + barHeight, r, b);
			}

			// A card is inset from the top, so only its own bar (plus grabber) must be cleared; without a
			// bar it is not inset at all, as on Android.
			float top = barHeight > 0 ? barHeight + CardGrabberAllowancePoints : 0;

			// A medium sheet stops above the home indicator; a page sheet reaches the bottom.
			float bottom = modalStyle == ModalPresentationStyle.Sheet ? 0.0f : b;

			return float4(l, top, r, bottom);
		}

		/**
			Pixel size (points × screen scale) of the presented page's view, or false when it has no window.
		*/
		[Foreign(Language.ObjC)]
		static bool GetModalContentPixelSize(ObjC.Object modal, out int widthPx, out int heightPx)
		@{
			*widthPx = *heightPx = 0;

			UIViewController* modalController = (UIViewController*)modal;
			UIView* view = modalController != nil ? modalController.view : nil;
			if (view == nil || view.window == nil)
				return false;

			// Pixels, like iOSDisplay: the shared layer expects pixels, so points would lay the page out
			// at a fraction of the modal.
			CGFloat scale = view.window.screen != nil ? view.window.screen.scale : UIScreen.mainScreen.scale;
			CGSize size = view.bounds.size;
			*widthPx = (int)(size.width * scale);
			*heightPx = (int)(size.height * scale);

			return true;
		@}

		/**
			Safe-area insets of the controller's window (status bar/home indicator). A modal is presented
			over the whole window and needs them; the app stack does not.
		*/
		[Foreign(Language.ObjC)]
		static void GetWindowSafeAreaInsets(ObjC.Object navCtrl, out float l, out float t, out float r, out float b)
		@{
			*l = *t = *r = *b = 0;

			UINavigationController* navController = (UINavigationController*)navCtrl;
			UIWindow* window = navController != nil ? navController.view.window : nil;
			if (window == nil)
				return;

			UIEdgeInsets insets = window.safeAreaInsets;
			*l = insets.left;
			*t = insets.top;
			*r = insets.right;
			*b = insets.bottom;
		@}

		[Foreign(Language.ObjC)]
		static float GetModalNavigationBarHeight(ObjC.Object modal)
		@{
			UINavigationController* nav = (UINavigationController*)modal;
			if (nav != nil && [nav isKindOfClass:[UINavigationController class]] && !nav.navigationBarHidden)
				return nav.navigationBar.frame.size.height;
			return 0;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateModalNavigationController(ObjC.Object rootViewController)
		@{
			UIViewController* root = (UIViewController*)rootViewController;
			// A FuseModalNavigationController, so the page follows the modal's own view when it is given a different
			// size (see ModalNavigationController.h).
			FuseModalNavigationController* nav = [[FuseModalNavigationController alloc] initWithRootViewController:root];
			// Translucent bar so the content extends under it (matches the full-screen Fuse viewport).
			nav.navigationBar.translucent = YES;
			return nav;
		@}

		/** Makes the modal's navigation controller report each layout; the block is released with it. */
		[Foreign(Language.ObjC)]
		static void SetModalLayoutCallback(ObjC.Object modalNav, Action onLayout)
		@{
			((FuseModalNavigationController*)modalNav).onLayout = onLayout;
		@}

		// Foreign code interface

		[Foreign(Language.ObjC)]
		static void GetSafeAreaInsets(ObjC.Object navCtrl, out float l, out float t, out float r, out float b)
		@{
			*l = *t = *r = *b = 0;

			// Use this controller's view, not the deprecated key window: its safe area reflects where
			// the embedded stack actually sits.
			UINavigationController* navController = (UINavigationController*)navCtrl;
			UIView* view = navController ? navController.view : nil;
			if (view) {
				if (@available(iOS 11.0, *)) {
					UIEdgeInsets insets = view.safeAreaInsets;
					*l = insets.left;
					*t = insets.top;
					*r = insets.right;
					*b = insets.bottom;
				} else {
					// iOS < 11: only the status bar.
					*t = 20; // Standard status bar height
				}
			}
		@}

		[Foreign(Language.ObjC)]
		static void SetNavigationBarHidden(ObjC.Object navCtrl, bool hidden)
		@{
			UINavigationController* navController = (UINavigationController*)navCtrl;
			if (navController == nil)
				return;

			[navController setNavigationBarHidden:hidden animated:YES];
		@}

		[Foreign(Language.ObjC)]
		static float GetNavigationBarHeight(ObjC.Object navCtrl)
		@{
			UINavigationController* navController = (UINavigationController*)navCtrl;

			if (navController && !navController.navigationBarHidden) {
				return navController.navigationBar.frame.size.height;
			}

			return 0;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateContainer()
		@{
			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			// Non-empty initial frame: UINavigationController's internal Auto Layout is unsatisfiable at
			// zero size until Fuse lays the control out.
			containerView.frame = [[UIScreen mainScreen] bounds];
			return containerView;
		@}

		[Foreign(Language.ObjC)]
		static void AddNavigationViewToContainer(ObjC.Object container, ObjC.Object navigationView)
		@{
			UIView* containerView = (UIView*)container;
			UIView* navView = (UIView*)navigationView;

			[containerView addSubview:navView];

			// Pin to the host with Auto Layout; this is what lays the navigation bar out correctly. The
			// host's initial frame (see CreateContainer) keeps it satisfiable before Fuse measures it.
			navView.translatesAutoresizingMaskIntoConstraints = NO;
			[NSLayoutConstraint activateConstraints:@[
				[navView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
				[navView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
				[navView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
				[navView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
			]];
		@}

		/**
			Makes the navigation controller a child of the nearest ancestor controller. A detached
			controller cannot present (e.g. bar-button menus) and warns this will become an error.
		*/
		[Foreign(Language.ObjC)]
		static void EnsureInViewControllerHierarchy(ObjC.Object navigationController)
		@{
			UINavigationController* nav = (UINavigationController*)navigationController;
			if (nav == nil || nav.parentViewController != nil)
				return;

			// Walk the responder chain to the nearest controller, falling back to the window's root.
			UIResponder* responder = nav.view.superview;
			while (responder != nil && ![responder isKindOfClass:[UIViewController class]])
				responder = responder.nextResponder;
			UIViewController* parent = (UIViewController*)responder;
			if (parent == nil)
				parent = nav.view.window.rootViewController;

			if (parent != nil && parent != nav)
			{
				[parent addChildViewController:nav];
				[nav didMoveToParentViewController:parent];
				return;
			}

			// Not in the hierarchy yet (first rooting pass): retry once the view is in the window.
			dispatch_async(dispatch_get_main_queue(), ^{
				UINavigationController* retry = (UINavigationController*)navigationController;
				if (retry == nil || retry.parentViewController != nil)
					return;

				UIResponder* r = retry.view.superview;
				while (r != nil && ![r isKindOfClass:[UIViewController class]])
					r = r.nextResponder;
				UIViewController* p = (UIViewController*)r;
				if (p == nil)
					p = retry.view.window.rootViewController;
				if (p != nil && p != retry)
				{
					[p addChildViewController:retry];
					[retry didMoveToParentViewController:p];
				}
			});
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateNavigationController()
		@{
			UINavigationController* navController = [[UINavigationController alloc] init];

			navController.navigationBar.barStyle = UIBarStyleDefault;
			navController.navigationBar.translucent = NO;
			navController.navigationBar.backgroundColor = [UIColor clearColor];

			// Enable swipe back gesture
			if ([navController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
				navController.interactivePopGestureRecognizer.enabled = YES;
			}

			return navController;
		@}

		[Foreign(Language.ObjC)]
		static void ReleaseNavigationController(ObjC.Object handle)
		@{
			// ARC handles cleanup.
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetNavigationView(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			return navController.view;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateViewControllerWithNativeView(ObjC.Object nativeView, string templateName)
		@{
			UIView* fuseView = (UIView*)nativeView;
			UIViewController* viewController = [[UIViewController alloc] init];
			viewController.title = templateName;
			viewController.extendedLayoutIncludesOpaqueBars = YES;

			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			containerView.accessibilityIdentifier = templateName;
			viewController.view = containerView;

			// Use frame/autoresizing, not Auto Layout: Fuse anchors native views top-left and manages
			// frames directly, so AL would offset by half the size.
			[containerView addSubview:fuseView];
			fuseView.frame = containerView.bounds;
			fuseView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			return viewController;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreatePlaceholderViewController(string templateName, string errorMessage)
		@{
			UIViewController* viewController = [[UIViewController alloc] init];
			viewController.title = templateName;
			viewController.view.backgroundColor = [UIColor lightGrayColor];
			viewController.view.accessibilityIdentifier = templateName;

			UILabel* errorLabel = [[UILabel alloc] init];
			errorLabel.text = [NSString stringWithFormat:@"Error loading template: %@\n\n%@", templateName, errorMessage];
			errorLabel.textAlignment = NSTextAlignmentCenter;
			errorLabel.numberOfLines = 0;
			errorLabel.textColor = [UIColor redColor];
			errorLabel.translatesAutoresizingMaskIntoConstraints = NO;

			[viewController.view addSubview:errorLabel];

			[errorLabel.centerXAnchor constraintEqualToAnchor:viewController.view.centerXAnchor].active = YES;
			[errorLabel.centerYAnchor constraintEqualToAnchor:viewController.view.centerYAnchor].active = YES;
			[errorLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:viewController.view.leadingAnchor constant:20].active = YES;
			[errorLabel.trailingAnchor constraintLessThanOrEqualToAnchor:viewController.view.trailingAnchor constant:-20].active = YES;

			return viewController;
		@}

		[Foreign(Language.ObjC)]
		static void PushViewController(ObjC.Object navigationController, ObjC.Object viewController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			UIViewController* vc = (UIViewController*)viewController;
			[navController pushViewController:vc animated:YES];
		@}

		[Foreign(Language.ObjC)]
		static void PopViewController(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			[navController popViewControllerAnimated:YES];
		@}

		[Foreign(Language.ObjC)]
		static void SetRootViewController(ObjC.Object navigationController, ObjC.Object viewController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			UIViewController* vc = (UIViewController*)viewController;
			[navController setViewControllers:@[vc] animated:NO];
		@}

		[Foreign(Language.ObjC)]
		ObjC.Object PresentModal(ObjC.Object presenter, ObjC.Object modal, ModalPresentationStyle style, bool dragToDismiss, bool expandable)
		@{
			UIViewController* presenting = (UIViewController*)presenter;
			UIViewController* modalController = (UIViewController*)modal;
			if (presenting == nil || modalController == nil)
				return nil;

			// The nav controller is embedded in the Fuse view, so present from the window's top-most
			// controller instead.
			UIViewController* host = presenting;
			UIWindow* window = presenting.view.window;
			if (window != nil && window.rootViewController != nil)
				host = window.rootViewController;
			while (host.presentedViewController != nil)
				host = host.presentedViewController;

			if (@{ModalPresentationStyle:of(style)} == @{ModalPresentationStyle.FullScreen})
			{
				modalController.modalPresentationStyle = UIModalPresentationFullScreen;
			}
			else
			{
				if (@{ModalPresentationStyle:of(style)} == @{ModalPresentationStyle.FormSheet})
					modalController.modalPresentationStyle = UIModalPresentationFormSheet;
				else
					modalController.modalPresentationStyle = UIModalPresentationPageSheet;

				// A sheet is swipeable unless told otherwise; UIKit then dismisses it and reports through
				// the presentation controller delegate (see ModalDismissHandler). Otherwise it springs back.
				modalController.modalInPresentation = dragToDismiss ? NO : YES;

				if (@{ModalPresentationStyle:of(style)} == @{ModalPresentationStyle.Sheet})
				{
					if (@available(iOS 15.0, *))
					{
						// Medium by default; add the large detent when expandable.
						UISheetPresentationController* sheet = modalController.sheetPresentationController;
						if (sheet != nil)
							sheet.detents = expandable
								? @[UISheetPresentationControllerDetent.mediumDetent,
									UISheetPresentationControllerDetent.largeDetent]
								: @[UISheetPresentationControllerDetent.mediumDetent];
					}
				}
			}

			// Force the first layout so a card's bar is already placed when PresentView reports the size,
			// and the insets apply before the modal is visible.
			[modalController.view layoutIfNeeded];

			modalController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
			[host presentViewController:modalController animated:YES completion:^{
				if (@{ModalPresentationStyle:of(style)} == @{ModalPresentationStyle.FullScreen})
					return;

				// Exists only once presenting; it holds its delegate weakly, so we keep the handler.
				if (dragToDismiss)
					modalController.presentationController.delegate =
						(FuseModalDismissHandler*)@{NativeNavigationViewImpl:Of(_this)._modalDismissHandler};

				// Fallback for a modal reported before its view was in a window; reporting twice is harmless.
				dispatch_async(dispatch_get_main_queue(), ^{
					@{global::Fuse.Controls.iOS.NativeNavigationViewImpl:of(_this).TryReportModalLaidOut():call()};
				});
			}];
			return modalController;
		@}

		[Foreign(Language.ObjC)]
		void DismissModal(ObjC.Object modal)
		@{
			UIViewController* modalController = (UIViewController*)modal;
			if (modalController == nil)
			{
				@{global::Fuse.Controls.iOS.NativeNavigationViewImpl:of(_this).NotifyModalDismissed():call()};
				return;
			}

			UIViewController* presenter = modalController.presentingViewController;
			if (presenter == nil)
			{
				@{global::Fuse.Controls.iOS.NativeNavigationViewImpl:of(_this).NotifyModalDismissed():call()};
				return;
			}

			[presenter dismissViewControllerAnimated:YES completion:^{
				@{global::Fuse.Controls.iOS.NativeNavigationViewImpl:of(_this).NotifyModalDismissed():call()};
			}];
		@}

		[Foreign(Language.ObjC)]
		static int GetNavigationStackCount(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			return (int)[navController.viewControllers count];
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object GetCurrentViewController(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			return navController.topViewController;
		@}

		[Foreign(Language.ObjC)]
		static string GetViewControllerAccessibilityIdentifier(ObjC.Object viewController)
		@{
			UIViewController* vc = (UIViewController*)viewController;
			return vc.view.accessibilityIdentifier ?: @"";
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object[] GetNavigationStackTemplateNames(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			NSArray<UIViewController*>* viewControllers = navController.viewControllers;

			NSUInteger count = [viewControllers count];
			id<UnoArray> result = @{ObjC.Object[]:new(count)};

			NSUInteger i = 0;
			for (UIViewController* vc in viewControllers) {
				NSString* accessibilityIdentifier = vc.view.accessibilityIdentifier ?: @"";
				@{ObjC.Object[]:of(result).Set(i, accessibilityIdentifier)};
				i++;
			}

			return result;
		@}

		[Foreign(Language.ObjC)]
		static string GetTemplateName(ObjC.Object templateName)
		@{
			return [templateName description];
		@}

		[Foreign(Language.ObjC)]
		static void SetNavigationBarAppearance(ObjC.Object navigationController, ObjC.Object viewController,
			string title, float bgR, float bgG, float bgB, float bgA,
			float fgR, float fgG, float fgB, float fgA,
			float tintR, float tintG, float tintB, float tintA,
			bool largeTitle, bool translucent, bool hidden, string backButtonTitle)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			UIViewController* vc = (UIViewController*)viewController;

			vc.title = title;

			UINavigationBar* navBar = navController.navigationBar;

			navBar.translucent = translucent;

			[navController setNavigationBarHidden:hidden animated:YES];

			if (!hidden) {
				UIColor* backgroundColor = [UIColor colorWithRed:bgR green:bgG blue:bgB alpha:bgA];
				UIColor* foregroundColor = [UIColor colorWithRed:fgR green:fgG blue:fgB alpha:fgA];
				UIColor* tintColor = [UIColor colorWithRed:tintR green:tintG blue:tintB alpha:tintA];
				NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					foregroundColor, NSForegroundColorAttributeName,
					nil];

				if (@available(iOS 13.0, *)) {
					// Modern appearance API
					UINavigationBarAppearance* appearance = [[UINavigationBarAppearance alloc] init];
					if (!translucent) {
						[appearance configureWithOpaqueBackground];
						appearance.backgroundColor = backgroundColor;
					}
					appearance.titleTextAttributes = attributes;
					appearance.largeTitleTextAttributes = attributes;

					navBar.standardAppearance = appearance;
					navBar.compactAppearance = appearance;
					navBar.scrollEdgeAppearance = appearance;
					navBar.tintColor = tintColor;

					if (@available(iOS 11.0, *)) {
						navBar.prefersLargeTitles = largeTitle;
						vc.navigationItem.largeTitleDisplayMode = largeTitle ? UINavigationItemLargeTitleDisplayModeAlways : UINavigationItemLargeTitleDisplayModeNever;
					}
				} else {
					// Legacy appearance API
					navBar.backgroundColor = backgroundColor;
					navBar.barTintColor = backgroundColor;
					navBar.titleTextAttributes = attributes;
					navBar.tintColor = tintColor;
				}

				// The back button comes from the controller beneath this one; setting it on `vc` would
				// only affect pages pushed on top.
				if (backButtonTitle && ![backButtonTitle isEqualToString:@""]) {
					NSArray<UIViewController*>* stack = navController.viewControllers;
					NSUInteger index = [stack indexOfObject:vc];
					if (index != NSNotFound && index > 0) {
						UIViewController* previous = stack[index - 1];
						previous.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStylePlain target:nil action:nil];
					}
				}
			}
		@}

		[Foreign(Language.ObjC)]
		void SetNavigationBarButtons(ObjC.Object viewController, ToolbarItemProps[] toolbarItems, ToolbarMenuItemProps[] menuItems, ObjC.Object[] icons, ObjC.Object[] menuIcons)
		@{
			UIViewController* vc = (UIViewController*)viewController;
			NSMutableArray* leftBarButtonItems = [[NSMutableArray alloc] init];
			NSMutableArray* rightBarButtonItems = [[NSMutableArray alloc] init];

			FuseToolbarActionHandler* menuHandler = (FuseToolbarActionHandler*)@{NativeNavigationViewImpl:Of(_this)._toolbarActionHandler};

			int menuItemsCount = @{ToolbarMenuItemProps[]:of(menuItems).Length:Get()};
			int iconCount = @{ObjC.Object[]:of(icons).Length:Get()};
			int menuIconCount = @{ObjC.Object[]:of(menuIcons).Length:Get()};

			for (int i = 0; i < @{ToolbarItemProps[]:of(toolbarItems).Length:Get()}; i++) {
				@{ToolbarItemProps} item = @{ToolbarItemProps[]:of(toolbarItems).Get(i)};
				@{string} title = @{ToolbarItemProps:of(item).Title};
				@{string} symbols = @{ToolbarItemProps:of(item).Symbols};
				bool enabled = @{ToolbarItemProps:of(item).Enabled};
				bool visible = @{ToolbarItemProps:of(item).Visible};
				bool hasColor = @{ToolbarItemProps:of(item).HasColor};
				@{ToolbarItemPosition} position = @{ToolbarItemProps:of(item).Position};
				@{string} accessibilityLabel = @{ToolbarItemProps:of(item).AccessibilityLabel};

				// Hidden items are not built; clicks carry the declared index, so hiding does not shift others.
				if (!visible) continue;

				// A symbol, a supplied image, or the title.
				UIImage* image = nil;
				if (symbols != nil && [symbols length] > 0) {
					if (@available(iOS 13.0, *))
						image = [UIImage systemImageNamed:symbols];
				} else if (iconCount > i) {
					image = (UIImage*)@{ObjC.Object[]:of(icons).Get(i)};
				}
				if (image != nil)
					image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

				BOOL hasTitle = title != nil && [title length] > 0;
				if (image == nil && !hasTitle) continue;

				NSMutableArray* actions = [[NSMutableArray alloc] init];
				if (@available(iOS 14.0, *)) {
					for (int k = 0; k < menuItemsCount; k++) {
						@{ToolbarMenuItemProps} mi = @{ToolbarMenuItemProps[]:of(menuItems).Get(k)};
						if (@{ToolbarMenuItemProps:of(mi).ToolbarIndex} != i) continue;

						if (!@{ToolbarMenuItemProps:of(mi).Visible}) continue;

						@{string} miTitle = @{ToolbarMenuItemProps:of(mi).Title};
						@{string} miAccessibilityLabel = @{ToolbarMenuItemProps:of(mi).AccessibilityLabel};
						bool miEnabled = @{ToolbarMenuItemProps:of(mi).Enabled};
						int flatIndex = k;

						// A symbol or a supplied image (or neither).
						UIImage* menuImage = nil;
						@{string} miSymbols = @{ToolbarMenuItemProps:of(mi).Symbols};
						if (miSymbols != nil && [miSymbols length] > 0) {
							if (@available(iOS 13.0, *))
								menuImage = [UIImage systemImageNamed:miSymbols];
						} else if (menuIconCount > k) {
							menuImage = (UIImage*)@{ObjC.Object[]:of(menuIcons).Get(k)};
						}
						if (menuImage != nil)
							menuImage = [menuImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

						// A menu entry needs a title; an icon-only entry announces its accessibility label.
						NSString* actionTitle = (miTitle != nil && [miTitle length] > 0)
							? miTitle
							: (miAccessibilityLabel != nil ? miAccessibilityLabel : @"");
						UIAction* action = [UIAction actionWithTitle:actionTitle image:menuImage identifier:nil handler:^(UIAction* a) {
							[menuHandler handleMenuAction:flatIndex];
						}];
						if (!miEnabled)
							action.attributes = UIMenuElementAttributesDisabled;

						[actions addObject:action];
					}
				}

				UIMenu* menu = nil;
				if (@available(iOS 14.0, *)) {
					if ([actions count] > 0)
						menu = [UIMenu menuWithTitle:@"" children:actions];
				}

				UIBarButtonItem* barButton = image != nil
					? [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:nil action:nil]
					: [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:nil action:nil];

				if (hasColor) {
					barButton.tintColor = [UIColor colorWithRed:@{ToolbarItemProps:of(item).ColorR}
										 green:@{ToolbarItemProps:of(item).ColorG}
										  blue:@{ToolbarItemProps:of(item).ColorB}
										 alpha:@{ToolbarItemProps:of(item).ColorA}];
				}

				if (accessibilityLabel != nil && [accessibilityLabel length] > 0)
					barButton.accessibilityLabel = accessibilityLabel;

				if (menu != nil) {
					barButton.menu = menu;
				} else {
					barButton.target = @{NativeNavigationViewImpl:Of(_this)._toolbarActionHandler};
					barButton.action = @selector(handleToolbarItemAction:);
				}

				barButton.tag = i;
				barButton.enabled = enabled;

				if (@{ToolbarItemPosition:of(position)} == @{ToolbarItemPosition.Left}
					|| @{ToolbarItemPosition:of(position)} == @{ToolbarItemPosition.Leading}) {
					[leftBarButtonItems addObject:barButton];
				} else {
					// rightBarButtonItems is ordered trailing-first, so insert at the front to keep
					// declaration order (as Android's bar does).
					[rightBarButtonItems insertObject:barButton atIndex:0];
				}
			}

			// Always assign both sides so buttons from a previous configuration do not linger.
			vc.navigationItem.leftBarButtonItems = [leftBarButtonItems count] > 0 ? leftBarButtonItems : nil;
			vc.navigationItem.rightBarButtonItems = [rightBarButtonItems count] > 0 ? rightBarButtonItems : nil;
		@}

		[Foreign(Language.ObjC)]
		static void ClearNavigationBarButtons(ObjC.Object viewController)
		@{
			UIViewController* vc = (UIViewController*)viewController;
			vc.navigationItem.leftBarButtonItems = nil;
			vc.navigationItem.rightBarButtonItems = nil;
		@}

		Dictionary<string, ToolbarItemProps[]> _toolbarItemConfigs = new Dictionary<string, ToolbarItemProps[]>();

		void OnToolbarItemClicked(int itemIndex)
		{
			// A presented modal covers the main bar, so toolbar clicks belong to it.
			var modal = CurrentModal;
			ObjC.Object barViewController = modal != null
				? GetPresentedModalRootViewController(modal.Controller)
				: GetCurrentViewController(_navigationController);
			if (barViewController == null)
				return;

			string templateName = GetViewControllerAccessibilityIdentifier(barViewController);
			if (_toolbarItemConfigs.ContainsKey(templateName))
			{
				var toolbarItems = _toolbarItemConfigs[templateName];
				if (toolbarItems != null && itemIndex >= 0 && itemIndex < toolbarItems.Length)
				{
					var toolbarItem = toolbarItems[itemIndex];
					if (toolbarItem != null && toolbarItem.Source != null)
					{
						toolbarItem.Source.TriggerClicked();
					}
				}
			}
		}

		void OnMenuItemClicked(int menuIndex)
		{
			var modal = CurrentModal;
			ObjC.Object barViewController = modal != null
				? GetPresentedModalRootViewController(modal.Controller)
				: GetCurrentViewController(_navigationController);
			if (barViewController == null)
				return;

			string templateName = GetViewControllerAccessibilityIdentifier(barViewController);
			ToolbarMenuItemProps[] menuItems;
			if (!_toolbarMenuConfigs.TryGetValue(templateName, out menuItems) || menuItems == null)
				return;

			if (menuIndex < 0 || menuIndex >= menuItems.Length)
				return;

			var menuItem = menuItems[menuIndex];
			if (menuItem != null && menuItem.Source != null)
				menuItem.Source.TriggerClicked();
		}
	}

	extern(iOS) internal static class NativeNavigationViewFactory
	{
		internal static Fuse.Controls.Native.IView Create(Fuse.Controls.NativeNavigationView host)
		{
			var impl = new NativeNavigationViewImpl();
			impl.SetHost(host);
			return impl;
		}
	}
}
