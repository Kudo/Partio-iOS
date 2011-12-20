//
//  WADefines.m
//  wammer
//
//  Created by Evadne Wu on 10/2/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WADefines.h"

NSString * const kWAAdvancedFeaturesEnabled = @"WAAdvancedFeaturesEnabled";

BOOL WAAdvancedFeaturesEnabled (void) {
  return [[NSUserDefaults standardUserDefaults] boolForKey:kWAAdvancedFeaturesEnabled];
};


NSString * const kWARemoteEndpointURL = @"WARemoteEndpointURL";
NSString * const kWARemoteEndpointVersion = @"WARemoteEndpointVersion";
NSString * const kWARemoteEndpointCurrentVersion = @"WARemoteEndpointCurrentVersion";
NSString * const kWALastAuthenticatedUserTokenKeychainItem = @"WALastAuthenticatedUserTokenKeychainItem";
NSString * const kWALastAuthenticatedUserPrimaryGroupIdentifier = @"WALastAuthenticatedUserPrimaryGroupIdentifier";
NSString * const kWALastAuthenticatedUserIdentifier = @"WALastAuthenticatedUserIdentifier";
NSString * const kWAUserRegistrationUsesWebVersion = @"WAUserRegistrationUsesWebVersion";
NSString * const kWAUserRegistrationEndpointURL = @"WAUserRegistrationEndpointURL";
NSString * const kWAUserRequiresReauthentication = @"WAUserRequiresReauthentication";
NSString * const kWAUserPasswordResetEndpointURL = @"WAUserPasswordResetEndpointURL";
NSString * const kWAAlwaysAllowExpensiveRemoteOperations = @"WAAlwaysAllowExpensiveRemoteOperations";
NSString * const kWAAlwaysDenyExpensiveRemoteOperations = @"WAAlwaysDenyExpensiveRemoteOperations";
NSString * const kWADebugAutologinUserIdentifier = @"WADebugAutologinUserIdentifier";
NSString * const kWADebugAutologinUserPassword = @"WADebugAutologinUserPassword";
NSString * const kWACrashReportRecipients = @"WACrashReportRecipients";
NSString * const kWADebugLastScanSyncBezelsVisible = @"WADebugLastScanSyncBezelsVisible";

NSString * const kWACompositionSessionRequestedNotification = @"WACompositionSessionRequestedNotification";
NSString * const kWAApplicationDidReceiveRemoteURLNotification = @"WAApplicationDidReceiveRemoteURLNotification";
NSString * const kWARemoteInterfaceReachableHostsDidChangeNotification = @"WARemoteInterfaceReachableHostsDidChangeNotification";
NSString * const kWARemoteInterfaceDidObserveAuthenticationFailureNotification = @"WARemoteInterfaceDidObserveAuthenticationFailureNotification";
NSString * const kWASettingsDidRequestActionNotification = @"kWASettingsDidRequestActionNotification";

NSString * const kWARemoteEndpointApplicationKeyPhone = @"ca5c3c5c-287d-5805-93c1-a6c2cbf9977c";
NSString * const kWARemoteEndpointApplicationKeyPad = @"ba15e628-44e6-51bc-8146-0611fdfa130b";
NSString * const kWARemoteEndpointApplicationKeyMac = @"ba15e628-44e6-51bc-8146-0611fdfa130b";	//	FIXME: Announce the Mac version when it matures and use the correct key

NSString * const kWACallbackActionDidFinishUserRegistration = @"didFinishUserRegistration";
NSString * const kWACallbackActionSetAdvancedFeaturesEnabled = @"showMeTheMoney";
NSString * const kWACallbackActionSetRemoteEndpointURL = @"setRemoteEndpointURL";
NSString * const kWACallbackActionSetUserRegistrationEndpointURL = @"setUserRegistrationEndpointURL";
NSString * const kWACallbackActionSetUserPasswordResetEndpointURL = @"setUserPasswordResetEndpointURL";


void WARegisterUserDefaults () {

	[[NSUserDefaults standardUserDefaults] registerDefaults:WAPresetDefaults()];

}

NSDictionary * WAPresetDefaults () {

	NSURL *defaultsURL = [[NSBundle mainBundle] URLForResource:@"WADefaults" withExtension:@"plist"];
	NSData *defaultsData = [NSData dataWithContentsOfMappedFile:[defaultsURL path]];
	NSDictionary *defaultsObject = [NSPropertyListSerialization propertyListFromData:defaultsData mutabilityOption:NSPropertyListImmutable format:nil errorDescription:nil];
	
	return defaultsObject;

}


NSString * const kWACurrentGeneratedDeviceIdentifier = @"WACurrentGeneratedDeviceIdentifier";

BOOL WADeviceIdentifierReset (void) {

	CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
	if (!uuidRef)
    return NO;
	
	NSString *uuid = [NSMakeCollectable(CFUUIDCreateString(kCFAllocatorDefault, uuidRef)) autorelease];
	CFRelease(uuidRef);

  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWACurrentGeneratedDeviceIdentifier];
  [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:kWACurrentGeneratedDeviceIdentifier];
  
  return [[NSUserDefaults standardUserDefaults] synchronize];

}

NSString * WADeviceIdentifier (void) {

  NSString *returnedString = [[NSUserDefaults standardUserDefaults] stringForKey:kWACurrentGeneratedDeviceIdentifier];
  if (returnedString)
    return returnedString;

  if (WADeviceIdentifierReset())
    return WADeviceIdentifier();

  return nil;

}