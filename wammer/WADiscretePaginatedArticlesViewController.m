//
//  WADiscretePaginatedArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/31/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "WADiscretePaginatedArticlesViewController.h"
#import "IRDiscreteLayoutManager.h"
#import "WADataStore.h"

#import "WAArticleViewController.h"
#import "WAPaginatedArticlesViewController.h"

#import "WAOverlayBezel.h"
#import "CALayer+IRAdditions.h"

#import "WAFauxRootNavigationController.h"
#import "WAEightPartLayoutGrid.h"

#import "WANavigationBar.h"


static NSString * const kWADiscreteArticlePageElements = @"kWADiscreteArticlePageElements";
static NSString * const kWADiscreteArticleViewControllerOnItem = @"kWADiscreteArticleViewControllerOnItem";
static NSString * const kWADiscreteArticlesViewLastUsedLayoutGrids = @"kWADiscreteArticlesViewLastUsedLayoutGrids";

@interface WADiscretePaginatedArticlesViewController () <IRDiscreteLayoutManagerDelegate, IRDiscreteLayoutManagerDataSource, WAArticleViewControllerPresenting, UIGestureRecognizerDelegate>

@property (nonatomic, readwrite, retain) IRDiscreteLayoutManager *discreteLayoutManager;
@property (nonatomic, readwrite, retain) IRDiscreteLayoutResult *discreteLayoutResult;
@property (nonatomic, readwrite, retain) NSArray *layoutGrids;

- (UIView *) representingViewForItem:(WAArticle *)anArticle;
- (void) adjustPageViewAtIndex:(NSUInteger)anIndex;
- (void) adjustPageViewAtIndex:(NSUInteger)anIndex withAdditionalAdjustments:(void(^)(UIView *aSubview))aBlock;

- (void) adjustPageView:(UIView *)aPageView usingGridAtIndex:(NSUInteger)anIndex;

@end

@implementation WADiscretePaginatedArticlesViewController
@synthesize paginationSlider, discreteLayoutManager, discreteLayoutResult, layoutGrids, paginatedView;

- (id) init {

	return [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	__block IRPaginatedView *ownPaginatedView = self.paginatedView;
	
	ownPaginatedView.onPointInsideWithEvent = ^ (CGPoint aPoint, UIEvent *anEvent, BOOL superAnswer) {
	
		CGPoint convertedPoint = [ownPaginatedView.scrollView convertPoint:aPoint fromView:ownPaginatedView];
		if ([ownPaginatedView.scrollView pointInside:convertedPoint withEvent:anEvent])
			return YES;
		
		return superAnswer;
	
	};
	
	UILongPressGestureRecognizer *backgroundTouchRecognizer = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTouchPresense:)] autorelease];
	backgroundTouchRecognizer.minimumPressDuration = 0.05;
	backgroundTouchRecognizer.delegate = self;
	[self.view addGestureRecognizer:backgroundTouchRecognizer];

	if (self.discreteLayoutResult)
		[self.paginatedView reloadViews];
		
	self.paginationSlider.backgroundColor = nil;
	[self.paginationSlider irBind:@"currentPage" toObject:self.paginatedView keyPath:@"currentPage" options:nil];
	
	self.paginatedView.backgroundColor = nil;
	self.paginatedView.horizontalSpacing = 32.0f;
	
	self.view.backgroundColor = nil;
	self.view.opaque = NO;
	
	if (self.navigationItem.leftBarButtonItem)
	if (!self.navigationItem.leftBarButtonItem.customView) {
	
		UIBarButtonItem *oldItem = self.navigationItem.leftBarButtonItem;
	
		IRBarButtonItem *replacementItem = [IRBarButtonItem itemWithButton:((^ {
		
			UIButton *returnedButton = [UIButton buttonWithType:UIButtonTypeCustom];
			
			[returnedButton setImage:[IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBordered withTitle:oldItem.title font:nil backgroundColor:nil gradientColors:[NSArray arrayWithObjects:
				(id)[UIColor colorWithRed:.95 green:.95 blue:.95 alpha:1].CGColor,
				(id)[UIColor colorWithRed:.85 green:.85 blue:.85 alpha:1].CGColor,
			nil] innerShadow:nil border:[IRBorder borderForEdge:IREdgeNone withType:IRBorderTypeInset width:1.0f color:[UIColor colorWithWhite:.6 alpha:1]] shadow:nil] forState:UIControlStateNormal];
			
			[returnedButton setImage:[IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBordered withTitle:oldItem.title font:nil backgroundColor:nil gradientColors:[NSArray arrayWithObjects:
				(id)[UIColor colorWithRed:.85 green:.85 blue:.85 alpha:1].CGColor,
				(id)[UIColor colorWithRed:.75 green:.75 blue:.75 alpha:1].CGColor,
			nil] innerShadow:nil border:[IRBorder borderForEdge:IREdgeNone withType:IRBorderTypeInset width:1.0f color:[UIColor colorWithWhite:.6 alpha:1]] shadow:nil] forState:UIControlStateHighlighted];
			
			[returnedButton sizeToFit];
			
			return returnedButton;
		
		})()) wiredAction:nil];
		
		replacementItem.target = oldItem.target;
		replacementItem.action = oldItem.action;
		
		if ([oldItem isKindOfClass:[IRBarButtonItem class]]) {
			replacementItem.block = ((IRBarButtonItem *)oldItem).block;
		}
		
		self.navigationItem.leftBarButtonItem = replacementItem;
	
	}
	
	
	__block __typeof__(self) nrSelf = self;
	
	[self.paginatedView irAddObserverBlock: ^ (id inOldValue, id inNewValue, NSString *changeKind) {
	
		if (!nrSelf.paginatedView.numberOfPages)
			return;
	
		NSUInteger newIndex = [inNewValue unsignedIntValue];
		[nrSelf paginatedView:nrSelf.paginatedView didShowView:[nrSelf.paginatedView existingPageAtIndex:newIndex] atIndex:newIndex];
		
	} forKeyPath:@"currentPage" options:NSKeyValueObservingOptionNew context:nil];
		
}

