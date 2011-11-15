//
//  WAComposeViewControllerPhone.m
//  wammer-iOS
//
//  Created by jamie on 8/11/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "IRImagePickerController.h"

#import "WAComposeViewControllerPhone.h"
#import "WADataStore.h"
#import "WAAttachedMediaListViewController.h"

#import "IRGradientView.h"


@interface WAComposeViewControllerPhone () <UITextViewDelegate>

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) WAArticle *post;
@property (nonatomic, copy) void (^completionBlock)(NSURL *returnedURI);
@property (nonatomic, retain) NSURL *urlForPreview;

- (void) handleIncomingSelectedAssetURI:(NSURL *)selectedAssetURI representedAsset:(ALAsset *)representedAsset;

@end

@implementation WAComposeViewControllerPhone
@synthesize managedObjectContext, post;
@synthesize contentTextView;
@synthesize contentContainerView;
@synthesize attachmentsListViewControllerHeaderView;
@synthesize completionBlock;
@synthesize toolbar;
@synthesize urlForPreview;

+ (WAComposeViewControllerPhone *)controllerWithPost:(NSURL *)aPostURLOrNil completion:(void (^)(NSURL *))aBlock
{
    WAComposeViewControllerPhone *returnedController = [[[self alloc] init] autorelease];
    returnedController.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
    returnedController.post = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:aPostURLOrNil];
    
    if (!returnedController.post) {
        returnedController.post = [WAArticle objectInsertingIntoContext:returnedController.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
        returnedController.post.draft = [NSNumber numberWithBool:YES]; 
    }
    returnedController.completionBlock = aBlock;
    
    return returnedController;
}
+ (WAComposeViewControllerPhone *) controllerWithWebPost:(NSURL *) anURLOrNil completion:(void(^)(NSURL *anURLOrNil))aBlock
{
  WAComposeViewControllerPhone *returnedController = [[[self alloc] init] autorelease];
  returnedController.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
  returnedController.post = (WAArticle *)[returnedController.managedObjectContext irManagedObjectForURI:nil];
  
  if (!returnedController.post) {
    returnedController.post = [WAArticle objectInsertingIntoContext:returnedController.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
    returnedController.post.draft = [NSNumber numberWithBool:YES]; 
  }
  returnedController.completionBlock = aBlock;
  returnedController.post.text = [anURLOrNil description];
  returnedController.urlForPreview = anURLOrNil;
  return returnedController;
}

- (id)init
{
    return [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
		
	self.title = @"Compose";
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCancel:)] autorelease];
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleBordered target:self action:@selector(handleDone:)] autorelease];
	self.navigationItem.rightBarButtonItem.enabled = NO;
	
	self.navigationItem.titleView = ((^ {	
		
		IRTransparentToolbar *centerToolbar = [[[IRTransparentToolbar alloc] initWithFrame:(CGRect){ 0, 0, 128, 44 }] autorelease];
		centerToolbar.usesCustomLayout = NO;
		centerToolbar.items = [NSArray arrayWithObjects:
			[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemFlexibleSpace wiredAction:nil],
			[[[UIBarButtonItem alloc] initWithTitle:@"Attachment" style:UIBarButtonItemStyleBordered target:self action:@selector(handleCameraItemTap:)] autorelease],	
			[IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemFlexibleSpace wiredAction:nil],
		nil];
		centerToolbar.frame = (CGRect){ (CGPoint){ 0, -1 }, centerToolbar.frame.size };
		centerToolbar.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		
		UIView *wrapper = [[[UIView alloc] initWithFrame:centerToolbar.frame] autorelease];
		[wrapper addSubview:centerToolbar];
		wrapper.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		
		return wrapper;
		
	})());
	
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardNotification:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardNotification:) name:UIKeyboardDidShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleManagedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];

 	return self;
}


- (void) setPost:(WAArticle *)newPost {
    
	//	__block __typeof__(self) nrSelf = self;
    
	[self willChangeValueForKey:@"post"];
	
	[post irRemoveObserverBlocksForKeyPath:@"files"];	
	[post release];
	post = [newPost retain];
		
	[self didChangeValueForKey:@"post"];
	
}

