//
//  WAOverviewController+DiscreteLayout.h
//  wammer
//
//  Created by Evadne Wu on 2/29/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAOverviewController.h"
#import "WAArticleViewController.h"

@class WAArticleViewController, WAArticle;
@interface WAOverviewController (DiscreteLayout)

@property (nonatomic, readwrite, retain) NSArray *lastUsedLayoutGrids;

- (WAArticleViewController *) newDiscreteArticleViewControllerForArticle:(WAArticle *)article NS_RETURNS_RETAINED;
- (WAArticleViewController *) cachedArticleViewControllerForArticle:(WAArticle *)article;
- (void) removeCachedArticleViewController:(WAArticleViewController *)aVC;
- (void) removeCachedArticleViewControllers;

- (UIView *) newPageContainerView NS_RETURNS_RETAINED;
- (NSArray *) newLayoutGrids NS_RETURNS_RETAINED;

- (UIView *) representingViewForItem:(WAArticle *)anArticle;

@end
