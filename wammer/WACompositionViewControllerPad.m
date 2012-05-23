//
//  WACompositionViewControllerPad.m
//  wammer
//
//  Created by Evadne Wu on 2/20/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WACompositionViewControllerPad.h"
#import "UIKit+IRAdditions.h"
#import "WAPreviewBadge.h"
#import "WADataStore.h"
#import "WACompositionViewPhotoCell.h"

@interface WACompositionViewControllerPad () <AQGridViewDelegate, AQGridViewDataSource>

@property (nonatomic, readwrite, retain) UIPopoverController *imagePickerPopover;
@property (nonatomic, readwrite, retain) UIButton *imagePickerPopoverPresentingSender;

@property (nonatomic, readwrite, retain) WAPreviewBadge *previewBadge;
@property (nonatomic, readwrite, retain) UIButton *previewBadgeButton;

- (void) adjustPhotos;

@end


@implementation WACompositionViewControllerPad
@synthesize photosView, noPhotoReminderView, toolbar, noPhotoReminderViewElements, previewBadge, previewBadgeButton;
@synthesize imagePickerPopover, imagePickerPopoverPresentingSender;

- (id) init {

	return [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];

}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	
	[self.contentTextView becomeFirstResponder];

}

- (IBAction) handlePreviewBadgeTap:(id)sender {

	if (!self.previewBadge.preview)
		return;
		
	WAPreview *removedPreview = self.previewBadge.preview;
	
	[[[IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:[IRAction actionWithTitle:NSLocalizedString(@"COMPOSITION_REMOVE_CURRENT_PREVIEW", nil) block: ^ {
	
		self.article.previews = [self.article.previews objectsPassingTest: ^ (id obj, BOOL *stop) {
			return (BOOL)![obj isEqual:removedPreview];
		}];
		
	}] otherActions:nil] singleUseActionSheet] showFromRect:self.previewBadge.bounds inView:self.previewBadge animated:NO];

}

- (IBAction) handleCameraItemTap:(UIButton *)sender {

	[self handleImageAttachmentInsertionRequestWithSender:sender];

}

- (void) presentImagePickerController:(IRImagePickerController *)controller sender:(UIButton *)sender animated:(BOOL)animated {

	@try {
	
		self.imagePickerPopover.contentViewController = controller;
	
		if (!self.imagePickerPopover)
			self.imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:controller];
					
		if (!self.imagePickerPopoverPresentingSender)
			self.imagePickerPopoverPresentingSender = sender;
	
		[self.imagePickerPopover presentPopoverFromRect:sender.bounds inView:sender permittedArrowDirections:UIPopoverArrowDirectionDown animated:NO];
				
	} @catch (NSException *exception) {

		[[[UIAlertView alloc] initWithTitle:@"Error Presenting Image Picker" message:@"There was an error presenting the image picker." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
	
	}

}

- (void) dismissImagePickerController:(IRImagePickerController *)controller animated:(BOOL)animated {

	self.imagePickerPopoverPresentingSender = nil;

	[self.imagePickerPopover dismissPopoverAnimated:YES];

}

- (void) presentCameraCapturePickerController:(IRImagePickerController *)controller sender:(id)sender animated:(BOOL)animated {

	__block __typeof__(self) nrSelf = self;
	__block __typeof__(controller) nrController = controller;
	
	controller.showsCameraControls = NO;
	controller.onViewDidAppear = ^ (BOOL animated) {
		
		nrController.showsCameraControls = YES;
		nrController.view.frame = [nrController.view.window convertRect:[nrController.view.window.screen applicationFrame] fromWindow:nil];
		
	};
	
	void (^animation)() = ^ {

		CATransition *pushTransition = [CATransition animation];
		pushTransition.type = kCATransitionMoveIn;
		pushTransition.duration = 0.3;
		pushTransition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		pushTransition.subtype = ((NSString * []){
			[UIInterfaceOrientationPortrait] = kCATransitionFromTop,
			[UIInterfaceOrientationPortraitUpsideDown] = kCATransitionFromBottom,
			[UIInterfaceOrientationLandscapeLeft] = kCATransitionFromRight,
			[UIInterfaceOrientationLandscapeRight] = kCATransitionFromLeft
		})[[UIApplication sharedApplication].statusBarOrientation];
					
    [[UIApplication sharedApplication] irBeginIgnoringStatusBarAppearanceRequests];
          
		[nrSelf presentModalViewController:controller animated:NO];
		
		[[UIApplication sharedApplication].keyWindow.layer addAnimation:pushTransition forKey:kCATransition];
		
	};
			
	UIView *firstResponder = [nrSelf.view irFirstResponderInView];

	if (firstResponder) {
	
		[firstResponder resignFirstResponder];
		double delayInSeconds = 0.15;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), animation);
		
	} else {
	
		animation();
		
	}

}