- (void) handleManagedObjectContextDidSave:(NSNotification *)aNotification {

	NSManagedObjectContext *savedContext = (NSManagedObjectContext *)[aNotification object];
	
	if (savedContext == self.managedObjectContext)
		return;
	
	if ([NSThread isMainThread])
		[self retain];
	else
		dispatch_sync(dispatch_get_main_queue(), ^ { [self retain]; });
	
	dispatch_async(dispatch_get_main_queue(), ^ {
	
		[self.managedObjectContext mergeChangesFromContextDidSaveNotification:aNotification];
		[self.managedObjectContext refreshObject:self.post mergeChanges:YES];
		
		if ([self isViewLoaded]) {
		
			//	Refresh view
		
		}
			
		[self autorelease];
	
	});

}

- (IBAction) handleCameraItemTap:(id)sender {

	__block WAAttachedMediaListViewController *controller = nil;
	//	__block __typeof__(self) nrSelf = self;
	//	[self.post.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:self.post] error:nil];
	
	NSLog(@"self.post %@", self.post);
	
	if ([self.post.objectID isTemporaryID]) {
		NSError *permanentIDObtainingError = nil;
		if (![self.post.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:self.post] error:&permanentIDObtainingError])
			NSLog(@"Error obtaining permanent ID: %@", permanentIDObtainingError);
	}
	
	NSLog(@"post = %@", self.post);

  controller = [WAAttachedMediaListViewController controllerWithArticleURI:[[self.post objectID] URIRepresentation] completion: ^ (NSURL *objectURI) {
		[controller dismissModalViewControllerAnimated:YES];
	}];
	
	controller.headerView = self.attachmentsListViewControllerHeaderView;
	UINavigationController *wrapper = [[[UINavigationController alloc] initWithRootViewController:controller] autorelease];
 
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil];
  [self.navigationController presentModalViewController:wrapper animated:YES];
	
}

- (void) handleAttachmentAddFromCameraItemTap:(id)sender {

	if (![IRImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
		return;
		
	__block IRImagePickerController *imagePickerController = [IRImagePickerController cameraCapturePickerWithCompletionBlock:^(NSURL *selectedAssetURI, ALAsset *representedAsset) {
	
		[self handleIncomingSelectedAssetURI:selectedAssetURI representedAsset:representedAsset];
		[imagePickerController dismissModalViewControllerAnimated:YES];
		
	}];
	
	//	[imagePickerController.view addSubview:((^ {
	//		UIView *decorativeView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 480, 20 }] autorelease];
	//		decorativeView.backgroundColor = [UIColor blackColor];
	//		return decorativeView;
	//	})())];

	[(self.modalViewController ? self.modalViewController : self) presentModalViewController:imagePickerController animated:YES];

}

- (void) handleAttachmentAddFromPhotosLibraryItemTap:(id)sender {

	if (![IRImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	
	__block IRImagePickerController *imagePickerController = [IRImagePickerController photoLibraryPickerWithCompletionBlock:^(NSURL *selectedAssetURI, ALAsset *representedAsset) {
	
		[self handleIncomingSelectedAssetURI:selectedAssetURI representedAsset:representedAsset];
		[imagePickerController dismissModalViewControllerAnimated:YES];
		
	}];
	
	[imagePickerController.view addSubview:((^ {
		UIView *decorativeView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 480, 20 }] autorelease];
		decorativeView.backgroundColor = [UIColor blackColor];
		return decorativeView;
	})())];
	
	[(self.modalViewController ? self.modalViewController : self) presentModalViewController:imagePickerController animated:YES];

}


- (void) handleDone:(UIBarButtonItem *)sender {
    
	//	Deleting all the changed stuff and saving is like throwing all the stuff away
	//	In that sense just don’t do anything.

	//	TBD save a draft
  self.post.text = self.contentTextView.text;
	
	NSError *savingError = nil;
	if (![self.managedObjectContext save:&savingError])
		NSLog(@"Error saving: %@", savingError);
	
	if (self.completionBlock)
		self.completionBlock([[self.post objectID] URIRepresentation]);
	
	[self.parentViewController dismissModalViewControllerAnimated:YES];
    
}	

- (void) handleCancel:(UIBarButtonItem *)sender {
    
	[self.navigationController dismissModalViewControllerAnimated:YES];
    
}

- (void) handleKeyboardNotification:(NSNotification *)aNotification {

	NSDictionary *userInfo = [aNotification userInfo];
	CGRect globalFinalKeyboardRect = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGRect keyboardRectInView = [self.view.window convertRect:globalFinalKeyboardRect toView:self.view];
	CGRect usableRect = CGRectNull, tempRect = CGRectNull;
	CGRectDivide(self.view.bounds, &usableRect, &tempRect, CGRectGetMinY(keyboardRectInView), CGRectMinYEdge);
	
	self.contentContainerView.frame = usableRect;

}

- (void)textViewDidChange:(UITextView *)textView {
	self.navigationItem.rightBarButtonItem.enabled = self.contentTextView.hasText;
}

#pragma mark - View lifecycle

- (void) viewDidLoad {
	
	[super viewDidLoad];
  
  NSLog(@"Trigger preview API and display it later.");
	
  self.contentTextView.text = self.post.text;
	[self.contentTextView becomeFirstResponder];
	
	self.navigationItem.titleView.bounds = (CGRect){
		CGPointZero,
		(CGSize){
			self.navigationItem.titleView.frame.size.width,
			self.navigationController.navigationBar.frame.size.height
		}
	};
	
	self.navigationItem.titleView.center = (CGPoint){
		CGRectGetMidX(self.navigationController.navigationBar.bounds),
		CGRectGetMidY(self.navigationController.navigationBar.bounds)
	};
	
	IRGradientView *toolbarGradient = [[[IRGradientView alloc] initWithFrame:self.toolbar.frame] autorelease];
	[toolbarGradient setLinearGradientFromColor:[UIColor colorWithWhite:.95 alpha:1] anchor:irTop toColor:[UIColor colorWithWhite:.75 alpha:1] anchor:irBottom];
	toolbarGradient.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleWidth;
	[toolbarGradient addSubview:((^ {
		UIView *separatorView = [[[UIView alloc] initWithFrame:(CGRect){
			CGPointZero,
			(CGSize){
				CGRectGetWidth(toolbarGradient.frame),
				1
			}
		}] autorelease];
		separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
		separatorView.backgroundColor = [UIColor colorWithWhite:0.65 alpha:1];
		return separatorView;
	})())];
	[toolbarGradient addSubview:((^ {
		UIView *separatorView = [[[UIView alloc] initWithFrame:(CGRect){
			(CGPoint){
				0,
				1
			},
			(CGSize){
				CGRectGetWidth(toolbarGradient.frame),
				1
			}
		}] autorelease];
		separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
		separatorView.backgroundColor = [UIColor colorWithWhite:1 alpha:1];
		return separatorView;
	})())];
	[self.toolbar.superview insertSubview:toolbarGradient belowSubview:self.toolbar];
		
}

- (void) viewDidUnload {

	self.contentTextView = nil;
	self.contentContainerView = nil;
	self.attachmentsListViewControllerHeaderView = nil;
	self.toolbar = nil;
	[super viewDidUnload];
	
}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[contentTextView release];
	[contentContainerView release];
	[attachmentsListViewControllerHeaderView release];
	[toolbar release];
	[urlForPreview release];
	[super dealloc];
}

