//
//  WAAuthenticationRequestViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/30/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "WAAuthenticationRequestViewController.h"
#import "WARemoteInterface.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WAOverlayBezel.h"

#import "WADefines.h"

#import "IRAction.h"


@interface WAAuthenticationRequestViewController () <UITextFieldDelegate>

@property (nonatomic, readwrite, retain) UITextField *usernameField;
@property (nonatomic, readwrite, retain) UITextField *passwordField;

@property (nonatomic, readwrite, copy) WAAuthenticationRequestViewControllerCallback completionBlock;

- (void) update;

@end


@implementation WAAuthenticationRequestViewController
@synthesize labelWidth;
@synthesize usernameField, passwordField;
@synthesize username, password, completionBlock;
@synthesize performsAuthenticationOnViewDidAppear;
@synthesize actions;

+ (WAAuthenticationRequestViewController *) controllerWithCompletion:(WAAuthenticationRequestViewControllerCallback)aBlock {

	WAAuthenticationRequestViewController *returnedVC = [[[self alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
	returnedVC.completionBlock = aBlock;
	return returnedVC;

}

- (id) initWithStyle:(UITableViewStyle)style {

	self = [super initWithStyle:style];
	if (!self)
		return nil;
	
	self.labelWidth = 128.0f;
	self.title = NSLocalizedString(@"WAAuthRequestTitle", @"Title for the auth request controller");
	
	switch (UI_USER_INTERFACE_IDIOM()) {
		
		case UIUserInterfaceIdiomPhone: {
			self.labelWidth = 128.0f;
			break;
		}
		case UIUserInterfaceIdiomPad: {
			self.labelWidth = 192.0f;
			break;
		}
	}
	
	return self;

}

- (void) dealloc {

	[username release];
	[usernameField release];
	
	[password release];
	[passwordField release];
  
  [actions release];

	[super dealloc];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	self.usernameField = [[[UITextField alloc] initWithFrame:(CGRect){ 0, 0, 256, 44 }] autorelease];
	self.usernameField.delegate = self;
	self.usernameField.placeholder = NSLocalizedString(@"WANounUsername", @"Noun for Username");
	self.usernameField.text = self.username;
	self.usernameField.font = [UIFont systemFontOfSize:17.0f];
	self.usernameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	self.usernameField.returnKeyType = UIReturnKeyNext;
	self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.usernameField.keyboardType = UIKeyboardTypeEmailAddress;
  self.usernameField.clearButtonMode = UITextFieldViewModeWhileEditing;
	
	self.passwordField = [[[UITextField alloc] initWithFrame:(CGRect){ 0, 0, 256, 44 }] autorelease];
	self.passwordField.delegate = self;
	self.passwordField.placeholder = NSLocalizedString(@"WANounPassword", @"Noun for Password");
	self.passwordField.text = self.password;
	self.passwordField.font = [UIFont systemFontOfSize:17.0f];
	self.passwordField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	self.passwordField.returnKeyType = UIReturnKeyGo;
	self.passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.passwordField.secureTextEntry = YES;
	self.passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	self.passwordField.keyboardType = UIKeyboardTypeASCIICapable;
  self.passwordField.clearButtonMode = UITextFieldViewModeWhileEditing;
		
}

- (void) viewDidUnload {

	self.usernameField = nil;
	self.passwordField = nil;
	
	[super viewDidUnload];
	
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {

	if (textField == self.usernameField) {
		BOOL shouldReturn = ![self.usernameField.text isEqualToString:@""];
		if (shouldReturn) {
			dispatch_async(dispatch_get_current_queue(), ^ {
				[self.passwordField becomeFirstResponder];
			});
		}
		return shouldReturn;
	}
		
	if (textField == self.passwordField) {
		BOOL shouldReturn = ![self.passwordField.text isEqualToString:@""];
		if (shouldReturn) {
			dispatch_async(dispatch_get_current_queue(), ^ {
				[self.passwordField resignFirstResponder];
				[self authenticate];
			});
		}
		return shouldReturn; 
		
	}
	
	return NO;

}

- (void) textFieldDidEndEditing:(UITextField *)textField {

	[self update];

}

- (void) viewWillAppear:(BOOL)animated {
	
	[super viewWillAppear:animated];
	[self.tableView reloadData];

	if (!self.usernameField.text) {
		[self.usernameField becomeFirstResponder];
	} else if (!self.passwordField.text) {
		[self.passwordField becomeFirstResponder];
  }
	
}

- (void) viewDidAppear:(BOOL)animated {

  [super viewDidAppear:animated];
  
  if (self.performsAuthenticationOnViewDidAppear) {
    self.performsAuthenticationOnViewDidAppear = NO;
    [self authenticate];
  }

}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {

  return [self.actions count] ? 2 : 1;
  
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

	return (section == 0) ? 2 : [self.actions count];
  
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *CellIdentifier = @"Cell";

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	}
  
  if (indexPath.section == 0) {
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.row == 0) {
      cell.textLabel.text = NSLocalizedString(@"WANounUsername", @"Noun for Username");
      cell.accessoryView = self.usernameField;
    } else if (indexPath.row == 1) {
      cell.textLabel.text = NSLocalizedString(@"WANounPassword", @"Noun for Password");
      cell.accessoryView = self.passwordField;
    } else {
      cell.accessoryView = nil;
    }
  
    cell.textLabel.textAlignment = UITextAlignmentLeft;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
  } else {
  
    IRAction *representedAction = (IRAction *)[self.actions objectAtIndex:indexPath.row];
    cell.textLabel.text = representedAction.title;
    cell.textLabel.textAlignment = UITextAlignmentCenter;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView = nil;
  
  }
		
	cell.accessoryView.frame = (CGRect){
		CGPointZero,
		(CGSize){
			CGRectGetWidth(tableView.bounds) - self.labelWidth - ((self.tableView.style == UITableViewStyleGrouped) ? 10.0f : 0.0f),
			45.0f
		}
	};

	return cell;
	
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {

  if (section == 0)
    return tableView.sectionHeaderHeight;
  
  return 12;

}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {

  if (!WAAdvancedFeaturesEnabled())
    return nil;
  
  if (section == 0)
    return [NSString stringWithFormat:@"Using Endpoint %@", [[NSUserDefaults standardUserDefaults] stringForKey:kWARemoteEndpointURL]];
  
  return nil;

}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

  if (indexPath.section != 1)
    return;

  IRAction *representedAction = (IRAction *)[self.actions objectAtIndex:indexPath.row];
  [representedAction invoke];
  
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

}





- (void) setUsername:(NSString *)newUsername {

  if (username == newUsername)
    return;
  
  [username release];
  username = [newUsername retain];
  
  self.usernameField.text = username;

}

- (void) setPassword:(NSString *)newPassword {

  if (password == newPassword)
    return;
  
  [password release];
  password = [newPassword retain];
  
  self.passwordField.text = password;

}

- (void) update {

	self.username = self.usernameField.text;
	self.password = self.passwordField.text;

}

- (void) authenticate {

  [self update];
  
  if (![self.username length] || ![self.password length])
    return; //  TBD maybe return NO

	WAOverlayBezel *busyBezel = [WAOverlayBezel bezelWithStyle:WAActivityIndicatorBezelStyle];
	busyBezel.caption = NSLocalizedString(@"WAActionProcessing", @"Action title for processing stuff");
	
	[busyBezel showWithAnimation:WAOverlayBezelAnimationFade];
	self.view.userInteractionEnabled = NO;

	[[WARemoteInterface sharedInterface] retrieveTokenForUser:self.username password:self.password onSuccess:^(NSDictionary *userRep, NSString *token) {
		
		[WARemoteInterface sharedInterface].userIdentifier = [userRep objectForKey:@"user_id"];
		[WARemoteInterface sharedInterface].userToken = token;
		
		NSArray *allGroups = [userRep objectForKey:@"groups"];
		if ([allGroups count])
			[WARemoteInterface sharedInterface].primaryGroupIdentifier = [[allGroups objectAtIndex:0] valueForKeyPath:@"group_id"];
		
		dispatch_async(dispatch_get_main_queue(), ^ {
			
			if (self.completionBlock)
				self.completionBlock(self, nil);
			
			self.view.userInteractionEnabled = YES;
			[busyBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			
		});

	} onFailure: ^ (NSError *error) {
		
		dispatch_async(dispatch_get_main_queue(), ^ {
		
			if (self.completionBlock)
				self.completionBlock(self, error);
			
			self.view.userInteractionEnabled = YES;
			[busyBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			
		});
			
	}];		

}

@end