- (void) dismissCameraCapturePickerController:(IRImagePickerController *)controller animated:(BOOL)animated {

  [CATransaction begin];
  
  CATransition *popTransition = [CATransition animation];
	popTransition.type = kCATransitionReveal;
	popTransition.duration = 0.3;
	popTransition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	popTransition.subtype = ((NSString * []){
		[UIInterfaceOrientationPortrait] = kCATransitionFromBottom,
		[UIInterfaceOrientationPortraitUpsideDown] = kCATransitionFromTop,
		[UIInterfaceOrientationLandscapeLeft] = kCATransitionFromLeft,
		[UIInterfaceOrientationLandscapeRight] = kCATransitionFromRight,
	})[[UIApplication sharedApplication].statusBarOrientation];
	
	[controller dismissModalViewControllerAnimated:NO];
	
  [[UIApplication sharedApplication] irEndIgnoringStatusBarAppearanceRequests];

  ((^{
    [UIView setAnimationsEnabled:NO];
    NSObject *viewControllerClass = (NSObject *)[UIViewController class];
    if ([viewControllerClass respondsToSelector:@selector(attemptRotationToDeviceOrientation)]) {
      [viewControllerClass performSelector:@selector(attemptRotationToDeviceOrientation)];
    }
    [UIView setAnimationsEnabled:YES];
  })());

	[[UIApplication sharedApplication].keyWindow.layer addAnimation:popTransition forKey:kCATransition];
	
  [CATransaction commit];
    
}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternWoodTexture"]];
	
	UIView *photosViewWrapper = [[UIView alloc] initWithFrame:self.photosView.frame];
	photosViewWrapper.autoresizingMask = self.photosView.autoresizingMask;
	photosViewWrapper.clipsToBounds = NO;
	[self.photosView.superview addSubview:photosViewWrapper];
	[photosViewWrapper addSubview:self.photosView];
	
	self.photosView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.photosView.frame = self.photosView.superview.bounds;
	self.photosView.layoutDirection = AQGridViewLayoutDirectionHorizontal;
	self.photosView.backgroundColor = nil;
	self.photosView.opaque = NO;
	self.photosView.bounces = YES;
	self.photosView.clipsToBounds = NO;
	self.photosView.alwaysBounceHorizontal = YES;
	self.photosView.alwaysBounceVertical = NO;
	self.photosView.directionalLockEnabled = YES;
	self.photosView.contentSizeGrowsToFillBounds = NO;
	self.photosView.showsVerticalScrollIndicator = NO;
	self.photosView.showsHorizontalScrollIndicator = NO;
	self.photosView.leftContentInset = 56.0f;
		
	CAGradientLayer *rightGradientMask = [CAGradientLayer layer];
	rightGradientMask.startPoint = irUnitPointForAnchor(irLeft, YES);
	rightGradientMask.endPoint = irUnitPointForAnchor(irRight, YES);
	rightGradientMask.colors = [NSArray arrayWithObjects:
		(id)[UIColor colorWithRed:1 green:1 blue:1 alpha:1].CGColor,
		(id)[UIColor colorWithRed:0 green:0 blue:0 alpha:0].CGColor,
	nil];
	rightGradientMask.locations = [NSArray arrayWithObjects:
		[NSNumber numberWithFloat:1-(20.0f / CGRectGetWidth(self.photosView.frame))],
		[NSNumber numberWithFloat:1],
	nil];
	photosViewWrapper.layer.mask = rightGradientMask;
	photosViewWrapper.layer.mask.anchorPoint = irUnitPointForAnchor(irTopLeft, YES);
	photosViewWrapper.layer.mask.bounds = UIEdgeInsetsInsetRect(photosViewWrapper.bounds, (UIEdgeInsets){ -32, 0, 0, 0 });
	photosViewWrapper.layer.mask.position = (CGPoint){
		photosViewWrapper.layer.mask.position.x,
		photosViewWrapper.layer.mask.position.y - 32
	};
	
	self.noPhotoReminderView.frame = UIEdgeInsetsInsetRect(self.photosView.frame, (UIEdgeInsets){ 0, 0, 0, -32 });
	self.noPhotoReminderView.autoresizingMask = self.photosView.autoresizingMask;
	
	for (UIView *aSubview in self.noPhotoReminderViewElements) {
		if ([aSubview isKindOfClass:[UIView class]]) {
			aSubview.layer.shadowColor = [UIColor colorWithWhite:1 alpha:1].CGColor;
			aSubview.layer.shadowOffset = (CGSize){ 0, 1 };
			aSubview.layer.shadowRadius = 0;
			aSubview.layer.shadowOpacity = .5;
		}
	}
	
	[self.photosView.superview insertSubview:self.noPhotoReminderView aboveSubview:self.photosView];
	
	//	UIView *photosBackgroundView = [[[UIView alloc] initWithFrame:self.photosView.frame] autorelease];
	//	photosBackgroundView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPhotoQueueBackground"]];
	//	photosBackgroundView.autoresizingMask = self.photosView.autoresizingMask;
	//	photosBackgroundView.frame = UIEdgeInsetsInsetRect(photosBackgroundView.frame, (UIEdgeInsets){ -20, -20, -40, -20 });
	//	photosBackgroundView.layer.masksToBounds = YES;
	//	photosBackgroundView.userInteractionEnabled = NO;
	//	[self.view insertSubview:photosBackgroundView atIndex:0];
	
	//	IRConcaveView *photosConcaveEdgeView = [[[IRConcaveView alloc] initWithFrame:self.photosView.frame] autorelease];
	//	photosConcaveEdgeView.autoresizingMask = self.photosView.autoresizingMask;
	//	photosConcaveEdgeView.backgroundColor = nil;
	//	photosConcaveEdgeView.frame = UIEdgeInsetsInsetRect(photosConcaveEdgeView.frame, (UIEdgeInsets){ -20, -20, -40, -20 });
	//	photosConcaveEdgeView.innerShadow = [IRShadow shadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.5f] offset:(CGSize){ 0.0f, -1.0f } spread:3.0f];
	//	photosConcaveEdgeView.layer.masksToBounds = YES;
	//	photosConcaveEdgeView.userInteractionEnabled = NO;
	//	[self.view addSubview:photosConcaveEdgeView];
	
	self.photosView.contentInset = (UIEdgeInsets){ 0, 20, 0, 20 };
	objc_setAssociatedObject(self.photosView, @"defaultInsets", [NSValue valueWithUIEdgeInsets:self.photosView.contentInset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	self.photosView.frame = UIEdgeInsetsInsetRect(self.photosView.frame, (UIEdgeInsets){ 0, -20, 0, -20 });
	
	UIView *contextTextShadowView = [[UIView alloc] initWithFrame:self.contentTextView.frame];
	contextTextShadowView.autoresizingMask = self.contentTextView.autoresizingMask;
	contextTextShadowView.layer.shadowOffset = (CGSize){ 0, 2 };
	contextTextShadowView.layer.shadowRadius = 2;
	contextTextShadowView.layer.shadowOpacity = 0.25;
	contextTextShadowView.layer.cornerRadius = 4;
	contextTextShadowView.layer.backgroundColor = [UIColor blackColor].CGColor;
	[self.contentTextView.superview insertSubview:contextTextShadowView belowSubview:self.contentTextView];
	
	IRConcaveView *contentTextBackgroundView = [[IRConcaveView alloc] initWithFrame:self.contentTextView.frame];
	contentTextBackgroundView.autoresizingMask = self.contentTextView.autoresizingMask;
	contentTextBackgroundView.innerShadow = [IRShadow shadowWithColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.25] offset:(CGSize){ 0, 2 } spread:4];
	contentTextBackgroundView.userInteractionEnabled = NO;
	contentTextBackgroundView.backgroundColor = [UIColor colorWithWhite:0.97f alpha:1];
	contentTextBackgroundView.layer.cornerRadius = 4;
	contentTextBackgroundView.layer.masksToBounds = YES;
	[self.contentTextView.superview insertSubview:contentTextBackgroundView belowSubview:self.contentTextView];
	
	self.previewBadge = [[WAPreviewBadge alloc] initWithFrame:photosViewWrapper.frame];
	self.previewBadge.autoresizingMask = photosViewWrapper.autoresizingMask;
	self.previewBadge.frame = UIEdgeInsetsInsetRect(self.previewBadge.frame, (UIEdgeInsets){ 0, 8, 8, -48 });
	self.previewBadge.alpha = 0;
	self.previewBadge.userInteractionEnabled = NO;
	[photosViewWrapper.superview addSubview:self.previewBadge];
	
	//	Makeshift implementation for preview removal
	
	self.previewBadgeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.previewBadgeButton.frame = self.previewBadge.frame;
	self.previewBadgeButton.autoresizingMask = self.previewBadge.autoresizingMask;
	self.previewBadgeButton.hidden = YES;
	[self.previewBadgeButton addTarget:self action:@selector(handlePreviewBadgeTap:) forControlEvents:UIControlEventTouchUpInside];
	[self.previewBadge.superview addSubview:self.previewBadgeButton];
  
  [self.noPhotoReminderViewElements enumerateObjectsUsingBlock: ^ (UILabel *aLabel, NSUInteger idx, BOOL *stop) {
  
    aLabel.text = NSLocalizedString(aLabel.text, nil);
    
  }];
	
	[self handleFilesChangeKind:NSKeyValueChangeSetting oldValue:nil newValue:self.article.files indices:nil isPrior:YES];
	[self handlePreviewsChangeKind:NSKeyValueChangeSetting oldValue:nil newValue:self.article.previews indices:nil isPrior:YES];
	
}

