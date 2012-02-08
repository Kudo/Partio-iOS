//
//  WAGalleryViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/3/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAGalleryViewController.h"
#import "IRPaginatedView.h"
#import "WADataStore.h"
#import "WAGalleryImageView.h"
#import "WAImageStreamPickerView.h"
#import "UIImage+IRAdditions.h"
#import "IRLifetimeHelper.h"

NSString * const kWAGalleryViewControllerContextPreferredFileObjectURI = @"WAGalleryViewControllerContextPreferredFileObjectURI";


@interface WAGalleryViewController () <IRPaginatedViewDelegate, UIGestureRecognizerDelegate, UINavigationBarDelegate, WAImageStreamPickerViewDelegate, NSFetchedResultsControllerDelegate, WAGalleryImageViewDelegate>

@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) WAArticle *article;
@property (nonatomic, readwrite, retain) IRPaginatedView *paginatedView;

@property (nonatomic, readwrite, retain) NSCache *galleryViewCache;

@property (nonatomic, readwrite, retain) UINavigationBar *navigationBar;
@property (nonatomic, readwrite, retain) UIToolbar *toolbar;
@property (nonatomic, readwrite, retain) UINavigationItem *previousNavigationItem;
@property (nonatomic, readwrite, retain) WAImageStreamPickerView *streamPickerView;

@property (nonatomic, readwrite, copy) void (^onViewDidLoad)(void);
@property (nonatomic, readwrite, copy) void (^onViewDidAppear)(BOOL animated);
@property (nonatomic, readwrite, copy) void (^onViewWillDisappear)(BOOL animated);
@property (nonatomic, readwrite, copy) void (^onViewDidDisappear)(BOOL animated);

- (void) waSubviewWillLayout;

- (WAFile *) representedFileAtIndex:(NSUInteger)anIndex;

@property (nonatomic, readwrite, assign) BOOL contextControlsShown;

@property (nonatomic, readwrite, assign) BOOL requiresReloadOnFetchedResultsChange;

#if WAGalleryViewController_UsesProxyOverlay
@property (nonatomic, readwrite, retain) WAGalleryImageView *swipeOverlay;
#endif

- (WAGalleryImageView *) configureGalleryImageView:(WAGalleryImageView *)aView withFile:(WAFile *)aFile degradeQuality:(BOOL)exclusivelyUsesThumbnail forceSync:(BOOL)forceSynchronousImageDecode;

- (void) adjustStreamPickerView;

@end


@implementation WAGalleryViewController
@dynamic view;
@synthesize managedObjectContext, fetchedResultsController, article;
@synthesize navigationBar, toolbar, previousNavigationItem;
@synthesize paginatedView;
@synthesize galleryViewCache;
@synthesize streamPickerView;
@synthesize contextControlsShown;
@synthesize onDismiss;
@synthesize onViewDidLoad, onViewDidAppear, onViewWillDisappear, onViewDidDisappear;
@synthesize requiresReloadOnFetchedResultsChange;

#if WAGalleryViewController_UsesProxyOverlay
@synthesize swipeOverlay;
#endif


+ (WAGalleryViewController *) controllerRepresentingArticleAtURI:(NSURL *)anArticleURI {

	return [self controllerRepresentingArticleAtURI:anArticleURI context:nil];

}

+ (WAGalleryViewController *) controllerRepresentingArticleAtURI:(NSURL *)anArticleURI context:(NSDictionary *)context {

	__block WAGalleryViewController *returnedController = [[[self alloc] init] autorelease];
	
	returnedController.managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];
	returnedController.article = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:anArticleURI];
	
	
	NSURL *preferredObjectURI = [context objectForKey:kWAGalleryViewControllerContextPreferredFileObjectURI];
	
	returnedController.onViewDidLoad = ^ {
	
		if (preferredObjectURI) {
		
			NSUInteger fileIndex = [returnedController.article.fileOrder indexOfObject:preferredObjectURI];
			if (fileIndex != NSNotFound) {
			
				//	FIXME: Actually fix IRPaginatedView.  We have copied this hack.

				[returnedController.paginatedView layoutSubviews];
				[returnedController.paginatedView scrollToPageAtIndex:fileIndex animated:NO];
				[returnedController.paginatedView layoutSubviews];
				[returnedController.paginatedView setNeedsLayout];

			}
		
		}
	
	};
	
	if ([returnedController isViewLoaded])
		returnedController.onViewDidLoad();
	
	return returnedController;

}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	self.wantsFullScreenLayout = YES;
	
	return self;

}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {

	return YES;

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	[self adjustStreamPickerView];

}

- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {

	self.requiresReloadOnFetchedResultsChange = NO;

}

- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {

	switch (type) {
	
		case NSFetchedResultsChangeUpdate: {
			
			NSUInteger index = [self.article.fileOrder indexOfObject:[[anObject objectID] URIRepresentation]];
			if (index != NSNotFound) {
				
				WAGalleryImageView *imageView = nil;
				@try {
					imageView = (WAGalleryImageView *)[self.paginatedView existingPageAtIndex:index];
				} @catch (NSException *e) {
					NSLog(@"Error %@", e);
				}
				
				if (imageView) {
					[self configureGalleryImageView:imageView withFile:(WAFile *)anObject degradeQuality:YES forceSync:NO];
				}

			}
			
			break;
		}

		case NSFetchedResultsChangeDelete:
		case NSFetchedResultsChangeInsert:
		case NSFetchedResultsChangeMove:
		default: {
			self.requiresReloadOnFetchedResultsChange = YES;
			break;
		}
		
	}

}

- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {

	self.requiresReloadOnFetchedResultsChange = YES;

}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {

	if (!self.requiresReloadOnFetchedResultsChange)
		return;
		
	//	Seriously
	
	NSUInteger oldCurrentPage = self.paginatedView.currentPage;
	
	[self.paginatedView reloadViews];
	[self.paginatedView scrollToPageAtIndex:oldCurrentPage animated:NO];
	[self.streamPickerView reloadData];
	[self.streamPickerView setNeedsLayout];

}

- (WAFile *) representedFileAtIndex:(NSUInteger)anIndex {

	WAFile *returnedFile = (WAFile *)[self.article.managedObjectContext irManagedObjectForURI:[self.article.fileOrder objectAtIndex:anIndex]];
	NSParameterAssert([self.article.files containsObject:returnedFile]);
	
	return returnedFile;

	//  return [[[self.article.fileOrder irMap: ^ (NSURL *anURI, NSUInteger index, BOOL *stop) {
	//  
	//    WAFile *returnedObject = (WAFile *)[self.article.managedObjectContext irManagedObjectForURI:anURI];
	//    if (![self.fetchedResultsController.fetchedObjects containsObject:returnedObject])
	//      return (id)nil;
	//    
	//    return (id)returnedObject;
	//      
	//  }] filteredArrayUsingPredicate:self.fetchedResultsController.fetchRequest.predicate] objectAtIndex:anIndex];

}

- (NSFetchedResultsController *) fetchedResultsController {

	if (fetchedResultsController)
		return fetchedResultsController;
		
	NSFetchRequest *fetchRequest = [self.managedObjectContext.persistentStoreCoordinator.managedObjectModel fetchRequestFromTemplateWithName:@"WAFRImagesForArticle" substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:
		self.article, @"Article",
	nil]];
	
	fetchRequest.returnsObjectsAsFaults = NO;
	fetchRequest.fetchBatchSize = 20;
	fetchRequest.sortDescriptors = [NSArray arrayWithObjects:
		[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:YES],
	nil];
		
	self.fetchedResultsController = [[[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil] autorelease];
	self.fetchedResultsController.delegate = self;
	
	NSError *fetchingError;
	if (![self.fetchedResultsController performFetch:&fetchingError])
		NSLog(@"Error fetching: %@", fetchingError);
  
	self.previousNavigationItem.title = self.article.text;
	
	return fetchedResultsController;

}

