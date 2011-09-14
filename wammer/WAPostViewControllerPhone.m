//
//  WAPostViewController.m
//  wammer-iOS
//
//  Created by jamie on 8/11/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAPostViewControllerPhone.h"
#import "WAComposeViewControllerPhone.h"
#import "WADataStore.h"
#import "WAArticleCommentsViewCell.h"
#import "WAPostViewCellPhone.h"
#import "WAArticle.h"

#import "WAGalleryViewController.h"
#import "WARemoteInterface.h"
#import "WAComposeCommentViewControllerPhone.h"

#import "IRShapeView.h"
#import "IRTableView.h"

static NSString * const WAPostViewControllerPhone_RepresentedObjectURI = @"WAPostViewControllerPhone_RepresentedObjectURI";
static NSString * const kWAPostViewCellFloatsAbove = @"kWAPostViewCellFloatsAbove";

@interface WAPostViewControllerPhone () <NSFetchedResultsControllerDelegate, WAImageStackViewDelegate>

@property (nonatomic, readwrite, retain) WAArticle *post;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;

- (void) didFinishComposingComment:(NSString *)commentText;
- (void) cellViewWithDecoration:(WAPostViewCellPhone *)cell;
- (void) refreshData;

+ (IRRelativeDateFormatter *) relativeDateFormatter;


@end


@implementation WAPostViewControllerPhone
@synthesize post, fetchedResultsController, managedObjectContext;

+ (WAPostViewControllerPhone *) controllerWithPost:(NSURL *)postURL{
    
    WAPostViewControllerPhone *controller = [[self alloc] initWithStyle:UITableViewStylePlain];
    
    controller.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
    controller.post = (WAArticle *)[controller.managedObjectContext irManagedObjectForURI:postURL];
    
    return controller;
}

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if(!self)
    return nil;
 
  self.title = @"Post";
  self.navigationItem.rightBarButtonItem  = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(handleCompose:)]autorelease];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleManagedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
  
  return self;

}