- (UIView *) representingViewForItem:(WAArticle *)anArticle {

	__block __typeof__(self) nrSelf = self;
	__block WAArticleViewController *articleViewController = nil;
	
	articleViewController = objc_getAssociatedObject(anArticle, &kWADiscreteArticleViewControllerOnItem);
	NSURL *objectURI = [[anArticle objectID] URIRepresentation];
	
	if (!articleViewController) {
		articleViewController = [WAArticleViewController controllerForArticle:objectURI usingPresentationStyle:(
			[anArticle.fileOrder count] ? WADiscreteSingleImageArticleStyle :
			[anArticle.previews count] ? WADiscretePreviewArticleStyle : 
			WADiscretePlaintextArticleStyle
		)];
		objc_setAssociatedObject(anArticle, &kWADiscreteArticleViewControllerOnItem, articleViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	articleViewController.onViewDidLoad = ^ (WAArticleViewController *loadedVC, UIView *loadedView) {
		loadedView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.65f];
		loadedView.clipsToBounds = YES;
		loadedView.layer.cornerRadius = 4.0f;
		loadedView.layer.borderColor = [UIColor colorWithWhite:0.5f alpha:0.35f].CGColor;
		loadedView.layer.borderWidth = 1.0f;
		((UIView *)loadedVC.view.imageStackView).userInteractionEnabled = NO;
	};
	
	articleViewController.onPresentingViewController = ^ (void(^action)(UIViewController <WAArticleViewControllerPresenting> *parentViewController)) {
	
		action(nrSelf);
	
	};
	
	articleViewController.onViewTap = ^ {
	
		NSParameterAssert(nrSelf.navigationController);
		
		self.view.superview.clipsToBounds = NO;
		self.view.superview.superview.clipsToBounds = NO;
	
		[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
		
		__block WAPaginatedArticlesViewController *enqueuedPaginatedVC = nil;
		WAFauxRootNavigationController *enqueuedNavController = ((^ {
	
			enqueuedPaginatedVC = [[[WAPaginatedArticlesViewController alloc] init] autorelease];
			enqueuedPaginatedVC.navigationItem.leftBarButtonItem = nil;
			enqueuedPaginatedVC.navigationItem.hidesBackButton = NO;
			enqueuedPaginatedVC.context = [NSDictionary dictionaryWithObjectsAndKeys:
				objectURI, @"lastVisitedObjectURI",		
			nil];
			
			__block WAFauxRootNavigationController *navController = [[[WAFauxRootNavigationController alloc] initWithRootViewController:[[[UIViewController alloc] init]  autorelease]] autorelease];
			
			NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:[NSKeyedArchiver archivedDataWithRootObject:navController]] autorelease];
			[unarchiver setClass:[WANavigationBar class] forClassName:@"UINavigationBar"];
			navController = [unarchiver decodeObjectForKey:@"root"];
			
			[navController initWithRootViewController:enqueuedPaginatedVC];
			
			[navController setOnViewDidLoad: ^ (WANavigationController *self) {
				((WANavigationBar *)self.navigationBar).backgroundView = [WANavigationBar defaultGradientBackgroundView];
			}];
			
			if ([navController isViewLoaded])
			if (navController.onViewDidLoad)
				navController.onViewDidLoad(navController);
				
			NSString *leftTitle = @"Back";
			
			IRBorder *border = [IRBorder borderForEdge:IREdgeNone withType:IRBorderTypeInset width:1 color:[UIColor colorWithRed:0 green:0 blue:0 alpha:.5]];
			IRShadow *innerShadow = [IRShadow shadowWithColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:.55] offset:(CGSize){ 0, 1 } spread:2];
			IRShadow *shadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:1] offset:(CGSize){ 0, 1 } spread:1];
			
			UIFont *titleFont = [UIFont boldSystemFontOfSize:12];
			UIColor *titleColor = [UIColor colorWithRed:.3 green:.3 blue:.3 alpha:1];
			IRShadow *titleShadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:.35] offset:(CGSize){ 0, 1 } spread:0];
			
			UIColor *normalFromColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1];
			UIColor *normalToColor = [UIColor colorWithRed:.5 green:.5 blue:.5 alpha:1];
			UIColor *normalBackgroundColor = nil;
			NSArray *normalGradientColors = [NSArray arrayWithObjects:(id)normalFromColor.CGColor, (id)normalToColor.CGColor, nil];
			
			UIColor *highlightedFromColor = [normalFromColor colorWithAlphaComponent:.95];
			UIColor *highlightedToColor = [normalToColor colorWithAlphaComponent:.95];
			UIColor *highlightedBackgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
			NSArray *highlightedGradientColors = [NSArray arrayWithObjects:(id)highlightedFromColor.CGColor, (id)highlightedToColor.CGColor, nil];
			
			UIImage *leftItemImage = [IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBack withTitle:leftTitle font:titleFont color:titleColor shadow:titleShadow backgroundColor:normalBackgroundColor gradientColors:normalGradientColors innerShadow:innerShadow border:border shadow:shadow];
			UIImage *highlightedLeftItemImage = [IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBack withTitle:leftTitle font:titleFont color:titleColor shadow:titleShadow backgroundColor:highlightedBackgroundColor gradientColors:highlightedGradientColors innerShadow:innerShadow border:border shadow:shadow];
			__block IRBarButtonItem *newLeftItem = [IRBarButtonItem itemWithCustomImage:leftItemImage highlightedImage:highlightedLeftItemImage];
			enqueuedPaginatedVC.navigationItem.leftBarButtonItem = newLeftItem;
			
			newLeftItem.block = ^ {
					
				[CATransaction begin];
				
				[navController dismissModalViewControllerAnimated:NO];
				
				[[UIApplication sharedApplication].keyWindow.layer addAnimation:((^{
					CATransition *transition = [CATransition animation];
					transition.type = kCATransitionFade;
					transition.removedOnCompletion = YES;
					transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
					transition.duration = 0.3f;
					return transition;
				})()) forKey:kCATransition];

				[CATransaction commit];
				
			};
			
			return navController;
		
		})());
		
		UIWindow *containingWindow = self.navigationController.view.window;
		CGAffineTransform containerTransform = containingWindow.rootViewController.view.transform;
		CGRect actualRect = CGRectApplyAffineTransform(containingWindow.bounds, containerTransform);
		UIView *transitionContainerView = [[[UIView alloc] initWithFrame:actualRect] autorelease];
		transitionContainerView.center = (CGPoint){
			CGRectGetMidX(containingWindow.bounds),
			CGRectGetMidY(containingWindow.bounds)
		};
		transitionContainerView.transform = containerTransform;
		
		UIEdgeInsets navBarSnapshotEdgeInsets = (UIEdgeInsets){ 0, 0, -12, 0 };
		CGRect navBarBounds = self.navigationController.navigationBar.bounds;
		navBarBounds = UIEdgeInsetsInsetRect(navBarBounds, navBarSnapshotEdgeInsets);
		CGRect navBarRectInWindow = [containingWindow convertRect:navBarBounds fromView:self.navigationController.navigationBar];
		UIImage *navBarSnapshot = [self.navigationController.navigationBar.layer irRenderedImageWithEdgeInsets:navBarSnapshotEdgeInsets];
		UIView *navBarSnapshotHolderView = [[[UIView alloc] initWithFrame:(CGRect){ CGPointZero, navBarSnapshot.size }] autorelease];
		navBarSnapshotHolderView.layer.contents = (id)navBarSnapshot.CGImage;
		
		self.navigationController.navigationBar.layer.opacity = 0;
		
		UIImage *initialStateSnapshot = [self.navigationController.view.layer irRenderedImage];
		transitionContainerView.layer.contents = (id)initialStateSnapshot.CGImage;
		transitionContainerView.layer.contentsGravity = kCAGravityResizeAspectFill;
		
		self.navigationController.navigationBar.layer.opacity = 1;
		
		UIView *backgroundView = [[[UIView alloc] initWithFrame:transitionContainerView.bounds] autorelease];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
		[transitionContainerView addSubview:backgroundView];
		
		UIView *scalingHolderView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
		[transitionContainerView addSubview:scalingHolderView];
		
		CGRect discreteArticleViewRectInWindow = [containingWindow convertRect:articleViewController.view.bounds fromView:articleViewController.view];
		UIImage *discreteArticleViewSnapshot = [articleViewController.view.layer irRenderedImage];
		UIView *discreteArticleSnapshotHolderView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
		discreteArticleSnapshotHolderView.frame = (CGRect){ CGPointZero, discreteArticleViewSnapshot.size };
		discreteArticleSnapshotHolderView.layer.contents = (id)discreteArticleViewSnapshot.CGImage;
		discreteArticleSnapshotHolderView.layer.contentsGravity = kCAGravityResize;
		[scalingHolderView addSubview:discreteArticleSnapshotHolderView];
		
		[self.navigationController presentModalViewController:enqueuedNavController animated:NO];
		[enqueuedPaginatedVC setContextControlsVisible:NO animated:NO];
		
		//	CGRect fullsizeArticleViewRectInWindow = [containingWindow convertRect:enqueuedNavController.view.bounds fromView:enqueuedNavController.view];
		UIImage *fullsizeArticleViewSnapshot = [enqueuedNavController.view.layer irRenderedImage];
		UIView *fullsizeArticleSnapshotHolderView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
		fullsizeArticleSnapshotHolderView.frame = (CGRect){ CGPointZero, fullsizeArticleViewSnapshot.size };
		fullsizeArticleSnapshotHolderView.layer.contents = (id)fullsizeArticleViewSnapshot.CGImage;
		fullsizeArticleSnapshotHolderView.layer.contentsGravity = kCAGravityResize;
		[scalingHolderView addSubview:fullsizeArticleSnapshotHolderView];
		
		discreteArticleSnapshotHolderView.frame = scalingHolderView.bounds;
		discreteArticleSnapshotHolderView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		fullsizeArticleSnapshotHolderView.frame = scalingHolderView.bounds;
		fullsizeArticleSnapshotHolderView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		
		[containingWindow addSubview:transitionContainerView];
		
		[transitionContainerView addSubview:navBarSnapshotHolderView];
		navBarSnapshotHolderView.frame = [containingWindow convertRect:navBarRectInWindow toView:navBarSnapshotHolderView.superview];
		
		backgroundView.alpha = 0;
		discreteArticleSnapshotHolderView.alpha = 1;
		fullsizeArticleSnapshotHolderView.alpha = 0;
		scalingHolderView.frame = [containingWindow convertRect:discreteArticleViewRectInWindow toView:scalingHolderView.superview];
		
		UIViewAnimationOptions animationOptions = UIViewAnimationOptionCurveEaseInOut;
		
		[UIView animateWithDuration:0.35 delay:0 options:animationOptions animations: ^ {
		
			backgroundView.alpha = 1;
			discreteArticleSnapshotHolderView.alpha = 0;
			fullsizeArticleSnapshotHolderView.alpha = 1;
			scalingHolderView.frame = (CGRect){ CGPointZero, fullsizeArticleViewSnapshot.size };
			
		} completion: ^ (BOOL finished) {
		
			[transitionContainerView removeFromSuperview];
			[[UIApplication sharedApplication] endIgnoringInteractionEvents];
			
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				[CATransaction begin];
				
				[enqueuedPaginatedVC setContextControlsVisible:YES animated:NO];
			
				[enqueuedPaginatedVC.view.window.layer addAnimation:((^{
					CATransition *transition = [CATransition animation];
					transition.type = kCATransitionFade;
					transition.removedOnCompletion = YES;
					transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
					transition.duration = 0.3f;
					return transition;
				})()) forKey:kCATransition];

				[CATransaction commit];

			});
			
		}];
	
	};
	
	articleViewController.onViewPinch = ^ (UIGestureRecognizerState state, CGFloat scale, CGFloat velocity) {
	
		if (state != UIGestureRecognizerStateChanged)
			return;
		
		if (scale > 1.05f)
		if (velocity > 1.05f)
			articleViewController.onViewTap();
	
	};

	return articleViewController.view;
	
}