- (void) handleIncomingSelectedAssetURI:(NSURL *)selectedAssetURI representedAsset:(ALAsset *)representedAsset {
	
	if (!selectedAssetURI)
	if (!representedAsset)
		return;

	NSURL *finalFileURL = nil;
	NSLog(@"%@", selectedAssetURI);
	if (selectedAssetURI){
    UIImage *image = [UIImage imageWithData:(NSData *)[NSData dataWithContentsOfURL:selectedAssetURI]];
    CGSize imageSize = [image size];
    CGSize thumbSize;
    if (imageSize.height > imageSize.width) {
      thumbSize = CGSizeMake(360.0, 480.0);
    } else {
      thumbSize = CGSizeMake(480.0, 360.0);
    }
    UIGraphicsBeginImageContext(thumbSize);
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    finalFileURL = [[WADataStore defaultStore] persistentFileURLForData:
                    UIImageJPEGRepresentation(newImage, 0.95) extension:@"jpeg"];
  }
	
	if (!finalFileURL)
	if (!selectedAssetURI && representedAsset)
		finalFileURL = [[WADataStore defaultStore] persistentFileURLForData:UIImageJPEGRepresentation([UIImage imageWithCGImage:[[representedAsset defaultRepresentation] fullScreenImage]], 0.95) extension:@"jpeg"];
	
  
	WAFile *stitchedFile = (WAFile *)[WAFile objectInsertingIntoContext:self.managedObjectContext withRemoteDictionary:[NSDictionary dictionary]];
	stitchedFile.resourceType = (NSString *)kUTTypeImage;
	stitchedFile.resourceURL = [finalFileURL absoluteString];
	stitchedFile.resourceFilePath = [finalFileURL path];
	stitchedFile.article = self.post;
	
	NSError *savingError = nil;
	if (![self.managedObjectContext save:&savingError])
		NSLog(@"Error saving: %@", savingError);
	
}

@end
