//
//  WAFirstUseBuildCloudViewController.h
//  wammer
//
//  Created by kchiu on 12/10/24.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WAFirstUseBuildCloudViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UITableViewCell *connectionCell;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *connectActivity;
@property (weak, nonatomic) IBOutlet UILabel *connectedHost;

@end