- (void) setContextControlsVisible:(BOOL)contextControlsVisible animated:(BOOL)animated {

	NSLog(@"TBD %s", __PRETTY_FUNCTION__);

}

- (IRDiscreteLayoutGrid *) layoutManager:(IRDiscreteLayoutManager *)manager nextGridForContentsUsingGrid:(IRDiscreteLayoutGrid *)proposedGrid {
	
	NSMutableArray *lastResultantGrids = objc_getAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids);
	
	if (![lastResultantGrids count]) {
		objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, nil, OBJC_ASSOCIATION_ASSIGN);
		return proposedGrid;
	}
	
	IRDiscreteLayoutGrid *prototype = [[[lastResultantGrids objectAtIndex:0] retain] autorelease];
	[lastResultantGrids removeObjectAtIndex:0];
	
	return prototype;

}

- (IRDiscreteLayoutManager *) discreteLayoutManager {

	if (discreteLayoutManager)
		return discreteLayoutManager;
		
	__block __typeof__(self) nrSelf = self;
		
	IRDiscreteLayoutGridAreaDisplayBlock genericDisplayBlock = [[^ (IRDiscreteLayoutGrid *self, id anItem) {
	
		if (![anItem isKindOfClass:[WAArticle class]])
			return nil;
	
		return [nrSelf representingViewForItem:(WAArticle *)anItem];
	
	} copy] autorelease];
	
	//	IRDiscreteLayoutGrid * (^gridWithLayoutBlocks)(IRDiscreteLayoutGridAreaLayoutBlock aBlock, ...) = ^ (IRDiscreteLayoutGridAreaLayoutBlock aBlock, ...) {
	//	
	//		IRDiscreteLayoutGrid *returnedPrototype = [IRDiscreteLayoutGrid prototype];
	//		NSUInteger numberOfAppendedLayoutAreas = 0;
	//	
	//		va_list arguments;
	//		va_start(arguments, aBlock);
	//		for (IRDiscreteLayoutGridAreaLayoutBlock aLayoutBlock = aBlock; aLayoutBlock != nil; aLayoutBlock =	va_arg(arguments, IRDiscreteLayoutGridAreaLayoutBlock)) {
	//			[returnedPrototype registerLayoutAreaNamed:[NSString stringWithFormat:@"area_%2.0i", numberOfAppendedLayoutAreas] validatorBlock:nil layoutBlock:aLayoutBlock displayBlock:genericDisplayBlock];
	//			numberOfAppendedLayoutAreas++;
	//		};
	//		va_end(arguments);
	//		return returnedPrototype;
	//		
	//	};
	
	NSMutableArray *enqueuedLayoutGrids = [NSMutableArray array];

	//	void (^enqueueGridPrototypes)(IRDiscreteLayoutGrid *, IRDiscreteLayoutGrid *) = ^ (IRDiscreteLayoutGrid *aGrid, IRDiscreteLayoutGrid *anotherGrid) {
	//		aGrid.contentSize = (CGSize){ 768, 1024 };
	//		anotherGrid.contentSize = (CGSize){ 1024, 768 };
	//		[enqueuedLayoutGrids addObject:aGrid];		
	//		[aGrid enumerateLayoutAreaNamesWithBlock: ^ (NSString *anAreaName) {
	//			[[aGrid class] markAreaNamed:anAreaName inGridPrototype:aGrid asEquivalentToAreaNamed:anAreaName inGridPrototype:anotherGrid];
	//		}];
	//	};
	
	//	IRDiscreteLayoutGridAreaLayoutBlock (^make)(float_t, float_t, float_t, float_t, float_t, float_t) = ^ (float_t a, float_t b, float_t c, float_t d, float_t e, float_t f) { return IRDiscreteLayoutGridAreaLayoutBlockForProportionsMake(a, b, c, d, e, f); };
	
	WAEightPartLayoutGrid *eightPartGrid = [WAEightPartLayoutGrid prototype];
	eightPartGrid.validatorBlock = nil;
	eightPartGrid.displayBlock = genericDisplayBlock;
	
	[enqueuedLayoutGrids addObject:eightPartGrid];
	
	//	enqueueGridPrototypes(
	//		gridWithLayoutBlocks(
	//			make(2, 3, 0, 0, 1, 1),
	//			make(2, 3, 0, 1, 1, 1),
	//			make(2, 3, 1, 0, 1, 2),
	//			make(2, 3, 0, 2, 2, 1),
	//		nil),
	//		gridWithLayoutBlocks(
	//			make(3, 2, 0, 0, 1, 1),
	//			make(3, 2, 0, 1, 1, 1),
	//			make(3, 2, 1, 0, 1, 2),
	//			make(3, 2, 2, 0, 1, 2),
	//		nil)		
	//	);
	
	//	enqueueGridPrototypes(
	//		gridWithLayoutBlocks(
	//			make(2, 2, 0, 0, 2, 1),
	//			make(2, 2, 0, 1, 1, 1),
	//			make(2, 2, 1, 1, 1, 1), 
	//		nil),
	//		gridWithLayoutBlocks(
	//			make(2, 2, 0, 0, 1, 2),
	//			make(2, 2, 1, 0, 1, 1),
	//			make(2, 2, 1, 1, 1, 1),
	//		nil)
	//	);
	
	//	enqueueGridPrototypes(
	//		gridWithLayoutBlocks(
	//			make(5, 5, 0, 0, 2, 2.5),
	//			make(5, 5, 0, 2.5, 2, 2.5),
	//			make(5, 5, 2, 0, 3, 1.66),
	//			make(5, 5, 2, 1.66, 3, 1.66),
	//			make(5, 5, 2, 3.32, 3, 1.68), 
	//		nil),
	//		gridWithLayoutBlocks(
	//			make(5, 5, 0, 0, 2, 2.5),
	//			make(5, 5, 0, 2.5, 2, 2.5),
	//			make(5, 5, 2, 0, 3, 1.66),
	//			make(5, 5, 2, 1.66, 3, 1.66),
	//			make(5, 5, 2, 3.32, 3, 1.68),
	//		nil)
	//	);

	//	enqueueGridPrototypes(
	//		gridWithLayoutBlocks(
	//			make(5, 5, 0, 0, 2.5, 3),
	//			make(5, 5, 0, 3, 2.5, 2),
	//			make(5, 5, 2.5, 0, 2.5, 1.5),
	//			make(5, 5, 2.5, 1.5, 2.5, 1.5),
	//			make(5, 5, 2.5, 3, 2.5, 0.66),
	//			make(5, 5, 2.5, 3.66, 2.5, 0.66),
	//			make(5, 5, 2.5, 4.33, 2.5, 0.67), 
	//		nil),
	//		gridWithLayoutBlocks(
	//			make(5, 5, 0, 0, 2, 2),
	//			make(5, 5, 0, 2, 2, 1),
	//			make(5, 5, 0, 3, 2, 1),
	//			make(5, 5, 0, 4, 2, 1),
	//			make(5, 5, 2, 0, 3, 2),
	//			make(5, 5, 2, 2, 3, 1.5),
	//			make(5, 5, 2, 3.5, 3, 1.5),
	//		nil)
	//	);

	//	enqueueGridPrototypes(
	//		gridWithLayoutBlocks(
	//			make(3, 3, 0, 0, 3, 1),
	//			make(3, 3, 0, 1, 1.5, 1),
	//			make(3, 3, 1.5, 1, 1.5, 1),
	//			make(3, 3, 0, 2, 1, 1),
	//			make(3, 3, 1, 2, 1, 1),
	//			make(3, 3, 2, 2, 1, 1), 
	//		nil),
	//		gridWithLayoutBlocks(
	//			make(3, 3, 0, 0, 1, 3),
	//			make(3, 3, 1, 0, 1, 1.5),
	//			make(3, 3, 1, 1.5, 1, 1.5),
	//			make(3, 3, 2, 0, 1, 1),
	//			make(3, 3, 2, 1, 1, 1),
	//			make(3, 3, 2, 2, 1, 1),
	//		nil)
	//	);
	
	self.layoutGrids = enqueuedLayoutGrids;
	self.discreteLayoutManager = [[IRDiscreteLayoutManager new] autorelease];
	self.discreteLayoutManager.delegate = self;
	self.discreteLayoutManager.dataSource = self;
	return self.discreteLayoutManager;

}

