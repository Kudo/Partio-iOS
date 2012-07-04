//
//  WAStackedArticleViewController.m
//  wammer
//
//  Created by Evadne Wu on 12/22/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAStackedArticleViewController.h"

#import "Foundation+IRAdditions.h"
#import "UIKit+IRAdditions.h"

#import "WADefines.h"

#import "WARemoteInterface.h"
#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WAOverlayBezel.h"
#import "WAArticleTextStackElement.h"
#import "WAArticleTextStackCell.h"
#import "WAArticleTextEmphasisLabel.h"

#import "WACompositionViewController.h"
#import "WAArticleCommentsViewController.h"

#import "WAStackedArticleViewController+Favorite.h"

#import "WAArticleDateItem.h"


@interface WAStackedArticleViewController () <WAArticleCommentsViewControllerDelegate, WAArticleTextStackElementDelegate>

@property (nonatomic, readwrite, retain) WAArticleTextStackCell *topCell;
@property (nonatomic, readwrite, retain) WAArticleTextStackElement *textStackCell;
@property (nonatomic, readwrite, assign) BOOL foldsTextStackCell;	//	Default is YES

@property (nonatomic, readwrite, retain) WAArticleTextEmphasisLabel *textStackCellLabel;
@property (nonatomic, readwrite, retain) WAArticleCommentsViewController *commentsVC;
@property (nonatomic, readwrite, retain) UIPopoverController *commentsPopover;

@property (nonatomic, readwrite, retain) UIView *wrapperView;

@property (nonatomic, readwrite, retain) UIView *textStackCellFoldingToggleWrapperView;
@property (nonatomic, readwrite, retain) UIButton *textStackCellFoldingToggle;

@property (nonatomic, readwrite, retain) NSArray *headerBarButtonItems;

- (void) adjustWrapperViewBoundsWithWindowInterfaceBounds:(CGRect)newInterfaceBounds animated:(BOOL)animate;

@end


