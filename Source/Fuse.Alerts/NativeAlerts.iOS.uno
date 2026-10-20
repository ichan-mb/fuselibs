using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Alerts
{
	[ForeignInclude(Language.ObjC, "iOS/AlertsUI.h")]
	public partial class NativeAlerts
	{

		[Foreign(Language.ObjC)]
		extern (iOS) internal static void AlertNative(String title, String message, String okButtonLabel, Action onOK, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertController* alert = [UIAlertController
					alertControllerWithTitle:title
					message:message
					preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction* defaultAction = [UIAlertAction
					actionWithTitle:okButtonLabel
					style:UIAlertActionStyleDefault
					handler:^(UIAlertAction * action) {
						onOK();
						// Let the alert finish dismissing before the next queued
						// dialog is presented.
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				[alert addAction:defaultAction];

				UIViewController* presenter = FuseAlertsTopViewController();

				if (!presenter || !presenter.view.window)
				{
					onError(@"No view controller available to present the alert.");
					onDismiss();
					return;
				}

				FuseAlertsSetCurrentController(alert, ^{ onDismiss(); });
				[presenter presentViewController:alert animated:YES completion:nil];
			});
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) internal static void ConfirmNative(String title, String message, String okButtonLabel, String cancelButtonLabel, Action onOK, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertController* modalAlert = [UIAlertController
					alertControllerWithTitle:title
					message:message
					preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction* positiveAction = [UIAlertAction
					actionWithTitle:okButtonLabel
					style:UIAlertActionStyleDefault
					handler:^(UIAlertAction * action) {
						onOK();
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				UIAlertAction* negativeAction = [UIAlertAction
					actionWithTitle:cancelButtonLabel
					style:UIAlertActionStyleCancel
					handler:^(UIAlertAction * action) {
						onCancel();
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				[modalAlert addAction:positiveAction];
				[modalAlert addAction:negativeAction];

				UIViewController* presenter = FuseAlertsTopViewController();

				if (!presenter || !presenter.view.window)
				{
					onError(@"No view controller available to present the confirm dialog.");
					onDismiss();
					return;
				}

				FuseAlertsSetCurrentController(modalAlert, ^{ onDismiss(); });
				[presenter presentViewController:modalAlert animated:YES completion:nil];
			});
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) internal static void PromptNative(String title, String message, String placeholder, String value, String okButtonLabel, String cancelButtonLabel, bool secure, String keyboardType, int minChars, Action<string> onOK, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertController* alert = [UIAlertController
					alertControllerWithTitle:title
					message:message
					preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction* positiveAction = [UIAlertAction
					actionWithTitle:okButtonLabel
					style:UIAlertActionStyleDefault
					handler:^(UIAlertAction* action) {
						UITextField* textField = alert.textFields.firstObject;
						onOK(textField.text ? textField.text : @"");
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				FuseAlertsTextChangeHandler* changeHandler = FuseAlertsCreateTextChangeHandler(^(NSString* text) {
					positiveAction.enabled = ((int)text.length >= minChars);
				});

				[alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
					textField.placeholder = placeholder;
					textField.text = value;
					textField.secureTextEntry = secure ? YES : NO;

					if ([keyboardType isEqualToString:@"email"])
						textField.keyboardType = UIKeyboardTypeEmailAddress;
					else if ([keyboardType isEqualToString:@"number"])
						textField.keyboardType = UIKeyboardTypeNumberPad;
					else if ([keyboardType isEqualToString:@"phone"])
						textField.keyboardType = UIKeyboardTypePhonePad;
					else if ([keyboardType isEqualToString:@"url"])
						textField.keyboardType = UIKeyboardTypeURL;
					else
						textField.keyboardType = UIKeyboardTypeDefault;

					[textField addTarget:changeHandler action:@selector(textChanged:) forControlEvents:UIControlEventEditingChanged];
				}];

				positiveAction.enabled = ((int)(value != nil ? value.length : 0) >= minChars);

				UIAlertAction* negativeAction = [UIAlertAction
					actionWithTitle:cancelButtonLabel
					style:UIAlertActionStyleCancel
					handler:^(UIAlertAction* action) {
						onCancel();
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				[alert addAction:positiveAction];
				[alert addAction:negativeAction];

				UIViewController* presenter = FuseAlertsTopViewController();
				if (!presenter || !presenter.view.window)
				{
					onError(@"No view controller available to present the prompt.");
					onDismiss();
					return;
				}

				FuseAlertsSetCurrentController(alert, ^{ onDismiss(); });
				[presenter presentViewController:alert animated:YES completion:nil];
			});
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) internal static void ActionSheetNative(String title, String message, String[] items, bool[] destructive, bool[] enabled, String cancelButtonLabel, bool hasOrigin, float originX, float originY, Action<int> onSelect, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertController* sheet = [UIAlertController
					alertControllerWithTitle:title
					message:message
					preferredStyle:UIAlertControllerStyleActionSheet];

				NSArray* labels = [items copyArray];
				NSArray* destructiveValues = [destructive copyArray];
				NSArray* enabledValues = [enabled copyArray];
				for (NSUInteger i = 0; i < labels.count; i++)
				{
					NSString* label = [labels objectAtIndex:i];
					BOOL isDestructive = i < destructiveValues.count && [[destructiveValues objectAtIndex:i] boolValue];
					BOOL isEnabled = i >= enabledValues.count || [[enabledValues objectAtIndex:i] boolValue];
					UIAlertActionStyle style = isDestructive
						? UIAlertActionStyleDestructive
						: UIAlertActionStyleDefault;

					UIAlertAction* itemAction = [UIAlertAction
						actionWithTitle:label
						style:style
						handler:^(UIAlertAction* action) {
							onSelect((int)i);
							dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
								onDismiss();
							});
						}];
					itemAction.enabled = isEnabled;
					[sheet addAction:itemAction];
				}

				UIAlertAction* cancelAction = [UIAlertAction
					actionWithTitle:cancelButtonLabel
					style:UIAlertActionStyleCancel
					handler:^(UIAlertAction* action) {
						onCancel();
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];
				[sheet addAction:cancelAction];

				UIViewController* presenter = FuseAlertsTopViewController();
				if (!presenter || !presenter.view.window)
				{
					onError(@"No view controller available to present the action sheet.");
					onDismiss();
					return;
				}

				if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
				{
					UIView* sourceView = presenter.view;
					sheet.popoverPresentationController.sourceView = sourceView;

					if (hasOrigin)
					{
						CGPoint point = [sourceView convertPoint:CGPointMake(originX, originY) fromView:nil];
						sheet.popoverPresentationController.sourceRect = CGRectMake(point.x, point.y, 1, 1);
					}
					else
					{
						sheet.popoverPresentationController.sourceRect = CGRectMake(
							CGRectGetMidX(sourceView.bounds),
							CGRectGetMidY(sourceView.bounds),
							1,
							1);
					}

					sheet.popoverPresentationController.delegate = FuseAlertsCreatePopoverDelegate(^{
						onCancel();
						onDismiss();
					});
				}

				FuseAlertsSetCurrentController(sheet, ^{ onDismiss(); });
				[presenter presentViewController:sheet animated:YES completion:nil];
			});
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) internal static void ConfirmChoiceNative(String title, String message, String okButtonLabel, String neutralButtonLabel, String cancelButtonLabel, bool destructive, bool cancelable, Action onOK, Action onNeutral, Action onCancel, Action<string> onError, Action onDismiss)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertController* alert = [UIAlertController
					alertControllerWithTitle:title
					message:message
					preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction* positiveAction = [UIAlertAction
					actionWithTitle:okButtonLabel
					style:destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
					handler:^(UIAlertAction* action) {
						onOK();
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				if (neutralButtonLabel != nil && neutralButtonLabel.length > 0)
				{
					UIAlertAction* neutralAction = [UIAlertAction
						actionWithTitle:neutralButtonLabel
						style:UIAlertActionStyleDefault
						handler:^(UIAlertAction* action) {
							onNeutral();
							dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
								onDismiss();
							});
						}];
					[alert addAction:neutralAction];
				}

				UIAlertAction* negativeAction = [UIAlertAction
					actionWithTitle:cancelButtonLabel
					style:UIAlertActionStyleCancel
					handler:^(UIAlertAction* action) {
						onCancel();
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							onDismiss();
						});
					}];

				[alert addAction:positiveAction];
				[alert addAction:negativeAction];

				UIViewController* presenter = FuseAlertsTopViewController();
				if (!presenter || !presenter.view.window)
				{
					onError(@"No view controller available to present the confirm dialog.");
					onDismiss();
					return;
				}

				FuseAlertsSetCurrentController(alert, ^{ onDismiss(); });
				[presenter presentViewController:alert animated:YES completion:nil];
			});
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) internal static void DismissAllNative()
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				FuseAlertsDismissCurrentController();
			});
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) static string DefaultOkLabel()
		@{
			return NSLocalizedString(@"OK", nil);
		@}

		[Foreign(Language.ObjC)]
		extern (iOS) static string DefaultCancelLabel()
		@{
			return NSLocalizedString(@"Cancel", nil);
		@}
	}
}
