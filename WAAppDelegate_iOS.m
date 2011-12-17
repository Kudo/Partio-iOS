//
//  WAAppDelegate_iOS.m
//  wammer
//
//  Created by Evadne Wu on 12/17/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAAppDelegate_iOS.h"

#import "WADefines.h"

#import "WAAppDelegate.h"

#import "IRRemoteResourcesManager.h"
#import "IRRemoteResourceDownloadOperation.h"

#import "IRWebAPIEngine+ExternalTransforms.h"

#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WAViewController.h"
#import "WANavigationController.h"

#import "WAAuthenticationRequestViewController.h"
#import "WARegisterRequestViewController.h"

#import "WARemoteInterface.h"
#import "IRKeychainManager.h"

#import "WAApplicationRootViewControllerDelegate.h"

#import "UIApplication+CrashReporting.h"
#import "WASetupViewController.h"

#import "WANavigationBar.h"

#import "UIView+IRAdditions.h"

#import "IRAlertView.h"
#import "IRAction.h"

#import "WAPostsViewControllerPhone.h"

#import "WAStationDiscoveryFeedbackViewController.h"

#import "IRLifetimeHelper.h"
#import "WAOverlayBezel.h"


@interface WAAppDelegate_iOS () <IRRemoteResourcesManagerDelegate, WAApplicationRootViewControllerDelegate, WASetupViewControllerDelegate>

- (void) presentSetupViewControllerAnimated:(BOOL)animated;
- (void) configureRemoteResourceDownloadOperation:(IRRemoteResourceDownloadOperation *)anOperation;

- (void) handleObservedAuthenticationFailure:(NSNotification *)aNotification;
- (BOOL) removeAuthenticationData;

- (void) performUserOnboardingUsingAuthRequestViewController:(WAAuthenticationRequestViewController *)self;

@property (nonatomic, readwrite, assign) BOOL alreadyRequestingAuthentication;

- (void) clearViewHierarchy;
- (void) recreateViewHierarchy;

@end


@implementation WAAppDelegate_iOS
@synthesize window = _window;
@synthesize alreadyRequestingAuthentication;

- (id) init {

  self = [super init];
  if (!self)
    return nil;

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleObservedAuthenticationFailure:) name:kWARemoteInterfaceDidObserveAuthenticationFailureNotification object:nil];
  
  return self;

}

- (void) dealloc {

  //  This is so not going to happen
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];

}

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	__block __typeof__(self) nrSelf = self;
	
	WARegisterUserDefaults();
  
  [IRRelativeDateFormatter sharedFormatter].approximationMaxTokenCount = 1;
	
	[IRRemoteResourcesManager sharedManager].delegate = self;
	[IRRemoteResourcesManager sharedManager].queue.maxConcurrentOperationCount = 4;
	[IRRemoteResourcesManager sharedManager].onRemoteResourceDownloadOperationWillBegin = ^ (IRRemoteResourceDownloadOperation *anOperation) {
		[nrSelf configureRemoteResourceDownloadOperation:anOperation];
	};

	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		(id)kCFBooleanTrue, [[UIApplication sharedApplication] crashReportingEnabledUserDefaultsKey],
	nil]];
  
	[[UIApplication sharedApplication] setCrashReportRecipients:[[NSUserDefaults standardUserDefaults] arrayForKey:kWACrashReportRecipients]];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
	
	
	self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	self.window.backgroundColor = [UIColor blackColor];
	[self.window makeKeyAndVisible];
	
			
	void (^initializeInterface)() = ^ {
		
		if (![self hasAuthenticationData]) {
		
			[self applicationRootViewControllerDidRequestReauthentication:nil];
						
		} else {
		
			NSString *lastAuthenticatedUserIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:kWALastAuthenticatedUserIdentifier];
			
			if (lastAuthenticatedUserIdentifier)
				[WADataStore defaultStore].persistentStoreName = [lastAuthenticatedUserIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			
			[self recreateViewHierarchy];
			
		}
    
	};
	
	
	//	UIApplication+CrashReporter shall only be used on a real device for now
	
	BOOL reportsCrashOnSimulator = NO;
	
	if (!reportsCrashOnSimulator && ([[UIDevice currentDevice].model rangeOfString:@"Simulator"].location != NSNotFound)) {
	
    //  Never send crash reports thru the Simulator since it won’t actually matter

		initializeInterface();
	
	} else {
  
    if (WAAdvancedFeaturesEnabled()) {
		
			[self clearViewHierarchy];
    
      //  Only enable crash reporting as an advanced feature
	
      [[UIApplication sharedApplication] handlePendingCrashReportWithCompletionBlock: ^ (BOOL didHandle) {
        if ([[UIApplication sharedApplication] crashReportingEnabled]) {
          [[UIApplication sharedApplication] enableCrashReporterWithCompletionBlock: ^ (BOOL didEnable) {
            [[UIApplication sharedApplication] setCrashReportingEnabled:didEnable];
            initializeInterface();
          }];
        } else {
          initializeInterface();
        }
      }];
    
    } else {
      initializeInterface();
    }
	
	}
	
  return YES;
	
}

