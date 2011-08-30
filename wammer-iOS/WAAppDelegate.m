//
//  WAAppDelegate.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAAppDelegate.h"
#import "IRRemoteResourcesManager.h"
#import "WAUserSelectionViewController.h"
#import "WADataStore.h"
#import "WAViewController.h"

#import "WAAuthenticationRequestViewController.h"

#import "WARemoteInterface.h"
#import "IRKeychainManager.h"

@interface WAAppDelegate () <IRRemoteResourcesManagerDelegate>
@end


@implementation WAAppDelegate
@synthesize window = _window;

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	
	self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	
	NSString *rootViewControllerClassName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? @"WAPostsViewControllerPhone" : @"WAArticlesViewController";
	self.window.rootViewController = [[[UINavigationController alloc] initWithRootViewController:[[(UIViewController *)[NSClassFromString(rootViewControllerClassName) alloc] init] autorelease]] autorelease];
	
	[self.window makeKeyAndVisible];
	
	
	//	Ask the keychain
	
	NSString *lastAuthenticatedUserIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"WALastAuthenticatedUserIdentifier"];
	NSData *lastAuthenticatedUserTokenKeychainItemData = [[NSUserDefaults standardUserDefaults] dataForKey:@"WALastAuthenticatedUserTokenKeychainItem"];
	IRKeychainAbstractItem *lastAuthenticatedUserTokenKeychainItem = nil;
	
	if (!lastAuthenticatedUserTokenKeychainItem) {
		if (lastAuthenticatedUserTokenKeychainItemData) {
			lastAuthenticatedUserTokenKeychainItem = [NSKeyedUnarchiver unarchiveObjectWithData:lastAuthenticatedUserTokenKeychainItemData];
		}
	}
	
	BOOL authenticationInformationSufficient = (lastAuthenticatedUserTokenKeychainItem.secretString) && lastAuthenticatedUserIdentifier;
	
	if (!lastAuthenticatedUserTokenKeychainItem)
		lastAuthenticatedUserTokenKeychainItem = [[[IRKeychainInternetPasswordItem alloc] initWithIdentifier:@"com.waveface.wammer"] autorelease];
	
	void (^writeCredentials)(NSString *userIdentifier, NSString *userToken) = ^ (NSString *userIdentifier, NSString *userToken) {
	
		lastAuthenticatedUserTokenKeychainItem.secretString = userToken;
		[lastAuthenticatedUserTokenKeychainItem synchronize];
		
		NSData *archivedItemData = [NSKeyedArchiver archivedDataWithRootObject:lastAuthenticatedUserTokenKeychainItem];
		
		[[NSUserDefaults standardUserDefaults] setObject:archivedItemData forKey:@"WALastAuthenticatedUserTokenKeychainItem"];
		[[NSUserDefaults standardUserDefaults] setObject:userIdentifier forKey:@"WALastAuthenticatedUserIdentifier"];
		[[NSUserDefaults standardUserDefaults] setObject:userIdentifier forKey:@"WhoAmI"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	
	};
	
	
	if (authenticationInformationSufficient) {
	
		[WARemoteInterface sharedInterface].userIdentifier = lastAuthenticatedUserIdentifier;
		[WARemoteInterface sharedInterface].userToken = lastAuthenticatedUserTokenKeychainItem.secretString;
		
		//	We don’t have to validate this again since the token never expires
	
	}
	
	if (YES || !authenticationInformationSufficient) {
	
		__block UIViewController *userSelectionVC = nil;
        
		userSelectionVC = [WAAuthenticationRequestViewController controllerWithCompletion:^(WAAuthenticationRequestViewController *self) {
		
				writeCredentials([WARemoteInterface sharedInterface].userIdentifier, [WARemoteInterface sharedInterface].userToken);
		
				[self dismissModalViewControllerAnimated:YES];
				
				void (^operations)() = ^ {
						
						CATransition *transition = [CATransition animation];
						transition.type = kCATransitionFade;
						transition.duration = 0.3f;
						transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
						transition.removedOnCompletion = YES;
						[[UIApplication sharedApplication].keyWindow.rootViewController dismissModalViewControllerAnimated:NO];
						[[UIApplication sharedApplication].keyWindow.layer addAnimation:transition forKey:@"transition"];
						
				};
				
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC), dispatch_get_main_queue(), operations);
			
		}];
		
		UINavigationController *userSelectionWrappingVC = [[[UINavigationController alloc] initWithRootViewController:userSelectionVC] autorelease];
		userSelectionWrappingVC.modalPresentationStyle = UIModalPresentationFormSheet;
        
		switch (UI_USER_INTERFACE_IDIOM()) {
		
			case UIUserInterfaceIdiomPad: {
			
				WAViewController *fullscreenBaseVC = [[[WAViewController alloc] init] autorelease];
				fullscreenBaseVC.onShouldAutorotateToInterfaceOrientation = ^ (UIInterfaceOrientation toOrientation) {
					return YES;
				};
				fullscreenBaseVC.modalPresentationStyle = UIModalPresentationFullScreen;
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
				fullscreenBaseVC.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternCarbonFibre"]];
				[self.window.rootViewController presentModalViewController:fullscreenBaseVC animated:NO];
				[fullscreenBaseVC presentModalViewController:userSelectionWrappingVC animated:YES];
			
				break;
			
			}
			
			case UIUserInterfaceIdiomPhone:
			default: {
                // no background
                
                [self.window.rootViewController presentModalViewController:userSelectionWrappingVC animated:NO];
			
				break;
			
			}
		
		}
	
	}
		
	return YES;
	
}

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

@end
