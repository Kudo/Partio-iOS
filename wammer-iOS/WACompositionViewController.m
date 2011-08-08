//
//  WACompositionViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "WACompositionViewController.h"
#import "WADataStore.h"
#import "IRImagePickerController.h"
#import "IRConcaveView.h"
#import "IRActionSheetController.h"
#import "IRActionSheet.h"


@interface WACompositionViewController () <AQGridViewDelegate, AQGridViewDataSource, NSFetchedResultsControllerDelegate>

@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) WAArticle *article;
@property (nonatomic, readwrite, retain) UIPopoverController *imagePickerPopover;

- (void) handleCurrentArticleFilesChangedFrom:(id)fromValue to:(id)toValue changeKind:(NSString *)changeKind;
- (void) handleIncomingSelectedAssetURI:(NSURL *)aFileURL representedAsset:(ALAsset *)photoLibraryAsset;

@end


@implementation WACompositionViewController
@synthesize managedObjectContext, fetchedResultsController, article;
@synthesize photosView, contentTextView, toolbar;
@synthesize imagePickerPopover;
@synthesize noPhotoReminderView;

+ (WACompositionViewController *) controllerWithArticle:(NSURL *)anArticleURLOrNil completion:(void(^)(NSURL *anArticleURLOrNil))aBlock {

	WACompositionViewController *returnedController = [[[self alloc] init] autorelease];
	
	returnedController.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
	returnedController.article = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:anArticleURLOrNil];
	
	if (!returnedController.article)
		returnedController.article = [WAArticle objectInsertingIntoContext:returnedController.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
	
	return returnedController;
	
}

- (id) init {

	return [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];

}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if (!self)
		return nil;
	
	self.title = @"Compose";
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(handleDone:)] autorelease];
	
	return self;

}

- (void) setArticle:(WAArticle *)newArticle {

	__block __typeof__(self) nrSelf = self;

	[self willChangeValueForKey:@"article"];
	
	[article irRemoveObserverBlocksForKeyPath:@"files"];	
	[newArticle irAddObserverBlock:^(id inOldValue, id inNewValue, NSString *changeKind) {
		[nrSelf handleCurrentArticleFilesChangedFrom:inOldValue to:inNewValue changeKind:changeKind];
	} forKeyPath:@"files" options:NSKeyValueObservingOptionNew context:nil];	
	
	[article release];
	article = [newArticle retain];
	
	[self didChangeValueForKey:@"article"];

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
	
	return fetchedResultsController;

}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {

	NSLog(@"%s %@", __PRETTY_FUNCTION__, controller);

}

- (void) dealloc {

	[photosView release];
	[contentTextView release];
	[noPhotoReminderView release];
	[toolbar release];

	[article irRemoveObserverBlocksForKeyPath:@"files"];
	
	[managedObjectContext release];
	[fetchedResultsController release];
	[article release];
	[imagePickerPopover release];

	[super dealloc];

}

- (void) viewDidUnload {

	self.photosView = nil;
	self.noPhotoReminderView = nil;
	self.contentTextView = nil;
	self.toolbar = nil;
	self.imagePickerPopover = nil;

	[super viewDidUnload];

}