- (void) loadView {

	NSParameterAssert(self.article);

	__block __typeof__(self) nrSelf = self;

	self.view = [[[WAView alloc] initWithFrame:(CGRect){ 0, 0, 512, 512 }] autorelease];
	self.view.backgroundColor = [UIColor blackColor];
	self.view.onLayoutSubviews = ^ {
		[nrSelf waSubviewWillLayout];
	};
	
	NSString *articleTitle = self.article.text;
	if (![[articleTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length])
		articleTitle = @"Post";
	
	self.previousNavigationItem = [[[UINavigationItem alloc] initWithTitle:articleTitle] autorelease];
	self.previousNavigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:articleTitle style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
	
	self.paginatedView = [[[IRPaginatedView alloc] initWithFrame:self.view.bounds] autorelease];
	self.paginatedView.horizontalSpacing = 24.0f;
	self.paginatedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.paginatedView.delegate = self;
	
	self.navigationBar = [[[UINavigationBar alloc] initWithFrame:(CGRect){ 0.0f, 0.0f, CGRectGetWidth(self.view.bounds), 44.0f }] autorelease];
	self.navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
	self.navigationBar.barStyle = UIBarStyleBlackTranslucent;
	self.navigationBar.delegate = self;
	
	NSParameterAssert(self.previousNavigationItem);
	NSParameterAssert(self.navigationItem);
	
	[self.navigationBar pushNavigationItem:self.previousNavigationItem animated:NO];
	[self.navigationBar pushNavigationItem:self.navigationItem animated:NO];
	
	self.toolbar = [[[UIToolbar alloc] initWithFrame:(CGRect){ 0.0f, CGRectGetHeight(self.view.bounds) - 44.0f, CGRectGetWidth(self.view.bounds), 44.0f }] autorelease];
	self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
	self.toolbar.barStyle = UIBarStyleBlackTranslucent;
	
	self.toolbarItems = [NSArray arrayWithObjects:
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
		[[[UIBarButtonItem alloc] initWithCustomView:self.streamPickerView] autorelease],
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
	nil];
	
	if (!self.navigationController)
		self.toolbar.items = self.toolbarItems;
	
	[self.view addSubview:self.paginatedView];
	[self.view addSubview:self.navigationBar];
	[self.view addSubview:self.toolbar];
	
	self.contextControlsShown = YES;
	
	UITapGestureRecognizer *tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)] autorelease];
	tapRecognizer.delegate = self;
	[self.view addGestureRecognizer:tapRecognizer];
	
	UITapGestureRecognizer *doubleTapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundDoubleTap:)] autorelease];
	doubleTapRecognizer.numberOfTapsRequired = 2;
	[tapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
	[self.view addGestureRecognizer:doubleTapRecognizer];
	
	[self.paginatedView irAddObserverBlock:^(id inOldValue, id inNewValue, NSString *changeKind) {

		NSUInteger oldIndex = [inOldValue unsignedIntValue];	
		NSUInteger newIndex = [inNewValue unsignedIntValue];
		
		if (oldIndex == newIndex)
			return;
		
		[nrSelf paginatedView:nrSelf.paginatedView didShowView:[nrSelf.paginatedView existingPageAtIndex:newIndex] atIndex:newIndex];
	
	} forKeyPath:@"currentPage" options:NSKeyValueObservingOptionNew context:nil];
	
	[self adjustStreamPickerView];
	
}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	if (self.onViewDidLoad)
		self.onViewDidLoad();
	
#if WAGalleryViewController_UsesProxyOverlay
	
	[self.view insertSubview:self.swipeOverlay aboveSubview:self.paginatedView];

#endif

}

- (void) viewWillAppear:(BOOL)animated {

	if (self.navigationController) {
	
		UINavigationController *navC = self.navigationController;

		UIBarStyle oldNavBarStyle = navC.navigationBar.barStyle;
		BOOL oldNavBarWasTranslucent = navC.navigationBar.translucent;
		UIBarStyle oldToolBarStyle = navC.toolbar.barStyle;
		BOOL oldToolBarWasTranslucent = navC.toolbar.translucent;
		BOOL toolbarWasHidden = navC.toolbarHidden;
		UIColor *oldNavBarTintColor = navC.navigationBar.tintColor;
		
		navC.navigationBar.barStyle = UIBarStyleBlackTranslucent;
		navC.navigationBar.translucent = YES;
		
		navC.toolbar.barStyle = UIBarStyleBlackTranslucent;
		navC.toolbar.translucent = YES;
		
		navC.toolbar.items = self.toolbarItems;
		
		[self.navigationBar removeFromSuperview];
		self.navigationBar = nil;
		
		[self.toolbar removeFromSuperview];
		self.toolbar = nil;
				
		[navC setToolbarHidden:NO animated:YES];
			
		__block __typeof__(self) nrSelf = self;
		
		self.onViewDidAppear = ^ (BOOL animated) {
		
			nrSelf.onViewDidAppear = nil;
		
		};
		
		self.onViewWillDisappear = ^ (BOOL animated) {
		
			navC.navigationBar.barStyle = oldNavBarStyle;
			navC.navigationBar.translucent = oldNavBarWasTranslucent;
			navC.navigationBar.tintColor = [UIColor blackColor];
			
			[navC setToolbarHidden:toolbarWasHidden animated:animated];
			
			nrSelf.onViewDidDisappear = ^ (BOOL animated) {
			
				navC.toolbar.barStyle = oldToolBarStyle;
				navC.toolbar.translucent = oldToolBarWasTranslucent;
				navC.navigationBar.tintColor = oldNavBarTintColor;
				
				if (nrSelf.onDismiss)
					nrSelf.onDismiss();
			
				nrSelf.onViewDidDisappear = nil;
				
			};
			
			nrSelf.onViewWillDisappear = nil;
		
		};
	
	}
	
	[self adjustStreamPickerView];
	
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:YES];
	
	[super viewWillAppear:animated];
	
	[self.paginatedView reloadViews];

}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	
	if (self.onViewDidAppear)
		self.onViewDidAppear(animated);

}

