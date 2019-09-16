#import <Foundation/Foundation.h>

@interface NSUserDefaults (SecureAdditions)

- (void)setSecret:(NSString*)secret;

- (BOOL)secretBoolForKey:(NSString *)defaultName;
- (float)secretFloatForKey:(NSString *)defaultName;
- (NSInteger)secretIntegerForKey:(NSString *)defaultName;
- (NSString *)secretStringForKey:(NSString *)defaultName;
- (id)secretObjectForKey:(NSString *)defaultName;

- (void)setSecretBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setSecretFloat:(float)value forKey:(NSString *)defaultName;
- (void)setSecretInteger:(NSInteger)value forKey:(NSString *)defaultName;
- (void)setSecretObject:(id)value forKey:(NSString *)defaultName;

@end