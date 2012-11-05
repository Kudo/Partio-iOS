//
//  WAFirstUseConnectServicesViewController.m
//  wammer
//
//  Created by kchiu on 12/10/24.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFirstUseConnectServicesViewController.h"
#import "WAFirstUsePhotoImportViewController.h"
#import "WAFacebookConnectionSwitch.h"

@interface WAFirstUseConnectServicesViewController ()

@end

@implementation WAFirstUseConnectServicesViewController

- (void)viewDidLoad {

	[super viewDidLoad];
	self.navigationItem.hidesBackButton = YES;
	self.facebookConnectCell.accessoryView = [[WAFacebookConnectionSwitch alloc] init];

}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

	WAFirstUsePhotoImportViewController *vc = segue.destinationViewController;
	vc.isFromConnectServicesPage = YES;

}

@end
