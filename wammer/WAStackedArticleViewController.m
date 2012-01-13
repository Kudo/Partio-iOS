//
//  WAStackedArticleViewController.m
//  wammer
//
//  Created by Evadne Wu on 12/22/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAStackedArticleViewController.h"

#import "WADefines.h"
#import "WAArticleTextStackCell.h"
#import "WAArticleTextEmphasisLabel.h"

#import "WAArticleCommentsViewController.h"

#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WAOverlayBezel.h"


@interface WAStackedArticleViewController () <WAArticleCommentsViewControllerDelegate>

@property (nonatomic, readwrite, retain) WAArticleTextStackCell *topCell;
@property (nonatomic, readwrite, retain) WAArticleTextStackCell *textStackCell;
@property (nonatomic, readwrite, retain) WAArticleTextEmphasisLabel *textStackCellLabel;
@property (nonatomic, readwrite, retain) WAArticleCommentsViewController *commentsVC;

@property (nonatomic, readwrite, retain) UIView *wrapperView;

- (void) adjustWrapperViewBoundsWithWindowInterfaceBounds:(CGRect)newInterfaceBounds;

@end


@implementation WAStackedArticleViewController
@synthesize headerView;
@synthesize topCell, textStackCell, textStackCellLabel, commentsVC, stackView, wrapperView, onViewDidLoad, onPullTop, footerCell;

- (void) dealloc {

	[headerView release];
	[topCell release];
	[textStackCell release];
	[commentsVC release];
	[stackView release];
	[wrapperView release];
	[onViewDidLoad release];
	[onPullTop release];
	[footerCell release];
	
	[super dealloc];

}

- (WAArticleTextStackCell *) textStackCell {

	if (textStackCell)
		return textStackCell;
	
	textStackCell = [[WAArticleTextStackCell cellFromNib] retain];
	textStackCell.backgroundView = WAStandardArticleStackCellCenterBackgroundView();
	
	textStackCell.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
	
	__block WAArticleTextEmphasisLabel *cellLabel = self.textStackCellLabel;
	UIEdgeInsets cellLabelInsets = (UIEdgeInsets){ 0, 24, 0, 24 };
	
	cellLabel.frame = UIEdgeInsetsInsetRect(textStackCell.contentView.bounds, cellLabelInsets);
	cellLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	[textStackCell.contentView addSubview:cellLabel];
	
	textStackCell.onSizeThatFits = ^ (CGSize proposedSize, CGSize superAnswer) {
		
		CGSize labelAnswer = [cellLabel sizeThatFits:(CGSize){
			proposedSize.width - cellLabelInsets.left - cellLabelInsets.right,
			proposedSize.height - cellLabelInsets.top - cellLabelInsets.bottom,
		}];
		
		return (CGSize){
			ceilf(labelAnswer.width + cellLabelInsets.left + cellLabelInsets.right),
			MAX(32, ceilf(labelAnswer.height + cellLabelInsets.top + cellLabelInsets.bottom))
		};
		
	};
	
	return textStackCell;

}

