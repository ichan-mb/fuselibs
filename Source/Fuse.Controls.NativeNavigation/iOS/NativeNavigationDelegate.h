#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FuseNavigationDelegate : NSObject <UINavigationControllerDelegate>

@property (nonatomic, copy) void (^onWillShowViewController)(NSString* templateName);
@property (nonatomic, copy) void (^onDidShowViewController)(NSString* templateName);

- (instancetype)initWithCallbacks:(void (^)(NSString*))willShow
                          didShow:(void (^)(NSString*))didShow;

@end
