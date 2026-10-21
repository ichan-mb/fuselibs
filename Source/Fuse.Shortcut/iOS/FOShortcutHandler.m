#import "FOShortcutHandler.h"

@interface FOShortcutHandler ()
@property(nonatomic, copy) NSString *pendingShortcutType;
@property(nonatomic, strong) NSDictionary *pendingUserInfo;
@property(nonatomic, copy) NSString *pendingLaunchType;
@property(nonatomic, assign) BOOL _pendingCall;
@end

@implementation FOShortcutHandler

static const NSUInteger FOShortcutMaxCount = 4;

static FOShortcutHandler * instance = nil;

@synthesize _onCallback;

+(instancetype)sharedInstance
{
    if (instance == nil)
        instance = [[FOShortcutHandler alloc] init];
    return instance;
}

// Removes NSNull values, which are not valid UIApplicationShortcutItem userInfo
// values, without dropping the surrounding dictionary or array.
static id FOSanitizeJSON(id value)
{
    if (value == nil || value == [NSNull null])
        return nil;

    if ([value isKindOfClass:[NSDictionary class]])
    {
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        for (id key in value)
        {
            id sanitized = FOSanitizeJSON(value[key]);
            if (sanitized != nil)
                result[key] = sanitized;
        }
        return result;
    }

    if ([value isKindOfClass:[NSArray class]])
    {
        NSMutableArray* result = [NSMutableArray array];
        for (id element in value)
        {
            id sanitized = FOSanitizeJSON(element);
            if (sanitized != nil)
                [result addObject:sanitized];
        }
        return result;
    }

    return value;
}

-(NSMutableArray<UIApplicationShortcutItem *> *)buildShortcutItems:(NSArray*)shortcuts
{
    NSMutableArray<UIApplicationShortcutItem *> *newShortcuts = [[NSMutableArray alloc] init];

    if (![shortcuts isKindOfClass:[NSArray class]])
        return newShortcuts;

    for (id rawItem in shortcuts)
    {
        if (![rawItem isKindOfClass:[NSDictionary class]])
            continue;

        NSDictionary* item = (NSDictionary*)rawItem;

        NSString* type = item[@"id"];
        NSString* title = item[@"title"];
        if (![type isKindOfClass:[NSString class]] || type.length == 0)
            continue;
        if (![title isKindOfClass:[NSString class]] || title.length == 0)
            continue;

        id subtitleValue = item[@"subtitle"];
        NSString* subtitle = [subtitleValue isKindOfClass:[NSString class]] ? subtitleValue : nil;

        id systemIconValue = item[@"systemIcon"];
        NSString* systemIcon = [systemIconValue isKindOfClass:[NSString class]] ? systemIconValue : nil;

        UIApplicationShortcutIcon* icon = nil;
        if (systemIcon.length > 0)
        {
            if (@available(iOS 13.0, *))
                icon = [UIApplicationShortcutIcon iconWithSystemImageName:systemIcon];
        }

        if (icon == nil)
        {
            id iconValue = item[@"icon"];
            if ([iconValue isKindOfClass:[NSString class]] && [iconValue length] > 0)
                icon = [UIApplicationShortcutIcon iconWithTemplateImageName:iconValue];
        }

        id extrasValue = item[@"extras"];
        NSDictionary* userInfo = nil;
        if ([extrasValue isKindOfClass:[NSDictionary class]])
            userInfo = FOSanitizeJSON(extrasValue);

        UIApplicationShortcutItem *shortcut = [[UIApplicationShortcutItem alloc] initWithType:type localizedTitle:title localizedSubtitle:subtitle icon:icon userInfo:userInfo];
        [newShortcuts addObject:shortcut];
    }

    return newShortcuts;
}

-(void)applyShortcuts:(NSArray*)shortcuts
{
    // Safety net: iOS displays at most four home screen quick actions.
    if (shortcuts.count > FOShortcutMaxCount)
        shortcuts = [shortcuts subarrayWithRange:NSMakeRange(0, FOShortcutMaxCount)];

    [UIApplication sharedApplication].shortcutItems = shortcuts;
}

-(void)registerCallback:(void (^)(NSString* payload))callback
{
    self._onCallback = callback;
    if (self._pendingCall)
        [self handleShortcut:self.pendingShortcutType userInfo:self.pendingUserInfo launchType:self.pendingLaunchType];
}

-(BOOL)registerShortcuts:(NSArray*)shortcuts error:(NSString**)error
{
    if (![shortcuts isKindOfClass:[NSArray class]])
    {
        if (error) *error = @"registerShortcuts expects an array of shortcuts.";
        return NO;
    }

    NSMutableArray* items = [self buildShortcutItems:shortcuts];
    if (items.count > FOShortcutMaxCount)
    {
        if (error)
            *error = [NSString stringWithFormat:@"Cannot register %lu shortcuts; iOS supports at most %lu.", (unsigned long)items.count, (unsigned long)FOShortcutMaxCount];
        return NO;
    }

    [self applyShortcuts:items];
    return YES;
}

