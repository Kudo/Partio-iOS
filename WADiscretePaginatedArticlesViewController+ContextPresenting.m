//
//  WADiscretePaginatedArticlesViewController+ContextPresenting.m
//  wammer
//
//  Created by Evadne Wu on 2/29/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WADiscretePaginatedArticlesViewController+ContextPresenting.h"
#import "WAArticleViewController.h"
#import "WADataStore.h"
#import "WAFauxRootNavigationController.h"
#import "WANavigationBar.h"
#import "WAButton.h"
#import "WAGestureWindow.h"

#define USES_PAGINATED_CONTEXT 0

@interface WADiscretePaginatedArticlesViewController (ContextPresenting_Private)

- (void(^)(void)) dismissBlockForArticleContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller;

- (void) setDismissBlock:(void(^)(void))aBlock forArticleContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller;

@end


@implementation WADiscretePaginatedArticlesViewController (ContextPresenting)

- (UIViewController<WAArticleViewControllerPresenting> *) presentDetailedContextForArticle:(NSURL *)anObjectURI {

	return [self presentDetailedContextForArticle:anObjectURI animated:YES];

}

- (UIViewController<WAArticleViewControllerPresenting> *) presentDetailedContextForArticle:(NSURL *)anObjectURI animated:(BOOL)animated {

	BOOL usesFlip = [[NSUserDefaults standardUserDefaults] boolForKey:kWADebugUsesDiscreteArticleFlip];
	
	WAArticleContextAnimation animation = WAArticleContextAnimationDefault;
	
	if (!animated) {
		animation = WAArticleContextAnimationNone;
	} else if (usesFlip) {
		animation = WAArticleContextAnimationFlipAndScale;
	} else {
		animation = WAArticleContextAnimationCoverVertically;
	}

	return [self presentDetailedContextForArticle:anObjectURI usingAnimation:animation];

}