- (void) viewDidUnload {

	self.imagePickerPopover = nil;
	
	self.photosView = nil;
	self.noPhotoReminderView = nil;
	self.toolbar = nil;
	self.noPhotoReminderViewElements = nil;
	
	self.previewBadge = nil;
	self.previewBadgeButton = nil;

	[super viewDidUnload];

}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {

	if (scrollView != self.photosView)
		return;
	
	self.photosView.contentOffset = (CGPoint){
		self.photosView.contentOffset.x,
		0
	};

}

- (CGSize) portraitGridCellSizeForGridView: (AQGridView *) gridView {

	return (CGSize){ 144, CGRectGetHeight(gridView.frame) - 1 };

}

- (NSUInteger) numberOfItemsInGridView:(AQGridView *)gridView {

	return [self.article.files count];

}

- (void) gridViewDidEndUpdateAnimation:(AQGridView *)gridView {

	[UIView animateWithDuration:0.3 animations:^{
		
		[self adjustPhotos];

	}];

}

- (AQGridViewCell *) gridView:(AQGridView *)gridView cellForItemAtIndex:(NSUInteger)index {

	static NSString * const identifier = @"photoCell";
	
	WACompositionViewPhotoCell *cell = (WACompositionViewPhotoCell *)[gridView dequeueReusableCellWithIdentifier:identifier];
	WAFile *representedFile = [self.article.files objectAtIndex:index];
	
	NSParameterAssert(representedFile);
	NSParameterAssert(representedFile.article);
	
	if (!cell) {
	
		cell = [WACompositionViewPhotoCell cellRepresentingFile:representedFile reuseIdentifier:identifier];
		cell.frame = (CGRect){
			CGPointZero,
			[self portraitGridCellSizeForGridView:gridView]
		};
				
	}
	
	cell.representedFile = representedFile;
//	cell.image = [representedFile smallestPresentableImage];
	cell.clipsToBounds = NO;
	cell.selectionStyle = AQGridViewCellSelectionStyleNone;
	
	NSParameterAssert(cell.representedFile);
	NSParameterAssert(cell.representedFile.article);
	
	__weak WACompositionViewPhotoCell *wCell = cell;
	
	cell.onRemove = ^ {

		if (!wCell)
			return;
	
		WAFile *file = wCell.representedFile;
		WAArticle *article = file.article;
		
		[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
		[[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents) withObject:nil afterDelay:0.5f];
		
		[article willChangeValueForKey:@"files"];
		[[article mutableOrderedSetValueForKey:@"files"] removeObject:file];
		[article didChangeValueForKey:@"files"];
			
	};
	
	return cell;

}

- (void) handleFilesChangeKind:(NSKeyValueChange)kind oldValue:(id)oldValue newValue:(id)newValue indices:(NSIndexSet *)indices isPrior:(BOOL)isPrior {

	if (![self isViewLoaded])
		return;
	
	self.noPhotoReminderView.hidden = !![self.article.files count];
	
	if ([oldValue isEqual:newValue])
	if ([self.photosView numberOfItems] == [newValue count])
		return;
	
	NSParameterAssert(![self.photosView isAnimatingUpdates]);
	
	switch (kind) {
	
		case NSKeyValueChangeSetting: {
			
			[self.photosView reloadData];
			[self adjustPhotos];
			
			break;
			
		}
		
		case NSKeyValueChangeInsertion: {
			
			[self.photosView beginUpdates];
			[self.photosView insertItemsAtIndices:indices withAnimation:AQGridViewItemAnimationFade];
			[self.photosView endUpdates];
			
			break;
			
		}
		
		case NSKeyValueChangeRemoval: {
		
			[self.photosView beginUpdates];
			[self.photosView deleteItemsAtIndices:indices withAnimation:AQGridViewItemAnimationFade];
			[self.photosView endUpdates];

			break;
			
		}
		
		case NSKeyValueChangeReplacement: {
		
			[self.photosView beginUpdates];
			[self.photosView reloadItemsAtIndices:indices withAnimation:AQGridViewItemAnimationFade];
			[self.photosView endUpdates];
			
			break;
			
		}

	}

}

- (void) handlePreviewsChangeKind:(NSKeyValueChange)kind oldValue:(id)oldValue newValue:(id)newValue indices:(NSIndexSet *)indices isPrior:(BOOL)isPrior {

	WAPreview *usedPreview = [self.article.previews anyObject];
	
	BOOL badgeShown = (BOOL)!!usedPreview;	

	if (usedPreview)
		self.previewBadge.preview = usedPreview;
	
	[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowAnimatedContent|UIViewAnimationOptionAllowUserInteraction animations:^{

		self.previewBadge.alpha = badgeShown ? 1 : 0;
		self.previewBadgeButton.hidden = badgeShown ? NO : YES;
		
		self.photosView.alpha = badgeShown ? 0 : 1;
		
	} completion: ^ (BOOL finished) {
	
		self.previewBadge.preview = usedPreview;
		
	}];

}

- (void) adjustPhotos {

	UIEdgeInsets insets = [objc_getAssociatedObject(self.photosView, @"defaultInsets") UIEdgeInsetsValue];
	CGFloat addedPadding = roundf(0.5f * MAX(0, CGRectGetWidth(self.photosView.frame) - insets.left - insets.right - self.photosView.contentSize.width));
	insets.left += addedPadding;
	
	self.photosView.contentInset = insets;

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	[self adjustPhotos];

}

@end