-(BOOL)updateShortcuts:(NSArray*)shortcuts error:(NSString**)error
{
    if (![shortcuts isKindOfClass:[NSArray class]])
    {
        if (error) *error = @"updateShortcuts expects an array of shortcuts.";
        return NO;
    }

    NSMutableArray* merged = [NSMutableArray arrayWithArray:[UIApplication sharedApplication].shortcutItems ?: [NSArray array]];
    for (UIApplicationShortcutItem* newItem in [self buildShortcutItems:shortcuts])
    {
        BOOL replaced = NO;
        for (NSUInteger i = 0; i < merged.count; i++)
        {
            UIApplicationShortcutItem* existing = merged[i];
            if ([existing.type isEqualToString:newItem.type])
            {
                [merged replaceObjectAtIndex:i withObject:newItem];
                replaced = YES;
                break;
            }
        }

        if (!replaced)
            [merged addObject:newItem];
    }

    if (merged.count > FOShortcutMaxCount)
    {
        if (error)
            *error = [NSString stringWithFormat:@"Cannot update shortcuts; the resulting set would contain %lu shortcuts, but iOS supports at most %lu.", (unsigned long)merged.count, (unsigned long)FOShortcutMaxCount];
        return NO;
    }

    [self applyShortcuts:merged];
    return YES;
}

-(void)removeShortcuts:(NSArray*)ids
{
    if (![ids isKindOfClass:[NSArray class]])
        return;

    NSSet* idSet = [NSSet setWithArray:ids];
    NSMutableArray* remaining = [NSMutableArray array];
    for (UIApplicationShortcutItem* item in ([UIApplication sharedApplication].shortcutItems ?: [NSArray array]))
    {
        if (![idSet containsObject:item.type])
            [remaining addObject:item];
    }

    [self applyShortcuts:remaining];
}

-(void)clearShortcuts
{
    [self applyShortcuts:[NSArray array]];
}

-(NSString*)getShortcuts
{
    NSMutableArray* result = [NSMutableArray array];
    for (UIApplicationShortcutItem* item in ([UIApplication sharedApplication].shortcutItems ?: [NSArray array]))
    {
        NSMutableDictionary* info = [NSMutableDictionary dictionary];
        info[@"id"] = item.type ?: @"";
        info[@"title"] = item.localizedTitle ?: @"";
        if (item.localizedSubtitle.length > 0)
            info[@"subtitle"] = item.localizedSubtitle;
        if (item.userInfo.count > 0)
            info[@"extras"] = item.userInfo;
        [result addObject:info];
    }

    NSData* data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    if (!data)
        return @"[]";

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UIApplicationShortcutItem *shortcutItem = launchOptions[UIApplicationLaunchOptionsShortcutItemKey];
    if (shortcutItem)
    {
        self.pendingShortcutType = shortcutItem.type;
        self.pendingUserInfo = shortcutItem.userInfo;
        self.pendingLaunchType = @"cold";
        self._pendingCall = YES;
        return NO;
    }
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (self.pendingShortcutType)
        [self handleShortcut:self.pendingShortcutType userInfo:self.pendingUserInfo launchType:self.pendingLaunchType ?: @"cold"];
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler
{
    [self handleShortcut:shortcutItem.type userInfo:shortcutItem.userInfo launchType:@"resume"];
    if (completionHandler)
        completionHandler(YES);
}

-(void)handleShortcut:(NSString*)type userInfo:(NSDictionary*)userInfo launchType:(NSString*)launchType
{
    if (type.length == 0)
        return;

    if (self._onCallback != nil)
    {
        self._onCallback([self payloadForType:type userInfo:userInfo launchType:launchType]);
        self._pendingCall = NO;
        self.pendingShortcutType = nil;
        self.pendingUserInfo = nil;
        self.pendingLaunchType = nil;
    }
    else
    {
        self.pendingShortcutType = type;
        self.pendingUserInfo = userInfo;
        self.pendingLaunchType = launchType;
        self._pendingCall = YES;
    }
}

-(NSString*)payloadForType:(NSString*)type userInfo:(NSDictionary*)userInfo launchType:(NSString*)launchType
{
    NSMutableDictionary* payload = [NSMutableDictionary dictionary];
    payload[@"id"] = type ?: @"";
    payload[@"extras"] = userInfo ?: [NSDictionary dictionary];
    payload[@"launchType"] = launchType ?: @"resume";

    NSData* data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!data)
    {
        // Keep the id and launch type even if the user info is not serializable.
        [payload removeObjectForKey:@"extras"];
        data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    }
    if (!data)
        return @"{}";

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
@end
