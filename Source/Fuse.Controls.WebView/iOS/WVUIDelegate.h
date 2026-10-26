#import "WVNavigationPolicy.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface WVUIDelegate : NSObject <WKUIDelegate, UIDocumentPickerDelegate>
@property(nonatomic) WVNewWindowPolicy newWindowPolicy;
@end