- (UIViewController<WAArticleViewControllerPresenting> *) presentDetailedContextForArticle:(NSURL *)articleURI usingAnimation:(WAArticleContextAnimation)animation {

	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	__block WAArticle *article = (WAArticle *)[self.managedObjectContext irManagedObjectForURI:articleURI];
	__block WADiscretePaginatedArticlesViewController *nrSelf = self;
	__block WAArticleViewController *articleViewController = [self cachedArticleViewControllerForArticle:article];
		
	__block UIViewController<WAArticleViewControllerPresenting> *shownArticleVC = [[self newContextViewControllerForArticle:articleURI] autorelease];
	
	UINavigationController *enqueuedNavController = [self wrappingNavigationControllerForContextViewController:shownArticleVC];
	
	__block void (^presentBlock)(void) = nil;
	__block void (^dismissBlock)(void) = nil;
	
	//	SHARED STUFF
	
	UIWindow *containingWindow = self.navigationController.view.window;
	CGAffineTransform containingWindowTransform = containingWindow.rootViewController.view.transform;
	CGRect containingWindowBounds = CGRectApplyAffineTransform(containingWindow.bounds, containingWindowTransform);		
	UIView *containerView = [[[UIView alloc] initWithFrame:containingWindowBounds] autorelease];
	containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	containerView.center = irCGRectAnchor(containingWindow.bounds, irCenter, YES);
	containerView.transform = containingWindowTransform;
	
	switch (animation) {

		case WAArticleContextAnimationFadeAndZoom: {
	
			presentBlock = ^ {
			
				UIEdgeInsets const navBarSnapshotEdgeInsets = (UIEdgeInsets){ 0, 0, -12, 0 };
				
				CGRect navBarBounds = self.navigationController.navigationBar.bounds;
				navBarBounds = UIEdgeInsetsInsetRect(navBarBounds, navBarSnapshotEdgeInsets);
				CGRect navBarRectInWindow = [containingWindow convertRect:navBarBounds fromView:self.navigationController.navigationBar];
				UIImage *navBarSnapshot = [self.navigationController.navigationBar.layer irRenderedImageWithEdgeInsets:navBarSnapshotEdgeInsets];
				UIView *navBarSnapshotHolderView = [[[UIView alloc] initWithFrame:(CGRect){ CGPointZero, navBarSnapshot.size }] autorelease];
				navBarSnapshotHolderView.layer.contents = (id)navBarSnapshot.CGImage;
				
				self.navigationController.navigationBar.layer.opacity = 0;
				articleViewController.view.hidden = YES;
				
				containerView.layer.contents = (id)[self.navigationController.view.layer irRenderedImage].CGImage;
				containerView.layer.contentsGravity = kCAGravityResizeAspectFill;
				
				self.navigationController.navigationBar.layer.opacity = 1;
				articleViewController.view.hidden = NO;
				
				UIView *backgroundView, *scalingHolderView;
				
				backgroundView = [[[UIView alloc] initWithFrame:containerView.bounds] autorelease];
				backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
				backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
				[containerView addSubview:backgroundView];
				
				scalingHolderView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
				[containerView addSubview:scalingHolderView];
				
				CGRect discreteArticleViewRectInWindow = [containingWindow convertRect:articleViewController.view.bounds fromView:articleViewController.view];
				UIView *discreteArticleSnapshotHolderView = [articleViewController.view irRenderedProxyView];
				discreteArticleSnapshotHolderView.frame = (CGRect){ CGPointZero, discreteArticleSnapshotHolderView.bounds.size };
				discreteArticleSnapshotHolderView.layer.contentsGravity = kCAGravityResize;
				[scalingHolderView addSubview:discreteArticleSnapshotHolderView];
				
				[self.navigationController presentModalViewController:enqueuedNavController animated:NO];
				[shownArticleVC setContextControlsVisible:NO animated:NO];
				
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
				
				[containingWindow addSubview:containerView];
				
				[containerView addSubview:navBarSnapshotHolderView];
				navBarSnapshotHolderView.frame = [containingWindow convertRect:navBarRectInWindow toView:navBarSnapshotHolderView.superview];
				
				backgroundView.alpha = 0;
				discreteArticleSnapshotHolderView.alpha = 1;
				fullsizeArticleSnapshotHolderView.alpha = 0;
				scalingHolderView.frame = [containingWindow convertRect:discreteArticleViewRectInWindow toView:scalingHolderView.superview];
				
				UIViewAnimationOptions animationOptions = UIViewAnimationOptionCurveEaseInOut;
				
				[UIView animateWithDuration:0.35 * 10 delay:0 options:animationOptions animations: ^ {
				
					backgroundView.alpha = 1;
					fullsizeArticleSnapshotHolderView.alpha = 1;
					scalingHolderView.frame = (CGRect){ CGPointZero, fullsizeArticleViewSnapshot.size };
					
				} completion: ^ (BOOL finished) {
				
					[[UIApplication sharedApplication] endIgnoringInteractionEvents];
					
					[containerView removeFromSuperview];

					if ([shownArticleVC conformsToProtocol:@protocol(WAArticleViewControllerPresenting)])
						[(id<WAArticleViewControllerPresenting>)shownArticleVC setContextControlsVisible:YES animated:NO];
					
					[shownArticleVC.view.window.layer addAnimation:((^{
						CATransition *transition = [CATransition animation];
						transition.type = kCATransitionFade;
						transition.removedOnCompletion = YES;
						transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
						transition.duration = 0.35f;
						return transition;
					})()) forKey:kCATransition];

				}];
			
			};
			
			dismissBlock = ^ {
			
				IRCATransact(^{
					
					[shownArticleVC dismissModalViewControllerAnimated:NO];
					
					[[UIApplication sharedApplication].keyWindow.layer addAnimation:((^{
						CATransition *transition = [CATransition animation];
						transition.type = kCATransitionFade;
						transition.removedOnCompletion = YES;
						transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
						transition.duration = 0.3f;
						return transition;
					})()) forKey:kCATransition];

				});
			
			};
						
			break;
			
		}

		case WAArticleContextAnimationCoverVertically: {
		
			__block UIWindow *currentKeyWindow = [UIApplication sharedApplication].keyWindow;
			__block UIWindow *containerWindow = nil;
			
			__block UIView *backgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
			backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
			backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];				
			
			__block UIView *contextView = nil;
		
			presentBlock = ^ {
			
				[enqueuedNavController setNavigationBarHidden:YES animated:NO];
				
				NSMutableArray *preconditions = [NSMutableArray array];
				NSMutableArray *animations = [NSMutableArray array];
				NSMutableArray *postconditions = [NSMutableArray array];
				
				[containingWindow.rootViewController.view addSubview:containerView];
				containerView.transform = CGAffineTransformIdentity;
				containerView.frame = containerView.superview.bounds;
				
				backgroundView.frame = containerView.bounds;
				[containerView addSubview:backgroundView];
				[preconditions irEnqueueBlock:^{
					backgroundView.alpha = 0;
				}];
				[animations irEnqueueBlock:^{
					backgroundView.alpha = 1;
				}];
				
				CGRect fromContextRect = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds));
				CGRect toContextRect = containerView.bounds;
				
				[enqueuedNavController viewWillAppear:NO];
				[containerView addSubview:(contextView = enqueuedNavController.view)];
				[enqueuedNavController viewDidAppear:NO];
				
				contextView.frame = toContextRect;
				contextView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
				[contextView layoutSubviews];
				[preconditions irEnqueueBlock:^{
					contextView.frame = fromContextRect;
				}];
				[animations irEnqueueBlock:^{
					contextView.frame = toContextRect;
				}];
				
				
				shownArticleVC.view.backgroundColor = [UIColor clearColor];
				[shownArticleVC view];
				
				if ([shownArticleVC respondsToSelector:@selector(handlePreferredInterfaceRect:)]) {
				
					__block __typeof__(enqueuedNavController) nrEnqueuedNavController = enqueuedNavController;
					__block __typeof__(containerView) nrContainerView = containerView;
				
					void (^onViewDidLoad)() = ^ {
					
						IRCATransact(^{
						
							shownArticleVC.view.backgroundColor = [UIColor clearColor];
							
							[nrContainerView layoutSubviews];
							[nrEnqueuedNavController.view layoutSubviews];
							
							CGRect contextRect = IRCGRectAlignToRect((CGRect){
								CGPointZero,
								(CGSize){
									CGRectGetWidth(nrContainerView.bounds),// - 24,
									CGRectGetHeight(nrContainerView.bounds)// - 56
								}
							}, nrContainerView.bounds, irBottom, YES);
							
							[shownArticleVC handlePreferredInterfaceRect:contextRect];
							
							__block void (^poke)(UIView *) = ^ (UIView *aView) {
							
								[aView layoutSubviews];
								
								for (UIView *aSubview in aView.subviews)
									poke(aSubview);
								
							};
							
							poke(shownArticleVC.view);
						
						});							
					
					};
					
					if ([shownArticleVC respondsToSelector:@selector(setOnViewDidLoad:)])
						[shownArticleVC performSelector:@selector(setOnViewDidLoad:) withObject:(id)onViewDidLoad];
					
					if ([shownArticleVC isViewLoaded])
						onViewDidLoad();
					
				}
				
				if ([shownArticleVC respondsToSelector:@selector(setOnPullTop:)]) {
					
					[shownArticleVC performSelector:@selector(setOnPullTop:) withObject:(id)(^ (UIScrollView *aSV){
					
						[aSV setContentOffset:aSV.contentOffset animated:NO];
						[nrSelf dismissArticleContextViewController:shownArticleVC];
						
					})];
					
				}
				
				if ([shownArticleVC respondsToSelector:@selector(setHeaderView:)]) {
				
					[shownArticleVC performSelector:@selector(setHeaderView:) withObject:((^ {
					
						UIView *enclosingView = [[[UIView alloc] initWithFrame:(CGRect){ CGPointZero, (CGSize){ 64, 64 }}] autorelease];
						UIView *topBackgroundView = WAStandardArticleStackCellCenterBackgroundView();
						topBackgroundView.frame = enclosingView.bounds;
						topBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
						[enclosingView addSubview:topBackgroundView];
						
						WAButton *closeButton = [WAButton buttonWithType:UIButtonTypeCustom];
						[closeButton setImage:[UIImage imageNamed:@"WACornerCloseButton"] forState:UIControlStateNormal];
						[closeButton setImage:[UIImage imageNamed:@"WACornerCloseButtonActive"] forState:UIControlStateHighlighted];
						[closeButton setImage:[UIImage imageNamed:@"WACornerCloseButtonActive"] forState:UIControlStateSelected];
						closeButton.frame = enclosingView.bounds;
						closeButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
						[enclosingView addSubview:closeButton];
						
						closeButton.action = ^ {
						
							[nrSelf dismissArticleContextViewController:shownArticleVC];
						
						};

						return enclosingView;
													
					})())];
				
				}
				
				[preconditions irEnqueueBlock:^{
					[containerView.superview bringSubviewToFront:containerView];
				}];
				
				[preconditions irExecuteAllObjectsAsBlocks];
				[UIView animateWithDuration:0.5f delay:0 options:0 animations:^{
					
					[animations irExecuteAllObjectsAsBlocks];
					
				} completion: ^ (BOOL finished) {
					
					[postconditions irExecuteAllObjectsAsBlocks];
					[[UIApplication sharedApplication] endIgnoringInteractionEvents];
					
					[CATransaction begin];
					
					[[containerView retain] autorelease];
					[containerView removeFromSuperview];
					
					[enqueuedNavController viewWillDisappear:NO];
					[enqueuedNavController.view removeFromSuperview];
					[enqueuedNavController viewDidDisappear:NO];
					
					UIScreen *usedScreen = [UIApplication sharedApplication].keyWindow.screen;
					if (!usedScreen)
						usedScreen = [UIScreen mainScreen];
				
					__block WAGestureWindow *usedWindow = [[[WAGestureWindow alloc] initWithFrame:usedScreen.bounds] autorelease];
					usedWindow.backgroundColor = backgroundView.backgroundColor;
					usedWindow.opaque = NO;
					usedWindow.rootViewController = enqueuedNavController;
					
					usedWindow.onTap = ^ {
						
						[nrSelf dismissArticleContextViewController:shownArticleVC];
						usedWindow.onTap = nil;
						
					};
					
					usedWindow.onGestureRecognizeShouldReceiveTouch = ^ (UIGestureRecognizer *recognizer, UITouch *touch) {
					
						if (shownArticleVC.modalViewController)
							return NO;
						
						UINavigationController *navC = shownArticleVC.navigationController;
						
						if (navC) {
						
							if (navC.modalViewController)
								return NO;
						
							if (!navC.navigationBarHidden)
							if (CGRectContainsPoint(navC.navigationBar.bounds, [touch locationInView:navC.navigationBar]))
								return NO;
							
							if (!navC.toolbarHidden)
							if (CGRectContainsPoint(navC.toolbar.bounds, [touch locationInView:navC.toolbar]))
								return NO;
						
						}
						
						//		if ([shownArticleVC.navigationController.viewControllers containsObject:shownArticleVC])
						//		if (shownArticleVC.navigationController.topViewController != shownArticleVC)
						//			return NO;
					
						CGPoint locationInShownArticleVC = [touch locationInView:shownArticleVC.view];
						
						if ([shownArticleVC respondsToSelector:@selector(isPointInsideInterfaceRect:)])
							return (BOOL)![shownArticleVC isPointInsideInterfaceRect:locationInShownArticleVC];
						
						return NO;
					
					};
					
					[usedWindow makeKeyAndVisible];
					
					[CATransaction commit];
					
					containerWindow = usedWindow;
					[containerWindow retain]; //	Keep it

				}];
			
			};
			
			dismissBlock = ^ {
			
				UIView *rootView = containerWindow.rootViewController.view;
				NSParameterAssert(rootView);
				
				UIViewAnimationOptions animationOptions = UIViewAnimationOptionCurveEaseInOut;
				
				[UIView animateWithDuration:0.35 delay:0 options:animationOptions animations:^{
				
					rootView.frame = [rootView.superview convertRect:CGRectOffset(rootView.bounds, 0, CGRectGetHeight(rootView.bounds)) fromView:rootView];
					containerWindow.backgroundColor = nil;
					
				} completion:^(BOOL finished) {
				
					@autoreleasepool {
							
						containerWindow.rootViewController = nil;
						
					}
				
					containerWindow.hidden = YES;
					
					[containerWindow resignKeyWindow];
					[containerWindow autorelease];
					
					//	Potentially smoofy
					
					NSArray *allCurrentWindows = [UIApplication sharedApplication].windows;
					__block BOOL hasFoundCapturedKeyWindow = NO;
					
					[allCurrentWindows enumerateObjectsUsingBlock: ^ (UIWindow *aWindow, NSUInteger idx, BOOL *stop) {
					
						if (aWindow == currentKeyWindow) {
							[aWindow makeKeyAndVisible];
							hasFoundCapturedKeyWindow = YES;
							*stop = YES;
							return;
						}
						
						if (!hasFoundCapturedKeyWindow)
						if (idx == ([allCurrentWindows count] - 1))
							[[allCurrentWindows objectAtIndex:0] becomeKeyWindow];
						
					}];
					
				}];
			
			};
		
			break;
			
		}

		default: {
			NSParameterAssert(NO);
			break;
		}
		
	}

	[self setDismissBlock:dismissBlock forArticleContextViewController:shownArticleVC];
	
	presentBlock();

	return shownArticleVC;
	
}

