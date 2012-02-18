//
//  WAAttachedMediaListViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/26/11.
//  Copyright 2011 Waveface Inc. All rights reserved.
//

#import "WAAttachedMediaListViewController.h"
#import "WAView.h"
#import "WADataStore.h"
#import "WATableViewCell.h"

#import "QuartzCore+IRAdditions.h"


@interface WAAttachedMediaListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, readwrite, copy) void(^callback)(NSURL *objectURI);
@property (nonatomic, readwrite, retain) UITableView *tableView;

@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) WAArticle *article;

@end


@implementation WAAttachedMediaListViewController
@synthesize callback, headerView, tableView;
@synthesize managedObjectContext, article;

+ (WAAttachedMediaListViewController *) controllerWithArticleURI:(NSURL *)anArticleURI completion:(void(^)(NSURL *objectURI))aBlock {

	return [[[self alloc] initWithArticleURI:anArticleURI completion:aBlock] autorelease];

}

- (id) init {

	return [self initWithArticleURI:nil completion:nil];

}

- (WAAttachedMediaListViewController *) initWithArticleURI:(NSURL *)anArticleURI completion:(void (^)(NSURL *))aBlock {
	
	return [self initWithArticleURI:anArticleURI usingContext:nil completion:aBlock];

}

- (WAAttachedMediaListViewController *) initWithArticleURI:(NSURL *)anArticleURI usingContext:(NSManagedObjectContext *)aContext completion:(void (^)(NSURL *))aBlock {

	self = [super init];
	if (!self)
		return nil;
	
	__block __typeof__(self) nrSelf = self;
	
	self.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemDone wiredAction:^(IRBarButtonItem *senderItem) {
		
		if (nrSelf.callback)
			nrSelf.callback(nil);
		
	}];
	
	self.callback = aBlock;
	self.title = @"Attachments";
	
	if (aContext) {
		self.managedObjectContext = aContext;
	} else {
		self.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
		self.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;		
	}
	
	self.article = (WAArticle *)[self.managedObjectContext irManagedObjectForURI:anArticleURI];
  
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleManagedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
	
	return self;

}

- (void) dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[managedObjectContext release];
	[article release];

	[callback release];
	[headerView release];
	[super dealloc];

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
		[self.managedObjectContext refreshObject:self.article mergeChanges:YES];
		
		if ([self isViewLoaded]) {
			[self.tableView reloadData];
		}
			
		[self autorelease];
	
	});

}