- (void) viewDidUnload {

	[self.paginationSlider irUnbind:@"currentPage"];
	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];

	self.discreteLayoutManager = nil;
	self.discreteLayoutResult = nil;
	[super viewDidUnload];

}

-	(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	
	return YES;
	
}

- (void) reloadViewContents {

	if (self.discreteLayoutResult) {
		objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, [self.discreteLayoutResult.grids irMap: ^ (IRDiscreteLayoutGrid *aGridInstance, NSUInteger index, BOOL *stop) {
			return [aGridInstance isFullyPopulated] ? aGridInstance.prototype : nil;
		}], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	self.discreteLayoutResult = [self.discreteLayoutManager calculatedResult];
	objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, nil, OBJC_ASSOCIATION_ASSIGN);
		
	NSUInteger lastCurrentPage = self.paginatedView.currentPage;
	
	[self.paginatedView reloadViews];
	self.paginationSlider.numberOfPages = self.paginatedView.numberOfPages;
	
	//	TBD: Cache contents of the previous screen, and then do some page index matching
	//	Instead of going back to the last current page, since we might have nothing left on the current page
	//	And things can get garbled very quickly
	
	if ((self.paginatedView.numberOfPages - 1) >= lastCurrentPage)
		[self.paginatedView scrollToPageAtIndex:lastCurrentPage animated:NO];

}

