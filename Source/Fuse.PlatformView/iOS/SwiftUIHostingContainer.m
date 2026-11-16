#import "SwiftUIHostingContainer.h"

/**
	Implementation of SwiftUIHostingContainer that handles containment and layout of SwiftUI content.

	This implementation establishes a proper parent/child view controller relationship with the
	hosted UIHostingController and ensures the hosted SwiftUI view always fills the container's
	bounds, providing seamless integration with Fuse's layout system.
*/
@implementation SwiftUIHostingContainer

	@synthesize swiftUIView;
	@synthesize hostingController = _hostingController;

	/**
		Finds the nearest UIViewController in the responder chain, falling back to the key
		window's root view controller when the container is not yet part of the view hierarchy.
	*/
	- (UIViewController *)fuse_parentViewController {
		UIResponder *responder = self;
		while ((responder = [responder nextResponder]) != nil) {
			if ([responder isKindOfClass:[UIViewController class]])
				return (UIViewController *)responder;
		}

		UIWindow *window = self.window;
		if (window == nil)
			window = [UIApplication sharedApplication].keyWindow;
		return window.rootViewController;
	}

	/**
		Attaches the hosting controller to the nearest parent view controller, re-parenting it
		if it was previously attached to a different controller (for example, when it was
		attached before the container was inserted into the view hierarchy).
	*/
	- (void)fuse_attachHostingController {
		UIViewController *controller = self.hostingController;
		if (controller == nil)
			return;

		UIViewController *parent = [self fuse_parentViewController];
		if (parent == nil)
			return;

		if (controller.parentViewController != nil) {
			if (controller.parentViewController == parent) {
				if (controller.view.superview != self)
					[self addSubview:controller.view];
				return;
			}

			[self fuse_detachHostingController];
		}

		[parent addChildViewController:controller];
		[self addSubview:controller.view];
		controller.view.frame = self.bounds;
		controller.view.autoresizingMask =
			UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[controller didMoveToParentViewController:parent];
	}

	/**
		Detaches the hosting controller from its parent view controller, if attached.
	*/
	- (void)fuse_detachHostingController {
		UIViewController *controller = self.hostingController;
		if (controller == nil || controller.parentViewController == nil)
			return;

		[controller willMoveToParentViewController:nil];
		[controller.view removeFromSuperview];
		[controller removeFromParentViewController];
	}

	- (void)setHostingController:(UIViewController *)hostingController {
		if (_hostingController == hostingController)
			return;

		[self fuse_detachHostingController];
		_hostingController = hostingController;
		self.swiftUIView = hostingController.view;
		[self fuse_attachHostingController];
		[self setNeedsLayout];
	}

	- (void)didMoveToWindow {
		[super didMoveToWindow];

		if (self.window != nil)
			[self fuse_attachHostingController];
		else
			[self fuse_detachHostingController];
	}

	/**
		Overrides layoutSubviews to ensure the hosted SwiftUI view matches the container's bounds.
		This method is called automatically by the iOS layout system whenever the container's
		size or position changes, ensuring the SwiftUI content is always properly sized.
	*/
	- (void)layoutSubviews {
		[super layoutSubviews];
		self.swiftUIView.frame = self.bounds;
		self.hostingController.view.frame = self.bounds;
	}

	/**
		Reports the intrinsic content size of the hosted SwiftUI view so Fuse can size the
		PlatformView when `Width`/`Height` are set to `Auto`.
	*/
	- (CGSize)sizeThatFits:(CGSize)size {
		UIView *content = self.swiftUIView;
		if (content == nil)
			return [super sizeThatFits:size];

		CGSize intrinsic = content.intrinsicContentSize;
		CGSize preferred = self.hostingController.preferredContentSize;
		CGSize bounds = self.bounds.size;

		CGFloat width = intrinsic.width != UIViewNoIntrinsicMetric
			? intrinsic.width
			: (preferred.width > 0 ? preferred.width : bounds.width);
		CGFloat height = intrinsic.height != UIViewNoIntrinsicMetric
			? intrinsic.height
			: (preferred.height > 0 ? preferred.height : bounds.height);

		if (size.width > 0 && size.width < width)
			width = size.width;
		if (size.height > 0 && size.height < height)
			height = size.height;

		return CGSizeMake(width, height);
	}

@end
