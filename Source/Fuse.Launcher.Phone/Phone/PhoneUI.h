#pragma once
#ifdef __OBJC__
#include <UIKit/UIKit.h>
#include <MessageUI/MessageUI.h>

typedef void (^FusePhoneOpened)(void);
typedef void (^FusePhoneComplete)(NSString* status);
typedef void (^FusePhoneError)(NSString* error);

#ifdef __cplusplus
extern "C" {
#endif

/* Returns YES when the platform can open the given URL. */
BOOL FusePhoneCanOpenUrl(NSString* uri);

/* Opens a URL and reports whether it opened. */
void FusePhoneOpenUrl(NSString* uri,
                      FusePhoneOpened onOpened,
                      FusePhoneError onError);

/*
	Returns YES when the platform can present the in-app composer or open an
	sms: link.
*/
BOOL FusePhoneCanSendSms(void);

/*
	Launches the SMS compose flow.

	When useInApp is YES and the device can send text messages, the message is
	shown in an MFMessageComposeViewController. Otherwise an sms: link is
	opened.

	Subject and attachments require the in-app composer; when that is
	unavailable the error block is called instead of silently dropping them.
*/
void FusePhoneLaunchSms(NSString* smsUri,
                        NSArray* recipients,
                        NSString* body,
                        NSString* subject,
                        NSArray* attachmentPaths,
                        BOOL useInApp,
                        FusePhoneComplete onComplete,
                        FusePhoneError onError);

#ifdef __cplusplus
}
#endif

#endif