- (void) dismissArticleContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller {

	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	(([self dismissBlockForArticleContextViewController:controller])());
	[self setDismissBlock:nil forArticleContextViewController:controller];
	
	[[UIApplication sharedApplication] endIgnoringInteractionEvents];

}

- (UIViewController<WAArticleViewControllerPresenting> *) newContextViewControllerForArticle:(NSURL *)articleURI {

	__block __typeof__(self) nrSelf = self;
	__block UIViewController<WAArticleViewControllerPresenting> *returnedVC = nil;

	#if USES_PAGINATED_CONTEXT
		
		returnedVC = nrSelf.paginatedArticlesViewController;
		
		((WAPaginatedArticlesViewController *)returnedVC).context = [NSDictionary dictionaryWithObjectsAndKeys:
			articleURI, @"lastVisitedObjectURI",
		nil];

	#else
	
		WAArticleViewControllerPresentationStyle style = WAFullFrameArticleStyleFromDiscreteStyle([WAArticleViewController suggestedDiscreteStyleForArticle:(WAArticle *)[self.managedObjectContext irManagedObjectForURI:articleURI]]);

		returnedVC = [WAArticleViewController controllerForArticle:articleURI usingPresentationStyle:style];
		
		((WAArticleViewController *)returnedVC).onPresentingViewController = ^ (void(^action)(UIViewController <WAArticleViewControllerPresenting> *parentViewController)) {
			if ([returnedVC.navigationController conformsToProtocol:@protocol(WAArticleViewControllerPresenting)]) {
				action((UIViewController <WAArticleViewControllerPresenting> *)returnedVC.navigationController);
			} else {
				action(nrSelf);
			}
		};
		
	#endif
		
	returnedVC.navigationItem.hidesBackButton = NO;
	returnedVC.navigationItem.leftBarButtonItem = WABackBarButtonItem(nil, @"Back", ^ {

		[nrSelf dismissArticleContextViewController:returnedVC];

	});

	return [returnedVC retain];

}

