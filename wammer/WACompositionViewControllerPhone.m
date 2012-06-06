//
//  WACompositionViewControllerPhone.m
//  wammer
//
//  Created by Evadne Wu on 2/20/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WACompositionViewControllerPhone.h"
#import "UIKit+IRAdditions.h"

#import "WAPreviewInspectionViewController.h"
#import "WADataStore.h"

#import "WAArticleAttachmentActivityView.h"
#import "IRTextAttributor.h"

#import "Foundation+IRAdditions.h"

#import "WAAttachedMediaListViewController.h"
#import "WANavigationController.h"

#import "IRLifetimeHelper.h"

#import "WADefines.h"


@interface WACompositionViewController (PhoneSubclassKnowledge) <IRTextAttributorDelegate>

@end


@interface WACompositionViewControllerPhone () <WAPreviewInspectionViewControllerDelegate>

@property (nonatomic, readwrite, retain) IRActionSheetController *actionSheetController;
@property (nonatomic, readwrite, retain) WAArticleAttachmentActivityView *articleAttachmentActivityView;

- (WAAttachedMediaListViewController *) newMediaListViewController NS_RETURNS_RETAINED;
- (void) presentMediaListViewController:(WAAttachedMediaListViewController *)controller sender:(id)sender animated:(BOOL)animated;
- (void) dismissMediaListViewController:(WAAttachedMediaListViewController *)controller animated:(BOOL)animated;

- (void) handleArticleAttachmentActivityViewTap:(WAArticleAttachmentActivityView *)view;

- (void) updateArticleAttachmentActivityView;

@property (nonatomic, readwrite, copy) void (^onDismissImagePickerControllerAnimated)(IRImagePickerController *controller, BOOL animated, BOOL *overrideDefault);
@property (nonatomic, readwrite, copy) void (^onDismissCameraCaptureControllerAnimated)(IRImagePickerController *controller, BOOL animated, BOOL *overrideDefault);

@end

@implementation WACompositionViewControllerPhone
@synthesize toolbar, actionSheetController, articleAttachmentActivityView;
@synthesize onDismissImagePickerControllerAnimated, onDismissCameraCaptureControllerAnimated;

- (id) init {

	return [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	self.contentTextView.backgroundColor = nil;
	self.contentTextView.contentInset = (UIEdgeInsets){ 4, 0, 64, 0 };
	self.contentTextView.font = [UIFont systemFontOfSize:18.0f];
		
	self.toolbar.items = [NSArray arrayWithObjects:
		[IRBarButtonItem itemWithCustomView:self.articleAttachmentActivityView],
	nil];
	
	self.toolbar.backgroundColor = nil;
	self.toolbar.opaque = NO;
	
	self.containerView.backgroundColor = [UIColor clearColor];
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WACompositionBackgroundPattern"]];
	
	UIImageView *toolbarBackground = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"WACompositionAttachmentsBarBackground"]];
	toolbarBackground.frame = self.toolbar.frame;
	toolbarBackground.autoresizingMask = self.toolbar.autoresizingMask;
	[self.toolbar.superview insertSubview:toolbarBackground belowSubview:self.toolbar];
	
	
	
}

- (void) viewDidUnload {

	self.actionSheetController = nil;
	self.toolbar = nil;
	
	[super viewDidUnload];

}

- (void) viewWillAppear:(BOOL)animated {
	
	[super viewWillAppear:animated];
	
	[self.contentTextView becomeFirstResponder];

}

- (void) adjustContainerViewWithInterfaceBounds:(CGRect)newBounds {

	if (![self isViewLoaded])
		return;
		
	[super adjustContainerViewWithInterfaceBounds:newBounds];
	
	if (CGRectEqualToRect(self.view.bounds, [self.view convertRect:self.containerView.bounds fromView:self.containerView])) {
	
		self.contentTextView.scrollIndicatorInsets = (UIEdgeInsets){ 0, 0, 6, 0};
	
	} else {
	
		self.contentTextView.scrollIndicatorInsets = UIEdgeInsetsZero;
	
	}

}

