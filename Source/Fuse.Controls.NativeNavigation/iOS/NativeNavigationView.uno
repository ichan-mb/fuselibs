using Uno;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;

using Fuse.Elements;

namespace Fuse.Controls.iOS
{
	// extern(!iOS) public class NativeNavigationViewImpl : INativeNavigationView
	// {
	// 	// Empty stub for non-iOS platforms
	// 	public NativeNavigationViewImpl()  {}

	// 	public void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop) { }
	// 	public void SetHost(NativeNavigationView host) { }
	// 	public Visual CreateTemplateInstance(string templateName) { return null; }
	// 	public object GetNavigationController() { return null; }
	// 	public void PresentInWindow() { }
	// }

	[Require("source.include", "UIKit/UIKit.h")]
	extern(iOS) public class NativeNavigationViewImpl : Fuse.Controls.Native.iOS.LeafView, INativeNavigationView
	{
		ObjC.Object _navigationController;
		ObjC.Object _containerView;
		Fuse.Controls.NativeNavigationView _fuseHost;

		// Store navigation bar configurations for each template
		Dictionary<string, NavigationBarProps> _navigationBarConfigs = new Dictionary<string, NavigationBarProps>();

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

			// Get the navigation view to embed in Fuse
			_containerView = GetNavigationView(_navigationController);

			// Add the navigation controller's view to our container
			AddNavigationViewToContainer(Handle, _containerView);
		}

		public override void Dispose()
		{
			if (_navigationController != null)
			{
				ReleaseNavigationController(_navigationController);
				_navigationController = null;
			}

			_containerView = null;
			base.Dispose();
		}

		public void NavigateToView(object nativeHandle, string templateName, bool isPush, bool isPop)
		{
			if (_navigationController == null || nativeHandle == null)
				return;

			// Create a view controller using the native handle from separate rendering context
			var viewController = CreateViewControllerWithNativeHandle(nativeHandle, templateName);

			if (isPop)
			{
				PopViewController(_navigationController);
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

			// Apply navigation bar configuration if it exists for this template
			if (_navigationBarConfigs.ContainsKey(templateName))
			{
				var config = _navigationBarConfigs[templateName];
				ApplyNavigationBarConfiguration(viewController, config);
			}
		}

		// Helper method for host to create templates
		public Visual CreateTemplateInstance(string templateName)
		{
			if (_fuseHost == null)
				return null;

			var template = _fuseHost.FindTemplate(templateName);
			if (template == null)
				return null;

			var instance = template.New() as Visual;
			if (instance != null)
			{
				instance.Name = templateName;
			}

			return instance;
		}

		ObjC.Object CreateViewControllerWithNativeHandle(object nativeHandle, string templateName)
		{
			if (nativeHandle == null)
			{
				// Fallback: create a placeholder view controller
				return CreatePlaceholderViewController(templateName, "Native handle is null - rendering context may not be properly established");
			}

			// Cast to ObjC.Object for iOS
			var nativeView = nativeHandle as ObjC.Object;
			if (nativeView == null)
			{
				return CreatePlaceholderViewController(templateName, "Native handle is not an ObjC.Object on iOS");
			}

			// Create a view controller that wraps the native view from separate rendering context
			return CreateViewControllerWithNativeView(nativeView, templateName);
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
			if (_navigationController == null || viewController == null || config == null)
				return;

			SetNavigationBarAppearance(_navigationController, viewController, config.Title ?? "",
				config.BackgroundColor.X, config.BackgroundColor.Y, config.BackgroundColor.Z, config.BackgroundColor.W,
				config.ForegroundColor.X, config.ForegroundColor.Y, config.ForegroundColor.Z, config.ForegroundColor.W,
				config.TintColor.X, config.TintColor.Y, config.TintColor.Z, config.TintColor.W,
				config.LargeTitle, config.Translucent, config.Hidden, config.BackButtonTitle ?? "");
		}

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
			// Create navigation controller without initial root view controller
			UINavigationController* navController = [[UINavigationController alloc] init];

			// Configure navigation bar appearance for proper content layout
			navController.navigationBar.barStyle = UIBarStyleDefault;
			navController.navigationBar.translucent = NO; // Make non-translucent to avoid content overlap
			navController.navigationBar.backgroundColor = [UIColor whiteColor];

			// Enable automatic content inset adjustments
			if (@available(iOS 11.0, *)) {
				// Modern iOS versions handle safe areas automatically
				navController.navigationBar.prefersLargeTitles = NO;
			}

			return navController;
		@}