- (UINavigationController *) wrappingNavigationControllerForContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller {
	
	WANavigationController *returnedNavC = nil;
	
	if ([controller isKindOfClass:[WAArticleViewController class]]) {
		
		returnedNavC = [(WAArticleViewController *)controller wrappingNavController];
		
	} else {

		returnedNavC = [[[WAFauxRootNavigationController alloc] initWithRootViewController:controller] autorelease];
		
	}
	
	returnedNavC.onViewDidLoad = ^ (WANavigationController *self) {
		((WANavigationBar *)self.navigationBar).customBackgroundView = [WANavigationBar defaultPatternBackgroundView];
	};
	
	if ([returnedNavC isViewLoaded])
	if (returnedNavC.onViewDidLoad)
		returnedNavC.onViewDidLoad(returnedNavC);
	
	return returnedNavC;

}

@end


@implementation WADiscretePaginatedArticlesViewController (ContextPresenting_Private)

NSString * const kWADiscretePaginatedArticlesViewController_ContextPresenting_Private_DismissBlock = @"WADiscretePaginatedArticlesViewController_ContextPresenting_Private_DismissBlock";

- (void(^)(void)) dismissBlockForArticleContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller {

	return objc_getAssociatedObject(controller, &kWADiscretePaginatedArticlesViewController_ContextPresenting_Private_DismissBlock);

}

- (void) setDismissBlock:(void(^)(void))aBlock forArticleContextViewController:(UIViewController<WAArticleViewControllerPresenting> *)controller {

	if (aBlock == [self dismissBlockForArticleContextViewController:controller])
		return;

	objc_setAssociatedObject(controller, &kWADiscretePaginatedArticlesViewController_ContextPresenting_Private_DismissBlock, aBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);

}

@end