- (WAArticleTextEmphasisLabel *) textStackCellLabel {

	if (textStackCellLabel)
		return textStackCellLabel;
	
	textStackCellLabel = [[WAArticleTextEmphasisLabel alloc] initWithFrame:CGRectZero];
	textStackCellLabel.backgroundColor = nil;
	textStackCellLabel.opaque = NO;
	textStackCellLabel.placeholder = @"This post has no body text";
	[textStackCellLabel irBind:@"text" toObject:self.article keyPath:@"text" options:[NSDictionary dictionaryWithObjectsAndKeys:
		(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
	nil]];
	
	return textStackCellLabel;

}

- (WAArticleCommentsViewController *) commentsVC {

	if (commentsVC)
		return commentsVC;
	
	commentsVC = [[WAArticleCommentsViewController controllerRepresentingArticle:[[self.article objectID] URIRepresentation]] retain];
	__block __typeof__(commentsVC) nrCommentsVC = commentsVC;
	
	commentsVC.delegate = self;
	commentsVC.onViewDidLoad = ^ {
		
		nrCommentsVC.view.clipsToBounds = YES;
		nrCommentsVC.view.layer.shadowOpacity = 0;
		
		nrCommentsVC.commentsRevealingActionContainerView.hidden = YES;
		nrCommentsVC.commentsView.backgroundColor = nil;
		nrCommentsVC.commentsView.bounces = NO;
		nrCommentsVC.commentsView.opaque = NO;
		nrCommentsVC.commentsView.frame = CGRectInset(nrCommentsVC.commentsView.frame, 64, 0);
		
		nrCommentsVC.compositionAccessoryView.frame = CGRectInset(nrCommentsVC.compositionAccessoryView.frame, 64, 0);
		
		WAView *compositionBackgroundView = nrCommentsVC.compositionAccessoryBackgroundView;
		for (UIView *aSubview in compositionBackgroundView.subviews)
			[aSubview removeFromSuperview];
		
		compositionBackgroundView.backgroundColor = [UIColor whiteColor];
		
		UIView *backgroundView = WAStandardArticleStackCellCenterBackgroundView();
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		
		UIView *backgroundWrapperView = [[[UIView alloc] initWithFrame:nrCommentsVC.commentsView.bounds] autorelease];
		backgroundWrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		backgroundView.frame = CGRectInset(backgroundWrapperView.bounds, -64, 0);
		[backgroundWrapperView addSubview:backgroundView];
				
		nrCommentsVC.commentsView.backgroundView = backgroundWrapperView;
		nrCommentsVC.commentsView.backgroundColor = nil;
		nrCommentsVC.commentsView.opaque = NO;
		nrCommentsVC.commentsView.clipsToBounds = NO;
		
		[backgroundView.superview sendSubviewToBack:backgroundView]; 
		
	};
	
	return commentsVC;
	
}

- (BOOL) stackView:(WAStackView *)aStackView shouldStretchElement:(UIView *)anElement {

//	if ([commentsVC isViewLoaded])
//	if (anElement == commentsVC.view)
//		return YES;
//	
	return NO;

}

- (CGSize) sizeThatFitsElement:(UIView *)anElement inStackView:(WAStackView *)aStackView {

	CGSize elementAnswer = [anElement sizeThatFits:(CGSize){
		CGRectGetWidth(aStackView.bounds),
		0
	}];
	
	CGFloat preferredHeight = roundf(elementAnswer.height);
	
	if ((anElement == self.commentsVC.view) || [self.commentsVC.view isDescendantOfView:anElement])
		preferredHeight = MAX(144, preferredHeight);
	
	return (CGSize){
		CGRectGetWidth(aStackView.bounds),
		preferredHeight
	};

}

- (void) articleCommentsViewController:(WAArticleCommentsViewController *)controller wantsState:(WAArticleCommentsViewControllerState)aState onFulfillment:(void (^)(void))aCompletionBlock {

	//	Immediate fulfillment. :D
	
	if (aCompletionBlock)
		aCompletionBlock();

}

- (BOOL) articleCommentsViewController:(WAArticleCommentsViewController *)controller canSendComment:(NSString *)commentText {

	return YES;	//	?

}

- (void) articleCommentsViewController:(WAArticleCommentsViewController *)controller didFinishComposingComment:(NSString *)commentText {

	__block WAOverlayBezel *nrBezel = [WAOverlayBezel bezelWithStyle:WAActivityIndicatorBezelStyle];
	[nrBezel showWithAnimation:WAOverlayBezelAnimationFade];
	
	[[WADataStore defaultStore] addComment:commentText onArticle:[[self.article objectID] URIRepresentation] onSuccess:^{
		
		dispatch_async(dispatch_get_main_queue(), ^{
		
			[nrBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			
		});
		
	} onFailure:^{
	
		dispatch_async(dispatch_get_main_queue(), ^{
		
			[nrBezel dismissWithAnimation:WAOverlayBezelAnimationNone];		
			nrBezel = [WAOverlayBezel bezelWithStyle:WAErrorBezelStyle];
			[nrBezel showWithAnimation:WAOverlayBezelAnimationNone];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
				[nrBezel dismissWithAnimation:WAOverlayBezelAnimationFade];
			});
			
		});
		
	}];
	

}