- (NSUInteger) numberOfItemsForLayoutManager:(IRDiscreteLayoutManager *)manager {

  return [self.fetchedResultsController.fetchedObjects count];

}

- (id<IRDiscreteLayoutItem>) layoutManager:(IRDiscreteLayoutManager *)manager itemAtIndex:(NSUInteger)index {

  return (id<IRDiscreteLayoutItem>)[self.fetchedResultsController.fetchedObjects objectAtIndex:index];

}

- (NSUInteger) numberOfLayoutGridsForLayoutManager:(IRDiscreteLayoutManager *)manager {

  return [self.layoutGrids count];

}

- (id<IRDiscreteLayoutItem>) layoutManager:(IRDiscreteLayoutManager *)manager layoutGridAtIndex:(NSUInteger)index {

  return (id<IRDiscreteLayoutItem>)[self.layoutGrids objectAtIndex:index];

}

- (NSUInteger) numberOfViewsInPaginatedView:(IRPaginatedView *)paginatedView {

	return [self.discreteLayoutResult.grids count];

}

- (UIView *) viewForPaginatedView:(IRPaginatedView *)aPaginatedView atIndex:(NSUInteger)index {

	UIView *returnedView = [[[UIView alloc] initWithFrame:aPaginatedView.bounds] autorelease];
	returnedView.autoresizingMask = UIViewAutoresizingNone;
	returnedView.layer.shouldRasterize = YES;
	
	IRDiscreteLayoutGrid *viewGrid = (IRDiscreteLayoutGrid *)[self.discreteLayoutResult.grids objectAtIndex:index];
	
	NSMutableArray *pageElements = [NSMutableArray arrayWithCapacity:[viewGrid.layoutAreaNames count]];
	
	CGSize oldContentSize = viewGrid.contentSize;
	viewGrid.contentSize = aPaginatedView.frame.size;
	
	[viewGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		if (!item)
			return;
	
		UIView *placedSubview = (UIView *)displayBlock(viewGrid, item);
		NSParameterAssert(placedSubview);
		placedSubview.frame = layoutBlock(viewGrid, item);
		placedSubview.autoresizingMask = UIViewAutoresizingNone;
		[pageElements addObject:placedSubview];
		[returnedView addSubview:placedSubview];
				
	}];

	viewGrid.contentSize = oldContentSize;
	
	objc_setAssociatedObject(returnedView, &kWADiscreteArticlePageElements, pageElements, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[returnedView setNeedsLayout];
	
	[self adjustPageView:returnedView usingGridAtIndex:index];
			
	return returnedView;

}

