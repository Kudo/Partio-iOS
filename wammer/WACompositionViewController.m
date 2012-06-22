//
//  WACompositionViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WACompositionViewController.h"

#import "Foundation+IRAdditions.h"
#import "UIKit+IRAdditions.h"
#import "AssetsLibrary+IRAdditions.h"

#import "IRTextAttributor.h"

#import "WADefines.h"
#import "WADataStore.h"
#import "WARemoteInterface.h"

#import "WACompositionViewPhotoCell.h"
#import "WANavigationBar.h"
#import "WANavigationController.h"
#import "WAPreviewBadge.h"


@interface WACompositionViewController () <UITextViewDelegate, IRTextAttributorDelegate>

@property (nonatomic, readwrite, copy) void (^completionBlock)(NSURL *returnedURI);
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) WAArticle *article;

@property (nonatomic, readwrite, retain) IRTextAttributor *textAttributor;
@property (nonatomic, readwrite, retain) IRActionSheetController *cancellationActionSheetController;

@end


@implementation WACompositionViewController

@synthesize managedObjectContext, article;
@synthesize containerView;
@synthesize contentTextView;
@synthesize completionBlock;
@synthesize usesTransparentBackground;
@synthesize textAttributor;
@synthesize cancellationActionSheetController;

+ (id) alloc {

	if ([self class] != [WACompositionViewController class])
		return [super alloc];

	switch ([UIDevice currentDevice].userInterfaceIdiom) {
	
		case UIUserInterfaceIdiomPad: {
			return [(Class)NSClassFromString(@"WACompositionViewControllerPad") alloc];
			break;
		}
	
		default:
		case UIUserInterfaceIdiomPhone: {
			return [(Class)NSClassFromString(@"WACompositionViewControllerPhone") alloc];
			break;
		}
		
	}

}

+ (WACompositionViewController *) controllerWithArticle:(NSURL *)anArticleURLOrNil completion:(void(^)(NSURL *anArticleURLOrNil))aBlock {

	WACompositionViewController *returnedController = [[self alloc] init];
	returnedController.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
	returnedController.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
	
	if (anArticleURLOrNil) {
		
		WAArticle *foundArticle = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:anArticleURLOrNil];
		NSAssert1(foundArticle, @"Unable to dereference WAArticle reference at %@", anArticleURLOrNil);
		returnedController.article = foundArticle;
	
	} else {
	
		WAArticle *article = [WAArticle objectInsertingIntoContext:returnedController.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
		article.dirty = (id)kCFBooleanTrue;
		article.draft = (id)kCFBooleanTrue;
		article.creationDate = [NSDate date];
		
		returnedController.article = article;
		
	}
	
	returnedController.completionBlock = aBlock;
	
	return returnedController;
	
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if (!self)
		return nil;
	
	self.title = NSLocalizedString(@"COMPOSITION_TITLE", @"Title for the composition view");
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"ACTION_DONE", @"In iPad composition view") style:UIBarButtonItemStyleDone target:self action:@selector(handleDone:)];
	
	//[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(handleDone:)];
	
	return self;

}

- (void) setArticle:(WAArticle *)newArticle {

	__weak WACompositionViewController *wSelf = self;
	
	[article irRemoveObserverBlocksForKeyPath:@"files"];
	[article irRemoveObserverBlocksForKeyPath:@"previews"];
	
	article = newArticle;
	
	[article irObserve:@"files" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
	
		[wSelf handleFilesChangeKind:kind oldValue:fromValue newValue:toValue indices:indices isPrior:isPrior];
		
	}];
	
	[article irObserve:@"previews" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
	
		CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{

			[wSelf handlePreviewsChangeKind:kind oldValue:fromValue newValue:toValue indices:indices isPrior:isPrior];
			
		});
		
	}];

}

- (void) dealloc {

	textAttributor.delegate = nil;

	[article irRemoveObserverBlocksForKeyPath:@"files"];
	[article irRemoveObserverBlocksForKeyPath:@"previews"];
	
	[self.navigationItem.rightBarButtonItem irUnbind:@"enabled"];

}

