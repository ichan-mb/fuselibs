#import "ShareUI.h"

@implementation FuseShareActivityItemSource

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	return self.item;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController
	itemForActivityType:(UIActivityType)activityType
{
	return self.item;
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController
	subjectForActivityType:(UIActivityType)activityType
{
	return self.subject;
}

@end

FuseShareActivityItemSource* FuseShareCreateItemSource(id item, NSString* subject)
{
	FuseShareActivityItemSource* source = [[FuseShareActivityItemSource alloc] init];
	source.item = item;
	source.subject = subject;
	return source;
}

UIViewController* FuseShareTopViewController(void)
{
	UIWindow* window = nil;

	id appDelegate = [UIApplication sharedApplication].delegate;
	UIViewController* delegateVC = [appDelegate isKindOfClass:[UIViewController class]]
		? (UIViewController*)appDelegate
		: nil;

	// Prefer the window that actually hosts the Fuse root view. This avoids
	// picking up a system window whose root view controller is nil or unrelated.
	if (delegateVC != nil)
		window = delegateVC.view.window;

	if (window == nil)
	{
		if (@available(iOS 13.0, *))
		{
			UIWindow* (^windowOfScene)(UIWindowScene*) = ^UIWindow*(UIWindowScene* windowScene) {
				for (UIWindow* candidate in windowScene.windows)
				{
					if (candidate.isKeyWindow)
						return candidate;
				}
				return windowScene.windows.firstObject;
			};

			for (UIScene* scene in [UIApplication sharedApplication].connectedScenes)
			{
				if (![scene isKindOfClass:[UIWindowScene class]] ||
					scene.activationState != UISceneActivationStateForegroundActive)
					continue;

				window = windowOfScene((UIWindowScene*)scene);
				if (window != nil)
					break;
			}

			if (window == nil)
			{
				for (UIScene* scene in [UIApplication sharedApplication].connectedScenes)
				{
					if (![scene isKindOfClass:[UIWindowScene class]])
						continue;

					window = windowOfScene((UIWindowScene*)scene);
					if (window != nil)
						break;
				}
			}
		}
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 130000
		else
		{
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			window = [UIApplication sharedApplication].keyWindow;
			#pragma clang diagnostic pop
		}
#endif
	}

	// The Uno runtime installs the Fuse root view on the app delegate's view,
	// but some scene configurations leave the window without a root view
	// controller. Presenting from a detached view controller makes UIKit choose
	// a popover even when a page sheet was requested, so attach it first.
	if (window.rootViewController == nil && delegateVC != nil)
		window.rootViewController = delegateVC;

	UIViewController* presenter = window.rootViewController;
	if (!presenter)
		presenter = delegateVC;

	while (presenter.presentedViewController)
		presenter = presenter.presentedViewController;

	if ([presenter isKindOfClass:[UIAlertController class]] ||
		[presenter isKindOfClass:[UIActivityViewController class]] ||
		presenter.isBeingDismissed)
		presenter = presenter.presentingViewController;

	return presenter;
}

NSArray* FuseShareCreateActivityItems(NSString* text, NSString* url, NSArray* filePaths,
                                      NSString* subject, NSString** error)
{
	NSMutableArray* items = [NSMutableArray array];

	if (text != nil && text.length > 0)
		[items addObject:text];

	if (url != nil && url.length > 0)
	{
		NSURL* shareUrl = [NSURL URLWithString:url];
		if (shareUrl != nil)
			[items addObject:shareUrl];
		else if (text == nil || text.length == 0)
			[items addObject:url];
	}

	for (NSString* path in filePaths)
	{
		NSString* filePath = path;

		if ([path hasPrefix:@"file://"])
		{
			NSURL* parsedPath = [NSURL URLWithString:path];
			filePath = parsedPath.path;
		}

		BOOL isDirectory = NO;
		BOOL exists = filePath != nil && [[NSFileManager defaultManager]
			fileExistsAtPath:filePath
			isDirectory:&isDirectory];

		if (!exists || isDirectory)
		{
			if (error != NULL)
				*error = [NSString stringWithFormat:@"The file does not exist: %@", path];
			return nil;
		}

		NSURL* fileUrl = [NSURL fileURLWithPath:filePath];
		if (fileUrl != nil)
			[items addObject:fileUrl];
	}

	if (items.count == 0)
	{
		if (error != NULL)
			*error = @"No content to share.";
		return nil;
	}

	NSMutableArray* activityItems = [NSMutableArray array];
	BOOL subjectAssigned = NO;

	for (id item in items)
	{
		if (subject != nil && subject.length > 0 && !subjectAssigned)
		{
			[activityItems addObject:FuseShareCreateItemSource(item, subject)];
			subjectAssigned = YES;
		}
		else
		{
			[activityItems addObject:item];
		}
	}

	return activityItems;
}

void FuseSharePresentActivity(UIActivityViewController* activityController,
                              UIViewController* presenter,
                              BOOL usePopover,
                              BOOL hasOrigin,
                              float originX,
                              float originY,
                              void (^onComplete)(UIActivityType activityType, BOOL completed))
{
	UIWindow* shareWindow = nil;
	UIWindow* previousKeyWindow = presenter.view.window;
	UIViewController* presentationHost = presenter;

	if (usePopover)
	{
		activityController.modalPresentationStyle = UIModalPresentationPopover;

		UIView* sourceView = presenter.view;
		activityController.popoverPresentationController.sourceView = sourceView;

		if (hasOrigin)
		{
			CGPoint point = [sourceView convertPoint:CGPointMake(originX, originY) fromView:nil];
			activityController.popoverPresentationController.sourceRect = CGRectMake(point.x, point.y, 1, 1);
		}
		else
		{
			activityController.popoverPresentationController.sourceRect = CGRectMake(
				CGRectGetMidX(sourceView.bounds),
				CGRectGetMidY(sourceView.bounds),
				1,
				1);
		}
	}
	else
	{
		activityController.modalPresentationStyle = UIModalPresentationPageSheet;

		UIWindow* appWindow = presenter.view.window;

		// Prefer the normal sheet path. Only fall back to a dedicated window
		// when UIKit refuses the sheet style or the app window has no root view
		// controller, which would otherwise turn the sheet into a popover.
		// On current iOS, UIActivityViewController reports .popover even when
		// presented from a properly rooted window, so it cannot be relied on for
		// a normal sheet. Use a dedicated full-screen window in that case. If a
		// future iOS accepts the page-sheet style, this fallback disables itself.
		BOOL pageSheetAccepted =
			activityController.modalPresentationStyle == UIModalPresentationPageSheet;
		BOOL needsDedicatedWindow =
			appWindow.rootViewController == nil || !pageSheetAccepted;

		if (needsDedicatedWindow)
		{
			if (@available(iOS 13.0, *))
			{
				if (appWindow.windowScene != nil)
					shareWindow = [[UIWindow alloc] initWithWindowScene:appWindow.windowScene];
			}

			if (shareWindow == nil)
				shareWindow = [[UIWindow alloc] initWithFrame:appWindow.bounds];

			shareWindow.frame = appWindow.bounds;
			shareWindow.windowLevel = UIWindowLevelAlert + 1;
			shareWindow.backgroundColor = [UIColor clearColor];

			UIViewController* host = [[UIViewController alloc] init];
			host.view.backgroundColor = [UIColor clearColor];
			host.view.frame = shareWindow.bounds;
			host.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			shareWindow.rootViewController = host;

			presentationHost = host;
			[shareWindow makeKeyAndVisible];
		}
	}

	activityController.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray* returnedItems, NSError* activityError) {
		if (onComplete != nil)
			onComplete(activityType, completed);

		if (shareWindow != nil)
		{
			[shareWindow setHidden:YES];
			[previousKeyWindow makeKeyWindow];
		}
	};

	[presentationHost presentViewController:activityController animated:YES completion:nil];
}
