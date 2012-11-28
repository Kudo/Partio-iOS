//
//  WAWebServiceSettingsViewController.h
//  wammer
//
//  Created by kchiu on 12/11/28.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WAWebServiceSettingsViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UITableViewCell *facebookConnectCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *twitterConnectCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *flickrConnectCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *picasaConnectCell;

@end
