#import "RNHockeyApp.h"
#import "RCTEventDispatcher.h"

static BOOL initialized = NO;
static BOOL autoSend = YES;
static BOOL metrics = YES;
static AuthType authType = 0;
static NSString *token = nil;
static NSString *appSecret = nil;

@interface RNHockeyApp() <BITHockeyManagerDelegate, BITCrashManagerDelegate>
@end

@implementation RNHockeyApp

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(configure:(NSString *) apiToken autoSend:(BOOL) autoSendCrashes authType:(NSInteger) apiAuthType appSecret:(NSString*) apiAppSecret ignoreDefaultHandler:(BOOL) ignoreDefaultCrashHandler metrics:(BOOL) metrics_enabled)
{
    if (initialized == NO) {
        autoSend = autoSendCrashes;
        token = apiToken;
        authType = apiAuthType;
        appSecret = apiAppSecret;
        metrics = metrics_enabled;
        initialized = YES;
    } else {
        NSLog(@"Already initialized! \n");
    }
}

RCT_EXPORT_METHOD(start) {
    if (initialized == YES) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:token
                                                                   delegate:self];
            if (autoSend == YES) {
                [[BITHockeyManager sharedHockeyManager].crashManager setCrashManagerStatus:BITCrashManagerStatusAutoSend];
            }

            if(metrics == NO) {
                [BITHockeyManager sharedHockeyManager].disableMetricsManager = YES;
            }

            switch (authType) {
                case EmailSecret:
                    NSLog(@"react-native-hockeyapp: Email + Secret Auth set");
                    [[BITHockeyManager sharedHockeyManager].authenticator setAuthenticationSecret:appSecret];
                    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeHockeyAppEmail];
                    break;
                case EmailPassword:
                    NSLog(@"react-native-hockeyapp: Email + Password Auth set");
                    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeHockeyAppUser];
                    break;
                case DeviceUUID:
                    NSLog(@"react-native-hockeyapp: Device UUID Auth set");
                    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeDevice];
                    break;
                case WebAuth:
                    NSLog(@"react-native-hockeyapp: Web Auth set");
                    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeWebAuth];
                    break;
                case Anonymous:
                default:
                    NSLog(@"react-native-hockeyapp: Anonymous Auth set");
                    [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeAnonymous];
                    break;
            }
            [[BITHockeyManager sharedHockeyManager] startManager];
            [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];

            [RNHockeyApp deleteMetadataFileIfExists];
        });
    }
}

RCT_EXPORT_METHOD(addMetadata:(NSData*) metadata)
{
    if (initialized == YES) {
        NSDictionary *newMetadata = [NSJSONSerialization JSONObjectWithData:metadata options:0 error:nil];

        if (!newMetadata) {
           NSLog(@"react-native-hockeyapp: the metadata is not valid JSON.");
           return;
        }

        NSMutableDictionary *allMetadata = [RNHockeyApp getExistingMetadata];
        [allMetadata addEntriesFromDictionary:newMetadata];
        NSData *json = [NSJSONSerialization dataWithJSONObject:allMetadata options:0 error:nil];

        if (json) {
            NSString *filePath = [RNHockeyApp getMetadataFilePath];
            [json writeToFile:filePath atomically:YES];
        }
    } else {
        NSLog(@"Not initialized! \n");
    }
}

RCT_EXPORT_METHOD(feedback)
{
    if (initialized == YES) {
        [[BITHockeyManager sharedHockeyManager].feedbackManager showFeedbackListView];
    } else {
        NSLog(@"Not initialized! \n");
    }
}

RCT_EXPORT_METHOD(trackEvent: (NSString *) event)
{
    if (initialized == YES) {
        BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;
      [metricsManager trackEventWithName:event];
    } else {
        NSLog(@"Not initialized! \n");
    }
}

RCT_EXPORT_METHOD(checkForUpdate)
{
    if (initialized == YES) {
        [[BITHockeyManager sharedHockeyManager].updateManager checkForUpdate];
    } else {
        NSLog(@"Not initialized! \n");
    }
}

RCT_EXPORT_METHOD(generateTestCrash)
{
    if (initialized == YES) {
        [[BITHockeyManager sharedHockeyManager].crashManager generateTestCrash];
    }
}

+ (void)deleteMetadataFileIfExists
{
    NSString *filePath = [RNHockeyApp getMetadataFilePath];

    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
}

+ (NSMutableDictionary *)getExistingMetadata
{
    NSString *filePath = [RNHockeyApp getMetadataFilePath];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSMutableDictionary *dictionary = nil;

    if (data) {
        dictionary = [[NSJSONSerialization JSONObjectWithData:data options:0 error:nil] mutableCopy];
    }

    if (!dictionary) {
        dictionary = [NSMutableDictionary new];
    }

    return dictionary;
}

+ (NSString *)getMetadataFilePath
{
    BOOL expandTilde = YES;
    NSString *directoryPath = [NSSearchPathForDirectoriesInDomains (NSLibraryDirectory, NSUserDomainMask, expandTilde) objectAtIndex:0];

    return [directoryPath stringByAppendingPathComponent:@"HockeyAppCrashMetadata.json"];
}

- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager
{
    NSString *filePath = [RNHockeyApp getMetadataFilePath];

    return [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
}

@end
