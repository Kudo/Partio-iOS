//
//  WAViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 8/10/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WAViewController : UIViewController

@property (nonatomic, readwrite, copy) BOOL (^onShouldAutorotateToInterfaceOrientation)(UIInterfaceOrientation toOrientation);

@end
