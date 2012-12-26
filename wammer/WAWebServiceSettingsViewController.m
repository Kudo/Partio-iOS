//
//  WAWebServiceSettingsViewController.m
//  wammer
//
//  Created by kchiu on 12/11/28.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAWebServiceSettingsViewController.h"
#import "WAFacebookConnectionSwitch.h"
#import "WAOAuthViewController.h"
#import "WASnsConnectSwitch.h"
#import "WARemoteInterface.h"

static NSString * const kWASegueSettingsToOAuth = @"WASegueSettingsToOAuth";

@interface WAWebServiceSettingsViewController ()

@property (nonatomic, strong) NSURLRequest *sentRequest;
@property (nonatomic, strong) WAOAuthDidComplete didCompleteBlock;
@property (nonatomic, strong) WAFacebookConnectionSwitch *facebookConnectSwitch;
@property (nonatomic, strong) WASnsConnectSwitch *googleConnectSwitch;
@property (nonatomic, strong) WASnsConnectSwitch *twitterConnectSwitch;
@property (nonatomic, strong) WASnsConnectSwitch *foursquareConnectSwitch;

@end

@implementation WAWebServiceSettingsViewController

- (void)viewDidLoad {

	[super viewDidLoad];

	self.title = NSLocalizedString(@"WEB_SERVICES_TITLE", @"Title of web service settings view controller");

	self.facebookConnectSwitch = [[WAFacebookConnectionSwitch alloc] init];
	self.facebookConnectCell.accessoryView = self.facebookConnectSwitch;

	UISwitch *flickrSwitch = [[UISwitch alloc] init];
	flickrSwitch.enabled = NO;
	self.flickrConnectCell.accessoryView = flickrSwitch;
	UISwitch *picasaSwitch = [[UISwitch alloc] init];
	picasaSwitch.enabled = NO;
	self.picasaConnectCell.accessoryView = picasaSwitch;

	self.googleConnectSwitch = [[WASnsConnectSwitch alloc] initForStyle:WASnsConnectGoogleStyle];
	self.googleConnectSwitch.delegate = self;
	self.googleConnectCell.accessoryView = self.googleConnectSwitch;
	
	self.twitterConnectSwitch = [[WASnsConnectSwitch alloc] initForStyle:WASnsConnectTwitterStyle];
	self.twitterConnectSwitch.delegate = self;
	self.twitterConnectCell.accessoryView = self.twitterConnectSwitch;
	
	self.foursquareConnectSwitch = [[WASnsConnectSwitch alloc] initForStyle:WASnsConnectFoursquareStyle];
	self.foursquareConnectSwitch.delegate = self;
	self.foursquareConnectCell.accessoryView = self.foursquareConnectSwitch;
	
	[self reloadStatus];
	
}

- (void) reloadStatus {
	
	self.facebookConnectSwitch.enabled = NO;
	self.googleConnectSwitch.enabled = NO;
	self.twitterConnectSwitch.enabled = NO;
	self.foursquareConnectSwitch.enabled = NO;
	
	__weak WAWebServiceSettingsViewController *wSelf = self;
	
	BOOL (^snsEnabled)(NSArray*, NSString *) = ^(NSArray *reps, NSString *snsType) {
		NSArray *snsReps = [reps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^ (id evaluatedObject, NSDictionary *bindings) {
			
			return [[evaluatedObject valueForKeyPath:@"type"] isEqual:snsType];
			
		}]];
		
		NSDictionary *snsRep = [snsReps lastObject];
		NSNumber *enabled = [snsRep valueForKeyPath:@"enabled"];
		
		if ([enabled isEqual:(id)kCFBooleanTrue])
			return YES;
		else
			return NO;
	};
	
	WARemoteInterface * const ri = [WARemoteInterface sharedInterface];
	[ri retrieveConnectedSocialNetworksOnSuccess:^(NSArray *snsReps) {
		
		if (!wSelf)
			return;
		
		BOOL fbImported = snsEnabled(snsReps, @"facebook");
		BOOL twitterImported = snsEnabled(snsReps, @"twitter");
		BOOL foursquareImported = snsEnabled(snsReps, @"foursquare");
		BOOL googleImported = snsEnabled(snsReps, @"google");
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (wSelf) {
				
				[wSelf.facebookConnectSwitch setOn:fbImported animated:YES];
				wSelf.facebookConnectSwitch.enabled = YES;
				
				[wSelf.twitterConnectSwitch setOn:twitterImported animated:YES];
				wSelf.twitterConnectSwitch.enabled = YES;
								
				[wSelf.googleConnectSwitch setOn:googleImported animated:YES];
				wSelf.googleConnectSwitch.enabled = YES;

				[wSelf.foursquareConnectSwitch setOn:foursquareImported animated:YES];
				wSelf.foursquareConnectSwitch.enabled = YES;
				
			}
			
		});
		
	} onFailure:^(NSError *error) {
		
		NSLog(@"error %@", error);
		
	}];
}



- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

	WAOAuthViewController *vc = [segue destinationViewController];
	vc.request = self.sentRequest;
	vc.didCompleteBlock = self.didCompleteBlock;

}

- (void)dealloc {

	self.googleConnectSwitch.delegate = nil;
	self.twitterConnectSwitch.delegate = nil;
	self.foursquareConnectSwitch.delegate = nil;

}

- (NSUInteger) supportedInterfaceOrientations {
	
	if (isPad())
		return UIInterfaceOrientationMaskAll;
	else
		return UIInterfaceOrientationMaskPortrait;
	
}

- (BOOL) shouldAutorotate {
	
	return YES;
	
}

#pragma mark - WAOAuthSwitch delegates

- (void)openOAuthWebViewWithRequest:(NSURLRequest *)request completeBlock:(WAOAuthDidComplete)didCompleteBlock {

	self.sentRequest = request;
	self.didCompleteBlock = didCompleteBlock;

	[self performSegueWithIdentifier:kWASegueSettingsToOAuth sender:nil];

}

#pragma mark - UITableView delegates

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

	NSString *headerTitleID = [super tableView:tableView titleForHeaderInSection:section];
	return NSLocalizedString(headerTitleID, @"Header title of web service setting view controller");

}

@end