- (void) paginatedView:(IRPaginatedView *)paginatedView didShowView:(UIView *)aView atIndex:(NSUInteger)index {

	IRDiscreteLayoutGrid *viewGrid = (IRDiscreteLayoutGrid *)[self.discreteLayoutResult.grids objectAtIndex:index];
	[viewGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		WAArticle *representedArticle = (WAArticle *)item;
				
		//	for (WAFile *aFile in representedArticle.fileOrder)
		//		[aFile resourceFilePath];
			
		if ([representedArticle.fileOrder count]) {
			WAFile *firstFile = (WAFile *)[representedArticle.managedObjectContext irManagedObjectForURI:[representedArticle.fileOrder objectAtIndex:0]];
			[firstFile resourceFilePath];
			[firstFile thumbnailFilePath];
		}
			
		for (WAPreview *aPreview in representedArticle.previews)
			[aPreview.graphElement thumbnailFilePath];
	
	}];

}

- (UIViewController *) viewControllerForSubviewAtIndex:(NSUInteger)index inPaginatedView:(IRPaginatedView *)paginatedView {

	return nil;

}

- (void) adjustPageViewAtIndex:(NSUInteger)anIndex {

	[self adjustPageViewAtIndex:anIndex withAdditionalAdjustments:nil];

}

