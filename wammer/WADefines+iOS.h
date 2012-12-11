//
//  WADefines+iOS.h
//  wammer
//
//  Created by Evadne Wu on 12/17/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAAppearance.h"

@class WAAppDelegate;
extern WAAppDelegate * AppDelegate (void);

extern BOOL WAIsXCallbackURL (NSURL *anURL, NSString **outCommand, NSDictionary **outParams);
extern BOOL isPad(void);
extern BOOL isPhone(void);

#define kFBAccessToken @"kFBAccessToken"
#define kFBExpirationDate @"kFBExpirationDate"

#define WAApplicationDidFinishLaunchingNotification UIApplicationDidFinishLaunchingNotification