- (void) viewWillDisappear:(BOOL)animated {

	if (self.onViewWillDisappear)
		self.onViewWillDisappear(animated);
	
	[super viewWillDisappear:animated];

}

- (void) viewDidDisappear:(BOOL)animated {

	[super viewDidDisappear:animated];

	if (self.onViewDidDisappear)
		self.onViewDidDisappear(animated);

}

- (void) waSubviewWillLayout {

	self.navigationBar.frame = (CGRect){
	
		(CGPoint){
			self.navigationBar.frame.origin.x,
			MAX(20, [self.view convertRect:[[UIApplication sharedApplication] statusBarFrame] fromView:nil].size.height)
		},
		self.navigationBar.frame.size
	
	};

}


#if WAGalleryViewController_UsesProxyOverlay

- (WAGalleryImageView *) swipeOverlay {

	if (swipeOverlay)
		return swipeOverlay;
	
	swipeOverlay = [[WAGalleryImageView viewForImage:nil] retain];
	swipeOverlay.hidden = YES;
	swipeOverlay.frame = self.view.bounds;
	swipeOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	swipeOverlay.onPointInsideWithEvent = ^ (CGPoint aPoint, UIEvent *anEvent, BOOL superAnswer) {
		return NO;
	};
	
	swipeOverlay.alpha = 0.5;
	
	[swipeOverlay reset];
	
	return swipeOverlay;

}

#endif





- (void) paginatedView:(IRPaginatedView *)aPaginatedView didShowView:(UIView *)aView atIndex:(NSUInteger)index {

	self.streamPickerView.selectedItemIndex = index;
	
	[self.paginatedView.scrollView.subviews enumerateObjectsUsingBlock: ^ (WAGalleryImageView *aPage, NSUInteger idx, BOOL *stop) {
	
		if (![aPage isKindOfClass:[WAGalleryImageView class]])
			return;
		
		if (aPage == aView)
			return;
		
		[aPage reset];
		
	}];
	
	
	//	Hides contest on page turns, but NOT stream picker changes
	
	if (((^ {
	
		UIScrollView *sv = self.paginatedView.scrollView;
		if ([sv respondsToSelector:@selector(panGestureRecognizer)])
			return sv.panGestureRecognizer;
		
		for (UIGestureRecognizer *aGR in sv.gestureRecognizers)
			if ([aGR isKindOfClass:[UIPanGestureRecognizer class]])
				return aGR;
		
		return (UIGestureRecognizer *)nil;
	
	})()).state == UIGestureRecognizerStateChanged) {
		
		[self setContextControlsHidden:YES animated:YES barringInteraction:NO completion:nil];
	
	}
	
	
	IRPaginatedView *paginatedView = self.paginatedView;
	NSUInteger currentPage = paginatedView.currentPage;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
	
		if (paginatedView.currentPage != currentPage)
			return;
		
		WAGalleryImageView *pageView = [self.paginatedView existingPageAtIndex:currentPage];
		if (!pageView)
			return;
		
		WAFile *pageFile = [self representedFileAtIndex:currentPage];
		if (!pageFile)
			return;
		
		[self configureGalleryImageView:pageView withFile:pageFile degradeQuality:NO forceSync:NO];
	
	});
	
}

- (void) galleryImageViewDidBeginInteraction:(WAGalleryImageView *)imageView {

	[self setContextControlsHidden:YES animated:YES barringInteraction:NO completion:nil];

}

- (BOOL) navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item {

	if (self.onDismiss)
		dispatch_async(dispatch_get_main_queue(), self.onDismiss);
	
	return NO;

}