- (void) clearViewHierarchy {

	__block void (^dismissModal)(UIViewController *aVC);
	dismissModal = ^ (UIViewController *aVC) {
		
		if (aVC.modalViewController)
			dismissModal(aVC.modalViewController);
		else
			[aVC dismissModalViewControllerAnimated:NO];
	
	};
	
	dismissModal(self.window.rootViewController);
	
	
	WAViewController *bottomMostViewController = [[[WAViewController alloc] init] autorelease];
	bottomMostViewController.onShouldAutorotateToInterfaceOrientation = ^ (UIInterfaceOrientation toOrientation) {
		return YES;
	};
	bottomMostViewController.onLoadview = ^ (WAViewController *self) {
		self.view = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 1024, 1024 }] autorelease];
		self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternBlackPaper"]];
	};
	
	self.window.rootViewController = bottomMostViewController;

}

- (void) recreateViewHierarchy {

	NSString *rootViewControllerClassName = nil;
		
	switch (UI_USER_INTERFACE_IDIOM()) {
		case UIUserInterfaceIdiomPad: {
			rootViewControllerClassName = @"WADiscretePaginatedArticlesViewController";
			break;
		}
		default:
		case UIUserInterfaceIdiomPhone: {
			rootViewControllerClassName = @"WAPostsViewControllerPhone";
			break;
		}
	}
	
	NSParameterAssert(rootViewControllerClassName);
	
	__block UIViewController *presentedViewController = [[(UIViewController *)[NSClassFromString(rootViewControllerClassName) alloc] init] autorelease];
	
	self.window.rootViewController = (( ^ {
	
		__block WANavigationController *navController = [[WANavigationController alloc] initWithRootViewController:presentedViewController];
		
		navController.onViewDidLoad = ^ (WANavigationController *self) {
			self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternThickShrunkPaper"]];
			((WANavigationBar *)self.navigationBar).tintColor = [UIColor brownColor];
			((WANavigationBar *)self.navigationBar).backgroundView = [WANavigationBar defaultPatternBackgroundView];
		};
		
		if ([navController isViewLoaded])
			navController.onViewDidLoad(navController);
		
		return navController;
		
	})());
	
	if ([presentedViewController conformsToProtocol:@protocol(WAApplicationRootViewController)])
		[(id<WAApplicationRootViewController>)presentedViewController setDelegate:self];
			
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];

}





- (void) applicationRootViewControllerDidRequestReauthentication:(id<WAApplicationRootViewController>)controller {

	dispatch_async(dispatch_get_main_queue(), ^ {

		//	[self presentAuthenticationRequestRemovingPriorData:YES clearingNavigationHierarchy:YES runningOnboardingProcess:YES];
		
		void (^writeCredentials)(NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier) = ^ (NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier) {
		
			IRKeychainAbstractItem *keychainItem = [self currentKeychainItem];
			keychainItem.secretString = userToken;
			[keychainItem synchronize];
			
			NSData *archivedItemData = [NSKeyedArchiver archivedDataWithRootObject:keychainItem];
			
			[[NSUserDefaults standardUserDefaults] setObject:archivedItemData forKey:kWALastAuthenticatedUserTokenKeychainItem];
			[[NSUserDefaults standardUserDefaults] setObject:userIdentifier forKey:kWALastAuthenticatedUserIdentifier];
			[[NSUserDefaults standardUserDefaults] setObject:primaryGroupIdentifier forKey:kWALastAuthenticatedUserPrimaryGroupIdentifier];
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kWAUserRequiresReauthentication];
			[[NSUserDefaults standardUserDefaults] synchronize];
		
		};

		[self presentAuthenticationRequestWithReason:nil allowingCancellation:NO removingPriorData:YES clearingNavigationHierarchy:YES onAuthSuccess:^(NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier) {
		
			writeCredentials(userIdentifier, userToken, primaryGroupIdentifier);
			[WADataStore defaultStore].persistentStoreName = userIdentifier;
			//	HECKLING ?
			
		} runningOnboardingProcess:YES];
			
	});

}

