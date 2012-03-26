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

@property (nonatomic, readwrite, copy) void(^callback)(void);
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) WAArticle *article;

@property (nonatomic, readwrite, retain) id articleFilesObservingsHelper;

@property (nonatomic, readwrite, assign, getter=isUndergoingProgrammaticEntityMutation, setter=setUndergoingProgrammaticEntityMutation:) BOOL undergoingProgrammaticEntityMutation;

@end


@implementation WAAttachedMediaListViewController
@synthesize callback, tableView;
@synthesize managedObjectContext, article;
@synthesize articleFilesObservingsHelper;
@synthesize onViewDidLoad;
@synthesize undergoingProgrammaticEntityMutation;

+ (WAAttachedMediaListViewController *) controllerWithArticleURI:(NSURL *)anArticleURI completion:(void(^)(void))aBlock {

	return [[self alloc] initWithArticleURI:anArticleURI completion:aBlock];

}

- (id) init {

	return [self initWithArticleURI:nil completion:nil];

}

- (WAAttachedMediaListViewController *) initWithArticleURI:(NSURL *)anArticleURI completion:(void (^)(void))aBlock {
	
	return [self initWithArticleURI:anArticleURI usingContext:nil completion:aBlock];

}

- (WAAttachedMediaListViewController *) initWithArticleURI:(NSURL *)anArticleURI usingContext:(NSManagedObjectContext *)aContext completion:(void (^)(void))aBlock {

	self = [super init];
	if (!self)
		return nil;
	
	__block __typeof__(self) nrSelf = self;
	
	self.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemDone wiredAction:^(IRBarButtonItem *senderItem) {
		
		if (nrSelf.callback)
			nrSelf.callback();
		
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
	
	self.articleFilesObservingsHelper =  [self.article irAddObserverBlock: ^ (id inOldValue, id inNewValue, NSKeyValueChange changeKind) {
	
		if (![nrSelf isViewLoaded])
			return;
		
		if ([nrSelf isUndergoingProgrammaticEntityMutation])
			return;
		
		[nrSelf.tableView reloadData];
		
		// Fixme: Use NSFRC
		// Fixme: Also remove dupe KVO invocations
		
	} forKeyPath:@"files" options:NSKeyValueObservingOptionNew context:nil];
  
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleManagedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
	
	return self;

}

- (void) dealloc {

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[article irRemoveObservingsHelper:self.articleFilesObservingsHelper];
	
}

- (void) handleManagedObjectContextDidSave:(NSNotification *)aNotification {

	if (![NSThread isMainThread]) {

		dispatch_sync(dispatch_get_main_queue(), ^ {
			[self handleManagedObjectContextDidSave:aNotification];
		});
		return;
		
	}
	
	NSManagedObjectContext *savedContext = (NSManagedObjectContext *)[aNotification object];
	
	if (savedContext == self.managedObjectContext) {
		if ([self isViewLoaded]) {
			[self.tableView reloadData];
		}
		return;
	}
	
	[self.managedObjectContext mergeChangesFromContextDidSaveNotification:aNotification];
	[self.managedObjectContext refreshObject:self.article mergeChanges:YES];
	
	if ([self isViewLoaded]) {
		[self.tableView reloadData];
	}

}

- (void) loadView {

	self.view = [[WAView alloc] initWithFrame:[UIApplication sharedApplication].keyWindow.rootViewController.view.bounds];
	
	tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.rowHeight = 76.0f; // plus 1 to get UIImageView in right size
	self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
	[self.view addSubview:self.tableView];
	
}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	if (self.onViewDidLoad)
		self.onViewDidLoad();

}

- (void) viewDidUnload {

	[super viewDidUnload];

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
		
		[self.tableView beginUpdates];
		
		self.undergoingProgrammaticEntityMutation = YES;
		
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
		[self.article removeFilesObject:removedFile];

		self.undergoingProgrammaticEntityMutation = NO;
		
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
		
		cell = [[WATableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
		cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	NSURL *fileURI = [self.article.fileOrder objectAtIndex:indexPath.row];
	WAFile *representedFile = (WAFile *)[[self.article.files objectsPassingTest: ^ (id obj, BOOL *stop) {
	
		BOOL objectMatches = [[[obj objectID] URIRepresentation] isEqual:fileURI];
		
		if (objectMatches)
			*stop = YES;
		
		return objectMatches;
		
	}] anyObject];
	
	UIImage *actualImage = representedFile.resourceImage;
  
  cell.imageView.image = representedFile.thumbnail;
	cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  
	cell.textLabel.text = [NSString stringWithFormat:@"%1.0f × %1.0f", 
    actualImage.size.width,
    actualImage.size.height
  ];
  
  NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:representedFile.resourceFilePath error:nil];
  long fileSize = [[fileAttributes objectForKey:NSFileSize] longValue];
 	cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0fK", (float)fileSize/(1024.0)];
	
	return cell;

}

#pragma ---MOVE---

-(BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

-(void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath{
	
	NSURL *fromURL = [self.article.fileOrder objectAtIndex:[sourceIndexPath row]];
	[self.article.fileOrder removeObjectAtIndex:[sourceIndexPath row]];
	[self.article.fileOrder insertObject:fromURL atIndex:[destinationIndexPath row]];
}
@end