- (WAArticleAttachmentActivityView *) articleAttachmentActivityView {

	if (articleAttachmentActivityView)
		return articleAttachmentActivityView;
	
	__weak WACompositionViewControllerPhone *nrSelf = self;
	
	articleAttachmentActivityView = [[WAArticleAttachmentActivityView alloc] initWithFrame:(CGRect){ CGPointZero, (CGSize){ 96, 32 }}];
	articleAttachmentActivityView.onTap = ^ {
	
		[nrSelf handleArticleAttachmentActivityViewTap:nrSelf.articleAttachmentActivityView];
	
	};
	
	[self updateArticleAttachmentActivityView];
	
	return articleAttachmentActivityView;

}

- (void) updateArticleAttachmentActivityView {

	if (![self isViewLoaded])
		return;
		
	WAArticleAttachmentActivityView *activityView = self.articleAttachmentActivityView;

	if ([self.textAttributor.queue.operations count]) {
		
		activityView.style = WAArticleAttachmentActivityViewSpinnerStyle;
		
	} else if ([self.article.previews count]) {
		
		activityView.style = WAArticleAttachmentActivityViewLinkStyle;
		[activityView setTitle:NSLocalizedString(@"WEB_PREVIEW", @"preview button in composition view") forStyle:WAArticleAttachmentActivityViewLinkStyle];
		[activityView setAccessibilityLabel:NSLocalizedString(@"ACCESS_PREVIEW", @"accessibility label for webpage preview in composition view")];
		
	} else if ([self.article.files count] == 1) {
		
		activityView.style = WAArticleAttachmentActivityViewAttachmentsStyle;
		[activityView setTitle:[NSString stringWithFormat:NSLocalizedString(@"COMPOSITION_ONE_PHOTO_BUTTON_CAPTION_FORMAT", @"add photo button in composition view"), 1] forStyle:WAArticleAttachmentActivityViewAttachmentsStyle];
		[activityView setAccessibilityLabel:NSLocalizedString(@"ACCESS_ADD_PHOTO", @"accessibility label for adding photos in composition view")];
		
	} else if ([self.article.files count] > 1) {
		
		activityView.style = WAArticleAttachmentActivityViewAttachmentsStyle;
		[activityView setTitle:[NSString stringWithFormat:NSLocalizedString(@"COMPOSITION_MANY_PHOTOS_BUTTON_CAPTION_FORMAT", @"add photo button in composition view"), [self.article.files count]] forStyle:WAArticleAttachmentActivityViewAttachmentsStyle];
		[activityView setAccessibilityLabel:NSLocalizedString(@"ACCESS_ADD_PHOTO", @"accessibility label for adding photos in composition view")];
		
	} else {
		
		activityView.style = WAArticleAttachmentActivityViewDefaultStyle;
		[activityView setTitle:NSLocalizedString(@"ACTION_ADD", @"add photo button in composition view") forStyle:WAArticleAttachmentActivityViewDefaultStyle];
		[activityView setAccessibilityLabel:NSLocalizedString(@"ACCESS_ADD_PHOTO", @"accessibility label for adding photos in composition view")];
		
	}

	[activityView sizeToFit];

}

- (IRTextAttributor *) textAttributor {

	__weak IRTextAttributor *returnedAttributor = [super textAttributor];
	
	if (!objc_getAssociatedObject(returnedAttributor, _cmd))
		return returnedAttributor;
	
	NSOperationQueue *queue = returnedAttributor.queue;
	__weak WACompositionViewControllerPhone *wSelf = self;
	id observer = [queue irAddObserverBlock:^(id inOldValue, id inNewValue, NSKeyValueChange changeKind) {
	
		dispatch_async(dispatch_get_main_queue(), ^ {
			
			[wSelf updateArticleAttachmentActivityView];
			
		});
		
	} forKeyPath:@"operations" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
	
	[returnedAttributor irPerformOnDeallocation:^{

	 [queue irRemoveObservingsHelper:observer];
	 
	}];

	NSCParameterAssert(!objc_getAssociatedObject(returnedAttributor, _cmd));
	objc_setAssociatedObject(returnedAttributor, _cmd, (id)kCFBooleanTrue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	NSCParameterAssert(objc_getAssociatedObject(returnedAttributor, _cmd));
	
	return returnedAttributor;

}

- (void) textAttributor:(IRTextAttributor *)attributor willUpdateAttributedString:(NSAttributedString *)attributedString withToken:(NSString *)aToken range:(NSRange)tokenRange attribute:(id)newAttribute {

	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		[super textAttributor:attributor willUpdateAttributedString:attributedString withToken:aToken range:tokenRange attribute:newAttribute];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self updateArticleAttachmentActivityView];

	});
	
}