@implementation WAStackedArticleViewController
@synthesize headerView;
@synthesize topCell, textStackCell, foldsTextStackCell, textStackCellLabel, commentsVC, commentsPopover, stackView, wrapperView, onViewDidLoad, onPullTop, footerCell;
@synthesize textStackCellFoldingToggleWrapperView, textStackCellFoldingToggle;
@synthesize headerBarButtonItems;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
	
	__weak WAStackedArticleViewController *wSelf = self;
	
	WAArticleDateItem *articleDateItem = [WAArticleDateItem instanceFromNib];
	
	[articleDateItem.dateLabel irBind:@"text" toObject:wSelf keyPath:@"article.presentationDate" options:[NSDictionary dictionaryWithObjectsAndKeys:
	
		[^ (NSDate *fromDate, NSDate *toDate, NSString *changeKind) {

			return [toDate description];
		
		} copy], kIRBindingsValueTransformerBlock,
	
	nil]];
	
	[articleDateItem.deviceLabel irBind:@"text" toObject:wSelf keyPath:@"article.creationDeviceName" options:[NSDictionary dictionaryWithObjectsAndKeys:
	
		[^ (NSString *fromValue, NSString *toValue, NSString *changeKind) {

			return toValue;
		
		} copy], kIRBindingsValueTransformerBlock,
	
	nil]];
	
	//	IRBarButtonItem *articleDateItem = [IRBarButtonItem itemWithCustomView:((^ {
	//					
	//		IRLabel *label = [[IRLabel alloc] initWithFrame:(CGRect){ (CGPoint){ 36, 32 }, (CGSize){ 256 , 24 } }];
	//		label.opaque = NO;
	//		label.backgroundColor = nil;
	//		
	//		__weak IRLabel *wLabel = label;
	//		[label irBind:@"attributedText" toObject:wSelf keyPath:@"article" options:[NSDictionary dictionaryWithObjectsAndKeys:
	//		
	//			[^ (id inOldValue, id inNewValue, NSString *changeKind) {
	//			
	//				NSString *relDate = [[IRRelativeDateFormatter sharedFormatter] stringFromDate:wSelf.article.creationDate];
	//				NSString *device = wSelf.article.creationDeviceName;
	//				NSString *string = [NSString stringWithFormat:@"%@ (%@)", relDate, device];
	//				
	//				UIFont * const font = [UIFont fontWithName:@"HelveticaNeue-Light" size:14.0f];
	//				UIColor * const color = [UIColor colorWithWhite:0.5 alpha:1];
	//
	//				return [wLabel attributedStringForString:string font:font color:color];
	//			
	//			} copy], kIRBindingsValueTransformerBlock,
	//		
	//		nil]];
			
	//		[wSelf irPerformOnDeallocation:^{
	//		
	//			[wLabel irUnbind:@"attributedText"];
	//			
	//		}];
	//		
	//		return label;
	//		
	//	})())];
	
	//	IRBarButtonItem *commentsItem = ((^ {
	//	
	//		IRBarButtonItem *commentsItem = [[IRBarButtonItem alloc] initWithTitle:@"Comments" style:UIBarButtonItemStyleBordered target:nil action:nil];
	//	
	//		switch ([UIDevice currentDevice].userInterfaceIdiom) {
	//		
	//			case UIUserInterfaceIdiomPad: {
	//				
	//				[commentsItem setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
	//					[UIColor colorWithWhite:.5 alpha:1], UITextAttributeTextColor,
	//					[UIColor clearColor], UITextAttributeTextShadowColor,
	//					[NSValue valueWithUIOffset:UIOffsetZero], UITextAttributeTextShadowOffset,
	//				nil] forState:UIControlStateNormal];
	//				
	//				[commentsItem setBackgroundImage:[[UIImage imageNamed:@"WAGrayTranslucentBarButton"] resizableImageWithCapInsets:(UIEdgeInsets){ 4, 4, 5, 4 }] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
	//				
	//				[commentsItem setBackgroundImage:[[UIImage imageNamed:@"WAGrayTranslucentBarButtonPressed"] resizableImageWithCapInsets:(UIEdgeInsets){ 4, 4, 5, 4 }] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
	//				
	//				break;
	//				
	//			}
	//			
	//			case UIUserInterfaceIdiomPhone: {
	//			
	//				break;
	//			
	//			}
	//		
	//		}
	//		
	//		__weak IRBarButtonItem *wCommentsItem = commentsItem;
	//		
	//		commentsItem.block = ^ {
	//		
	//			[wSelf presentCommentsViewController:[wSelf newArticleCommentsController] sender:wCommentsItem];
	//			
	//		};
	//		
	//		[commentsItem irBind:@"title" toObject:self keyPath:@"article.comments.@count" options:[NSDictionary dictionaryWithObjectsAndKeys:
	//		
	//			[^ (id inOldValue, id inNewValue, NSString *changeKind) {
	//			
	//				NSUInteger numberOfComments = [inNewValue isKindOfClass:[NSNumber class]] ? [(NSNumber *)inNewValue unsignedIntegerValue] : 0;
	//				
	//				return [NSString stringWithFormat:(numberOfComments == 0) ?
	//					NSLocalizedString(@"COMMENTS_COUNT_ZERO_FORMAT_STRING", @"“%@ Comment” or “No Comment”") :
	//						(numberOfComments == 1) ?
	//							NSLocalizedString(@"COMMENTS_COUNT_ONE_FORMAT_STRING", @"“%@ Comment”") :
	//								NSLocalizedString(@"COMMENTS_COUNT_MANY_FORMAT_STRING", @"“%@ Comments”"), inNewValue];
	//			
	//			} copy], kIRBindingsValueTransformerBlock,
	//		
	//		nil]];
	//		
	//		[wSelf irPerformOnDeallocation:^{
	//		
	//			[wCommentsItem irUnbind:@"title"];
	//			
	//		}];
	//		
	//		return commentsItem;
	//	
	//	})());
	
	UIBarButtonItem *favoriteToggleItem = [self newFavoriteToggleItem];
	
	switch ([UIDevice currentDevice].userInterfaceIdiom) {
		
		case UIUserInterfaceIdiomPad: {
			
			NSMutableArray *barButtonItems = [NSMutableArray arrayWithObjects:
				[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemFlexibleSpace wiredAction:nil],
				articleDateItem,
			nil];
			
			if (WAAdvancedFeaturesEnabled())
				[barButtonItems addObject:[self editButtonItem]];
			
			[barButtonItems addObjectsFromArray:[NSArray arrayWithObjects:
				favoriteToggleItem,
				//	commentsItem,
			nil]];
			
			self.headerBarButtonItems = barButtonItems;
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWindowInterfaceBoundsDidChange:) name:IRWindowInterfaceBoundsDidChangeNotification object:nil];
			
			break;
			
		}
		
		case UIUserInterfaceIdiomPhone: {
			
			self.headerBarButtonItems = [NSArray arrayWithObjects:
				[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
				[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
				articleDateItem,
			nil];

			NSMutableArray *barButtonItems = [NSMutableArray arrayWithObjects:
				favoriteToggleItem,
				//	commentsItem,
			nil];
			
			if (WAAdvancedFeaturesEnabled())
				[barButtonItems addObject:[self editButtonItem]];
			
			self.navigationItem.rightBarButtonItems = barButtonItems;
			
			break;
			
		}
	
	}
		
	self.foldsTextStackCell = [self enablesTextStackElementFolding];
		
	return self;

}

