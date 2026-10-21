#import <UIKit/UIKit.h>

@interface FOShortcutHandler : NSObject

+(instancetype)sharedInstance;

@property (nonatomic, copy) void (^_onCallback)(NSString* payload);

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
- (void)applicationDidBecomeActive:(UIApplication *)application;
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler;

- (BOOL)registerShortcuts:(NSArray*)shortcuts error:(NSString**)error;
- (BOOL)updateShortcuts:(NSArray*)shortcuts error:(NSString**)error;
- (void)removeShortcuts:(NSArray*)ids;
- (void)clearShortcuts;
- (NSString*)getShortcuts;
- (void)registerCallback:(void (^)(NSString* payload))callback;
@end
