//
//  WAArticleViewController_Plaintext.m
//  wammer
//
//  Created by Evadne Wu on 12/19/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticleViewController_Plaintext.h"
#import "WAArticleTextStackCell.h"
#import "WAArticleTextEmphasisLabel.h"
#import "WAArticle.h"

#import "WAArticleCommentsViewController.h"

#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WAOverlayBezel.h"

#import "WADefines.h"


@interface WAArticleViewController_Plaintext () <WAArticleCommentsViewControllerDelegate>

@property (nonatomic, readwrite, retain) WAArticleTextStackCell *textStackCell;
@property (nonatomic, readwrite, retain) WAArticleTextEmphasisLabel *textStackCellLabel;
@property (nonatomic, readwrite, retain) WAArticleCommentsViewController *commentsVC;

- (void) adjustStackViewBoundsWithWindowInterfaceBounds:(CGRect)newInterfaceBounds;

@end


@implementation WAArticleViewController_Plaintext
@synthesize textStackCell, textStackCellLabel, commentsVC, stackView;

- (void) dealloc {

	[textStackCell release];
	[commentsVC release];
	[stackView release];
	[super dealloc];

}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
	
	return self;

}

- (WAArticleTextStackCell *) textStackCell {

	if (textStackCell)
		return textStackCell;
	
	textStackCell = [[WAArticleTextStackCell cellFromNib] retain];
	textStackCell.backgroundView = WAStandardArticleStackCellCenterBackgroundView();
	
	__block WAArticleTextEmphasisLabel *cellLabel = self.textStackCellLabel;
	UIEdgeInsets cellLabelInsets = (UIEdgeInsets){ 0, 40, 0, 40 }; 
	
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
		nrCommentsVC.commentsView.opaque = NO;
		nrCommentsVC.commentsView.frame = CGRectInset(nrCommentsVC.commentsView.frame, 64, 0);
		
		nrCommentsVC.compositionAccessoryView.frame = CGRectInset(nrCommentsVC.compositionAccessoryView.frame, 64, 0);
		
		WAView *compositionBackgroundView = nrCommentsVC.compositionAccessoryBackgroundView;
		for (UIView *aSubview in compositionBackgroundView.subviews)
			[aSubview removeFromSuperview];
		
		compositionBackgroundView.backgroundColor = [UIColor whiteColor];
		
		UIView *backgroundView = WAStandardArticleStackCellCenterBackgroundView();
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		backgroundView.frame = nrCommentsVC.view.bounds;
		
		[nrCommentsVC.view addSubview:backgroundView];
		[backgroundView.superview sendSubviewToBack:backgroundView]; 
		
	};
	
	return commentsVC;
	
}

- (BOOL) stackView:(WAStackView *)aStackView shouldStretchElement:(UIView *)anElement {

	if ([commentsVC isViewLoaded])
	if (anElement == commentsVC.view)
		return YES;
	
	return NO;

}

- (CGSize) sizeThatFitsElement:(UIView *)anElement inStackView:(WAStackView *)aStackView {

	CGSize elementAnswer = [anElement sizeThatFits:(CGSize){
		CGRectGetWidth(aStackView.bounds),
		0
	}];
	
	CGFloat preferredHeight = roundf(elementAnswer.height);
	
	if (anElement == self.commentsVC.view)
		preferredHeight = MIN(320, preferredHeight);
	
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

	UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;
	
	[UIView animateWithDuration:0.3 delay:0 options:animationOptions animations:^{
		
		[self.stackView layoutSubviews];
		
	} completion:nil];

}

- (void) adjustStackViewBoundsWithWindowInterfaceBounds:(CGRect)newInterfaceBounds {

	CGRect convertedRect = [self.view.window convertRect:newInterfaceBounds toView:self.view];
	CGRect intersection = CGRectIntersection(convertedRect, self.view.bounds);
	
	UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;
	
	[UIView animateWithDuration:0.3 delay:0 options:animationOptions animations:^{
		
		self.stackView.frame = intersection;
		[self.stackView layoutSubviews];
		
	} completion:nil];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	WAArticleTextStackCell *topCell = [WAArticleTextStackCell cellFromNib];
	topCell.backgroundView = WAStandardArticleStackCellTopBackgroundView();
	topCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(topCell.bounds), 48 }};

	[self.stackView addStackElementsObject:topCell];	
	[self.stackView addStackElementsObject:self.textStackCell];	
	[self.stackView addStackElementsObject:self.commentsVC.view];

	WAArticleTextStackCell *bottomCell = [WAArticleTextStackCell cellFromNib];
	bottomCell.backgroundView = WAStandardArticleStackCellBottomBackgroundView();
	bottomCell.frame = (CGRect){ CGPointZero, (CGSize){ CGRectGetWidth(bottomCell.bounds), 48 }};

	[self.stackView addStackElementsObject:bottomCell];	
	
#if 0
	
	self.stackView.layer.borderColor = [UIColor redColor].CGColor;
	self.stackView.layer.borderWidth = 1.0;	
	self.commentsVC.view.layer.borderColor = [UIColor blueColor].CGColor;
	self.commentsVC.view.layer.borderWidth = 2.0;
	
#endif
	
	self.stackView.backgroundColor = nil;
	
}

- (void) viewDidUnload {

	[super viewDidUnload];
	
	self.stackView = nil;
	
}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	[self.commentsVC viewWillAppear:animated];

}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	[self.commentsVC viewDidAppear:animated];
	
	[self.view.window addObserver:self forKeyPath:@"irInterfaceBounds" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:nil];

}

- (void) viewWillDisappear:(BOOL)animated {

	[self.view.window removeObserver:self forKeyPath:@"irInterfaceBounds"];

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
		
		[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{

			[self adjustStackViewBoundsWithWindowInterfaceBounds:[[change objectForKey:NSKeyValueChangeNewKey] CGRectValue]];
			
		} completion:nil];
	
	}

}

@end