- (void) viewDidLoad {

	[super viewDidLoad];
	
	if ([[UIDevice currentDevice].name rangeOfString:@"Simulator"].location != NSNotFound)
		self.contentTextView.autocorrectionType = UITextAutocorrectionTypeNo;
	
	self.contentTextView.text = self.article.text;
	
	self.toolbar.opaque = NO;
	self.toolbar.backgroundColor = [UIColor clearColor];
	
	self.photosView.layoutDirection = AQGridViewLayoutDirectionHorizontal;
	self.photosView.backgroundColor = nil;
	self.photosView.layer.cornerRadius = 4.0f;
	self.photosView.opaque = NO;
	self.photosView.bounces = YES;
	self.photosView.alwaysBounceHorizontal = YES;
	self.photosView.alwaysBounceVertical = NO;
	self.photosView.directionalLockEnabled = YES;
	self.photosView.contentSizeGrowsToFillBounds = NO;
	self.photosView.contentInset = (UIEdgeInsets){ 0, 12, 0, 12 };
	
	self.noPhotoReminderView.frame = self.photosView.frame;
	self.noPhotoReminderView.autoresizingMask = self.photosView.autoresizingMask;
	[self.view addSubview:self.noPhotoReminderView];
		
	UIView *photosBackgroundView = [[[UIView alloc] initWithFrame:self.photosView.frame] autorelease];
	photosBackgroundView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPhotoQueueBackground"]];
	photosBackgroundView.autoresizingMask = self.photosView.autoresizingMask;
	photosBackgroundView.layer.cornerRadius = 4.0f;
	photosBackgroundView.layer.masksToBounds = YES;
	photosBackgroundView.userInteractionEnabled = NO;
	[self.view insertSubview:photosBackgroundView atIndex:0];
	
	IRConcaveView *photosConcaveEdgeView = [[[IRConcaveView alloc] initWithFrame:self.photosView.frame] autorelease];
	photosConcaveEdgeView.autoresizingMask = self.photosView.autoresizingMask;
	photosConcaveEdgeView.backgroundColor = nil;
	photosConcaveEdgeView.innerShadow = [IRShadow shadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.5f] offset:(CGSize){ 0.0f, 1.0f } spread:3.0f];
	photosConcaveEdgeView.layer.cornerRadius = 4.0f;
	photosConcaveEdgeView.layer.masksToBounds = YES;
	photosConcaveEdgeView.userInteractionEnabled = NO;
	[self.view addSubview:photosConcaveEdgeView];

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];

	if (![[self.contentTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length])
		[self.contentTextView becomeFirstResponder];

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

	return (CGSize){ 144, 144 - 1 };

}

- (NSUInteger) numberOfItemsInGridView:(AQGridView *)gridView {

	return [self.fetchedResultsController.fetchedObjects count];

}

- (AQGridViewCell *) gridView:(AQGridView *)gridView cellForItemAtIndex:(NSUInteger)index {

	static NSString * const identifier = @"photoCell";
	
	AQGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:identifier];
	WAFile *representedFile = (WAFile *)[self.fetchedResultsController.fetchedObjects objectAtIndex:index];
	
	if (!cell) {
	
		cell = [[[AQGridViewCell alloc] initWithFrame:(CGRect){
			CGPointZero,
			[self portraitGridCellSizeForGridView:gridView]
		} reuseIdentifier:identifier] autorelease];
		
		cell.backgroundColor = nil;
		cell.contentView.backgroundColor = nil;
		cell.selectionStyle = AQGridViewCellSelectionStyleNone;
		cell.contentView.layer.shouldRasterize = YES;
		cell.contentView.layer.shadowOffset = (CGSize){ 0, 0 };
		cell.contentView.layer.shadowOpacity = 0.95f;
		cell.contentView.layer.shadowRadius = 1.0f;
		
		UIView *imageContainer = [[[UIView alloc] initWithFrame:UIEdgeInsetsInsetRect(cell.contentView.bounds, (UIEdgeInsets){ 8, 8, 8, 8 })] autorelease];
		imageContainer.layer.contentsGravity = kCAGravityResizeAspect;
		imageContainer.layer.minificationFilter = kCAFilterTrilinear;
		[cell.contentView addSubview:imageContainer];
		
	}
		
	UIImage *cellImage = [UIImage imageWithContentsOfFile:representedFile.resourceFilePath];
	UIView *imageContainer = (UIView *)[cell.contentView.subviews objectAtIndex:0];
	imageContainer.layer.contents = (id)cellImage.CGImage;
	
	return cell;

}

- (void) handleCurrentArticleFilesChangedFrom:(id)fromValue to:(id)toValue changeKind:(NSString *)changeKind {

	dispatch_async(dispatch_get_main_queue(), ^ {
	
		if (![self isViewLoaded])
			return;
			
		@try {
		
			self.noPhotoReminderView.hidden = ([self.article.files count] > 0);
		
		} @catch (NSException *e) {
		
			self.noPhotoReminderView.hidden = YES;
		
			if (![e.name isEqualToString:NSObjectInaccessibleException])
				@throw e;
			
    } @finally {
			
			[self.photosView reloadData];
		
		}
		
	});

}





