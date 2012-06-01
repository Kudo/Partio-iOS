//
//  WAOverviewController+DiscreteLayout.m
//  wammer
//
//  Created by Evadne Wu on 2/29/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAOverviewController+DiscreteLayout.h"
#import "WADataStore.h"
#import "WAArticleViewController.h"

#import "IRDiscreteLayoutManager.h"
#import "IRDiscreteLayoutGrid+Transforming.h"

#import "WADiscreteLayoutHelpers.h"

#import "WAArticle+DiscreteLayoutAdditions.h"


static NSString * const kLastUsedLayoutGrids = @"-[WAOverviewController(DiscreteLayout) lastUsedLayoutGrids]";


@interface WAOverviewController (DiscreteLayout_Private) <WAArticleViewControllerDelegate>

@property (nonatomic, readwrite, retain) IRDiscreteLayoutResult *discreteLayoutResult;
@property (nonatomic, readonly, retain) NSCache *articleViewControllersCache;

@end


@implementation WAOverviewController (DiscreteLayout)

- (NSArray *) lastUsedLayoutGrids {

	return objc_getAssociatedObject(self, &kLastUsedLayoutGrids);

}

- (void) setLastUsedLayoutGrids:(NSArray *)newGrids {

	if ([self lastUsedLayoutGrids] == newGrids)
		return;
	
	objc_setAssociatedObject(self, &kLastUsedLayoutGrids, newGrids, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (WAArticleViewController *) newDiscreteArticleViewControllerForArticle:(WAArticle *)article NS_RETURNS_RETAINED {

	__weak WAOverviewController *wSelf = self;
	
	WAArticleViewControllerPresentationStyle style = [WAArticleViewController suggestedDiscreteStyleForArticle:article];
	WAArticleViewController *articleViewController = [WAArticleViewController controllerForArticle:article context:article.managedObjectContext presentationStyle:style];
	
	articleViewController.onViewDidLoad = ^ (WAArticleViewController *loadedVC, UIView *loadedView) {
		
		UIView *borderView = [[UIView alloc] initWithFrame:CGRectInset(loadedVC.view.bounds, 0, 0)];
		borderView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		borderView.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1].CGColor;
		borderView.layer.borderWidth = 1;
		
		[loadedVC.view addSubview:borderView];
		[borderView.superview sendSubviewToBack:borderView];
		
	};
	
	articleViewController.hostingViewController = self;
	articleViewController.delegate = self;
	
	articleViewController.onViewTap = ^ {
	
		[wSelf presentDetailedContextForArticle:[[articleViewController.article objectID] URIRepresentation]];
		
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
	
	return articleViewController;

}

- (WAArticleViewController *) cachedArticleViewControllerForArticle:(WAArticle *)article {

	NSValue *objectValue = [NSValue valueWithNonretainedObject:article];

	WAArticleViewController *cachedVC = [self.articleViewControllersCache objectForKey:objectValue];
	if (cachedVC)
		return cachedVC;
	
	WAArticleViewController *createdVC = [self newDiscreteArticleViewControllerForArticle:article];
	[self.articleViewControllersCache setObject:createdVC forKey:objectValue];
	[self addChildViewController:createdVC];
	
	return createdVC;

}

- (void) removeCachedArticleViewControllers {

	[self.articleViewControllersCache removeAllObjects];

}

- (UIView *) newPageContainerView {

	IRView *returnedView = [[IRView alloc] initWithFrame:(CGRect){ CGPointZero, (CGSize){ 320, 320 } }];
	returnedView.backgroundColor = [UIColor colorWithWhite:242.0/256.0 alpha:1];
	returnedView.opaque = YES;
	returnedView.autoresizingMask = UIViewAutoresizingNone;
	returnedView.clipsToBounds = YES;
	
	[returnedView setNeedsLayout];
	
	return returnedView;

}

- (NSArray *) newLayoutGrids {

	NSArray *grids = WADefaultLayoutGrids();
	
	__weak WAOverviewController *wSelf = self;
	
	IRDiscreteLayoutAreaDisplayBlock displayBlock = ^ (IRDiscreteLayoutArea *self, id anItem) {
	
		return [wSelf representingViewForItem:anItem];
	
	};
	
	for (IRDiscreteLayoutGrid *grid in grids)
		for (IRDiscreteLayoutArea *area in grid.layoutAreas)
			area.displayBlock = displayBlock;
	
	return grids;
	
}

- (UIView *) representingViewForItem:(WAArticle *)anArticle {

	UIView *returnedView = [self cachedArticleViewControllerForArticle:anArticle].view;
	
	return returnedView;
	
}

- (NSString *) presentationTemplateNameForArticleViewController:(WAArticleViewController *)controller {

	WAArticle *article = controller.article;
	if (!article)
		return nil;
	
	IRDiscreteLayoutGrid *grid = [self.discreteLayoutResult gridContainingItem:article];
	grid = [grid transformedGridWithPrototype:[grid bestCounteprartPrototypeForAspectRatio:[self currentAspectRatio]]];
	
	WADiscreteLayoutArea *area = (WADiscreteLayoutArea *)[grid areaForItem:article];
	NSParameterAssert([area isKindOfClass:[WADiscreteLayoutArea class]]);
	
	if (area.templateNameBlock) {
		NSString *answer = area.templateNameBlock(area);
		return answer;
	}
	
	return nil;

}

- (NSCache *) articleViewControllersCache {

	static NSString * key = @"WAOverviewController_DiscreteLayout_Private_articleViewControllersCache";
	
	NSCache *currentCache = objc_getAssociatedObject(self, &key);
	if (currentCache)
		return currentCache;
	
	NSCache *cache = [[NSCache alloc] init];
	objc_setAssociatedObject(self, &key, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	return cache;

}

@end