- (void) handleObservedAuthenticationFailure:(NSNotification *)aNotification {

  dispatch_async(dispatch_get_main_queue(), ^{

		[self presentAuthenticationRequestWithReason:@"Token Expired" allowingCancellation:YES removingPriorData:NO clearingNavigationHierarchy:NO runningOnboardingProcess:NO];

  });
  
}





- (BOOL) hasAuthenticationData {

	NSString *lastAuthenticatedUserIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:kWALastAuthenticatedUserIdentifier];
	NSData *lastAuthenticatedUserTokenKeychainItemData = [[NSUserDefaults standardUserDefaults] dataForKey:kWALastAuthenticatedUserTokenKeychainItem];
	NSString *lastAuthenticatedUserPrimaryGroupIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:kWALastAuthenticatedUserPrimaryGroupIdentifier];
	IRKeychainAbstractItem *lastAuthenticatedUserTokenKeychainItem = nil;
	
	if (!lastAuthenticatedUserTokenKeychainItem) {
		if (lastAuthenticatedUserTokenKeychainItemData) {
			lastAuthenticatedUserTokenKeychainItem = [NSKeyedUnarchiver unarchiveObjectWithData:lastAuthenticatedUserTokenKeychainItemData];
		}
	}
	
	BOOL authenticationInformationSufficient = (lastAuthenticatedUserTokenKeychainItem.secret) && lastAuthenticatedUserIdentifier;
	
	if (authenticationInformationSufficient) {
	
		if (lastAuthenticatedUserIdentifier)
			[WARemoteInterface sharedInterface].userIdentifier = lastAuthenticatedUserIdentifier;
		
		if (lastAuthenticatedUserTokenKeychainItem.secretString)
			[WARemoteInterface sharedInterface].userToken = lastAuthenticatedUserTokenKeychainItem.secretString;
		
		if (lastAuthenticatedUserPrimaryGroupIdentifier)
			[WARemoteInterface sharedInterface].primaryGroupIdentifier = lastAuthenticatedUserPrimaryGroupIdentifier;
		
	}
  
  if ([[NSUserDefaults standardUserDefaults] boolForKey:kWAUserRequiresReauthentication])
    authenticationInformationSufficient = NO;
	
	return authenticationInformationSufficient;

}

- (BOOL) removeAuthenticationData {

  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWALastAuthenticatedUserTokenKeychainItem];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWALastAuthenticatedUserIdentifier];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWALastAuthenticatedUserPrimaryGroupIdentifier];
  
  [WARemoteInterface sharedInterface].userIdentifier = nil;
  [WARemoteInterface sharedInterface].userToken = nil;
  [WARemoteInterface sharedInterface].primaryGroupIdentifier = nil;
  
  BOOL didEraseAuthData = [[NSUserDefaults standardUserDefaults] synchronize];
  BOOL didResetDeviceIdentifier = WADeviceIdentifierReset();
  
  return didEraseAuthData && didResetDeviceIdentifier;

}

- (IRKeychainAbstractItem *) currentKeychainItem {

  IRKeychainAbstractItem *lastAuthenticatedUserTokenKeychainItem = nil;

  if (!lastAuthenticatedUserTokenKeychainItem) {
    NSData *lastAuthenticatedUserTokenKeychainItemData = [[NSUserDefaults standardUserDefaults] dataForKey:kWALastAuthenticatedUserTokenKeychainItem];
    if (lastAuthenticatedUserTokenKeychainItemData)
      lastAuthenticatedUserTokenKeychainItem = [NSKeyedUnarchiver unarchiveObjectWithData:lastAuthenticatedUserTokenKeychainItemData];
  }
  
  if (!lastAuthenticatedUserTokenKeychainItem) {
    lastAuthenticatedUserTokenKeychainItem = [[[IRKeychainInternetPasswordItem alloc] initWithIdentifier:@"com.waveface.wammer"] autorelease];
  }

  return lastAuthenticatedUserTokenKeychainItem;
  
}