- (void) handleDone:(UIBarButtonItem *)sender {

	[self.article.managedObjectContext deleteObject:self.article];
	[self.article.managedObjectContext save:nil];

	[self dismissModalViewControllerAnimated:YES];

}	

- (void) handleCancel:(UIBarButtonItem *)sender {

	[self.article.managedObjectContext deleteObject:self.article];
	[self.article.managedObjectContext save:nil];
	
	[self dismissModalViewControllerAnimated:YES];

}

- (IBAction) handleCameraItemTap:(UIButton *)sender {

	[(IRActionSheet *)[[IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:nil destructiveAction:nil otherActions:[NSArray arrayWithObjects:
	
		[IRAction actionWithTitle:@"Photo Library" block: ^ {
		
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				[self.imagePickerPopover presentPopoverFromRect:sender.bounds inView:sender permittedArrowDirections:UIPopoverArrowDirectionLeft|UIPopoverArrowDirectionRight animated:YES];
			
			});
		
		}],
		
		[IRAction actionWithTitle:@"Take Photo" block: ^ {
		
			dispatch_async(dispatch_get_main_queue(), ^ {
			
				__block __typeof__(self) nrSelf = self;

				IRImagePickerController *imagePickerController = [IRImagePickerController cameraImageCapturePickerWithCompletionBlock:^(NSURL *selectedAssetURI, ALAsset *representedAsset) {
				
					[nrSelf handleIncomingSelectedAssetURI:selectedAssetURI representedAsset:representedAsset];
					
				}];
				
				[self presentModalViewController:imagePickerController animated:YES];
			
			});
		
		}],
	
	nil]] singleUseActionSheet] showFromRect:sender.bounds inView:sender animated:YES];
	
}

- (UIPopoverController *) imagePickerPopover {

	if (imagePickerPopover)
		return imagePickerPopover;
		
	__block __typeof__(self) nrSelf = self;
		
	IRImagePickerController *imagePickerController = [IRImagePickerController photoLibraryPickerWithCompletionBlock:^(NSURL *selectedAssetURI, ALAsset *representedAsset) {
		
		[nrSelf handleIncomingSelectedAssetURI:selectedAssetURI representedAsset:representedAsset];
		
	}];
	
	self.imagePickerPopover = [[[UIPopoverController alloc] initWithContentViewController:imagePickerController] autorelease];
	
	return imagePickerPopover;

}

- (void) handleIncomingSelectedAssetURI:(NSURL *)selectedAssetURI representedAsset:(ALAsset *)representedAsset {
	
	//	Ditch the views
	
	[self.modalViewController dismissModalViewControllerAnimated:YES];
	
	if ([imagePickerPopover isPopoverVisible])
		[imagePickerPopover dismissPopoverAnimated:YES];
	
	
	if (!selectedAssetURI && !representedAsset)
		return;
	
	
	//	Copy the file away immediately
	
	NSURL *finalFileURL = nil;
	
	if (selectedAssetURI) {
	
		finalFileURL = [[WADataStore defaultStore] persistentFileURLForFileAtURL:selectedAssetURI];
	
	} else if (!selectedAssetURI && representedAsset) {
	
		finalFileURL = [[WADataStore defaultStore] persistentFileURLForData:UIImagePNGRepresentation([UIImage imageWithCGImage:[[representedAsset defaultRepresentation] fullResolutionImage]])];
			
	}
	
	
	//	Then fix stuff up
	
	dispatch_async(dispatch_get_main_queue(), ^ {
	
		WAFile *stitchedFile = (WAFile *)[WAFile objectInsertingIntoContext:self.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
		stitchedFile.resourceType = (NSString *)kUTTypeImage;
		stitchedFile.resourceURL = [finalFileURL absoluteString];
		stitchedFile.resourceFilePath = [finalFileURL path];
		stitchedFile.article = self.article;
		
		[self.managedObjectContext save:nil];
	
	});
	
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	
	return YES;
	
}

@end