- (void) loadView {

	self.view = [[[WAView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.rootViewController.view.bounds] autorelease]; // dummy size for autoresizing
	
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPhotoQueueBackground"]];
	
	self.tableView = [[[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain] autorelease];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.rowHeight = 65.0f; // plus 1 to get UIImageView in right size
  self.tableView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLineEtched;
	[self.view addSubview:self.tableView];
  
	__block __typeof__(self) nrSelf = self;
	
	((WAView *)self.view).onLayoutSubviews = ^ {
	
		//	Handle header view conf
		
		CGFloat headerViewHeight = 0.0f;
		
		if (nrSelf.headerView) {
			[nrSelf.view addSubview:nrSelf.headerView];
			headerViewHeight = CGRectGetHeight(nrSelf.headerView.bounds);
		}
			
		nrSelf.headerView.frame = (CGRect){
			CGPointZero,
			(CGSize){
				CGRectGetWidth(nrSelf.view.bounds),
				CGRectGetHeight(nrSelf.headerView.bounds)
			}
		};
		
		nrSelf.tableView.frame = (CGRect){
			(CGPoint){
				0,
				headerViewHeight
			},
			(CGSize){
				CGRectGetWidth(nrSelf.view.bounds),
				CGRectGetHeight(nrSelf.view.bounds) - headerViewHeight
			}
		};
		
		//	Relocate table view
	
	};

}

- (void) viewDidUnload {

	[super viewDidUnload];

}
- (void) setHeaderView:(UIView *)newHeaderView {

	if (headerView == newHeaderView)
		return;
	
	if ([self isViewLoaded])
		if ([headerView isDescendantOfView:self.view])
			[headerView removeFromSuperview];
	
	[self willChangeValueForKey:@"headerView"];
	[headerView release];
	headerView = [newHeaderView retain];
	[self didChangeValueForKey:@"headerView"];
	
	if ([self isViewLoaded])
		[self.view setNeedsLayout];

} 

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {

	return 1;

}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

	return [self.article.files count];

}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {

	switch (editingStyle) {
	case UITableViewCellEditingStyleDelete: {
		
		NSUInteger deletedFileIndex = indexPath.row;
		NSURL *deletedFileURI = [self.article.fileOrder objectAtIndex:deletedFileIndex];
		WAFile *removedFile = (WAFile *)[self.managedObjectContext irManagedObjectForURI:deletedFileURI];
		removedFile.article = nil;
		
		[self.article removeFilesObject:removedFile];

		NSError *savingError = nil;
		if (![self.managedObjectContext save:&savingError]) {
			
			id oldMergePolicy = [[self.managedObjectContext.mergePolicy retain] autorelease];
			self.managedObjectContext.mergePolicy = NSOverwriteMergePolicy; //hmph
			NSLog(@"Error saving: %@", savingError);
			
			if (![self.managedObjectContext save:&savingError])
				NSLog(@"%s failed spectacularly", __PRETTY_FUNCTION__);
			
			self.managedObjectContext.mergePolicy = oldMergePolicy;
			
		}
		
		
			
		[self.tableView beginUpdates];
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
		[self.tableView endUpdates];
		
		break;
		
	}
	case UITableViewCellEditingStyleNone: {
		break;
	};
	case UITableViewCellEditingStyleInsert: {
		break;
	}
	}

}

- (UITableViewCell *) tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	static NSString *identifier = @"Identifier";
	
	WATableViewCell *cell = (WATableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:identifier];
	if (!cell) {
		
		cell = [[[WATableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
		cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.indentationWidth = 8.0f;
    
		cell.onSetEditing = ^ (WATableViewCell *self, BOOL editing, BOOL animated) {

			if (editing) {
				self.indentationLevel = 1;
			} else {
				self.indentationLevel = 0;
			}
		
		};

	}
	
	NSURL *fileURI = [self.article.fileOrder objectAtIndex:indexPath.row];
	WAFile *representedFile = (WAFile *)[[self.article.files objectsPassingTest: ^ (id obj, BOOL *stop) {
	
		BOOL objectMatches = [[[obj objectID] URIRepresentation] isEqual:fileURI];
		
		if (objectMatches)
			*stop = YES;
		
		return objectMatches;
		
	}] anyObject];
	
	UIImage *actualImage = representedFile.resourceImage;
  UIImage *croppedImage = nil;
  
  CGRect imageRect = (CGRect){
    CGPointZero,
    (CGSize){ aTableView.rowHeight, aTableView.rowHeight }
  };

  //TODO fix the blur problem
  UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, 0.0);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSaveGState(context);
  CGContextSetShouldAntialias(context, NO);
  CGContextSetAllowsAntialiasing(context, NO);
  CGContextClipToRect(context, imageRect);
  [actualImage drawInRect:IRGravitize(imageRect, actualImage.size, kCAGravityResizeAspectFill)];
  croppedImage = UIGraphicsGetImageFromCurrentImageContext();
  CGContextRestoreGState(context);
  UIGraphicsEndImageContext();
  
  cell.imageView.image = croppedImage;
  
	cell.textLabel.text = [NSString stringWithFormat:@"%1.0f × %1.0f", 
    actualImage.size.width,
    actualImage.size.height
  ];
  
  NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:representedFile.resourceFilePath error:nil];
  long fileSize = [[fileAttributes objectForKey:NSFileSize] longValue];
 	cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0fK", (float)fileSize/(1024.0)];
	
	return cell;

}

@end
