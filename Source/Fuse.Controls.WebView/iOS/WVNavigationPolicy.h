#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, WVExternalNavigationPolicy) {
  WVExternalNavigationPolicyAllow = 0,
  WVExternalNavigationPolicyOpenExternally = 1,
  WVExternalNavigationPolicyBlock = 2
};

typedef NS_ENUM(NSInteger, WVNewWindowPolicy) {
  WVNewWindowPolicyOpenInWebView = 0,
  WVNewWindowPolicyOpenExternally = 1,
  WVNewWindowPolicyBlock = 2
};