- (void) loadView {

	self.tableView = [[IRTableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
	self.view = self.tableView;
	
	__block IRTableView *nrTV = ((IRTableView *)self.tableView);
	nrTV.onLayoutSubviews = ^ {
		
		for (UIView *aSubview in nrTV.subviews)
		if (objc_getAssociatedObject(aSubview, &kWAPostViewCellFloatsAbove) == (id)kCFBooleanTrue) {

			[aSubview.superview bringSubviewToFront:aSubview];
			
			for (UIView *aCellSubview in aSubview.subviews) {
				
				aCellSubview.hidden = NO;
			
				if (CGRectGetHeight(aCellSubview.frame) == 1)
				if (CGRectGetMaxY(aCellSubview.frame) == CGRectGetHeight(aSubview.bounds)) {
					aCellSubview.hidden = YES;
				}
				
			}
			
		}
		
	};
	
	self.tableView.delegate = self;
	self.tableView.dataSource = self;

}

- (void) handleManagedObjectContextDidSave:(NSNotification *)aNotification {
  
  NSLog(@"%@: a managed object context saved, merge it", self);
  
  if (aNotification.object == self.managedObjectContext)
    return;
  
  [self.managedObjectContext mergeChangesFromContextDidSaveNotification:aNotification];
  
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
  
  //  This method will be called initially to populate the table view, and also on updates so the table view shows newly composed comments
  
  void (^operation)() = ^ {
  
    if (![self isViewLoaded])
      return;
      
    [self.tableView reloadData];
		[self.tableView layoutSubviews];
		[self.tableView setNeedsLayout];
    
    NSIndexPath *indexPathForLastCell = [NSIndexPath indexPathForRow:([self.fetchedResultsController.fetchedObjects count] - 1) inSection:1];
    
    if (indexPathForLastCell) {
      [self.tableView scrollToRowAtIndexPath:indexPathForLastCell atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
  
  };
  
  if ([NSThread isMainThread])
    operation();
  else
    dispatch_async(dispatch_get_main_queue(), operation);

}

- (void) dealloc {
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [super dealloc];
  
}

- (NSFetchedResultsController *) fetchedResultsController {
    
	if (fetchedResultsController)
		return fetchedResultsController;
	
	if (!self.post)
		return nil;
    
	NSFetchRequest *fetchRequest = [self.managedObjectContext.persistentStoreCoordinator.managedObjectModel 
                                    fetchRequestFromTemplateWithName:@"WAFRCommentsForArticle" 
                                    substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:self.post, @"Article",nil]];
	
	fetchRequest.sortDescriptors = [NSArray arrayWithObjects:
                                    [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
                                    nil];
	
	self.fetchedResultsController = [[[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil] autorelease];
	
	self.fetchedResultsController.delegate = self;
	
	NSError *fetchingError = nil;
	if (![fetchedResultsController performFetch:&fetchingError])
		NSLog(@"Error fetching: %@", fetchingError);
	
	return fetchedResultsController;
    
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)showCompose:(UIBarButtonItem *)sender
{
  [self.navigationController pushViewController:[[WAComposeCommentViewControllerPhone alloc] init] animated:YES];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
		[self.tableView setNeedsLayout];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
	[self.tableView layoutSubviews];
	[self.tableView setNeedsLayout];
  [super viewWillAppear:animated];
  [self refreshData];
	[self.tableView layoutSubviews];
	[self.tableView setNeedsLayout];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == 0)
        return 1;
    else
        return [[[self post] comments] count];
}

- (void)cellViewWithDecoration:(WAPostViewCellPhone *)cell {
  objc_setAssociatedObject(cell, &kWAPostViewCellFloatsAbove, (id)kCFBooleanTrue, OBJC_ASSOCIATION_ASSIGN);
  
  cell.backgroundView = [[[UIView alloc] initWithFrame:cell.bounds] autorelease];
  cell.clipsToBounds = NO;
  cell.backgroundView.clipsToBounds = NO;
  cell.backgroundView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
  
  [cell.backgroundView addSubview:((^ {
    
    static const CGRect triangle = (CGRect){ 0, 0, 16, 12 };
    IRShapeView *decorativeTriangleView = [[[IRShapeView alloc] initWithFrame:triangle] autorelease];
    decorativeTriangleView.layer.path = (( ^ {
      UIBezierPath *path = [UIBezierPath bezierPath];
      [path moveToPoint:(CGPoint){
        CGRectGetMidX(triangle),
        CGRectGetMinY(triangle)
      }];
      [path addLineToPoint:(CGPoint){
        CGRectGetMaxX(triangle),
        CGRectGetMaxY(triangle)
      }];
      [path addLineToPoint:(CGPoint){
        CGRectGetMinX(triangle),
        CGRectGetMaxY(triangle)
      }];
      [path addLineToPoint:(CGPoint){
        CGRectGetMidX(triangle),
        CGRectGetMinY(triangle)
      }];
      return path;
    })()).CGPath;
    decorativeTriangleView.layer.fillColor = [UIColor whiteColor].CGColor;
    
    decorativeTriangleView.frame = (CGRect){
      (CGPoint){
        CGRectGetMinX(cell.backgroundView.frame) + 16,
        CGRectGetMaxY(cell.backgroundView.frame) - CGRectGetHeight(triangle) + 2,
      },
      triangle.size
    };
    
    decorativeTriangleView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin;
    
    return decorativeTriangleView;
    
  })())];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Section 0 for post cell
    if( [indexPath section] == 0) {
        //TODO the cell style need to use Image && Comment for settings rather than 4 different style which grows exponentially
      static NSString *defaultCellIdentifier = @"PostCell-Default";
      static NSString *imageCellIdentifier = @"PostCell-Stacked";
      
      BOOL postHasFiles = (BOOL)!![post.files count];
      
      NSString *identifier = postHasFiles ? imageCellIdentifier : defaultCellIdentifier;
      
      WAPostViewCellStyle style = postHasFiles ? WAPostViewCellStyleImageStack : WAPostViewCellStyleDefault;
      
      WAPostViewCellPhone *cell = (WAPostViewCellPhone *)[tableView dequeueReusableCellWithIdentifier:identifier];
      if(!cell) {
			       
				cell = [[WAPostViewCellPhone alloc] initWithPostViewCellStyle:style reuseIdentifier:identifier];
        cell.imageStackView.delegate = self;
        
				[self cellViewWithDecoration:cell];
      }
			
      NSLog(@"Post ID: %@ with WAPostViewCellStyle %d and Text %@", [post identifier], style, post.text);
      cell.userNicknameLabel.text = post.owner.nickname;
      cell.avatarView.image = post.owner.avatar;
      cell.commentLabel.text = post.text;
      cell.dateLabel.text = [NSString stringWithFormat:@"%@ %@", 
                             [[[self class] relativeDateFormatter] stringFromDate:post.timestamp], 
                             [NSString stringWithFormat:@"via %@", post.creationDeviceName]];
      cell.originLabel.text = [NSString stringWithFormat:@"via %@", post.creationDeviceName];
      
      if (cell.imageStackView)
        objc_setAssociatedObject(cell.imageStackView, &WAPostViewControllerPhone_RepresentedObjectURI, [[post objectID] URIRepresentation], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      
      NSArray *allFilePaths = [post.fileOrder irMap: ^ (id inObject, int index, BOOL *stop) {
        
        return ((WAFile *)[[post.files objectsPassingTest: ^ (WAFile *aFile, BOOL *stop) {		
          return [[[aFile objectID] URIRepresentation] isEqual:inObject];
        }] anyObject]).resourceFilePath;
        
      }];
      
      if ([allFilePaths count] == [post.files count]) {
        
        cell.imageStackView.images = [allFilePaths irMap: ^ (NSString *aPath, int index, BOOL *stop) {
          
          return [UIImage imageWithContentsOfFile:aPath];
          
        }];
        
      } else {
        cell.imageStackView.images = nil;
      }
      
      return cell;
    }
    
    // Section 2 for comment cell
    NSIndexPath *commentIndexPath = [NSIndexPath indexPathForRow:[indexPath row] inSection:0];
    WAComment *representedComment = (WAComment *)[self.fetchedResultsController objectAtIndexPath:commentIndexPath];
	
	WAPostViewCellPhone *cell = (WAPostViewCellPhone *)[tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
		cell = [[[WAPostViewCellPhone alloc] initWithPostViewCellStyle:WAPostViewCellStyleDefault reuseIdentifier:@"Cell"] autorelease];
    
	cell.userNicknameLabel.text = representedComment.owner.nickname;
	cell.avatarView.image = representedComment.owner.avatar;
	cell.commentLabel.text = representedComment.text;
	cell.dateLabel.text = [[[self class] relativeDateFormatter] stringFromDate:post.timestamp];

    [representedComment.timestamp description];
	cell.originLabel.text = representedComment.creationDeviceName;
	
    return cell;
}

- (void) handleCompose:(UIBarButtonItem *)sender
{

  WAComposeCommentViewControllerPhone *ccvc = [WAComposeCommentViewControllerPhone controllerWithPost:[[self.post objectID] URIRepresentation] 
                                                                                           completion:nil];
  
  [self.navigationController pushViewController:ccvc animated:YES];
}

- (void) didFinishComposingComment:(NSString *)commentText 
{
	
	WAArticle *currentArticle = self.post;
	NSString *currentArticleIdentifier = currentArticle.identifier;
	NSString *currentUserIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"WhoAmI"];
	
	[[WARemoteInterface sharedInterface] createCommentAsUser:currentUserIdentifier forArticle:currentArticleIdentifier withText:commentText usingDevice:[UIDevice currentDevice].model onSuccess:^(NSDictionary *createdCommentRep) {
		
		NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
		
		NSMutableDictionary *mutatedCommentRep = [[createdCommentRep mutableCopy] autorelease];
		
		if ([createdCommentRep objectForKey:@"creator_id"]) {
			[mutatedCommentRep setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [createdCommentRep objectForKey:@"creator_id"], @"id",
                                    nil] forKey:@"owner"];
		}
		
		if ([createdCommentRep objectForKey:@"post_id"]) {
			[mutatedCommentRep setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [createdCommentRep objectForKey:@"post_id"], @"id",
                                    nil] forKey:@"article"];
		}
		
		NSArray *insertedComments = [WAComment insertOrUpdateObjectsUsingContext:context 
                                                          withRemoteResponse:[NSArray arrayWithObjects:
                                                                              mutatedCommentRep,
                                                                              nil] 
                                                                usingMapping:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                              @"WAFile", @"files",
                                                                              @"WAArticle", @"article",
                                                                              @"WAUser", @"owner",
                                                                              nil] 
                                                                     options:0];
		
		for (WAComment *aComment in insertedComments)
			if (!aComment.timestamp)
				aComment.timestamp = [NSDate date];
		
		NSError *savingError = nil;
		if (![context save:&savingError])
			NSLog(@"Error saving: %@", savingError);
		
	} onFailure:^(NSError *error) {
		
		NSLog(@"Error: %@", error);
		
	}];
	
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void) refreshData {
  
 NSLog(@"%s TBD", __PRETTY_FUNCTION__);

}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  WAArticle *po = [self post];
  
  NSString *text;
  CGFloat height = 48.0;
  if([indexPath section]==0){
     text = [po text];
    if( [post.files count ] > 0)
      height += 170.0;
    
    if( [post.comments count] > 0)
      height += 40.0;
  }else{
    NSIndexPath *commentIndexPath = [NSIndexPath indexPathForRow:[indexPath row] inSection:0];
    WAComment *representedComment = (WAComment *)[self.fetchedResultsController objectAtIndexPath:commentIndexPath];
    text = [representedComment text];
    height += 32.0;
  }
  height += [text sizeWithFont:[UIFont fontWithName:@"Helvetica" size:14.0] constrainedToSize:CGSizeMake(240.0, 9999.0) lineBreakMode:UILineBreakModeWordWrap].height;
  
  return MAX(height,100);
}

+ (IRRelativeDateFormatter *) relativeDateFormatter {
    
	static IRRelativeDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        
		formatter = [[IRRelativeDateFormatter alloc] init];
		formatter.approximationMaxTokenCount = 1;
        
	});
    
	return formatter;
    
}