- (void) articleCommentsViewControllerDidBeginComposition:(WAArticleCommentsViewController *)controller {

	//	Scroll to critical area
	
	[self.stackView layoutSubviews];
	[controller.view layoutSubviews];
	CGRect criticalRect = [self.stackView convertRect:[controller rectForComposition] fromView:controller.view];
	[self.stackView scrollRectToVisible:criticalRect animated:NO];
	
}

- (void) articleCommentsViewControllerDidFinishComposition:(WAArticleCommentsViewController *)controller {

	[self.stackView layoutSubviews];

}

- (void) articleCommentsViewController:(WAArticleCommentsViewController *)controller didChangeContentSize:(CGSize)newSize {

	[self.stackView setNeedsLayout];
	
	if ([self isViewLoaded] && self.view.window) {

		UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;	
		[UIView animateWithDuration:0.3 delay:0 options:animationOptions animations:^{		
		
			[self.stackView layoutSubviews];
			
		} completion:^(BOOL finished) {
			
			[self.stackView setNeedsLayout];
			
		}];
	
	}

}

- (void) adjustWrapperViewBoundsWithWindowInterfaceBounds:(CGRect)newInterfaceBounds {

	if (!self.view.window)
		return;

	CGRect ownRectInWindow = [self.view.window convertRect:self.view.bounds fromView:self.view];
	CGRect intersection = CGRectIntersection(ownRectInWindow, newInterfaceBounds);
	
	if (CGRectEqualToRect(CGRectNull, intersection) || CGRectIsInfinite(intersection))
		return;
	
	intersection = [self.view.window convertRect:intersection toView:self.wrapperView.superview];
	
	UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;
	
	[UIView animateWithDuration:0.3 delay:0 options:animationOptions animations:^{
		
		self.wrapperView.frame = intersection;
		[self.stackView layoutSubviews];
		
	} completion:^(BOOL finished) {
		
		//	NSLog(@"STACK VIEW now %@, super view %@", self.stackView, self.stackView.superview);
		
	}];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	self.wrapperView = [[[UIView alloc] initWithFrame:self.stackView.frame] autorelease];
	[self.stackView.superview addSubview:self.wrapperView];
	[self.wrapperView addSubview:self.stackView];
	self.stackView.frame = self.wrapperView.bounds;
	self.wrapperView.frame = self.view.bounds;
	self.wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.stackView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;

	self.stackView.alwaysBounceVertical = YES;
	self.stackView.showsHorizontalScrollIndicator = NO;	
	self.stackView.showsVerticalScrollIndicator = NO;
	
	if (!headerView) {
		
		WAArticleTextStackCell *topTextStackCell = [WAArticleTextStackCell cellFromNib];
		topTextStackCell.backgroundView = WAStandardArticleStackCellTopBackgroundView();
		topTextStackCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(topCell.bounds), 48 }};
		
		self.headerView = topTextStackCell;
		
	}
	
	BOOL hasText = [self.article.text length];
	BOOL showsComments = NO;
	
	if (hasText) {
		[self.stackView addStackElementsObject:self.textStackCell];
	}
	
	if (showsComments) {
		if (hasText) {
			WAArticleTextStackCell *commentsSeparatorCell = [WAArticleTextStackCell cellFromNib];
			commentsSeparatorCell.backgroundView = WAStandardArticleStackCellCenterBackgroundView();
			commentsSeparatorCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(commentsSeparatorCell.bounds), 24 }};
			[self.stackView addStackElementsObject:commentsSeparatorCell];
		}
		[self.stackView addStackElementsObject:self.commentsVC.view];
	}

	WAArticleTextStackCell *contentsSeparatorCell = [WAArticleTextStackCell cellFromNib];
	contentsSeparatorCell.backgroundView = WAStandardArticleStackCellCenterBackgroundView();
	contentsSeparatorCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(contentsSeparatorCell.bounds), 24 }};
	[self.stackView addStackElementsObject:contentsSeparatorCell];
	
#if 0
	
	self.wrapperView.layer.borderColor = [UIColor redColor].CGColor;
	self.wrapperView.layer.borderWidth = 1;
	
	self.stackView.layer.borderColor = [UIColor greenColor].CGColor;
	self.stackView.layer.borderWidth = 2;
	
	self.commentsVC.view.layer.borderColor = [UIColor blueColor].CGColor;
	self.commentsVC.view.layer.borderWidth = 2.0;
	