- (NSUInteger) numberOfViewsInPaginatedView:(IRPaginatedView *)paginatedView {

	return [[self.fetchedResultsController fetchedObjects] count];

}

- (UIView *) viewForPaginatedView:(IRPaginatedView *)aPaginatedView atIndex:(NSUInteger)index {

	WAFile *file = [self representedFileAtIndex:index];
	WAGalleryImageView *view = [self.galleryViewCache objectForKey:file];
	
	if (!view) {
		view = [WAGalleryImageView viewForImage:nil];
		[self.galleryViewCache setObject:view forKey:file];
	}
	
	return [self configureGalleryImageView:view withFile:file degradeQuality:YES forceSync:NO];

}

- (UIViewController *) viewControllerForSubviewAtIndex:(NSUInteger)index inPaginatedView:(IRPaginatedView *)paginatedView {

	return nil;

}

- (WAGalleryImageView *) configureGalleryImageView:(WAGalleryImageView *)aView withFile:(WAFile *)aFile degradeQuality:(BOOL)exclusivelyUsesThumbnail forceSync:(BOOL)forceSynchronousImageDecode {

	if (exclusivelyUsesThumbnail) {
		
		[aView setImage:aFile.thumbnailImage animated:NO synchronized:forceSynchronousImageDecode];
		
	} else {
		
		[aView setImage:aFile.presentableImage animated:NO synchronized:forceSynchronousImageDecode];
		
	}
	
#if 0

	if (exclusivelyUsesThumbnail) {
		
		aView.layer.borderColor = [UIColor greenColor].CGColor;
		aView.layer.borderWidth = 2;
	
	} else {
	
		aView.layer.borderColor = [UIColor redColor].CGColor;
		aView.layer.borderWidth = 2;
	
	}
	
#endif
	
	aView.delegate = self;
  [aView reset];
	
	return aView;

}





- (WAImageStreamPickerView *) streamPickerView {

	if (streamPickerView)
		return streamPickerView;
	
	self.streamPickerView = [[[WAImageStreamPickerView alloc] init] autorelease];
	self.streamPickerView.delegate = self;
	self.streamPickerView.style = WAClippedThumbnailsStyle;
	self.streamPickerView.exclusiveTouch = YES;
	
	[self.streamPickerView reloadData];
	
	return streamPickerView;

}

- (void) adjustStreamPickerView {

	UIToolbar *usedBar = ((self.navigationController && !self.navigationController.toolbarHidden) ? self.navigationController.toolbar : self.toolbar);
	NSParameterAssert(usedBar);

	self.streamPickerView.frame = CGRectInset(usedBar.bounds, 10, 0);

}

- (NSUInteger) numberOfItemsInImageStreamPickerView:(WAImageStreamPickerView *)picker {

	return [self.fetchedResultsController.fetchedObjects count];

}

- (id) itemAtIndex:(NSUInteger)anIndex inImageStreamPickerView:(WAImageStreamPickerView *)picker {

  WAFile *representedFile = [self representedFileAtIndex:anIndex];
	return representedFile;

}

- (UIImage *) thumbnailForItem:(WAFile *)aFile inImageStreamPickerView:(WAImageStreamPickerView *)picker {

	return aFile.thumbnailImage;

}

- (void) imageStreamPickerView:(WAImageStreamPickerView *)picker didSelectItem:(WAFile *)anItem {

	NSUInteger index = [self.article.fileOrder indexOfObject:[[anItem objectID] URIRepresentation]];
	
	if (index == NSNotFound)
		return;
	
	WAFile *representedFile = [self representedFileAtIndex:index];
	NSParameterAssert(representedFile);
	
	NSUInteger selectedIndex = picker.selectedItemIndex;

#if WAGalleryViewController_UsesProxyOverlay

	self.swipeOverlay.hidden = NO;
	[self configureGalleryImageView:self.swipeOverlay withFile:representedFile degradeQuality:YES forceSync:NO];
	[self.swipeOverlay reset];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		if (picker.selectedItemIndex == selectedIndex) {
			[self.paginatedView scrollToPageAtIndex:selectedIndex animated:NO];
			self.swipeOverlay.hidden = YES;
		}
	});

#else
	
	[self.paginatedView scrollToPageAtIndex:selectedIndex animated:NO];

#endif


}





- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {

	if (![gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]])
		return YES;

	if (!self.contextControlsShown)
		return YES;
		
	if (CGRectContainsPoint(UIEdgeInsetsInsetRect(self.navigationBar.bounds, (UIEdgeInsets){ -20, -20, -20, -20 }), [touch locationInView:self.navigationBar]))
		return NO;
	
	if (CGRectContainsPoint(UIEdgeInsetsInsetRect(self.toolbar.bounds, (UIEdgeInsets){ -20, -20, -20, -20 }), [touch locationInView:self.toolbar]))
		return NO;
	
	return YES;

}

- (void) handleBackgroundDoubleTap:(UITapGestureRecognizer *)tapRecognizer {

	if (!self.paginatedView.numberOfPages)
		return;

	WAGalleryImageView *currentPage = (WAGalleryImageView *)[self.paginatedView existingPageAtIndex:self.paginatedView.currentPage];
	
	if (![currentPage isKindOfClass:[WAGalleryImageView class]])
		return;
		
	[currentPage handleDoubleTap:tapRecognizer];
	
}

- (void) handleBackgroundTap:(UITapGestureRecognizer *)tapRecognizer {

	[self setContextControlsHidden:self.contextControlsShown animated:YES completion:nil];

}

- (void) setContextControlsHidden:(BOOL)willHide animated:(BOOL)animate completion:(void(^)(void))callback {

	[self setContextControlsHidden:willHide animated:animate barringInteraction:YES completion:callback];

}

- (void) setContextControlsHidden:(BOOL)willHide animated:(BOOL)animate barringInteraction:(BOOL)barringInteraction completion:(void(^)(void))callback {

	if (contextControlsShown == !willHide)
		return;
	
	NSTimeInterval animationDuration = animate ? 0.3f : 0.0f;
	
	if (barringInteraction && (animationDuration > 0)) {
	
		[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, animationDuration * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
			[[UIApplication sharedApplication] endIgnoringInteractionEvents];
		});	
	
	}
	
	[[UIApplication sharedApplication] setStatusBarHidden:willHide withAnimation:(animate ? UIStatusBarAnimationFade : UIStatusBarAnimationNone)];
	[self.view setNeedsLayout];
	[self.view layoutSubviews];
	
	UIViewAnimationOptions animationOptions = UIViewAnimationOptionBeginFromCurrentState;
	
	if (!barringInteraction)
		animationOptions |= UIViewAnimationOptionAllowUserInteraction;
	
	[UIView animateWithDuration:animationDuration delay:0.0f options:animationOptions animations:^(void) {
	
		self.navigationBar.alpha = (willHide ? 0.0f : 1.0f);
		self.toolbar.alpha = (willHide ? 0.0f : 1.0f);
		
		self.navigationController.navigationBar.alpha = (willHide ? 0.0f : 1.0f);
		self.navigationController.toolbar.alpha = (willHide ? 0.0f : 1.0f);
		
	} completion: ^ (BOOL didFinish){
	
		if (callback)
			callback();
			
	}];
	
	self.contextControlsShown = willHide ? NO : YES;

}





- (UIImage *) currentImage {

	return ((WAGalleryImageView *)[self.paginatedView existingPageAtIndex:self.paginatedView.currentPage]).image;

}





- (void) didReceiveMemoryWarning {

	[super didReceiveMemoryWarning];
	
	[self.galleryViewCache removeAllObjects];
	

}

- (void) viewDidUnload {

	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];

	self.paginatedView = nil;
	self.navigationBar = nil;
	self.toolbar = nil;
	self.previousNavigationItem = nil;
	self.streamPickerView = nil;
	
	[self.galleryViewCache removeAllObjects];
	
	self.view.onLayoutSubviews = nil;
	
	#if WAGalleryViewController_UsesProxyOverlay
	self.swipeOverlay = nil;
	#endif
		
	[super viewDidUnload];

}

- (void) dealloc {

	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];
	self.view.onLayoutSubviews = nil;

	[managedObjectContext release];
	[fetchedResultsController release];
	[article release];
	
	[paginatedView removeFromSuperview];	//	Also triggers page deallocation
	[paginatedView release];
	[navigationBar release];
	[toolbar release];
	[previousNavigationItem release];
	[streamPickerView release];
	
	[galleryViewCache release];
		
	[onDismiss release];
	
	[onViewDidLoad release];
	
	[onViewDidAppear release];
	[onViewWillDisappear release];
	[onViewDidDisappear release];
	
	[super dealloc];

}

@end
