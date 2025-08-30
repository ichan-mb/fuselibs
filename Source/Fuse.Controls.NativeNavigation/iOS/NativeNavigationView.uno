using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Fuse.Controls.Native;

namespace Fuse.Controls.iOS
{
	extern(iOS) public class NativeNavigationViewImpl : Fuse.Controls.Native.iOS.LeafView, INativeNavigationView
	{
		ObjC.Object _navigationController;
		ObjC.Object _containerView;
		ObjC.Object _navigationDelegate;
		Fuse.Controls.NativeNavigationView _fuseHost;

		// Store navigation bar configurations for each template
		Dictionary<string, NavigationBarProps> _navigationBarConfigs = new Dictionary<string, NavigationBarProps>();

		// Callback to notify the main NativeNavigationView of navigation changes
		Action<string, int, bool> _navigationChangeCallback;

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
			// Create the native navigation controller without initial root controller
			_navigationController = CreateNavigationController();

			// Create and set up navigation delegate to handle stack synchronization
			_navigationDelegate = NativeNavigationDelegate.Create(
				OnViewWillAppear,
				OnViewDidAppear,
				OnViewWillDisappear,
				OnViewDidDisappear
			);
			NativeNavigationDelegate.SetAsDelegate(_navigationController, _navigationDelegate);

			// Get the navigation view to embed in Fuse
			_containerView = GetNavigationView(_navigationController);
			AddNavigationViewToContainer(Handle, _containerView);
		}