- (BOOL) presentAuthenticationRequestRemovingPriorData:(BOOL)eraseAuthInfo clearingNavigationHierarchy:(BOOL)zapEverything runningOnboardingProcess:(BOOL)shouldRunOnboardingChecksIfUserUnchanged {

  return [self presentAuthenticationRequestWithReason:nil allowingCancellation:NO removingPriorData:eraseAuthInfo clearingNavigationHierarchy:zapEverything runningOnboardingProcess:shouldRunOnboardingChecksIfUserUnchanged];

}

- (BOOL) presentAuthenticationRequestWithReason:(NSString *)aReason allowingCancellation:(BOOL)allowsCancellation removingPriorData:(BOOL)eraseAuthInfo clearingNavigationHierarchy:(BOOL)zapEverything runningOnboardingProcess:(BOOL)shouldRunOnboardingChecksIfUserUnchanged {

	return [self presentAuthenticationRequestWithReason:aReason allowingCancellation:allowsCancellation removingPriorData:eraseAuthInfo clearingNavigationHierarchy:zapEverything onAuthSuccess:nil runningOnboardingProcess:shouldRunOnboardingChecksIfUserUnchanged];

}

- (BOOL) presentAuthenticationRequestWithReason:(NSString *)aReason allowingCancellation:(BOOL)allowsCancellation removingPriorData:(BOOL)eraseAuthInfo clearingNavigationHierarchy:(BOOL)zapEverything onAuthSuccess:(void (^)(NSString *userIdentifier, NSString *userToken, NSString *primaryGroupIdentifier))successBlock runningOnboardingProcess:(BOOL)shouldRunOnboardingChecksIfUserUnchanged {

  @synchronized (self) {
    
    if (self.alreadyRequestingAuthentication)
      return NO;
    
    self.alreadyRequestingAuthentication = YES;
  
  }
	
  NSString *capturedCurrentUserIdentifier = [WARemoteInterface sharedInterface].userIdentifier;
  BOOL (^userIdentifierChanged)() = ^ {
    return (BOOL)![[WARemoteInterface sharedInterface].userIdentifier isEqualToString:capturedCurrentUserIdentifier];
  };
  
  if (allowsCancellation)
    NSParameterAssert(!eraseAuthInfo);

	if (eraseAuthInfo)
    [self removeAuthenticationData];
	
	if (zapEverything)
		[self clearViewHierarchy];

	
  __block WAAuthenticationRequestViewController *authRequestVC;
	
	void (^presentWrappedAuthRequestVC)(WAAuthenticationRequestViewController *authVC, BOOL animated) = ^ (WAAuthenticationRequestViewController *authVC, BOOL animated) {
	
		WANavigationController *authRequestWrappingVC = [[[WANavigationController alloc] initWithRootViewController:authVC] autorelease];
		authRequestWrappingVC.modalPresentationStyle = UIModalPresentationFormSheet;
		authRequestWrappingVC.disablesAutomaticKeyboardDismissal = NO;
	
		[self.window.rootViewController presentModalViewController:authRequestWrappingVC animated:animated];
		return;
	
		switch (UI_USER_INTERFACE_IDIOM()) {
		
			//  FIXME: Move this in a CustomUI category
		
			case UIUserInterfaceIdiomPad: {
			
				WAViewController *fullscreenBaseVC = [[[WAViewController alloc] init] autorelease];
				fullscreenBaseVC.onShouldAutorotateToInterfaceOrientation = ^ (UIInterfaceOrientation toOrientation) {
					return YES;
				};
				fullscreenBaseVC.modalPresentationStyle = UIModalPresentationFullScreen;
				fullscreenBaseVC.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternBlackPaper"]];	//	was		WAPatternCarbonFibre
				
				[fullscreenBaseVC.view addSubview:((^ {
					UIActivityIndicatorView *spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
					spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
					spinner.center = (CGPoint){
						roundf(CGRectGetMidX(fullscreenBaseVC.view.bounds)),
						roundf(CGRectGetMidY(fullscreenBaseVC.view.bounds))
					};
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
						[spinner startAnimating];							
					});
					return spinner;
				})())];
				
				if (self.window.rootViewController.modalViewController)
					[self.window.rootViewController.modalViewController dismissModalViewControllerAnimated:NO];
				
				[self.window.rootViewController presentModalViewController:fullscreenBaseVC animated:NO];
				[fullscreenBaseVC presentModalViewController:authRequestWrappingVC animated:animated];
				
				break;
			
			}
			
			case UIUserInterfaceIdiomPhone:
			default: {
			
				if (self.window.rootViewController.modalViewController)
					[self.window.rootViewController.modalViewController dismissModalViewControllerAnimated:NO];
				
				[self.window.rootViewController presentModalViewController:authRequestWrappingVC animated:animated];
				break;
				
			}
		
		}
	
	};
  
  IRAction *resetPasswordAction = [IRAction actionWithTitle:NSLocalizedString(@"WAActionResetPassword", @"Action title for resetting password") block: ^ {
  
    authRequestVC.password = nil;
    [authRequestVC assignFirstResponderStatusToBestMatchingField];
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:kWAUserPasswordResetEndpointURL]]];
  
  }];

  IRAction *registerUserAction = [IRAction actionWithTitle:NSLocalizedString(@"WAActionRegisterUser", @"Action title for registering") block: ^ {
  
    __block WARegisterRequestViewController *registerRequestVC = [WARegisterRequestViewController controllerWithCompletion:^(WARegisterRequestViewController *self, NSError *error) {
    
      if (error) {
        
        NSString *alertTitle = NSLocalizedString(@"WAErrorUserRegistrationFailedTitle", @"Title for registration failure");
        
        NSString *alertText = [[NSArray arrayWithObjects:
          NSLocalizedString(@"WAErrorUserRegistrationFailedDescription", @"Description for registration failure"),
          [NSString stringWithFormat:@"“%@”.", [error localizedDescription]], @"\n\n",
          NSLocalizedString(@"WAErrorUserRegistrationFailedRecoveryNotion", @"Recovery notion for registration failure recovery"),
        nil] componentsJoinedByString:@""];

        [[IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:nil otherActions:[NSArray arrayWithObjects:
        
          [IRAction actionWithTitle:@"OK" block:nil],
        
        nil]] show];
        
        return;
      
      }
      
      authRequestVC.username = self.username;
      authRequestVC.password = self.password;
      authRequestVC.performsAuthenticationOnViewDidAppear = YES;

      [authRequestVC.tableView reloadData];
      [authRequestVC.navigationController popToViewController:authRequestVC animated:YES];

    }];
  
    registerRequestVC.username = authRequestVC.username;
    registerRequestVC.password = authRequestVC.password;
    
    [authRequestVC.navigationController pushViewController:registerRequestVC animated:YES];
  
  }];
  
  IRAction *signInUserAction = [IRAction actionWithTitle:NSLocalizedString(@"WAActionSignIn", @"Action title for signing in") block:^{
    
    [authRequestVC authenticate];
    
  }];
  
  
  __block __typeof__(self) nrAppDelegate = self;
  
  authRequestVC = [WAAuthenticationRequestViewController controllerWithCompletion: ^ (WAAuthenticationRequestViewController *self, NSError *anError) {
  
      if (anError) {
      
        NSString *alertTitle = NSLocalizedString(@"WAErrorAuthenticationFailedTitle", @"Title for authentication failure");
        NSString *alertText = [[NSArray arrayWithObjects:
          NSLocalizedString(@"WAErrorAuthenticationFailedDescription", @"Description for authentication failure"),
          [NSString stringWithFormat:@"“%@”.", [anError localizedDescription]], @"\n\n",
          NSLocalizedString(@"WAErrorAuthenticationFailedRecoveryNotion", @"Recovery notion for authentication failure recovery"),
        nil] componentsJoinedByString:@""];
        
        [[IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:[IRAction actionWithTitle:NSLocalizedString(@"WAActionCancel", @"Action title for cancelling") block:^{
        
          authRequestVC.password = nil;
          [authRequestVC assignFirstResponderStatusToBestMatchingField];
          
        }] otherActions:[NSArray arrayWithObjects:
          
          resetPasswordAction,
          registerUserAction,
          
        nil]] show];
        
        return;
      
      }
			
			WARemoteInterface *ri = [WARemoteInterface sharedInterface];
			
			if (successBlock)
				successBlock(ri.userIdentifier, ri.userToken, ri.primaryGroupIdentifier);
			
			if (zapEverything) {
				UINavigationController *navC = [self.navigationController retain];
				[self dismissModalViewControllerAnimated:NO];
				[nrAppDelegate recreateViewHierarchy];
				[nrAppDelegate.window.rootViewController presentModalViewController:navC animated:NO];
			}
  
      if (userIdentifierChanged() || shouldRunOnboardingChecksIfUserUnchanged) {
        [nrAppDelegate performUserOnboardingUsingAuthRequestViewController:self];
      } else {
        [self dismissModalViewControllerAnimated:YES];
      }
      
      nrAppDelegate.alreadyRequestingAuthentication = NO;
      
  }];
  
  if (aReason)
    authRequestVC.navigationItem.prompt = aReason;
  
  if (allowsCancellation) {
    authRequestVC.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemCancel wiredAction:^(IRBarButtonItem *senderItem) {
      [authRequestVC.navigationController dismissModalViewControllerAnimated:YES];
    }];
  }
  
  [signInUserAction irBind:@"enabled" toObject:authRequestVC keyPath:@"validForAuthentication" options:[NSDictionary dictionaryWithObjectsAndKeys:
    (id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
  nil]];
  [authRequestVC irPerformOnDeallocation:^{
    [signInUserAction irUnbind:@"enabled"];
  }];
  
  NSMutableArray *authRequestActions = [NSMutableArray arrayWithObjects:
    
    signInUserAction,
    registerUserAction,
    
  nil];

  if (WAAdvancedFeaturesEnabled()) {
    
    [authRequestActions addObject:[IRAction actionWithTitle:@"Debug Fill" block:^{
      
      authRequestVC.username = [[NSUserDefaults standardUserDefaults] stringForKey:kWADebugAutologinUserIdentifier];
      authRequestVC.password = [[NSUserDefaults standardUserDefaults] stringForKey:kWADebugAutologinUserPassword];
      [authRequestVC authenticate];
      
    }]];
		
  }
  
  authRequestVC.actions = authRequestActions;
	
	presentWrappedAuthRequestVC(authRequestVC, NO);
	
  return YES;

}