- (void) textAttributor:(IRTextAttributor *)attributor didUpdateAttributedString:(NSAttributedString *)attributedString withToken:(NSString *)aToken range:(NSRange)tokenRange attribute:(id)newAttribute {

	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		[super textAttributor:attributor didUpdateAttributedString:attributedString withToken:aToken range:tokenRange attribute:newAttribute];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self updateArticleAttachmentActivityView];

	});

}

- (void) handleFilesChangeKind:(NSKeyValueChange)kind oldValue:(id)oldValue newValue:(id)newValue indices:(NSIndexSet *)indices isPrior:(BOOL)isPrior {

	[super handleFilesChangeKind:kind oldValue:oldValue newValue:newValue indices:indices isPrior:isPrior];

	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self updateArticleAttachmentActivityView];

	});
	
}

- (void) handlePreviewsChangeKind:(NSKeyValueChange)kind oldValue:(id)oldValue newValue:(id)newValue indices:(NSIndexSet *)indices isPrior:(BOOL)isPrior {

	[super handlePreviewsChangeKind:kind oldValue:oldValue newValue:newValue indices:indices isPrior:isPrior];

	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self updateArticleAttachmentActivityView];

	});

}

- (void) handleArticleAttachmentActivityViewTap:(WAArticleAttachmentActivityView *)view {

	switch (view.style) {
	
		case WAArticleAttachmentActivityViewAttachmentsStyle: {
		
			if ([self.article.files count]) {
			
				[self presentMediaListViewController:[self newMediaListViewController] sender:view animated:YES];
			
			} else {
			
				[self handleImageAttachmentInsertionRequestWithSender:view];
				
				__weak WACompositionViewControllerPhone *nrSelf = self;
				
				NSOrderedSet *capturedFiles = [self.article.files copy];
				BOOL (^filesChanged)(void) = ^ {
					return (BOOL)![nrSelf.article.files isEqual:capturedFiles];
				};
				
				CALayer *crossfadeLayer = nrSelf.view.window.layer;
				
				void (^crossfade)(void(^)(void)) = ^ (void(^aBlock)(void)) {
				
					CATransition *transition = [CATransition animation];
					transition.type = kCATransitionFade;
					transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
					transition.duration = 0.3;
					transition.removedOnCompletion = YES;
					transition.fillMode = kCAFillModeForwards;
					
					[CATransaction begin];
					[CATransaction setDisableActions:YES];
					
					aBlock();
					
					[crossfadeLayer addAnimation:transition forKey:kCATransition];
					
					[CATransaction commit];
					
				};
				
				
				self.onDismissCameraCaptureControllerAnimated = ^ (IRImagePickerController *controller, BOOL animated, BOOL *overrideDefault) {
				
					nrSelf.onDismissCameraCaptureControllerAnimated = nil;
					
					if (!filesChanged())
						return;
					
					*overrideDefault = YES;
					
					crossfade(^ {
					
						[nrSelf dismissCameraCapturePickerController:controller animated:NO];
						[nrSelf presentMediaListViewController:[nrSelf newMediaListViewController] sender:nil animated:NO];
					
					});
									
				};
				
				self.onDismissImagePickerControllerAnimated = ^ (IRImagePickerController *controller, BOOL animated, BOOL *overrideDefault) {
				
					nrSelf.onDismissImagePickerControllerAnimated = nil;

					if (!filesChanged())
						return;
					
					*overrideDefault = YES;
				
					crossfade(^ {

						[nrSelf dismissImagePickerController:controller animated:NO];
						[nrSelf presentMediaListViewController:[nrSelf newMediaListViewController] sender:nil animated:NO];
					
					});
				
				};
				
			}
										 
			break;
			
		}
	
		case WAArticleAttachmentActivityViewLinkStyle: {
			
			NSParameterAssert([self.article.previews count]);
			
			WAPreview *inspectedPreview = [self.article.previews anyObject];
			
			TFLog(@"Inspecting preview %@", inspectedPreview);
			[self inspectPreview:inspectedPreview];			
			
			break;
			
		}

		case WAArticleAttachmentActivityViewSpinnerStyle: {
			break;
		}

	}

}

