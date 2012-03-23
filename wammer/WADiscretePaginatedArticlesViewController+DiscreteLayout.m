//
//  WADiscretePaginatedArticlesViewController+DiscreteLayout.m
//  wammer
//
//  Created by Evadne Wu on 2/29/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WADiscretePaginatedArticlesViewController+DiscreteLayout.h"
#import "WADataStore.h"
#import "WAArticleViewController.h"
#import "WAView.h"

#import "IRDiscreteLayoutManager.h"
#import "WAEightPartLayoutGrid.h"
#import "IRDiscreteLayoutGrid+Transforming.h"

#import "WADiscreteLayoutHelpers.h"


static NSString * const kWADiscreteArticleViewControllerOnItem = @"kWADiscreteArticleViewControllerOnItem";
static NSString * const kWADiscreteArticlesViewLastUsedLayoutGrids = @"kWADiscreteArticlesViewLastUsedLayoutGrids";


@interface WADiscretePaginatedArticlesViewController (DiscreteLayout_Private)

@property (nonatomic, readonly, retain) NSCache *articleViewControllersCache;

@end


@implementation WADiscretePaginatedArticlesViewController (DiscreteLayout)

- (NSArray *) lastUsedLayoutGrids {

	return objc_getAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids);

}

- (void) setLastUsedLayoutGrids:(NSArray *)newGrids {

	if ([self lastUsedLayoutGrids] == newGrids)
		return;
	
	objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, newGrids, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (WAArticleViewController *) newDiscreteArticleViewControllerForArticle:(WAArticle *)article NS_RETURNS_RETAINED {

	__block __typeof__(self) nrSelf = self;
	
	NSURL *objectURI = [[article objectID] URIRepresentation];
	
	WAArticleViewControllerPresentationStyle style = [WAArticleViewController suggestedDiscreteStyleForArticle:article];
	WAArticleViewController *articleViewController = [WAArticleViewController controllerForArticle:objectURI usingPresentationStyle:style];
	
	articleViewController.onViewDidLoad = ^ (WAArticleViewController *loadedVC, UIView *loadedView) {
		
		((UIView *)loadedVC.view.imageStackView).userInteractionEnabled = NO;
		
	};
	
	articleViewController.onPresentingViewController = ^ (void(^action)(UIViewController <WAArticleViewControllerPresenting> *parentViewController)) {
		
		action((UIViewController<WAArticleViewControllerPresenting> *)nrSelf);
		
	};
	
	articleViewController.onViewTap = ^ {
	
		[nrSelf updateLatestReadingProgressWithIdentifier:articleViewController.article.identifier];
		[nrSelf presentDetailedContextForArticle:[[articleViewController.article objectID] URIRepresentation] animated:YES];		
		
	};
	
	articleViewController.onViewPinch = ^ (UIGestureRecognizerState state, CGFloat scale, CGFloat velocity) {
	
		if (state == UIGestureRecognizerStateChanged)
		if (scale > 1.05f)
		if (velocity > 1.05f) {
		
			for (UIGestureRecognizer *gestureRecognizer in articleViewController.view.gestureRecognizers)
				gestureRecognizer.enabled = NO;
		
			articleViewController.onViewTap();
			
			for (UIGestureRecognizer *gestureRecognizer in articleViewController.view.gestureRecognizers)
				gestureRecognizer.enabled = YES;
			
		}
	
	};
	
//	NSString *identifier = articleViewController.article.identifier;
//	articleViewController.additionalDebugActions = [NSArray arrayWithObjects:
//	
//		[IRAction actionWithTitle:@"Make Last Read" block:^{
//		
//			nrSelf.lastReadObjectIdentifier = identifier;
//			[nrSelf updateLastReadingProgressAnnotation];
//		
//		}],
//		
//	nil];
	
	return articleViewController;

}

- (WAArticleViewController *) cachedArticleViewControllerForArticle:(WAArticle *)article {

	WAArticleViewController *cachedVC = [self.articleViewControllersCache objectForKey:article];
	if (cachedVC)
		return cachedVC;
	
	WAArticleViewController *createdVC = [self newDiscreteArticleViewControllerForArticle:article];
	[self.articleViewControllersCache setObject:createdVC forKey:article];
	
	return createdVC;

}

- (void) removeCachedArticleViewControllers {

	[self.articleViewControllersCache removeAllObjects];

}

- (UIView *) newPageContainerView {

	WAView *returnedView = [[WAView alloc] initWithFrame:(CGRect){ CGPointZero, (CGSize){ 320, 320 } }];
	returnedView.autoresizingMask = UIViewAutoresizingNone;
	returnedView.clipsToBounds = NO;
	returnedView.layer.shouldRasterize = YES;
	returnedView.layer.rasterizationScale = [UIScreen mainScreen].scale;
	
	__block UIView *backdropView = [[UIView alloc] initWithFrame:CGRectInset(returnedView.bounds, -12, -12)];
	backdropView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	backdropView.layer.backgroundColor = [UIColor colorWithRed:245.0f/255.0f green:240.0f/255.0f blue:234.0f/255.0f alpha:1].CGColor;
	backdropView.layer.cornerRadius = 4;
	backdropView.layer.shadowOpacity = 0.35;
	backdropView.layer.shadowOffset = (CGSize){ 0, 2 };
	[returnedView addSubview:backdropView];
	
	returnedView.onLayoutSubviews = ^ {
	
		backdropView.layer.shadowPath = [UIBezierPath bezierPathWithRect:backdropView.bounds].CGPath;
	
	};
	
	[returnedView setNeedsLayout];
	
	return returnedView;

}

- (NSArray *) newLayoutGrids {

	NSArray *returnedArray = WADefaultLayoutGrids();
	
	__weak WADiscretePaginatedArticlesViewController *wSelf = self;
	
	IRDiscreteLayoutGridAreaDisplayBlock displayBlock = [ ^ (IRDiscreteLayoutGrid *self, id anItem) {
	
		NSCParameterAssert(wSelf);
		return [wSelf representingViewForItem:anItem];
	
	} copy];
	
	return [returnedArray irMap: ^ (IRDiscreteLayoutGrid *grid, NSUInteger index, BOOL *stop) {
	
		[grid enumerateLayoutAreaNamesWithBlock:^(NSString *anAreaName) {
		
			[grid setDisplayBlock:displayBlock forAreaNamed:anAreaName];
			
		}];
		
		return grid;
		
	}];

}

- (UIView *) representingViewForItem:(WAArticle *)anArticle {

	UIView *returnedView = [self cachedArticleViewControllerForArticle:anArticle].view;
	
	returnedView.layer.cornerRadius = 2;

	returnedView.layer.backgroundColor = [UIColor whiteColor].CGColor;
	returnedView.layer.masksToBounds = YES;
	
	returnedView.layer.borderWidth = 1;
	returnedView.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.05].CGColor;
	
	return returnedView;
	
}

@end


@implementation WADiscretePaginatedArticlesViewController (DiscreteLayout_Private)

- (NSCache *) articleViewControllersCache {

	static NSString * key = @"WADiscretePaginatedArticlesViewController_DiscreteLayout_Private_articleViewControllersCache";
	
	NSCache *currentCache = objc_getAssociatedObject(self, &key);
	if (currentCache)
		return currentCache;
	
	NSCache *cache = [[NSCache alloc] init];
	objc_setAssociatedObject(self, &key, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	return cache;

}

@end
