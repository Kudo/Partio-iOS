//
//  WAAttachedMediaListViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 8/26/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "UIKit+IRAdditions.h"

@interface WAAttachedMediaListViewController : UIViewController

+ (WAAttachedMediaListViewController *) controllerWithArticleURI:(NSURL *)anArticleURI completion:(void(^)(NSURL *objectURI))aBlock;

- (WAAttachedMediaListViewController *) initWithArticleURI:(NSURL *)anArticleURI completion:(void(^)(NSURL *objectURI))aBlock;
- (WAAttachedMediaListViewController *) initWithArticleURI:(NSURL *)anArticleURI usingContext:(NSManagedObjectContext *)aContext completion:(void(^)(NSURL *objectURI))aBlock;

@property (nonatomic, readwrite, retain) UIView *headerView;
@property (nonatomic, readonly, retain) UITableView *tableView; // Exposed only for external observers

@end
