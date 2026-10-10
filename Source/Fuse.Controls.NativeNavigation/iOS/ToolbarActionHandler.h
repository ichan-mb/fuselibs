#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FuseToolbarActionHandler : NSObject

@property (nonatomic, copy) void (^onToolbarItemClicked)(int itemIndex);

- (instancetype)initWithCallback:(void (^)(int))callback;
- (void)handleToolbarItemAction:(UIBarButtonItem*)sender;

@end