- (void) performUserOnboardingUsingAuthRequestViewController:(WAAuthenticationRequestViewController *)authVC {

	NSParameterAssert([NSThread isMainThread]);

	__block __typeof__(self) nrAppDelegate = self;

	UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
	UIViewController *rootVC = keyWindow.rootViewController;
	UIView *rootView = rootVC.view;
	
	UIView *overlayView = ((^ {
	
		UIView *returnedView = [[[UIView alloc] initWithFrame:rootView.bounds] autorelease];
		returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		
		UIActivityIndicatorView *spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
		
		spinner.center = (CGPoint){
			CGRectGetMidX(returnedView.bounds),
			CGRectGetMidY(returnedView.bounds)
		};
		
		spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
		
		[spinner startAnimating];
		
		[returnedView addSubview:spinner];
		returnedView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75f];
	
		return returnedView;
	
	})());
	
	void (^addOverlayView)(void) = ^ {
	
		[rootVC.view addSubview:overlayView];	
	
	};
	
	void (^removeOverlayView)(BOOL) = ^ (BOOL animated) {
		
		[UIView animateWithDuration:(animated ? 0.3f : 0.0f) delay:0.0f options:0 animations:^{
		
			overlayView.alpha = 0.0f;
			
		} completion:^(BOOL finished) {
		
			[overlayView removeFromSuperview];
			
		}];
		
	};
	
	
	__block WAOverlayBezel *nrBezel = [WAOverlayBezel bezelWithStyle:WAActivityIndicatorBezelStyle];
	[nrBezel showWithAnimation:WAOverlayBezelAnimationNone];
	
	
	//	Always request reauth beyond this point
	
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWAUserRequiresReauthentication];
	[[NSUserDefaults standardUserDefaults] synchronize];

	[[WADataStore defaultStore] updateCurrentUserOnSuccess: ^ {

    dispatch_async(dispatch_get_main_queue(), ^{
            
      void (^operations)() = ^ {
          
					addOverlayView();	
          [keyWindow.rootViewController dismissModalViewControllerAnimated:YES];
          
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
					
						[[WARemoteInterface sharedInterface] retrieveUser:[WARemoteInterface sharedInterface].userIdentifier onSuccess:^(NSDictionary *userRep, NSArray *groupReps) {
							
							BOOL userNeedsStation = [[userRep valueForKeyPath:@"state"] isEqual:@"station_required"];
							
              dispatch_async(dispatch_get_main_queue(), ^ {
              
                if (!userNeedsStation) {
                
                  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kWAUserRequiresReauthentication];
                  [[NSUserDefaults standardUserDefaults] synchronize];

                  removeOverlayView(YES);
									[nrBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
                
                } else {
                
                  WAStationDiscoveryFeedbackViewController *stationDiscoveryFeedbackVC = [[[WAStationDiscoveryFeedbackViewController alloc] init] autorelease];
                  UINavigationController *stationDiscoveryNavC = [stationDiscoveryFeedbackVC wrappingNavigationController];
                  stationDiscoveryFeedbackVC.dismissalAction = [IRAction actionWithTitle:NSLocalizedString(@"WAActionSignOut", @"Action title for signing the user out") block:^{
                    
                    removeOverlayView(NO);
                    [stationDiscoveryNavC dismissModalViewControllerAnimated:NO];
                    [nrAppDelegate applicationRootViewControllerDidRequestReauthentication:nil];
                    
                  }];
									
									void (^finalizeOnboarding)(void) = ^ {
									
										[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kWAUserRequiresReauthentication];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    [stationDiscoveryFeedbackVC dismissModalViewControllerAnimated:YES];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
                      removeOverlayView(YES);
                    });
									
									};
									
									if (WAAdvancedFeaturesEnabled()) {
									
										//	Alright!
										
										stationDiscoveryFeedbackVC.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithTitle:@"I don’t care" action:^{
											finalizeOnboarding();
										}];
										
									}
                  
									[nrBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
                  [rootVC presentModalViewController:stationDiscoveryNavC animated:YES];
                  
                  __block id notificationListener = [[NSNotificationCenter defaultCenter] addObserverForName:kWARemoteInterfaceReachableHostsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
                  
                    WARemoteInterface *interface = [note object];
                    
                    if ([interface.monitoredHosts count] <= 1) {
                    
                      return;
                    
                      //  Damned shabby check
                      //  Should refactor
                    
                    }
                    
                   finalizeOnboarding();
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                    
                      [[NSNotificationCenter defaultCenter] removeObserver:notificationListener];
                      objc_setAssociatedObject(stationDiscoveryFeedbackVC, &kWARemoteInterfaceReachableHostsDidChangeNotification, nil, OBJC_ASSOCIATION_ASSIGN);
                      
                    });
                    
                  }];
                
                  objc_setAssociatedObject(stationDiscoveryFeedbackVC, &kWARemoteInterfaceReachableHostsDidChangeNotification, notificationListener, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                
                }
              
              });
              
            } onFailure:^(NSError *error) {
            
              dispatch_async(dispatch_get_main_queue(), ^ {
            
                NSLog(@"Error retrieving user information: %@", error);  //  FAIL
                removeOverlayView(YES);
								[nrBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
              
              });
              
            }];
            
          });
          
      };
      
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC), dispatch_get_main_queue(), operations);
    
    });
    
  } onFailure: ^ {
  
    dispatch_async(dispatch_get_main_queue(), ^{

      [IRAlertView alertViewWithTitle:@"Error Retrieving User Information" message:@"Unable to retrieve user metadata." cancelAction:nil otherActions:[NSArray arrayWithObjects:
      
        [IRAction actionWithTitle:NSLocalizedString(@"WAActionOkay", @"Action title for accepting what happened reluctantly") block:nil],
      
      nil]];
    
			[nrBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			
    });
    
  }];

}

