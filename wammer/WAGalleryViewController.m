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


@interface WAGalleryViewController () <IRPaginatedViewDelegate, UIGestureRecognizerDelegate, UINavigationBarDelegate, WAImageStreamPickerViewDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) WAArticle *article;
@property (nonatomic, readwrite, retain) IRPaginatedView *paginatedView;

@property (nonatomic, readwrite, retain) UINavigationBar *navigationBar;
@property (nonatomic, readwrite, retain) UIToolbar *toolbar;
@property (nonatomic, readwrite, retain) UINavigationItem *previousNavigationItem;
@property (nonatomic, readwrite, retain) WAImageStreamPickerView *streamPickerView;

- (void) waSubviewWillLayout;

@property (nonatomic, readwrite, assign) BOOL contextControlsShown;

@end


@implementation WAGalleryViewController
@dynamic view;
@synthesize managedObjectContext, fetchedResultsController, article;
@synthesize navigationBar, toolbar, previousNavigationItem;
@synthesize paginatedView;
@synthesize streamPickerView;
@synthesize contextControlsShown;
@synthesize onDismiss;


+ (WAGalleryViewController *) controllerRepresentingArticleAtURI:(NSURL *)anArticleURI {

	WAGalleryViewController *returnedController = [[[self alloc] init] autorelease];
	
	returnedController.managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];
	returnedController.article = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:anArticleURI];
	
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
	
	self.streamPickerView.frame = CGRectInset(self.toolbar.bounds, 10, 0);

}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {

	NSUInteger oldCurrentPage = self.paginatedView.currentPage;
	
	[self.paginatedView reloadViews];
	[self.paginatedView scrollToPageAtIndex:oldCurrentPage animated:NO];
	[self.streamPickerView reloadData];
	[self.streamPickerView setNeedsLayout];

}

- (NSFetchedResultsController *) fetchedResultsController {

	if (fetchedResultsController)
		return fetchedResultsController;
		
	NSFetchRequest *fetchRequest = [self.managedObjectContext.persistentStoreCoordinator.managedObjectModel fetchRequestFromTemplateWithName:@"WAFRFilesForArticle" substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:
		self.article, @"Article",
	nil]];
	
	fetchRequest.returnsObjectsAsFaults = NO;
	
	fetchRequest.sortDescriptors = [NSArray arrayWithObjects:
		[NSSortDescriptor sortDescriptorWithKey:@"resourceURL" ascending:YES],
		[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
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
		
	self.toolbar.items = [NSArray arrayWithObjects:
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
		[[[UIBarButtonItem alloc] initWithCustomView:self.streamPickerView] autorelease],
		[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
	nil];
	
	[self.view addSubview:self.paginatedView];
	[self.view addSubview:self.navigationBar];
	[self.view addSubview:self.toolbar];
	
	self.contextControlsShown = YES;
	[self setContextControlsHidden:YES animated:NO completion:nil];
	
	UITapGestureRecognizer *tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)] autorelease];
	tapRecognizer.delegate = self;
	[self.view addGestureRecognizer:tapRecognizer];
	
	[self.paginatedView irAddObserverBlock:^(id inOldValue, id inNewValue, NSString *changeKind) {
		nrSelf.streamPickerView.selectedItemIndex = [inNewValue unsignedIntValue];
	} forKeyPath:@"currentPage" options:NSKeyValueObservingOptionNew context:nil];
	
}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	[self.paginatedView reloadViews];

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





- (BOOL) navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item {

	if (self.onDismiss)
		dispatch_async(dispatch_get_main_queue(), self.onDismiss);
	
	return NO;

}

- (NSUInteger) numberOfViewsInPaginatedView:(IRPaginatedView *)paginatedView {

	return [[self.fetchedResultsController fetchedObjects] count];

}

- (UIView *) viewForPaginatedView:(IRPaginatedView *)aPaginatedView atIndex:(NSUInteger)index {

	WAFile *representedFile = [[self.fetchedResultsController fetchedObjects] objectAtIndex:index];
	UIImage *representedImage = representedFile.resourceImage ? representedFile.resourceImage : representedFile.thumbnailImage;
	WAGalleryImageView *returnedView =  [WAGalleryImageView viewForImage:representedImage];
	
	return returnedView;

}

- (UIViewController *) viewControllerForSubviewAtIndex:(NSUInteger)index inPaginatedView:(IRPaginatedView *)paginatedView {

	return nil;

}





- (WAImageStreamPickerView *) streamPickerView {

	if (streamPickerView)
		return streamPickerView;
	
	self.streamPickerView = [[[WAImageStreamPickerView alloc] init] autorelease];
	self.streamPickerView.delegate = self;
	self.streamPickerView.style = WAClippedThumbnailsStyle;
	
	[self.streamPickerView reloadData];
	
	return streamPickerView;

}

- (NSUInteger) numberOfItemsInImageStreamPickerView:(WAImageStreamPickerView *)picker {

	return [self.article.fileOrder count];

}

- (id) itemAtIndex:(NSUInteger)anIndex inImageStreamPickerView:(WAImageStreamPickerView *)picker {

	WAFile *representedFile = (WAFile *)[self.article.managedObjectContext irManagedObjectForURI:[self.article.fileOrder objectAtIndex:anIndex]];
	return representedFile;

}

- (UIImage *) thumbnailForItem:(WAFile *)aFile inImageStreamPickerView:(WAImageStreamPickerView *)picker {

	return aFile.thumbnailImage;

}

- (void) imageStreamPickerView:(WAImageStreamPickerView *)picker didSelectItem:(WAFile *)anItem {

	NSUInteger index = [self.article.fileOrder indexOfObject:[[anItem objectID] URIRepresentation]];
	
	if (index == NSNotFound)
		return;
		
	[self.paginatedView scrollToPageAtIndex:index animated:NO];

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
	
	[UIView animateWithDuration:animationDuration delay:0.0f options:(barringInteraction ? 0 : UIViewAnimationOptionAllowUserInteraction) animations:^(void) {
	
		self.navigationBar.alpha = (willHide ? 0.0f : 1.0f);
		self.toolbar.alpha = (willHide ? 0.0f : 1.0f);
		
	} completion: ^ (BOOL didFinish){
	
		if (callback)
			callback();
			
	}];
	
	self.contextControlsShown = willHide ? NO : YES;

}





- (UIImage *) currentImage {

	return ((WAGalleryImageView *)[self.paginatedView existingPageAtIndex:self.paginatedView.currentPage]).image;

}





- (void) viewDidUnload {

	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];

	self.paginatedView = nil;
	self.navigationBar = nil;
	self.toolbar = nil;
	self.previousNavigationItem = nil;
	self.streamPickerView = nil;
	
	self.view.onLayoutSubviews = nil;
		
	[super viewDidUnload];

}

- (void) dealloc {

	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];
	self.view.onLayoutSubviews = nil;

	[managedObjectContext release];
	[fetchedResultsController release];
	[article release];
	
	[paginatedView release];
	[navigationBar release];
	[toolbar release];
	[previousNavigationItem release];
	[streamPickerView release];
		
	[onDismiss release];
	
	[super dealloc];

}

@end