- (void) adjustPageView:(UIView *)currentPageView usingGridAtIndex:(NSUInteger)anIndex {

	//	Find the best grid alternative in allDestinations, and then enumerate its layout areas, using the provided layout blocks to relayout all the element representing views in the current paginated view page.
	
	if ([self.discreteLayoutResult.grids count] < (anIndex + 1))
		return;
	
	NSArray *currentPageElements = objc_getAssociatedObject(currentPageView, &kWADiscreteArticlePageElements);
	IRDiscreteLayoutGrid *currentPageGrid = [self.discreteLayoutResult.grids objectAtIndex:anIndex];
	NSSet *allDestinations = [currentPageGrid allTransformablePrototypeDestinations];
	NSSet *allIntrospectedGrids = [allDestinations setByAddingObject:currentPageGrid];
	IRDiscreteLayoutGrid *bestGrid = nil;
	CGFloat currentAspectRatio = CGRectGetWidth(self.paginatedView.frame) / CGRectGetHeight(self.paginatedView.frame);
	for (IRDiscreteLayoutGrid *aGrid in allIntrospectedGrids) {
		
		CGFloat bestGridAspectRatio = bestGrid.contentSize.width / bestGrid.contentSize.height;
		CGFloat currentGridAspectRatio = aGrid.contentSize.width / aGrid.contentSize.height;
		
		if (!bestGrid) {
			bestGrid = [[aGrid retain] autorelease];
			continue;
		}
		
		if (fabs(currentAspectRatio - bestGridAspectRatio) < fabs(currentAspectRatio - currentGridAspectRatio)) {
			continue;
		}
		
		bestGrid = [[aGrid retain] autorelease];
		
	}
	
	
	IRDiscreteLayoutGrid *transformedGrid = bestGrid;//[allDestinations anyObject];
	transformedGrid = [currentPageGrid transformedGridWithPrototype:(transformedGrid.prototype ? transformedGrid.prototype : transformedGrid)];
	
	CGSize oldContentSize = transformedGrid.contentSize;
	transformedGrid.contentSize = self.paginatedView.frame.size;
	[[currentPageGrid retain] autorelease];
			
	[transformedGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		if (!item)
			return;
	
		((UIView *)[currentPageElements objectAtIndex:[currentPageGrid.layoutAreaNames indexOfObject:name]]).frame = CGRectInset(layoutBlock(transformedGrid, item), 4, 4);
		
	}];
	
	transformedGrid.contentSize = oldContentSize;

}

