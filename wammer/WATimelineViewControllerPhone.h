//
//  WAArticlesViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <QuartzCore/QuartzCore.h>

#import "WAApplicationRootViewControllerDelegate.h"
#import "UIKit+IRAdditions.h"
#import "WASlidingMenuViewController.h"
#import "IIViewDeckController.h"
#import "WASwipeableTableViewController.h"

//@interface WATimelineViewControllerPhone : IRTableViewController <WAApplicationRootViewController, IIViewDeckControllerDelegate, WASlidingMenuDelegate>
@interface WATimelineViewControllerPhone : WASwipeableTableViewController <WAApplicationRootViewController, IIViewDeckControllerDelegate, WASlidingMenuDelegate>

@end
