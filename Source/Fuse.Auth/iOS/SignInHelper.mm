#import "SignInHelper.h"
#import <Security/Security.h>

static NSString* const FuseSecureStorageService = @"FuseSecureStorage";

static void FuseSecureStorageSet(NSString* key, NSString* value)
{
    if (value == nil)
        return;

    NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary* query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:FuseSecureStorageService forKey:(__bridge id)kSecAttrService];
    [query setObject:key forKey:(__bridge id)kSecAttrAccount];

    NSDictionary* update = [NSDictionary dictionaryWithObject:data forKey:(__bridge id)kSecValueData];
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
    if (status == errSecItemNotFound) {
        [query setObject:data forKey:(__bridge id)kSecValueData];
        [query setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
        SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
}

static void FuseSecureStorageRemove(NSString* key)
{
    NSMutableDictionary* query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:FuseSecureStorageService forKey:(__bridge id)kSecAttrService];
    [query setObject:key forKey:(__bridge id)kSecAttrAccount];
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@implementation SignInHelper


-(void)handleAppleIDAuthorization:(void (^)())action_success error: (void (^)(NSString*))action_error;
{

    if (@available(iOS 13.0, *)) {
        self._action_success = action_success;
        self._action_error = action_error;

        ASAuthorizationAppleIDProvider *appleIDProvider = [ASAuthorizationAppleIDProvider new];
        ASAuthorizationAppleIDRequest *request = appleIDProvider.createRequest;
        request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        [controller performRequests];
    }
}

-(void)hasSignedIn:(void (^)(bool))result
{
    if (@available(iOS 13.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ASAuthorizationAppleIDProvider *appleIDProvider = [ASAuthorizationAppleIDProvider new];
            NSString* userId= [[NSUserDefaults standardUserDefaults] valueForKey:@"appleIDCredential.currentIdentifier"];
            if (userId == nil)
            {
                result(false);
                return;
            }
            [appleIDProvider getCredentialStateForUserID:userId
                completion:^(ASAuthorizationAppleIDProviderCredentialState credentialState, NSError *error) {
                    switch(credentialState)
                    {
                        case ASAuthorizationAppleIDProviderCredentialAuthorized:
                            result(true);
                            break;
                        case ASAuthorizationAppleIDProviderCredentialNotFound:
                        case ASAuthorizationAppleIDProviderCredentialRevoked:
                            // remove appleId / password credential Information
                            FuseSecureStorageRemove(@"platformSignIn.userId");
                            FuseSecureStorageRemove(@"platformSignIn.lastName");
                            FuseSecureStorageRemove(@"platformSignIn.firstName");
                            FuseSecureStorageRemove(@"platformSignIn.email");

                            FuseSecureStorageRemove(@"platformSignIn.user");
                            FuseSecureStorageRemove(@"platformSignIn.password");

                            // Also remove values left in UserDefaults by older versions.
                            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"platformSignIn.userId"];
                            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"platformSignIn.lastName"];
                            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"platformSignIn.firstName"];
                            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"platformSignIn.email"];
                            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"platformSignIn.user"];
                            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"platformSignIn.password"];
                            result(false);
                            break;
                        default:
                            result(false);
                            break;
                    }
            }];
        });
    }
    result(false);
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error
{
    self._action_error(error.localizedDescription);
}

-(void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization
{
    if ([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
        ASAuthorizationAppleIDCredential *appleIDCredential = authorization.credential;
        NSString *user = appleIDCredential.user;
        NSString *familyName = appleIDCredential.fullName.familyName;
        NSString *givenName = appleIDCredential.fullName.givenName;
        NSString *email = appleIDCredential.email;
        // save to secure storage
        if (user != nil)
            FuseSecureStorageSet(@"platformSignIn.userId", user);
        if (familyName != nil)
            FuseSecureStorageSet(@"platformSignIn.lastName", familyName);
        if (givenName != nil)
            FuseSecureStorageSet(@"platformSignIn.firstName", givenName);
        if (email != nil)
            FuseSecureStorageSet(@"platformSignIn.email", email);

        if (self._action_success != nil)
            self._action_success();
    }
    if ([authorization.credential isKindOfClass:[ASPasswordCredential class]]) {
        ASPasswordCredential *passwordCredential = authorization.credential;
        NSString *user = passwordCredential.user;
        NSString *password = passwordCredential.password;

        if (user != nil)
            FuseSecureStorageSet(@"platformSignIn.user", user);
        if (password != nil)
            FuseSecureStorageSet(@"platformSignIn.password", password);

        if (self._action_success != nil)
            self._action_success();
    }
}

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller  API_AVAILABLE(ios(13.0)){

    return [[UIApplication sharedApplication] delegate].window;
}


@end