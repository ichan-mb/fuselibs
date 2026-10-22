#import "PhoneUI.h"
#import <objc/runtime.h>

static char kFusePhoneComposeDelegateKey;

@interface FusePhoneComposeDelegate : NSObject <MFMessageComposeViewControllerDelegate>
@property (nonatomic, copy) FusePhoneComplete onComplete;
@property (nonatomic, copy) FusePhoneError onError;
@end

@implementation FusePhoneComposeDelegate

- (void)messageComposeViewController:(MFMessageComposeViewController*)controller
				 didFinishWithResult:(MessageComposeResult)result
{
	NSString* status = @"cancelled";
	BOOL failed = NO;

	switch (result)
	{
		case MessageComposeResultSent:
			status = @"sent";
			break;
		case MessageComposeResultCancelled:
			status = @"cancelled";
			break;
		case MessageComposeResultFailed:
			failed = YES;
			break;
	}

	[controller dismissViewControllerAnimated:YES completion:^{
		if (failed)
		{
			if (self.onError != nil)
				self.onError(@"The message could not be sent.");
		}
		else if (self.onComplete != nil)
		{
			self.onComplete(status);
		}
	}];
}

@end

static UIViewController* FusePhoneTopViewController(void)
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

	if (window.rootViewController == nil && delegateVC != nil)
		window.rootViewController = delegateVC;

	UIViewController* presenter = window.rootViewController;
	if (presenter == nil)
		presenter = delegateVC;

	while (presenter.presentedViewController != nil)
		presenter = presenter.presentedViewController;

	if ([presenter isKindOfClass:[UIAlertController class]] || presenter.isBeingDismissed)
		presenter = presenter.presentingViewController;

	return presenter;
}

static BOOL FusePhoneAddAttachments(MFMessageComposeViewController* composer,
									NSArray* attachmentPaths,
									NSString** error)
{
	if (attachmentPaths.count == 0)
		return YES;

	if (![MFMessageComposeViewController canSendAttachments])
	{
		if (error != NULL)
			*error = @"This device cannot send attachments.";
		return NO;
	}

	if (@available(iOS 14.0, *))
	{
		for (NSString* path in attachmentPaths)
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
				return NO;
			}

			NSURL* url = [NSURL fileURLWithPath:filePath];

			@try
			{
				[composer addAttachmentURL:url withAlternateFilename:filePath.lastPathComponent];
			}
			@catch (NSException* exception)
			{
				if (error != NULL)
					*error = exception.reason != nil
						? exception.reason
						: @"Could not attach the file.";
				return NO;
			}
		}

		return YES;
	}

	if (error != NULL)
		*error = @"Attachments require iOS 14 or later.";
	return NO;
}

BOOL FusePhoneCanOpenUrl(NSString* uri)
{
	__block BOOL available = NO;

	void (^check)(void) = ^{
		NSURL* url = [NSURL URLWithString:uri];
		available = url != nil && [[UIApplication sharedApplication] canOpenURL:url];
	};

	if ([NSThread isMainThread])
		check();
	else
		dispatch_sync(dispatch_get_main_queue(), check);

	return available;
}

void FusePhoneOpenUrl(NSString* uri,
					  FusePhoneOpened onOpened,
					  FusePhoneError onError)
{
	void (^open)(void) = ^{
		NSURL* url = [NSURL URLWithString:uri];
		if (url == nil)
		{
			onError(@"Invalid phone URL.");
			return;
		}

		if (@available(iOS 10.0, *))
		{
			[[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:^(BOOL success) {
				if (success)
					onOpened();
				else
					onError(@"No app is available to handle this request.");
			}];
		}
		else
		{
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			BOOL success = [[UIApplication sharedApplication] openURL:url];
			#pragma clang diagnostic pop

			if (success)
				onOpened();
			else
				onError(@"No app is available to handle this request.");
		}
	};

	if ([NSThread isMainThread])
		open();
	else
		dispatch_async(dispatch_get_main_queue(), open);
}

BOOL FusePhoneCanSendSms(void)
{
	__block BOOL available = NO;

	void (^check)(void) = ^{
		NSURL* url = [NSURL URLWithString:@"sms:"];
		available = [MFMessageComposeViewController canSendText] ||
			(url != nil && [[UIApplication sharedApplication] canOpenURL:url]);
	};

	if ([NSThread isMainThread])
		check();
	else
		dispatch_sync(dispatch_get_main_queue(), check);

	return available;
}

void FusePhoneLaunchSms(NSString* smsUri,
						NSArray* recipients,
						NSString* body,
						NSString* subject,
						NSArray* attachmentPaths,
						BOOL useInApp,
						FusePhoneComplete onComplete,
						FusePhoneError onError)
{
	if (![NSThread isMainThread])
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			FusePhoneLaunchSms(smsUri, recipients, body, subject, attachmentPaths,
				useInApp, onComplete, onError);
		});
		return;
	}

	BOOL canCompose = [MFMessageComposeViewController canSendText];

	if (useInApp && canCompose)
	{
		MFMessageComposeViewController* composer = [[MFMessageComposeViewController alloc] init];
		if (composer == nil)
		{
			onError(@"Could not create the message composer.");
			return;
		}

		if (recipients.count > 0)
			composer.recipients = recipients;
		if (body.length > 0)
			composer.body = body;

		if (subject.length > 0)
		{
			if ([MFMessageComposeViewController canSendSubject])
				composer.subject = subject;
			else
			{
				onError(@"This device cannot send a message subject.");
				return;
			}
		}

		NSString* attachmentError = nil;
		if (!FusePhoneAddAttachments(composer, attachmentPaths, &attachmentError))
		{
			onError(attachmentError != nil
				? attachmentError
				: @"Could not attach the file.");
			return;
		}

		FusePhoneComposeDelegate* delegate = [[FusePhoneComposeDelegate alloc] init];
		delegate.onComplete = onComplete;
		delegate.onError = onError;
		composer.messageComposeDelegate = delegate;
		objc_setAssociatedObject(composer, &kFusePhoneComposeDelegateKey, delegate,
			OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		UIViewController* presenter = FusePhoneTopViewController();
		if (presenter == nil || presenter.view.window == nil)
		{
			onError(@"No view controller available to present the message composer.");
			return;
		}

		[presenter presentViewController:composer animated:YES completion:nil];
		return;
	}

	// The sms: URL scheme cannot carry a subject or attachments. Do not
	// silently drop them when the composer is unavailable.
	if (subject.length > 0)
	{
		onError(@"A message subject requires the in-app composer.");
		return;
	}

	if (attachmentPaths.count > 0)
	{
		onError(@"Attachments require the in-app composer.");
		return;
	}

	NSURL* url = [NSURL URLWithString:smsUri];
	if (url == nil)
	{
		onError(@"Could not create the message link.");
		return;
	}

	if (@available(iOS 10.0, *))
	{
		[[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:^(BOOL success) {
			if (success)
				onComplete(@"opened");
			else
				onError(@"No app is available to send messages.");
		}];
	}
	else
	{
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		BOOL success = [[UIApplication sharedApplication] openURL:url];
		#pragma clang diagnostic pop

		if (success)
			onComplete(@"opened");
		else
			onError(@"No app is available to send messages.");
	}
}