- (void) dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[commentsPopover dismissPopoverAnimated:NO];

}

- (WAArticleTextStackElement *) textStackCell {

	if (textStackCell)
		return textStackCell;
		
	textStackCell = [WAArticleTextStackElement cellFromNib];
	
	[textStackCell.textStackCellLabel irBind:@"text" toObject:self.article keyPath:@"text" options:[NSDictionary dictionaryWithObjectsAndKeys:
		(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
	nil]];
	
	textStackCell.delegate = self;

	return textStackCell;

}

- (void) textStackElement:(WAArticleTextStackElement *)element didRequestContentSizeToggle:(id)sender {

	self.foldsTextStackCell = !self.foldsTextStackCell;
	[self.stackView setNeedsLayout];
	
	CGSize oldContentSize = self.stackView.contentSize;
	
	[UIView animateWithDuration:0.3 animations:^{
		
		[self.stackView layoutSubviews];
		
		CGSize newContentSize = self.stackView.contentSize;
		
		if (oldContentSize.height > newContentSize.height)
			[self.stackView setContentOffset:CGPointZero];
		
	}];

}

- (UIView *) textStackCellFoldingToggleWrapperView {

	if (textStackCellFoldingToggleWrapperView)
		return textStackCellFoldingToggleWrapperView;
		
	textStackCellFoldingToggleWrapperView = [[IRView alloc] initWithFrame:(CGRect){ CGPointZero, (CGSize){ 320, 0 }}];
	[textStackCellFoldingToggleWrapperView addSubview:self.textStackCellFoldingToggle];
	
	__weak UIView *wWrapper = textStackCellFoldingToggleWrapperView;
	__weak UIButton *wToggle = self.textStackCellFoldingToggle;
	
	[(IRView *)textStackCellFoldingToggleWrapperView setOnHitTestWithEvent: ^ (CGPoint point, UIEvent *event, UIView *superAnswer) {
		return [wToggle hitTest:[wToggle convertPoint:point fromView:wWrapper] withEvent:event];
	}];

	self.textStackCellFoldingToggle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin;	
	self.textStackCellFoldingToggle.frame = CGRectOffset(IRGravitize(textStackCellFoldingToggleWrapperView.bounds, self.textStackCellFoldingToggle.bounds.size, kCAGravityTopRight), -8, 24);
	
	return textStackCellFoldingToggleWrapperView;

}

- (UIButton *) textStackCellFoldingToggle {

	if (!textStackCellFoldingToggle) {
		
		textStackCellFoldingToggle = [UIButton buttonWithType:UIButtonTypeCustom];
		[textStackCellFoldingToggle addTarget:self action:@selector(handleTextStackCellFoldingToggleTap:) forControlEvents:UIControlEventTouchUpInside];
		
		[self.textStackCellFoldingToggle setContentEdgeInsets:(UIEdgeInsets){ 0, 16, 0, 16 }];
		[self.textStackCellFoldingToggle setTitleEdgeInsets:(UIEdgeInsets){ -2, -4, 2, 4 }];
		[self.textStackCellFoldingToggle setImageEdgeInsets:(UIEdgeInsets){ -2, -4, 2, 4 }];
		[self.textStackCellFoldingToggle setTitleColor:[UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateNormal];
		[self.textStackCellFoldingToggle setAdjustsImageWhenHighlighted:NO];
		[self.textStackCellFoldingToggle.titleLabel setFont:[UIFont boldSystemFontOfSize:14.0]];
		
		UIImage *normalImage = [[UIImage imageNamed:@"WAArticleStackElementDropdownTag"] resizableImageWithCapInsets:(UIEdgeInsets){ 0, 8, 8, 8 }];
		UIImage *pressedImage = [[UIImage imageNamed:@"WAArticleStackElementDropdownTagPressed"] resizableImageWithCapInsets:(UIEdgeInsets){ 0, 8, 8, 8 }];
		UIImage *disabledImage = [[UIImage imageNamed:@"WAArticleStackElementDropdownTagDisabled"] resizableImageWithCapInsets:(UIEdgeInsets){ 0, 8, 8, 8 }];
		
		[self.textStackCellFoldingToggle setBackgroundImage:normalImage forState:UIControlStateNormal];
		[self.textStackCellFoldingToggle setBackgroundImage:pressedImage forState:UIControlStateHighlighted];
		[self.textStackCellFoldingToggle setBackgroundImage:disabledImage forState:UIControlStateDisabled];
		
		[self configureTextStackCellFoldingToggle];
	
	}
	
	return textStackCellFoldingToggle;

}

- (void) configureTextStackCellFoldingToggle {

	if (self.foldsTextStackCell) {
	
		NSString *title = NSLocalizedString(@"TEXT_ELEMENT_TOGGLE_MORE_TITLE", @"Title on the text stack more / less toggle button for “More”");

		[self.textStackCellFoldingToggle setTitle:title forState:UIControlStateNormal];
		[self.textStackCellFoldingToggle setImage:[[UIImage imageNamed:@"WADownDoubleArrowGlyph"] irSolidImageWithFillColor:[UIColor colorWithWhite:0.5 alpha:1] shadow:nil] forState:UIControlStateNormal];
	
	} else {
	
		NSString *title = NSLocalizedString(@"TEXT_ELEMENT_TOGGLE_LESS_TITLE", @"Title on the text stack more / less toggle button for “Less”");
		
		[self.textStackCellFoldingToggle setTitle:title forState:UIControlStateNormal];
		[self.textStackCellFoldingToggle setImage:[[UIImage imageNamed:@"WAUpDoubleArrowGlyph"] irSolidImageWithFillColor:[UIColor colorWithWhite:0.5 alpha:1] shadow:nil] forState:UIControlStateNormal];
	
	}
	
	CGSize fittingSize = [self.textStackCellFoldingToggle sizeThatFits:self.textStackCellFoldingToggle.bounds.size];
	fittingSize.height = MAX(44, fittingSize.height);
	
	self.textStackCellFoldingToggle.bounds = (CGRect){ CGPointZero, fittingSize };
	[self.textStackCellFoldingToggle.superview layoutSubviews];

}

- (void) handleTextStackCellFoldingToggleTap:(id)sender {

	self.foldsTextStackCell = !self.foldsTextStackCell;

	[self configureTextStackCellFoldingToggle];	
	
	BOOL hecklesContentOffset = self.foldsTextStackCell;
	
	CGFloat oldContentHeightLeft = self.stackView.contentSize.height - self.stackView.contentOffset.y;
	
	[self.stackView layoutSubviews];
	
	if (hecklesContentOffset) {

		[self.stackView setContentOffset:(CGPoint){
			self.stackView.contentOffset.x,
			MAX(0, self.stackView.contentSize.height - oldContentHeightLeft)
		} animated:NO];
	
	}
	
	if (self.foldsTextStackCell)
		[self.stackView setContentOffset:CGPointZero animated:YES];

}

- (WAArticleCommentsViewController *) newArticleCommentsController {

	return self.commentsVC;

}

- (void) presentCommentsViewController:(WAArticleCommentsViewController *)controller sender:(id)sender {

	switch ([UIDevice currentDevice].userInterfaceIdiom) {
	
		case UIUserInterfaceIdiomPad: {
		
			NSParameterAssert(self.commentsPopover);
		
			if ([self.commentsPopover isPopoverVisible]) {
				
				//	Toggle
				
				[self.commentsPopover dismissPopoverAnimated:NO];
				
				return;
				
			}
			
			if ([sender isKindOfClass:[UIBarButtonItem class]]) {
			
				[self.commentsPopover presentPopoverFromBarButtonItem:((UIBarButtonItem *)sender) permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
			
			} else if ([sender isKindOfClass:[UIView class]]) {
			
				[self.commentsPopover presentPopoverFromRect:((UIView *)sender).bounds inView:((UIView *)sender) permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
			
			}
		
			break;
		
		}
		
		case UIUserInterfaceIdiomPhone: {
		
			[self.navigationController pushViewController:controller animated:YES];
		
			break;
		
		}
	
	}

}

- (UIPopoverController *) commentsPopover {

	if (commentsPopover)
		return commentsPopover;
	
	commentsPopover = [[UIPopoverController alloc] initWithContentViewController:self.commentsVC];
	self.commentsVC.adjustsContainerViewOnInterfaceBoundsChange = NO;

	return commentsPopover;

}

- (WAArticleCommentsViewController *) commentsVC {

	if (commentsVC)
		return commentsVC;
		
	commentsVC = [WAArticleCommentsViewController controllerRepresentingArticle:[[self.article objectID] URIRepresentation]];
	commentsVC.delegate = self;
	
	return commentsVC;
	
}

- (BOOL) stackView:(IRStackView *)aStackView shouldStretchElement:(UIView *)anElement {

	return NO;

}

- (CGSize) sizeThatFitsElement:(UIView *)anElement inStackView:(IRStackView *)aStackView {

	CGSize elementAnswer = [anElement sizeThatFits:(CGSize){
		CGRectGetWidth(aStackView.bounds),
		0
	}];
	
	CGFloat preferredHeight = roundf(elementAnswer.height);
	
	if ((anElement == self.commentsVC.view) || [self.commentsVC.view isDescendantOfView:anElement])
		preferredHeight = MAX(144, preferredHeight);
	
	if (foldsTextStackCell)
	if ((anElement == self.textStackCell) || [self.textStackCell isDescendantOfView:anElement])
		preferredHeight = MIN(144, preferredHeight);
	
	CGSize answer = (CGSize){
		CGRectGetWidth(aStackView.bounds),
		preferredHeight
	};
	
	return answer;

}

- (void) articleCommentsViewController:(WAArticleCommentsViewController *)controller wantsState:(WAArticleCommentsViewControllerState)aState onFulfillment:(void (^)(void))aCompletionBlock {

	if (aCompletionBlock)
		aCompletionBlock();

}

- (BOOL) articleCommentsViewController:(WAArticleCommentsViewController *)controller canSendComment:(NSString *)commentText {

	return !![[commentText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length];

}

- (void) articleCommentsViewController:(WAArticleCommentsViewController *)controller didFinishComposingComment:(NSString *)commentText {

	[[WADataStore defaultStore] addComment:commentText onArticle:[[self.article objectID] URIRepresentation] onSuccess:nil onFailure:nil];
	

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

- (void) adjustWrapperViewBoundsWithWindowInterfaceBounds:(CGRect)newInterfaceBounds animated:(BOOL)animate {

	if (!self.view.window)
		return;

	CGRect ownRectInWindow = [self.view.window convertRect:self.view.bounds fromView:self.view];
	CGRect intersection = CGRectIntersection(ownRectInWindow, newInterfaceBounds);
	
	if (CGRectEqualToRect(CGRectNull, intersection) || CGRectIsInfinite(intersection))
		return;
	
	intersection = [self.view.window convertRect:intersection toView:self.wrapperView.superview];
	
	UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;
	
	[UIView animateWithDuration:(animate ? 0.3 : 0) delay:0 options:animationOptions animations:^{
		
		self.wrapperView.frame = intersection;
		[self.stackView layoutSubviews];
		
	} completion:^(BOOL finished) {
		
		//	NSLog(@"STACK VIEW now %@, super view %@", self.stackView, self.stackView.superview);
		
	}];

}

- (void) viewDidLoad {

	[super viewDidLoad];
		
	__weak WAStackedArticleViewController *wSelf = self;
	
	self.wrapperView = [[UIView alloc] initWithFrame:self.stackView.frame];
	[self.stackView.superview addSubview:self.wrapperView];
	[self.wrapperView addSubview:self.stackView];
	self.stackView.frame = self.wrapperView.bounds;
	self.wrapperView.frame = self.view.bounds;
	self.wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	
	self.stackView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
	
	self.stackView.alwaysBounceHorizontal = NO;
	self.stackView.bounces = NO;
	self.stackView.alwaysBounceVertical = NO;
	
	self.stackView.showsHorizontalScrollIndicator = NO;	
	self.stackView.showsVerticalScrollIndicator = NO;
	
	self.stackView.delaysContentTouches = NO;
	self.stackView.canCancelContentTouches = YES;
	self.stackView.onTouchesShouldBeginWithEventInContentView = ^ (NSSet *touches, UIEvent *event, UIView *contentView) {
	
		UIView *currentWrapperView = [wSelf scrollableStackElementWrapper];
		UIView *currentWrappedView = [wSelf scrollableStackElement];
		
		if (contentView != currentWrappedView)
		if (![contentView isDescendantOfView:currentWrappedView])
			return [contentView isKindOfClass:[UIControl class]];
			
		IRStackView *sv = wSelf.stackView;
		UIView *svContainer = wSelf.stackView.superview;
		
		if (CGRectContainsRect([svContainer convertRect:sv.bounds fromView:sv], [svContainer convertRect:currentWrapperView.bounds fromView:currentWrapperView]))
			return YES;
		
		return NO;
	
	};
	
	self.stackView.onTouchesShouldCancelInContentView = ^ (UIView *view) {
	
		return NO;
	
	};
	
	self.stackView.onGestureRecognizerShouldRecognizeSimultaneouslyWithGestureRecognizer = ^ (UIGestureRecognizer *aGR, UIGestureRecognizer *otherGR, BOOL superAnswer) {
	
		if ((otherGR.view == [wSelf scrollableStackElementWrapper]) || [otherGR.view isDescendantOfView:[wSelf scrollableStackElementWrapper]])
			return NO;
		
		return YES;
	
	};
	
	self.stackView.panGestureRecognizer.delaysTouchesBegan = NO;
	self.stackView.panGestureRecognizer.delaysTouchesEnded = NO;
	
	if (headerView) {
	
		NSMutableArray *stackElements = [self.stackView mutableStackElements];
	
		if ([stackElements containsObject:headerView])
			return;
		
		[stackElements insertObject:headerView atIndex:0];
		
		UIView *enclosingView = [[UIView alloc] initWithFrame:(CGRect){ 0, 0, CGRectGetWidth(headerView.bounds), 0 }];
		UIView *topBackgroundView = WAStandardArticleStackCellTopBackgroundView();
		[enclosingView addSubview:topBackgroundView];
		topBackgroundView.frame = IRGravitize(enclosingView.bounds, headerView.bounds.size, kCAGravityBottom);
		topBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
		
		[stackElements insertObject:enclosingView atIndex:1];
	
	} else {
	
		switch ([UIDevice currentDevice].userInterfaceIdiom) {
		
			case UIUserInterfaceIdiomPad: {
			
				WAArticleTextStackCell *topTextStackCell = [WAArticleTextStackCell cellFromNib];
				topTextStackCell.backgroundView = WAStandardArticleStackCellTopBackgroundView();
				topTextStackCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(topCell.bounds), 48 }};
				
				self.headerView = topTextStackCell;
				
				break;
			
			}
			
			case UIUserInterfaceIdiomPhone: {
			
				WAArticleTextStackCell *topTextStackCell = [WAArticleTextStackCell cellFromNib];
				topTextStackCell.backgroundView = WAStandardArticleStackCellTopBackgroundView();
				topTextStackCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(topCell.bounds), 24 }};
				
				self.headerView = topTextStackCell;
				
				break;
			
			}
		
		}
		
	}
	
	BOOL hasText = [self.article.text length];
	BOOL showsComments = NO;
	
	if (hasText) {
		
		[self.stackView addStackElementsObject:self.textStackCell];
		
		CGFloat currentTextStackCellHeight = [self sizeThatFitsElement:self.textStackCell inStackView:self.stackView].height;
		CGFloat idealTextStackCellHeight = [self.textStackCell sizeThatFits:(CGSize){ CGRectGetWidth(self.stackView.bounds), 0 }].height;
		
		if ([self enablesTextStackElementFolding] && (idealTextStackCellHeight > currentTextStackCellHeight))
			[self.stackView addStackElementsObject:self.textStackCellFoldingToggleWrapperView];
		
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

	self.stackView.onDidLayoutSubviews = ^ {
		
		[wSelf.textStackCellFoldingToggleWrapperView.superview bringSubviewToFront:wSelf.textStackCellFoldingToggleWrapperView];
		
		switch ([UIDevice currentDevice].userInterfaceIdiom) {
		
			case UIUserInterfaceIdiomPad: {
			
				[wSelf.headerView.superview bringSubviewToFront:wSelf.headerView];
				
				wSelf.headerView.center = (CGPoint){
					wSelf.headerView.center.x,
					MAX(0, wSelf.stackView.contentOffset.y) + 0.5 * CGRectGetHeight(wSelf.headerView.bounds)
				};
				
				break;
			
			}
			
			case UIUserInterfaceIdiomPhone: {
			
				break;
			
			}
		
		}
		
	};

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
	
	headerView = newHeaderView;
	
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
	footerShadow.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[footerCell addSubview:footerShadow];
	
	return footerCell;

}

- (void) viewDidUnload {

	self.stackView = nil;
	self.commentsVC = nil;
	self.commentsPopover = nil;
	
	self.textStackCellFoldingToggleWrapperView = nil;
	self.textStackCellFoldingToggle = nil;
	
	[super viewDidUnload];
	
}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	[self.commentsVC viewWillAppear:animated];
	
	[self.stackView layoutSubviews];

}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	[self.commentsVC viewDidAppear:animated];
	
	if (![self.toolbarItems count]) {

		if (!self.navigationController.toolbarHidden)
			[self.navigationController setToolbarHidden:YES animated:YES];
	
	} else {
	
		if (self.navigationController.toolbarHidden)
			[self.navigationController setToolbarHidden:NO animated:YES];
	
	}
	
}

- (void) viewWillDisappear:(BOOL)animated {

	[super viewWillDisappear:animated];
	[self.commentsVC viewWillDisappear:animated];

}

- (void) viewDidDisappear:(BOOL)animated {

	[super viewDidDisappear:animated];
	[self.commentsVC viewDidDisappear:animated];
	
}

- (void) handleWindowInterfaceBoundsDidChange:(NSNotification *)notification {

	if (![self isViewLoaded])
		return;
	
	if ([notification object] != self.view.window)
		return;
	
	[self adjustWrapperViewBoundsWithWindowInterfaceBounds:self.view.window.irInterfaceBounds animated:([[[[[notification userInfo] objectForKey:IRWindowInterfaceChangeUnderlyingKeyboardNotificationKey] userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] > 0)];

}

- (void) handlePreferredInterfaceRect:(CGRect)aRect {

	CGRect intersection = CGRectIntersection(aRect, self.stackView.superview.bounds);
	self.stackView.frame = intersection;
	self.stackView.contentInset = (UIEdgeInsets){
		CGRectGetMinY(intersection) - CGRectGetMinY(aRect),
		CGRectGetMinX(intersection) - CGRectGetMinX(aRect),
		CGRectGetMaxY(intersection) - CGRectGetMaxY(aRect),
		CGRectGetMaxX(intersection) - CGRectGetMaxX(aRect)
	};
	
}

- (BOOL) isPointInsideInterfaceRect:(CGPoint)aPoint { 

	CGRect stackViewFrame = [self.view convertRect:self.stackView.bounds fromView:self.stackView];
	
	if (self.stackView.contentOffset.y > CGRectGetMinY(stackViewFrame))
		return YES;
	
	return CGRectContainsPoint(stackViewFrame, aPoint);

}

- (void) scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {

	if (scrollView == self.stackView) {

		NSParameterAssert(scrollView == self.stackView);
		
		CGPoint contentOffset = self.stackView.contentOffset;
		CGFloat cap = -200.0f;
		
		if (contentOffset.y < cap) {
			if (self.onPullTop)
				self.onPullTop(self.stackView);
		}
	
	}
	
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {

	switch ([UIDevice currentDevice].userInterfaceIdiom) {
	
		case UIUserInterfaceIdiomPad: {

			if (scrollView == self.stackView) {
			
				IRStackView *sv = self.stackView;
				CGPoint oldSVOffset = sv.contentOffset;
				CGPoint newSVOffset = (CGPoint){
					oldSVOffset.x,
					MIN(sv.contentSize.height - CGRectGetHeight(sv.bounds), oldSVOffset.y)
				};
					
				if (!CGPointEqualToPoint(oldSVOffset, newSVOffset))
					[sv setContentOffset:newSVOffset animated:NO];
				
			}
			
			break;
		
		}
		
		case UIUserInterfaceIdiomPhone: {
		
			break;
		
		}
	
	}
	
}

- (void) scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(CGPoint *)targetContentOffset {

	if (scrollView == self.stackView) {

		CGPoint desiredTargetOffset = *targetContentOffset;
		desiredTargetOffset.y = MIN(desiredTargetOffset.y, self.stackView.contentSize.height - CGRectGetHeight(self.stackView.bounds));
		*targetContentOffset = desiredTargetOffset;
	
	}

}

- (UIView *) scrollableStackElementWrapper {

	return nil;

}

- (UIScrollView *) scrollableStackElement {

	return nil;

}

- (BOOL) enablesTextStackElementFolding {

	return NO;

}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {

	[super setEditing:editing animated:animated];
	
	__block void (^dismissBlock)(void) = nil;
	
	if (editing) {
	
		NSParameterAssert([self isViewLoaded] && self.view.window && !self.presentedViewController && (self.navigationController ? (self.navigationController.topViewController == self) : YES));
	
		[[WARemoteInterface sharedInterface] beginPostponingDataRetrievalTimerFiring];
		
		WACompositionViewController *compositionVC = [WACompositionViewController controllerWithArticle:[[self.article objectID] URIRepresentation] completion:^(NSURL *anArticleURLOrNil) {
			
			if (dismissBlock) {
				dismissBlock();
				dismissBlock = nil;
			}
			
			if (!anArticleURLOrNil)
				return;
				
			[[WADataStore defaultStore] updateArticle:anArticleURLOrNil withOptions:nil onSuccess:^{
				
				[[WARemoteInterface sharedInterface] endPostponingDataRetrievalTimerFiring];
				
			} onFailure:^(NSError *error) {
				
				[[WARemoteInterface sharedInterface] endPostponingDataRetrievalTimerFiring];
				
			}];
						
		}];
		
		UINavigationController *navC = [compositionVC wrappingNavigationController];
		navC.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentViewController:navC animated:YES completion:nil];
		
		__weak UINavigationController *wNavC = navC;
		__weak WAStackedArticleViewController *wSelf = self;
		
		dismissBlock = [^ {
			
			[wSelf setEditing:NO animated:NO];
			[wNavC dismissViewControllerAnimated:YES completion:nil];
			dismissBlock = nil;
			
		} copy];
	
	} else {
	
		//	?
	
	}

}

@end