		[Foreign(Language.ObjC)]
		static void ReleaseNavigationController(ObjC.Object handle)
		@{
			UINavigationController* navController = (UINavigationController*)handle;
			// Clean up if needed
			[navController setViewControllers:@[] animated:NO];
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

			// Create a view controller
			UIViewController* viewController = [[UIViewController alloc] init];
			viewController.title = templateName;

			// Create container view for the view controller that respects safe areas
			UIView* containerView = [[UIView alloc] init];
			containerView.backgroundColor = [UIColor whiteColor];
			viewController.view = containerView;

			// Add the Fuse view to the container
			[containerView addSubview:fuseView];

			// Set up constraints to make the Fuse view respect the navigation bar and safe areas
			fuseView.translatesAutoresizingMaskIntoConstraints = NO;
			return viewController;
		@}

		[Foreign(Language.ObjC)]
		static ObjC.Object CreatePlaceholderViewController(string templateName, string errorMessage)
		@{
			UIViewController* viewController = [[UIViewController alloc] init];
			viewController.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
			viewController.title = templateName;

			// Create error message display
			UIStackView* stackView = [[UIStackView alloc] init];
			stackView.axis = UILayoutConstraintAxisVertical;
			stackView.alignment = UIStackViewAlignmentCenter;
			stackView.distribution = UIStackViewDistributionEqualSpacing;
			stackView.spacing = 20;
			stackView.translatesAutoresizingMaskIntoConstraints = NO;

			// Template name label
			UILabel* titleLabel = [[UILabel alloc] init];
			titleLabel.text = [NSString stringWithFormat:@"Template: %@", templateName];
			titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
			titleLabel.textAlignment = NSTextAlignmentCenter;
			titleLabel.textColor = [UIColor darkGrayColor];
			[stackView addArrangedSubview:titleLabel];

			// Error message label
			UILabel* errorLabel = [[UILabel alloc] init];
			errorLabel.text = errorMessage;
			errorLabel.numberOfLines = 0;
			errorLabel.textAlignment = NSTextAlignmentCenter;
			errorLabel.textColor = [UIColor redColor];
			errorLabel.font = [UIFont systemFontOfSize:16];
			[stackView addArrangedSubview:errorLabel];

			// Instruction label
			UILabel* instructionLabel = [[UILabel alloc] init];
			instructionLabel.text = @"Make sure your template renders properly in a native context.";
			instructionLabel.numberOfLines = 0;
			instructionLabel.textAlignment = NSTextAlignmentCenter;
			instructionLabel.textColor = [UIColor grayColor];
			instructionLabel.font = [UIFont systemFontOfSize:14];
			[stackView addArrangedSubview:instructionLabel];

			// Add the stack view to the view controller
			[viewController.view addSubview:stackView];

			// Center the stack view
			[NSLayoutConstraint activateConstraints:@[
				[stackView.centerXAnchor constraintEqualToAnchor:viewController.view.centerXAnchor],
				[stackView.centerYAnchor constraintEqualToAnchor:viewController.view.centerYAnchor],
				[stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:viewController.view.leadingAnchor constant:20],
				[stackView.trailingAnchor constraintLessThanOrEqualToAnchor:viewController.view.trailingAnchor constant:-20]
			]];

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

		// Public method to get the native navigation controller
		public object GetNavigationController()
		{
			return _navigationController;
		}

		// Method to show the navigation controller modally or in a window
		[Foreign(Language.ObjC)]
		public void PresentInWindow()
		@{
			UINavigationController* navController = (UINavigationController*)_navigationController;

			// Get the key window
			UIWindow* keyWindow = nil;
			for (UIWindow* window in [[UIApplication sharedApplication] windows]) {
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
		static ObjC.Object GetCurrentViewController(ObjC.Object navigationController)
		@{
			UINavigationController* navController = (UINavigationController*)navigationController;
			return navController.topViewController;
		@}

		[Foreign(Language.ObjC)]
		static string GetViewControllerTitle(ObjC.Object viewController)
		@{
			UIViewController* vc = (UIViewController*)viewController;
			return vc.title ?: @"";
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
					[appearance configureWithOpaqueBackground];
					appearance.backgroundColor = backgroundColor;
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

	// Factory class to create the native implementation
	extern(iOS) public static class NativeNavigationViewFactory
	{
		public static Fuse.Controls.Native.IView Create(Fuse.Controls.NativeNavigationView host)
		{
			if defined(iOS)
			{
				var impl = new NativeNavigationViewImpl();
				impl.SetHost(host);
				return impl;
			}
			else
			{
				return null;
			}
		}

		public static INativeNavigationView CreateNativeImpl(Fuse.Controls.NativeNavigationView host)
		{
			if defined(iOS)
			{
				var impl = new NativeNavigationViewImpl();
				impl.SetHost(host);
				return impl;
			}
			else
			{
				return null;
			}
		}
	}
}
