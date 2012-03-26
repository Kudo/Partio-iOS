//
//  WADiscretePaginatedArticlesViewController+ContextPresenting.h
//  wammer
//
//  Created by Evadne Wu on 2/29/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WADiscretePaginatedArticlesViewController.h"


enum WADiscretePaginatedArticlesViewControllerAnimation {
	
	WAArticleContextAnimationNone = 0,
	WAArticleContextAnimationFlipAndScale = 1,
	WAArticleContextAnimationFadeAndZoom = 2,
	WAArticleContextAnimationCoverVertically = 3,
	
	WAArticleContextAnimationDefault = WAArticleContextAnimationCoverVertically
	
}; typedef NSUInteger WAArticleContextAnimation;


@protocol WAArticleViewControllerPresenting;
@interface WADiscretePaginatedArticlesViewController (ContextPresenting)

@property (nonatomic, readonly, retain) WAArticle *presentedArticle;

- (UIViewController<WAArticleViewControllerPresenting> *) presentDetailedContextForArticle:(NSURL *)anObjectURI;
- (UIViewController<WAArticleViewControllerPresenting> *) presentDetailedContextForArticle:(NSURL *)anObjectURI animated:(BOOL)animated;
- (UIViewController<WAArticleViewControllerPresenting> *) presentDetailedContextForArticle:(NSURL *)anObjectURI usingAnimation:(WAArticleContextAnimation)animation;

- (void) dismissArticleContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller;

- (UIViewController<WAArticleViewControllerPresenting> *) newContextViewControllerForArticle:(NSURL *)anObjectURI NS_RETURNS_RETAINED;
- (UINavigationController *) wrappingNavigationControllerForContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller;

@end
