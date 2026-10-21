#pragma once
#ifdef __OBJC__
#include <UIKit/UIKit.h>
#include <MessageUI/MessageUI.h>

typedef void (^FuseEmailComplete)(NSString* status);
typedef void (^FuseEmailError)(NSString* error);

#ifdef __cplusplus
extern "C" {
#endif

/*
	Returns YES when the platform can present the in-app composer or open a
	mailto: link.
*/
BOOL FuseEmailIsAvailable(void);

/*
	Composes an email.

	When useInApp is YES and a Mail account is configured, the message is shown
	in an MFMailComposeViewController. Otherwise a mailto: link is opened.

	Attachments and HTML require the in-app composer; when that is unavailable
	the error block is called instead of silently dropping the content.
*/
void FuseEmailLaunch(NSString* mailtoUri,
                     NSArray* to,
                     NSArray* cc,
                     NSArray* bcc,
                     NSString* subject,
                     NSString* body,
                     NSString* htmlBody,
                     NSArray* attachmentPaths,
                     BOOL useInApp,
                     FuseEmailComplete onComplete,
                     FuseEmailError onError);

#ifdef __cplusplus
}
#endif

#endif