#pragma mark - Setup View Controller and Delegate

- (void) applicationRootViewControllerDidRequestChangeAPIURL:(id<WAApplicationRootViewController>)controller {
	
	[self presentSetupViewControllerAnimated:YES];
	
}

- (void) presentSetupViewControllerAnimated:(BOOL)animated {
	
	WASetupViewController *setupVC = [[[WASetupViewController alloc] initWithAPIURLString:[[NSUserDefaults standardUserDefaults] stringForKey:kWARemoteEndpointURL]] autorelease];
	setupVC.delegate = self;
	[setupVC presentModallyOn:self.window.rootViewController animated:animated];
	
}

- (void) setupViewController:(WASetupViewController *)controller didChooseString:(NSString *)string {

	NSParameterAssert(controller);
	NSParameterAssert(string);
  
  [[NSUserDefaults standardUserDefaults] setObject:string forKey:kWARemoteEndpointURL];
	[[NSUserDefaults standardUserDefaults] synchronize];

  //	TODO
	//	Update remote interface context here. Right now the API update only works when the app is killed and restarted.	
	
	//	This will work:
	//	[[WARemoteInterface sharedInterface].engine performSelector:@selector(setContext:) withObject:[WARemoteInterfaceContext context]];
	
  [controller dismissModalViewControllerAnimated:YES];

}

