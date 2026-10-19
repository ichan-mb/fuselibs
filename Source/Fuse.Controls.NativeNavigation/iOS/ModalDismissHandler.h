#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 Reports user-initiated modal dismissals (drag-away, tap-outside). Programmatic dismissals are not
 reported, so the shared layer's own dismissals do not report twice.
 */
@interface FuseModalDismissHandler : NSObject <UIAdaptivePresentationControllerDelegate>

@property (nonatomic, copy) void (^onDismissed)(void);

- (instancetype)initWithCallback:(void (^)(void))dismissed;

@end