- (WAAttachedMediaListViewController *) newMediaListViewController {

	[self.article.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:self.article] error:nil];
	
	__weak WACompositionViewControllerPhone *wSelf = self;
	__block WAAttachedMediaListViewController *mediaList = [[WAAttachedMediaListViewController alloc] initWithArticleURI:[self.article.objectID URIRepresentation] usingContext:self.managedObjectContext completion: ^ {
	
		[wSelf dismissMediaListViewController:mediaList animated:YES];
		mediaList = nil;
		
	}];
	
	mediaList.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemAdd wiredAction:^(IRBarButtonItem *senderItem) {
	
		[wSelf handleImageAttachmentInsertionRequestWithSender:senderItem];
		
	}];
	
	mediaList.onViewDidLoad = ^ {
		[mediaList.tableView setEditing:YES animated:NO];
	};
	
	if ([mediaList isViewLoaded])
		mediaList.onViewDidLoad();
	
	return mediaList;

}

- (void) presentMediaListViewController:(WAAttachedMediaListViewController *)controller sender:(id)sender animated:(BOOL)animated {

	WANavigationController *navC = [[WANavigationController alloc] initWithRootViewController:[self newMediaListViewController]];
	
	[self presentModalViewController:navC animated:animated];

}

- (void) dismissMediaListViewController:(WAAttachedMediaListViewController *)controller animated:(BOOL)animated {

	[controller dismissModalViewControllerAnimated:animated];

}

- (void) dismissImagePickerController:(IRImagePickerController *)controller animated:(BOOL)animated {

	BOOL shouldOverride = NO;
	
	if (self.onDismissImagePickerControllerAnimated)
		self.onDismissImagePickerControllerAnimated(controller, animated, &shouldOverride);
	
	if (!shouldOverride)
		[super dismissImagePickerController:controller animated:animated];

}

- (void) dismissCameraCapturePickerController:(IRImagePickerController *)controller animated:(BOOL)animated {

	BOOL shouldOverride = NO;
	
	if (self.onDismissCameraCaptureControllerAnimated)
		self.onDismissCameraCaptureControllerAnimated(controller, animated, &shouldOverride);
	
	if (!shouldOverride)
		[super dismissCameraCapturePickerController:controller animated:animated];

}

- (void) inspectPreview:(WAPreview *)aPreview {
	
	NSCParameterAssert(aPreview.managedObjectContext == self.managedObjectContext);
	
	self.actionSheetController = nil;
	
	WAPreviewInspectionViewController *previewVC = [WAPreviewInspectionViewController controllerWithPreview:aPreview];
	previewVC.delegate = self;
	
	UINavigationController *navC = [previewVC wrappingNavController];
	[self presentModalViewController:navC animated:YES];

}

- (void) previewInspectionViewControllerDidFinish:(WAPreviewInspectionViewController *)inspector {

	[inspector dismissModalViewControllerAnimated:YES];

}

- (void) previewInspectionViewControllerDidRemove:(WAPreviewInspectionViewController *)inspector {

	BOOL const showsDeleteConfirmation = NO;
	
	if (showsDeleteConfirmation) {

		__weak WACompositionViewControllerPhone *wSelf = self;
		
		if (self.actionSheetController.managedActionSheet.visible)
			return;
		
		if (!self.actionSheetController) {
		
			WAPreview *removedPreview = [self.article.previews anyObject];
			NSParameterAssert([[inspector.preview objectID] isEqual:[removedPreview objectID]]);
				
			IRAction *discardAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_DISCARD", nil) block:^{
			
				[removedPreview.article removePreviewsObject:removedPreview];
				[inspector dismissModalViewControllerAnimated:YES];

				wSelf.actionSheetController = nil;
				
			}];
			
			self.actionSheetController = [IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:discardAction otherActions:nil];
			
		}

		[self.actionSheetController.managedActionSheet showInView:inspector.view];
	
	} else {
	
		WAPreview *removedPreview = [self.article.previews anyObject];
		NSParameterAssert([[inspector.preview objectID] isEqual:[removedPreview objectID]]);
		
		[removedPreview.article removePreviewsObject:removedPreview];
		[inspector dismissModalViewControllerAnimated:YES];
	
	}
	
}

@end
