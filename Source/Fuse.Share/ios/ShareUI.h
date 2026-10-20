#pragma once
#ifdef __OBJC__
#include <UIKit/UIKit.h>

/*
	Wraps a share item so a subject can be supplied to targets that support one,
	such as the iOS mail composer, without adding the subject as shareable content.
*/
@interface FuseShareActivityItemSource : NSObject <UIActivityItemSource>
@property (nonatomic, strong) id item;
@property (nonatomic, copy) NSString* subject;
@end

#ifdef __cplusplus
extern "C" {
#endif

FuseShareActivityItemSource* FuseShareCreateItemSource(id item, NSString* subject);

/*
	Returns the view controller that should present the share dialog.

	Prefers the window that hosts the Fuse root view, then the key window of the
	foreground-active scene.
*/
UIViewController* FuseShareTopViewController(void);

/*
	Builds the activity item array. Returns nil and sets *error to a
	user-facing message when the content is invalid.
*/
NSArray* FuseShareCreateActivityItems(NSString* text, NSString* url, NSArray* filePaths,
                                      NSString* subject, NSString** error);

/*
	Presents the activity controller. Uses a popover on wide iPad contexts and a
	dedicated full-screen window on compact contexts.
*/
void FuseSharePresentActivity(UIActivityViewController* activityController,
                              UIViewController* presenter,
                              BOOL usePopover,
                              BOOL hasOrigin,
                              float originX,
                              float originY,
                              void (^onComplete)(UIActivityType activityType, BOOL completed));

#ifdef __cplusplus
}
#endif
#endif