- (void) setupViewControllerDidCancel:(WASetupViewController *)controller{
	
	[controller dismissModalViewControllerAnimated:YES];
	
}

#pragma mark - Network Activity

static unsigned int networkActivityStackingCount = 0;

- (void) beginNetworkActivity {

	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self performSelector:_cmd];
		});
		return;
	}
	
	networkActivityStackingCount++;
	
	if (networkActivityStackingCount > 0)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

}

- (void) endNetworkActivity {

	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self performSelector:_cmd];
		});
		return;
	}

	NSParameterAssert(networkActivityStackingCount > 0);
	networkActivityStackingCount--;
	
	if (networkActivityStackingCount == 0)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

}

- (void) remoteResourcesManager:(IRRemoteResourcesManager *)managed didBeginDownloadingResourceAtURL:(NSURL *)anURL {

	[self beginNetworkActivity];

}

- (void) remoteResourcesManager:(IRRemoteResourcesManager *)managed didFinishDownloadingResourceAtURL:(NSURL *)anURL {

	[self endNetworkActivity];

}

- (void) remoteResourcesManager:(IRRemoteResourcesManager *)managed didFailDownloadingResourceAtURL:(NSURL *)anURL {

	[self endNetworkActivity];

}

- (NSURL *) remoteResourcesManager:(IRRemoteResourcesManager *)manager invokedURLForResourceAtURL:(NSURL *)givenURL {

	if ([[givenURL host] isEqualToString:@"invalid.local"]) {
	
		NSURL *currentBaseURL = [WARemoteInterface sharedInterface].engine.context.baseURL;
    NSString *replacementScheme = [currentBaseURL scheme];
    if (!replacementScheme)
      replacementScheme = @"http";
    
		NSString *replacementHost = [currentBaseURL host];
		NSNumber *replacementPort = [currentBaseURL port];    
		
		NSString *constructedURLString = [[NSArray arrayWithObjects:
			
			[replacementScheme stringByAppendingString:@"://"],
			replacementHost,	//	[givenURL host] ? [givenURL host] : @"",
			replacementPort ? [@":" stringByAppendingString:[replacementPort stringValue]] : @"",
			[givenURL path] ? [givenURL path] : @"",
			[givenURL query] ? [@"?" stringByAppendingString:[givenURL query]] : @"",
			[givenURL fragment] ? [@"#" stringByAppendingString:[givenURL fragment]] : @"",
			
		nil] componentsJoinedByString:@""];
		
		NSURL *constructedURL = [NSURL URLWithString:constructedURLString];
		
		return constructedURL;
		
	}
	
	return givenURL;

}

- (void) configureRemoteResourceDownloadOperation:(IRRemoteResourceDownloadOperation *)anOperation {

	NSMutableURLRequest *originalRequest = [anOperation underlyingRequest];
	
	NSURLRequest *transformedRequest = [[WARemoteInterface sharedInterface].engine transformedRequestWithRequest:originalRequest usingMethodName:@"loadedResource"];
		
	originalRequest.URL = transformedRequest.URL;
	originalRequest.allHTTPHeaderFields = transformedRequest.allHTTPHeaderFields;
	originalRequest.HTTPMethod = transformedRequest.HTTPMethod;
	originalRequest.HTTPBodyStream = transformedRequest.HTTPBodyStream;
	originalRequest.HTTPBody = transformedRequest.HTTPBody;

}

- (BOOL) application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

  [[NSNotificationCenter defaultCenter] postNotificationName:kWAApplicationDidReceiveRemoteURLNotification object:url userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
  
    url, @"url",
    sourceApplication, @"sourceApplication",
    annotation, @"annotation",
  
  nil]];

  return YES;

}

@end