- (void) viewDidUnload {

	self.containerView = nil;
	
	self.contentTextView.delegate = nil;
	self.contentTextView = nil;
	
	self.cancellationActionSheetController = nil;
	
	[super viewDidUnload];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	if (self.usesTransparentBackground) {
		self.view.backgroundColor = nil;
		self.view.opaque = NO;
	} else {
		self.view.backgroundColor = [UIColor colorWithWhite:0.98f alpha:1.0f];
	}
	
	self.contentTextView.delegate = self;
	self.contentTextView.backgroundColor = nil;
	self.contentTextView.opaque = NO;
	self.contentTextView.contentInset = (UIEdgeInsets){ 4, 0, 0, 0 };
	self.contentTextView.bounces = YES;
	self.contentTextView.alwaysBounceVertical = YES;
	
	//	Put this last so when the article is initialized things all work
	self.contentTextView.text = self.article.text;
	[self textViewDidChange:self.contentTextView];
	
}


static NSString * const kWACompositionViewWindowInterfaceBoundsNotificationHandler = @"kWACompositionViewWindowInterfaceBoundsNotificationHandler";

- (void) viewWillAppear:(BOOL)animated {

  [super viewWillAppear:animated];
	
	__weak WACompositionViewController *wSelf = self;
  	
	id notificationObject = [[NSNotificationCenter defaultCenter] addObserverForName:IRWindowInterfaceBoundsDidChangeNotification object:self.view.window queue:nil usingBlock:^(NSNotification *aNotification) {
	
		if (!wSelf)
			return;
	
		NSDictionary *userInfo = [aNotification userInfo];
		CGRect newBounds = [[userInfo objectForKey:IRWindowInterfaceChangeNewBoundsKey] CGRectValue];
		
		NSDictionary *keyboardInfo = [[userInfo objectForKey:IRWindowInterfaceChangeUnderlyingKeyboardNotificationKey] userInfo];
		
		UIViewAnimationCurve animationCurve = [[keyboardInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntValue];
		NSTimeInterval animationDuration = [[keyboardInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
		
		UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;
		animationOptions |= ((^ {
			switch (animationCurve) {
				case UIViewAnimationCurveEaseIn: return UIViewAnimationOptionCurveEaseIn;
				case UIViewAnimationCurveEaseOut:return UIViewAnimationOptionCurveEaseOut;
				case UIViewAnimationCurveEaseInOut: return UIViewAnimationOptionCurveEaseInOut;
				case UIViewAnimationCurveLinear: return UIViewAnimationOptionCurveLinear;
				default: return UIViewAnimationOptionCurveLinear;
			}
		})());
		
		if (animationDuration) {
		
			[UIView animateWithDuration:animationDuration delay:0 options:animationOptions animations:^{

				[wSelf adjustContainerViewWithInterfaceBounds:newBounds];
				
			} completion:nil];
		
		} else {

			[wSelf adjustContainerViewWithInterfaceBounds:newBounds];		
		
		}
		
	}];
	
	objc_setAssociatedObject(self, &kWACompositionViewWindowInterfaceBoundsNotificationHandler, notificationObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self.navigationItem.rightBarButtonItem irBind:@"enabled" toObject:self.article keyPath:@"hasMeaningfulContent" options:[NSDictionary dictionaryWithObjectsAndKeys:
		(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
	nil]];
		
}	

- (void) viewDidAppear:(BOOL)animated {
	
	[super viewDidAppear:animated];

}

- (void) viewWillDisappear:(BOOL)animated {

	[self.navigationItem.rightBarButtonItem irUnbind:@"enabled"];
	
	id notificationObject = objc_getAssociatedObject(self, &kWACompositionViewWindowInterfaceBoundsNotificationHandler);
	[[NSNotificationCenter defaultCenter] removeObserver:notificationObject];
	objc_setAssociatedObject(self, &kWACompositionViewWindowInterfaceBoundsNotificationHandler, nil, OBJC_ASSOCIATION_ASSIGN);
	
	[self.contentTextView resignFirstResponder];
	
	[textAttributor.queue cancelAllOperations];
	
	[super viewWillDisappear:animated];

}

- (void) adjustContainerViewWithInterfaceBounds:(CGRect)newBounds {

	if (![self isViewLoaded])
		return;
	
	UIWindow *ownWindow = self.view.window;
	if (!ownWindow) {
		if (!CGRectEqualToRect(self.containerView.frame, self.view.bounds))
			self.containerView.frame = self.view.bounds;
		return;
	}
	
	CGRect usableRectInWindow = newBounds;
	CGRect fullViewRectInWindow = [ownWindow convertRect:self.view.bounds fromView:self.view];
	CGRect overlappingRectInWindow = CGRectIntersection(fullViewRectInWindow, usableRectInWindow);
	
	CGRect usableRect = [ownWindow convertRect:overlappingRectInWindow toView:self.view];
	
	if (!CGRectEqualToRect(self.containerView.frame, usableRect))
		self.containerView.frame = usableRect;

}





- (IRTextAttributor *) textAttributor {

	if (textAttributor)
		return textAttributor;
	
	__weak WACompositionViewController *wSelf = self;
	
	textAttributor = [[IRTextAttributor alloc] init];
	textAttributor.delegate = self;
	textAttributor.discoveryBlock = IRTextAttributorDiscoveryBlockMakeWithRegularExpression([NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil]);
	
	textAttributor.attributionBlock = ^ (NSString *attributedString, IRTextAttributorAttributionCallback callback) {
	
		if (!attributedString) {
			callback(nil);
			return;
		}
	
		NSURL *url = [NSURL URLWithString:attributedString];
		if (!url) {
			callback(nil);
			return;
		}
		
		if ([[wSelf.article.previews objectsPassingTest: ^ (WAPreview *aPreview, BOOL *stop) {
			
			return [aPreview.url isEqualToString:attributedString];
			
		}] count]) {
		
			//	Already got something and attached, skip
			
			callback(nil);
			return;
		
		}
		
		[[WARemoteInterface sharedInterface] retrievePreviewForURL:url onSuccess:^(NSDictionary *aPreviewRep) {
		
			callback(aPreviewRep);
			
		} onFailure: ^ (NSError *error) {
			
			callback(nil);			
			
		}];
	
	};
	
	return textAttributor;

}

- (void) textViewDidChange:(UITextView *)textView {

	NSString *capturedText = textView.text;
	self.article.text = capturedText;
	
	__weak WACompositionViewController *wSelf = self;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
	
		if ([textView.text isEqualToString:capturedText])
			wSelf.textAttributor.attributedContent = [[NSMutableAttributedString alloc] initWithString:capturedText];
			
	});
	
}

- (void) textAttributor:(IRTextAttributor *)attributor willUpdateAttributedString:(NSAttributedString *)attributedString withToken:(NSString *)aToken range:(NSRange)tokenRange attribute:(id)newAttribute {

	//	NSLog(@"%s %@ %@ %@ %@ %@", __PRETTY_FUNCTION__, attributor, attributedString, aToken, NSStringFromRange(tokenRange), newAttribute);	

}

- (void) textAttributor:(IRTextAttributor *)attributor didUpdateAttributedString:(NSAttributedString *)attributedString withToken:(NSString *)aToken range:(NSRange)tokenRange attribute:(id)newAttribute {

	NSMutableArray *potentialLinkAttributes = [NSMutableArray array];

	[attributedString enumerateAttribute:IRTextAttributorTagAttributeName inRange:(NSRange){ 0, [attributedString length] } options:0 usingBlock: ^ (id value, NSRange range, BOOL *stop) {
		
		if (value)
			[potentialLinkAttributes addObject:value];
		
	}];
	
	NSArray *mappedPreviewEntities = [potentialLinkAttributes irMap: ^ (id anAttribute, NSUInteger index, BOOL *stop) {
	
		if (![anAttribute isKindOfClass:[NSDictionary class]])
			return (id)nil;
		
		return (id)[NSDictionary dictionaryWithObjectsAndKeys:
			anAttribute, @"og",
			[anAttribute valueForKeyPath:@"url"], @"id",
		nil];
		
	}];

	NSArray *allMatchingPreviews = [WAPreview insertOrUpdateObjectsUsingContext:self.managedObjectContext withRemoteResponse:mappedPreviewEntities usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
	if (![allMatchingPreviews count])
		return;
	
	WAPreview *stitchedPreview = [allMatchingPreviews objectAtIndex:0];
	NSError *error = nil;
	NSAssert1([self.managedObjectContext save:&error], @"Error Saving: %@", error);
	
	//	If there’s already an attachment, do nothing
	
	if ([self.article.files count])
		stitchedPreview = nil;
	
	//	If the article holds a preview already, don’t change it

	if ([self.article.previews count])
		return;

	//	Don’t delete them, just leave them for later to cleanup
	//	for (WAPreview *aPreview in allMatchingPreviews)
	//		if (stitchedPreview ? (aPreview != stitchedPreview) : YES)
	//			[aPreview.managedObjectContext deleteObject:aPreview];
	
	self.article.previews = stitchedPreview ? [NSSet setWithObject:stitchedPreview] : [NSSet set];

}

- (void) handleFilesChangeKind:(NSKeyValueChange)kind oldValue:(id)oldValue newValue:(id)newValue indices:(NSIndexSet *)indices isPrior:(BOOL)isPrior {

	//	No op

}

- (void) handlePreviewsChangeKind:(NSKeyValueChange)kind oldValue:(id)oldValue newValue:(id)newValue indices:(NSIndexSet *)indices isPrior:(BOOL)isPrior {

	//	No op

}

- (void) handleCurrentTextChangedFrom:(NSString *)fromValue to:(NSString *)toValue changeKind:(NSKeyValueChange)changeKind {

	//	No op

}

//	Deleting all the changed stuff and saving is like throwing all the stuff away
//	In that sense just don’t do anything.

- (void) handleDone:(UIBarButtonItem *)sender {

	self.article.text = self.contentTextView.text;
	self.article.modificationDate = [NSDate date];
	
	NSError *savingError = nil;
	if (![self.managedObjectContext save:&savingError])
		NSLog(@"Error saving: %@", savingError);
	
	if (self.completionBlock)
		self.completionBlock([[self.article objectID] URIRepresentation]);
		
	if([self.article.previews count])
		WAPostAppEvent(@"Create Preview", [NSDictionary dictionaryWithObjectsAndKeys:@"link",@"category",@"create", @"action", nil]);
	else if([self.article.files count])
		WAPostAppEvent(@"Create Photo", [NSDictionary dictionaryWithObjectsAndKeys:@"photo",@"category",@"create", @"action", nil]);
	else 
		WAPostAppEvent(@"Create Text", [NSDictionary dictionaryWithObjectsAndKeys:@"text",@"category",@"create", @"action", nil]);
		
}	

- (void) handleCancel:(UIBarButtonItem *)sender {

	if (!([self.article hasChanges] && [[self.article changedValues] count]) || ![self.article hasMeaningfulContent]) {
	
		if (self.completionBlock)
			self.completionBlock(nil);
		
		//	Delete things that are not meaningful if it’s a draft
		
		if (![self.article hasMeaningfulContent])
		if ([self.article.draft isEqualToNumber:(NSNumber *)kCFBooleanTrue])
			[self.article.managedObjectContext deleteObject:self.article];
		
		return;
	
	}
	
	IRActionSheetController *actionSheetController = self.cancellationActionSheetController;
	if ([[actionSheetController managedActionSheet] isVisible])
		return;
	
	NSParameterAssert(actionSheetController && ![actionSheetController.managedActionSheet isVisible]);
	
	[[actionSheetController managedActionSheet] showFromBarButtonItem:sender animated:YES];
	
}

- (IRActionSheetController *) cancellationActionSheetController {

	if (!cancellationActionSheetController) {
	
		__weak WACompositionViewController *wSelf = self;
	
		IRAction *discardAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_DISCARD", @"Action title for discarding a draft") block:^{
			
			if (wSelf.completionBlock)
				wSelf.completionBlock(nil);
			
		}];
		
		IRAction *saveAsDraftAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_SAVE_DRAFT", @"Action title for saving a draft") block:^{
		
			wSelf.article.text = wSelf.contentTextView.text;
			wSelf.article.creationDate = [NSDate date];
			
			NSError *savingError = nil;
			if (![wSelf.managedObjectContext save:&savingError])
				NSLog(@"Error saving: %@", savingError);
			
			if (wSelf.completionBlock)
				wSelf.completionBlock(nil);
		
		}];
			
		cancellationActionSheetController = [IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:discardAction otherActions:[NSArray arrayWithObjects:
			saveAsDraftAction,
		nil]];
			
		cancellationActionSheetController.onActionSheetCancel = ^ {
		
			wSelf.cancellationActionSheetController = nil;
		
		};
		
		cancellationActionSheetController.onActionSheetDidDismiss = ^ (IRAction *invokedAction) {
			
			wSelf.cancellationActionSheetController = nil;
				
		};
	
	}
	
	return cancellationActionSheetController;
	
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  
	return YES;
	
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	[self adjustContainerViewWithInterfaceBounds:((UIWindow *)[[UIApplication sharedApplication].windows objectAtIndex:0]).irInterfaceBounds];

}

@end