		public override void Dispose()
		{
			if (_navigationDelegate != null)
			{
				NativeNavigationDelegate.Destroy(_navigationDelegate);
				_navigationDelegate = null;
			}

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

			// Create a view controller using the native handle from separate rendering context
			var viewController = CreateViewControllerWithNativeHandle(nativeHandle, templateName);

			if (isPop)
			{
				// Check native iOS stack count
				var nativeStackCount = GetNativeStackCount();
				if (nativeStackCount > 1) // Allow pop if iOS has more than 1 view controller
				{
					PopViewController(_navigationController);
				}
			}
			else if (isPush)
			{
				PushViewController(_navigationController, viewController);
			}
			else
			{
				// Initial navigation - set as root
				SetRootViewController(_navigationController, viewController);
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

		public Visual CreateTemplateInstance(string templateName)
		{
			if (_fuseHost == null)
				return null;

			var tpl = _fuseHost.FindTemplate(templateName);
			if (tpl == null)
				return null;

			return tpl.New() as Visual;
		}

		public object GetNavigationController()
		{
			return _navigationController;
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

			// Store the configuration for this template
			_navigationBarConfigs[templateName] = config;

			// If this template is currently visible, apply the configuration immediately
			var currentViewController = GetCurrentViewController(_navigationController);
			if (currentViewController != null && GetViewControllerTitle(currentViewController) == templateName)
			{
				ApplyNavigationBarConfiguration(currentViewController, config);
			}
		}

		void ApplyNavigationBarConfiguration(ObjC.Object viewController, NavigationBarProps config)
		{
			if (viewController == null || config == null)
				return;

			SetNavigationBarAppearance(_navigationController, viewController, config.Title ?? "",
							config.BackgroundColor.X, config.BackgroundColor.Y, config.BackgroundColor.Z, config.BackgroundColor.W,
							config.ForegroundColor.X, config.ForegroundColor.Y, config.ForegroundColor.Z, config.ForegroundColor.W,
							config.TintColor.X, config.TintColor.Y, config.TintColor.Z, config.TintColor.W,
							config.LargeTitle, config.Translucent, config.Hidden, config.BackButtonTitle ?? "");
		}

		void OnViewWillAppear(string templateName)
		{
			// Apply navigation bar configuration when view will appear
			if (_navigationBarConfigs.ContainsKey(templateName))
			{
				var config = _navigationBarConfigs[templateName];
				var viewController = GetCurrentViewController(_navigationController);
				if (viewController != null)
				{
					ApplyNavigationBarConfiguration(viewController, config);
				}
			}
		}

		void OnViewDidAppear(string templateName)
		{
			// Notify the main NativeNavigationView of the change
			if (_navigationChangeCallback != null)
			{
				var stackCount = GetNativeStackCount();
				_navigationChangeCallback(templateName, stackCount, true);
			}
		}

		void OnViewWillDisappear(string templateName)
		{
			// Apply navigation bar configuration for the view that's about to appear
			var stackTemplates = GetNativeStackTemplates();
			if (stackTemplates.Length >= 2)
			{
				// Get the template that will be visible after this one disappears
				var previousTemplate = stackTemplates[stackTemplates.Length - 2];
				if (_navigationBarConfigs.ContainsKey(previousTemplate))
				{
					var config = _navigationBarConfigs[previousTemplate];
					var viewController = GetViewControllerAtIndex(_navigationController, stackTemplates.Length - 2);
					if (viewController != null)
					{
						ApplyNavigationBarConfiguration(viewController, config);
					}
				}
			}
		}

		void OnViewDidDisappear(string templateName)
		{
			// Notify the main NativeNavigationView of the change
			if (_navigationChangeCallback != null)
			{
				var stackTemplates = GetNativeStackTemplates();
				var currentTemplate = stackTemplates.Length > 0 ? stackTemplates[stackTemplates.Length - 1] : "";
				var stackCount = GetNativeStackCount();
				_navigationChangeCallback(currentTemplate, stackCount, false);
			}
		}

		public void PresentInWindow()
		{
			if (_navigationController != null)
			{
				PresentInWindow(_navigationController);
			}
		}

		// Foreign code interface methods
		[Foreign(Language.ObjC)]
		static ObjC.Object CreateContainer()
		@{
			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			return containerView;
		@}

		[Foreign(Language.ObjC)]
		static void AddNavigationViewToContainer(ObjC.Object container, ObjC.Object navigationView)
		@{
			UIView* containerView = (UIView*)container;
			UIView* navView = (UIView*)navigationView;

			[containerView addSubview:navView];

			// Set up constraints to make navigation view fill the container properly
			navView.translatesAutoresizingMaskIntoConstraints = NO;
			[NSLayoutConstraint activateConstraints:@[
				[navView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
				[navView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
				[navView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
				[navView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
			]];
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreateNavigationController()
		@{
			UINavigationController* navController = [[UINavigationController alloc] init];

			// Set default navigation bar appearance
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
			// ARC will handle cleanup automatically
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

			// Create container view that respects safe areas
			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			viewController.view = containerView;

			// Add the Fuse view to the container
			[containerView addSubview:fuseView];

			// Set up constraints to make the Fuse view respect safe areas
			fuseView.translatesAutoresizingMaskIntoConstraints = NO;
			return viewController;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreatePlaceholderViewController(string templateName, string errorMessage)
		@{
			UIViewController* viewController = [[UIViewController alloc] init];
			viewController.title = templateName;
			viewController.view.backgroundColor = [UIColor lightGrayColor];

			// Create error label
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
		static void PresentInWindow(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;

			// Get the key window
			UIWindow* keyWindow = nil;
			for (UIWindow* window in [UIApplication sharedApplication].windows) {
				if (window.isKeyWindow) {
					keyWindow = window;
					break;
				}
			}

			if (keyWindow && keyWindow.rootViewController) {
				[keyWindow.rootViewController presentViewController:navController animated:YES completion:nil];
			}
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
		static ObjC.Object GetViewControllerAtIndex(ObjC.Object navigationController, int index)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			NSArray<UIViewController*>* viewControllers = navController.viewControllers;
			if (index >= 0 && index < viewControllers.count) {
				return viewControllers[index];
			}
			return nil;
		@}

		[Foreign(Language.ObjC)]
		static string GetViewControllerTitle(ObjC.Object viewController)
		@{
			UIViewController* vc = (UIViewController*)viewController;
			return vc.title ?: @"";
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
				NSString* title = vc.title ?: @"";
				@{ObjC.Object[]:of(result).Set(i, title)};
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

			// Set the title
			vc.title = title;

			// Configure navigation bar appearance
			UINavigationBar* navBar = navController.navigationBar;

			// Set translucency
			navBar.translucent = translucent;
			vc.extendedLayoutIncludesOpaqueBars = translucent;

			// Set hidden state
			[navController setNavigationBarHidden:hidden animated:YES];

			if (!hidden) {
				// Set background color
				UIColor* backgroundColor = [UIColor colorWithRed:bgR green:bgG blue:bgB alpha:bgA];
				UIColor* foregroundColor = [UIColor colorWithRed:fgR green:fgG blue:fgB alpha:fgA];
				UIColor* tintColor = [UIColor colorWithRed:tintR green:tintG blue:tintB alpha:tintA];
				NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					foregroundColor, NSForegroundColorAttributeName,
					nil];

				// Configure appearance based on iOS version
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

					// Set tint color for interactive elements (buttons, etc.)
					navBar.tintColor = tintColor;

					// Set large title mode
					if (@available(iOS 11.0, *)) {
						navBar.prefersLargeTitles = largeTitle;
						vc.navigationItem.largeTitleDisplayMode = largeTitle ? UINavigationItemLargeTitleDisplayModeAlways : UINavigationItemLargeTitleDisplayModeNever;
					}
				} else {
					// Legacy appearance API
					navBar.backgroundColor = backgroundColor;
					navBar.barTintColor = backgroundColor;
					navBar.titleTextAttributes = attributes;
					// Set tint color for interactive elements (buttons, etc.) - can be different from foreground
					navBar.tintColor = tintColor;
				}

				// Set back button title if provided
				if (backButtonTitle && ![backButtonTitle isEqualToString:@""]) {
					vc.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStylePlain target:nil action:nil];
				}
			}
		@}
	}

	extern(iOS) public static class NativeNavigationViewFactory
	{
		public static Fuse.Controls.Native.IView Create(Fuse.Controls.NativeNavigationView host)
		{
			var impl = new NativeNavigationViewImpl();
			impl.SetHost(host);
			return impl;
		}
	}
}
