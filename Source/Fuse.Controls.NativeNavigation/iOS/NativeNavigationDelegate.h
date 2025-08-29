#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FuseNavigationDelegate : NSObject <UINavigationControllerDelegate>

@property (nonatomic, copy) void (^onViewWillAppear)(NSString* templateName);
@property (nonatomic, copy) void (^onViewDidAppear)(NSString* templateName);
@property (nonatomic, copy) void (^onViewWillDisappear)(NSString* templateName);
@property (nonatomic, copy) void (^onViewDidDisappear)(NSString* templateName);

- (instancetype)initWithCallbacks:(void (^)(NSString*))willAppear 
                       didAppear:(void (^)(NSString*))didAppear 
                   willDisappear:(void (^)(NSString*))willDisappear 
                    didDisappear:(void (^)(NSString*))didDisappear;

@end