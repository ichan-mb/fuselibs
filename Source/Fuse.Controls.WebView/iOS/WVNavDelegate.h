#import "WVNavigationPolicy.h"
#import <WebKit/WebKit.h>
typedef void (^Action)(void);
typedef void (^StringAction)(NSString *);
typedef void (^StringStringAction)(NSString *, NSString *);
typedef void (^ErrorAction)(NSString *, NSString *, int, int, bool);
typedef bool (^BoolFunc)(void);
@interface WVNavDelegate : NSObject <WKNavigationDelegate>
@property(copy) Action onURLChanged;
@property(copy) Action onPageLoaded;
@property(copy) Action onBeginLoading;
@property(copy) StringAction onCustomURI;
@property(copy) BoolFunc hasURISchemeHandler;
@property(copy) Action onProgress;
@property(copy) Action onHistoryChanged;
@property(copy) ErrorAction onPageError;
@property(copy) StringAction onBeginDownload;
@property(copy) StringStringAction onFileDownloaded;
@property(strong) id downloadDelegate;
@property(nonatomic) WVExternalNavigationPolicy externalNavigationPolicy;
@property(nonatomic, retain) NSArray *uriSchemes;
- (id)initWithEventHandlers:(Action)beginLoading
                     loaded:(Action)pageLoaded
                     change:(Action)urlChanged
                 uriHandler:(StringAction)uriHandler
                    schemes:(NSArray *)schemes
        hasURISchemeHandler:(BoolFunc)hasURISchemeHandler;
- (void)attachToWebView:(WKWebView *)webView;
- (void)detachFromWebView;
@end