- (void) imageStackView:(WAImageStackView *)aStackView didRecognizePinchZoomGestureWithRepresentedImage:(UIImage *)representedImage contentRect:(CGRect)aRect transform:(CATransform3D)layerTransform {
  
	NSURL *representedObjectURI = objc_getAssociatedObject(aStackView, &WAPostViewControllerPhone_RepresentedObjectURI);
	
	__block __typeof__(self) nrSelf = self;
	__block WAGalleryViewController *galleryViewController = nil;
	galleryViewController = [WAGalleryViewController controllerRepresentingArticleAtURI:representedObjectURI];
	galleryViewController.hidesBottomBarWhenPushed = YES;
	galleryViewController.onDismiss = ^ {
    
		CATransition *transition = [CATransition animation];
		transition.duration = 0.3f;
		transition.type = kCATransitionPush;
		transition.subtype = ((^ {
			switch (self.interfaceOrientation) {
				case UIInterfaceOrientationPortrait:
					return kCATransitionFromLeft;
				case UIInterfaceOrientationPortraitUpsideDown:
					return kCATransitionFromRight;
				case UIInterfaceOrientationLandscapeLeft:
					return kCATransitionFromTop;
				case UIInterfaceOrientationLandscapeRight:
					return kCATransitionFromBottom;
			}
		})());
		transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		transition.fillMode = kCAFillModeForwards;
		transition.removedOnCompletion = YES;
    
		[galleryViewController.navigationController setNavigationBarHidden:NO animated:NO];
		[galleryViewController.navigationController popViewControllerAnimated:NO];
		
		[nrSelf.navigationController.view.layer addAnimation:transition forKey:@"transition"];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    
	};
	
	CATransition *transition = [CATransition animation];
	transition.duration = 0.3f;
	transition.type = kCATransitionPush;
	transition.subtype = ((^ {
		switch (self.interfaceOrientation) {
			case UIInterfaceOrientationPortrait:
				return kCATransitionFromRight;
			case UIInterfaceOrientationPortraitUpsideDown:
				return kCATransitionFromLeft;
			case UIInterfaceOrientationLandscapeLeft:
				return kCATransitionFromBottom;
			case UIInterfaceOrientationLandscapeRight:
				return kCATransitionFromTop;
		}
	})());
	transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	transition.fillMode = kCAFillModeForwards;
	transition.removedOnCompletion = YES;
	
	[self.navigationController setNavigationBarHidden:YES animated:NO];
	[self.navigationController pushViewController:galleryViewController animated:NO];
	
	[self.navigationController.view.layer addAnimation:transition forKey:@"transition"];
	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
  
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, transition.duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:NO];
	});
	
}

@end