- (void) adjustPageViewAtIndex:(NSUInteger)anIndex withAdditionalAdjustments:(void(^)(UIView *aSubview))aBlock {

	UIView *currentPageView = [self.paginatedView existingPageAtIndex:anIndex];	
	[self adjustPageView:currentPageView usingGridAtIndex:anIndex];
		
	if (aBlock)
		aBlock(currentPageView);

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	void (^removeAnimations)(UIView *) = ^ (UIView *introspectedView) {
	
		__block void (^removeAnimationsOnView)(UIView *aView) = nil;
		
		removeAnimationsOnView = ^ (UIView *aView) {
		
			[aView.layer removeAllAnimations];

			for (UIView *aSubview in aView.subviews)
				removeAnimationsOnView(aSubview);
		
		};
		
		removeAnimationsOnView(introspectedView);

	};
	
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	removeAnimations(self.paginatedView);

	//	If the paginated view is currently showing a view constructed with information provided by a layout grid, and that layout grid’s prototype has a fully transformable target, grab that transformable prototype and do a transform, then reposition individual items
	
	if (self.paginatedView.currentPage > 0)
		[self adjustPageViewAtIndex:(self.paginatedView.currentPage - 1) withAdditionalAdjustments:removeAnimations];
	
	[self adjustPageViewAtIndex:self.paginatedView.currentPage withAdditionalAdjustments:removeAnimations];
	
	if ((self.paginatedView.currentPage + 1) < self.paginatedView.numberOfPages) {
		[self adjustPageViewAtIndex:(self.paginatedView.currentPage + 1) withAdditionalAdjustments:removeAnimations];
	}
	
	[CATransaction commit];
	
}

- (void) paginationSlider:(WAPaginationSlider *)slider didMoveToPage:(NSUInteger)destinationPage {

	if (self.paginatedView.currentPage == destinationPage)
		return;
	
	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	dispatch_async(dispatch_get_main_queue(), ^ {
	
		[CATransaction begin];
		CATransition *transition = [CATransition animation];
		transition.type = kCATransitionMoveIn;
		transition.subtype = (self.paginatedView.currentPage < destinationPage) ? kCATransitionFromRight : kCATransitionFromLeft;
		transition.duration = 0.25f;
		transition.fillMode = kCAFillModeForwards;
		transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		transition.removedOnCompletion = YES;
		
		[self.paginatedView scrollToPageAtIndex:destinationPage animated:NO];
		[(id<UIScrollViewDelegate>)self.paginatedView scrollViewDidScroll:self.paginatedView.scrollView];
		[self.paginatedView.layer addAnimation:transition forKey:@"transition"];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, transition.duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
			[[UIApplication sharedApplication] endIgnoringInteractionEvents];
		});
		
		[CATransaction commit];
	
	});
	
}

- (void) handleBackgroundTouchPresense:(UILongPressGestureRecognizer *)aRecognizer {

	switch (aRecognizer.state) {
	
		case UIGestureRecognizerStatePossible:
			break;
		
		case UIGestureRecognizerStateBegan: {
			[self beginDelayingInterfaceUpdates];
			break;
		}
		
		case UIGestureRecognizerStateChanged:
			break;
			
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed: {
			[self endDelayingInterfaceUpdates];
			break;
		}
	
	};

}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {

	return ![self.paginationSlider hitTest:[touch locationInView:self.paginationSlider] withEvent:nil];

}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {

	return YES;

}

- (void) enqueueInterfaceUpdate:(void (^)(void))anAction {

	[self performInterfaceUpdate:anAction];

}

- (NSArray *) debugActionSheetControllerActions {

	__block __typeof__(self) nrSelf = self; 

	return [[super debugActionSheetControllerActions] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:
	
		[IRAction actionWithTitle:@"Reflow" block: ^ {
		
			[nrSelf reloadViewContents];
		
		}],
		
		[IRAction actionWithTitle:@"Label Smoke" block: ^ {
		
			UIViewController *testingVC = [[(UIViewController *)[NSClassFromString(@"IRLabelTestingViewController") alloc] init] autorelease];
			__block UINavigationController *navC = [[[UINavigationController alloc] initWithRootViewController:testingVC] autorelease];
			testingVC.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithTitle:@"Close" action:^{
				[navC dismissModalViewControllerAnimated:YES];
			}];
			navC.modalPresentationStyle = UIModalPresentationFormSheet;
			[[UIApplication sharedApplication].keyWindow.rootViewController presentModalViewController:navC animated:YES];
		
		}],
	
	nil]];

}

- (void) dealloc {

	[self.paginationSlider irUnbind:@"currentPage"];
	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];
	
	[paginationSlider release];
	[paginatedView release];
	[discreteLayoutManager release];
	[discreteLayoutResult release];
	[layoutGrids release];

	[super dealloc];

}

@end