#endif

	[self.stackView addStackElementsObject:self.footerCell];
	
	self.stackView.backgroundColor = nil;
	self.wrapperView.backgroundColor = nil;

	if (self.onViewDidLoad)
		self.onViewDidLoad(self, self.view);
	
}

- (void) setHeaderView:(UIView *)newHeaderView {

	if (headerView == newHeaderView)
		return;
	
	NSMutableArray *allStackElements = [self.stackView mutableStackElements];
	
	if ([allStackElements containsObject:headerView]) {
		[headerView removeFromSuperview];
		[allStackElements removeObject:headerView];
	}
	
	[headerView release];
	headerView = [newHeaderView retain];
	
	if (![allStackElements containsObject:headerView]) {
		[allStackElements insertObject:headerView atIndex:0];
	}
	
	[self.stackView setNeedsLayout];

}

- (UIView *) footerCell {

	if (footerCell)
		return footerCell;
	
	WAArticleTextStackCell *footerShadow = [WAArticleTextStackCell cellFromNib];
	footerShadow.backgroundView = WAStandardArticleStackCellBottomBackgroundView();
	footerShadow.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(footerShadow.bounds), 1024 }};
	
	footerCell = [[UIView alloc] initWithFrame:(CGRect){
		CGPointZero,
		(CGSize){
			CGRectGetWidth(footerShadow.bounds),
			0
		}
	}];
	
	footerShadow.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
	[footerCell addSubview:footerShadow];
	
	return footerCell;

}

- (void) viewDidUnload {

	[super viewDidUnload];
	
	self.stackView = nil;
	
}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	[self.commentsVC viewWillAppear:animated];
	
	//	dispatch_async(dispatch_get_main_queue(), ^{
	
		[self.stackView layoutSubviews];
		
	//	});

}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	[self.commentsVC viewDidAppear:animated];
	
	[self.view.window addObserver:self forKeyPath:@"irInterfaceBounds" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:nil];
	
}

- (void) viewWillDisappear:(BOOL)animated {

	@try {
		
		[self.view.window removeObserver:self forKeyPath:@"irInterfaceBounds"];
		
	} @catch (NSException *exception) {
	
		if (![exception.name isEqual:NSRangeException])
			@throw exception;
		
	}

	[super viewWillDisappear:animated];
	[self.commentsVC viewWillDisappear:animated];

}

- (void) viewDidDisappear:(BOOL)animated {

	[super viewDidDisappear:animated];
	[self.commentsVC viewDidDisappear:animated];
	
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

	if ([self isViewLoaded])
	if (object == self.view.window)
	if ([keyPath isEqualToString:@"irInterfaceBounds"]) {
		
		[self adjustWrapperViewBoundsWithWindowInterfaceBounds:[[change objectForKey:NSKeyValueChangeNewKey] CGRectValue]];
	
	}

}

- (void) handlePreferredInterfaceRect:(CGRect)aRect {

	CGRect intersection = CGRectIntersection(aRect, self.stackView.superview.bounds);
	self.stackView.frame = intersection;
	self.stackView.contentInset = (UIEdgeInsets){
		CGRectGetMinY(intersection) - CGRectGetMinY(aRect),
		0,
		0,
		0
	};
	
}

- (BOOL) isPointInsideInterfaceRect:(CGPoint)aPoint { 

	CGRect stackViewFrame = [self.view convertRect:self.stackView.bounds fromView:self.stackView];
	
	if (self.stackView.contentOffset.y > CGRectGetMinY(stackViewFrame))
		return YES;
	
	return CGRectContainsPoint(stackViewFrame, aPoint);

}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	self.stackView.backgroundColor = [UIColor whiteColor];

}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {

	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

	self.stackView.backgroundColor = nil;

}

- (void) scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {

	if (scrollView != self.stackView)
		return;
	
	CGPoint contentOffset = self.stackView.contentOffset;
	CGFloat cap = -200.0f;
	
	if (contentOffset.y < cap) {
		if (self.onPullTop)
			self.onPullTop(self.stackView);
	}
	
}

@end
