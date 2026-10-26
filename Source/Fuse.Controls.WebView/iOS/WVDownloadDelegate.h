#import <WebKit/WebKit.h>

typedef void (^DownloadFinishedAction)(NSString *url, NSString *path);

API_AVAILABLE(ios(14.5))
@interface WVDownloadDelegate : NSObject <WKDownloadDelegate>
@property(copy) DownloadFinishedAction onFinished;
@end
