//
//  WALoginViewController.m
//  wammer
//
//  Created by jamie on 6/4/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WALoginViewController.h"

#import "WAOverlayBezel.h"
#import "WARemoteInterface.h"

@interface WALoginViewController ()
@property (nonatomic) BOOL performsAuthenticationOnViewDidAppear;
@property NSString *username;
@property NSString *password;
@property NSString *userID;
@property NSString *token;
@end

@implementation WALoginViewController
@synthesize usernameField;
@synthesize passwordField;
@synthesize username;
@synthesize password;
@synthesize userID;
@synthesize token;
@synthesize completionBlock;
@synthesize performsAuthenticationOnViewDidAppear;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		// Custom initialization
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	for (UIView* v in [self.view subviews]) 
		if([v isKindOfClass:[UILabel class]]){
			UILabel *aLabel = (UILabel *)v;
			aLabel.text = NSLocalizedString(aLabel.text, nil);
		}else if ([v isKindOfClass:[UITextField class]]) {
			UITextField *aField = (UITextField *)v;
			aField.placeholder = NSLocalizedString(aField.placeholder, nil);
		}else if ([v isKindOfClass:[UIButton class]]) {
			UIButton *aButton = (UIButton *)v;
			aButton.titleLabel.text = NSLocalizedString(aButton.titleLabel.text, nil);
		}
	
}

- (void)viewDidUnload
{
	[self setUsernameField:nil];
	[self setPasswordField:nil];
	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	if(self.performsAuthenticationOnViewDidAppear){
			self.performsAuthenticationOnViewDidAppear = NO;
			
	}
}


- (void) authenticate {
	
	WF_TESTFLIGHT(^ {
		[TestFlight passCheckpoint:@"SignIn"];	
	});

	self.username = self.usernameField.text;
	self.password = self.passwordField.text;
  
  if(!([self.username length] || [self.userID length]) && ([self.password length] || [self.token length]))
		return;

//	if (WAAdvancedFeaturesEnabled()) {
//		[[NSUserDefaults standardUserDefaults] setObject:self.username forKey:kWADebugAutologinUserIdentifier];
//		[[NSUserDefaults standardUserDefaults] setObject:self.password forKey:kWADebugAutologinUserPassword];
//		[[NSUserDefaults standardUserDefaults] synchronize];
//	}
  
	WAOverlayBezel *busyBezel = [WAOverlayBezel bezelWithStyle:WAActivityIndicatorBezelStyle];
	busyBezel.caption = NSLocalizedString(@"ACTION_PROCESSING", @"Action title for processing stuff");
	
	[busyBezel showWithAnimation:WAOverlayBezelAnimationFade];
	self.view.userInteractionEnabled = NO;
	
	void (^handleAuthSuccess)(NSString *, NSString *, NSString *) = ^ (NSString *inUserID, NSString *inUserToken, NSString *inUserGroupID) {

		[WARemoteInterface sharedInterface].userIdentifier = inUserID;
		[WARemoteInterface sharedInterface].userToken = inUserToken;
		[WARemoteInterface sharedInterface].primaryGroupIdentifier = inUserGroupID;
		
		dispatch_async(dispatch_get_main_queue(), ^ {
			
			if (self.completionBlock)
				self.completionBlock(self, nil);
			
			self.view.userInteractionEnabled = YES;
			[busyBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			
		});
	
	};
	
	void (^handleAuthFailure)(NSError *) = ^ (NSError *error) {

		dispatch_async(dispatch_get_main_queue(), ^ {
		
			if (self.completionBlock)
				self.completionBlock(self, error);
			
			self.view.userInteractionEnabled = YES;
			[busyBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			
		});
	
	};
	
	if ([self.userID length] && ![self.password length] && [self.token length]) {
	
		[WARemoteInterface sharedInterface].userIdentifier = self.userID;
		[WARemoteInterface sharedInterface].userToken = self.token;
		
		[[WARemoteInterface sharedInterface] retrieveUser:self.userID onSuccess:^(NSDictionary *userRep) {
			
			NSArray *allGroups = [userRep objectForKey:@"groups"];
			NSString *groupID = [allGroups count] ? [[allGroups objectAtIndex:0] valueForKey:@"group_id"] : nil;
			
			handleAuthSuccess(self.userID, self.token, groupID);
			
		} onFailure:^(NSError *error) {
			
			handleAuthFailure(error);
			
		}];
	
	} else {
	
		[[WARemoteInterface sharedInterface] retrieveTokenForUser:self.username password:self.password onSuccess:^(NSDictionary *userRep, NSString *inToken) {
		
			NSString *inUserID = [userRep objectForKey:@"user_id"];
			NSArray *allGroups = [userRep objectForKey:@"groups"];
			NSString *groupID = [allGroups count] ? [[allGroups objectAtIndex:0] valueForKey:@"group_id"] : nil;
			
			handleAuthSuccess(inUserID, inToken, groupID);
			
		} onFailure: ^ (NSError *error) {
			
			handleAuthFailure(error);
				
		}];
	
	}

}


- (IBAction)signInAction:(id)sender {
	[self authenticate];
}

- (IBAction)facebookSignInAction:(id)sender {
}

- (IBAction)registerAction:(id)sender {
}
@end
