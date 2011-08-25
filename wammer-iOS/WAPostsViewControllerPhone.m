//
//  WAArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WADataStore.h"
#import "WAPostsViewControllerPhone.h"
#import "WACompositionViewController.h"
#import "WAPaginationSlider.h"

#import "WARemoteInterface.h"

#import "IRPaginatedView.h"
#import "IRBarButtonItem.h"
#import "IRTransparentToolbar.h"
#import "IRActionSheetController.h"
#import "IRActionSheet.h"

#import "WAArticleViewController.h"
#import "WAPostViewControllerPhone.h"
#import "WAUserSelectionViewController.h"

#import "WAArticleCommentsViewCell.h"
#import "WAPostViewCellPhone.h"
#import "WAComposeViewControllerPhone.h"


@interface WAPostsViewControllerPhone () <NSFetchedResultsControllerDelegate>

@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;

- (void) refreshData;

+ (IRRelativeDateFormatter *) relativeDateFormatter;

@end


@implementation WAPostsViewControllerPhone
@synthesize fetchedResultsController;
@synthesize managedObjectContext;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if (!self)
		return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleManagedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
		
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Account" style:UIBarButtonItemStyleBordered target:self action:@selector(handleAccount:)] autorelease];
    self.title = @"Wammer";
    self.navigationItem.rightBarButtonItem  = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(handleCompose:)]autorelease];
    
	self.managedObjectContext = [[WADataStore defaultStore] disposableMOC];
	self.fetchedResultsController = [[[NSFetchedResultsController alloc] initWithFetchRequest:((^ {
        
		NSFetchRequest *returnedRequest = [[[NSFetchRequest alloc] init] autorelease];
		returnedRequest.entity = [NSEntityDescription entityForName:@"WAArticle" inManagedObjectContext:self.managedObjectContext];
		returnedRequest.predicate = [NSPredicate predicateWithFormat:@"(self != nil) AND (draft == NO)"]; //	@"ANY files.identifier != nil"]; // TBD files.thumbnailFilePath != nil
		returnedRequest.sortDescriptors = [NSArray arrayWithObjects:
                                           [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO],
                                           nil];
		return returnedRequest;
        
	})()) managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil] autorelease];
	
	self.fetchedResultsController.delegate = self;
    
    
    NSError *error;
	[self.fetchedResultsController performFetch:&error];
    
	return self;

}

- (void) handleManagedObjectContextDidSave:(NSNotification *)aNotification {
    
	NSManagedObjectContext *savedContext = (NSManagedObjectContext *)[aNotification object];
	
	if (savedContext == self.managedObjectContext)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^ {
        
		[self.managedObjectContext mergeChangesFromContextDidSaveNotification:aNotification];
        
	});
    
}


- (void) dealloc {
	
	[managedObjectContext release];
	[fetchedResultsController release];
	[super dealloc];

}

- (void) viewDidUnload {
	
	[super viewDidUnload];

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	
    [self.fetchedResultsController performFetch:nil];
    [self refreshData];
}

- (void) viewWillDisappear:(BOOL)animated {

	[super viewWillDisappear:animated];
	
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    if (!self.fetchedResultsController.fetchedObjects) {
        return 0;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(!self.fetchedResultsController.fetchedObjects)
        return 0;
    return [[self.fetchedResultsController.sections objectAtIndex:section] numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    WAArticle *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSParameterAssert(post);
    
    static NSString *defaultCellIdentifier = @"PostCell-Default";
    static NSString *imageCellIdentifier = @"PostCell-Stacked";
    
    BOOL postHasFiles = (BOOL)!![post.files count];
    BOOL postHasComments = (BOOL)!![post.comments count];
    
    NSString *identifier = postHasFiles ? imageCellIdentifier : defaultCellIdentifier;
    WAPostViewCellStyle style = WAPostViewCellStyleDefault; //text only with comment
    
    if (postHasFiles && postHasComments) {
        style = WAPostViewCellStyleImageStack;
    }else if(postHasFiles) {
        style = WAPostViewCellStyleCompactWithImageStack;
    }else {
        style = WAPostViewCellStyleCompact;
    }
    
    WAPostViewCellPhone *cell = (WAPostViewCellPhone *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if(!cell) {
        cell = [[WAPostViewCellPhone alloc] initWithStyle:style reuseIdentifier:identifier];
    }
    
    cell.userNicknameLabel.text = post.owner.nickname;
    cell.avatarView.image = post.owner.avatar;
    cell.contentTextLabel.text = post.text;
    cell.dateLabel.text = [NSString stringWithFormat:@"%@ %@", 
                           [[[self class] relativeDateFormatter] stringFromDate:post.timestamp], 
                           [NSString stringWithFormat:@"via %@", post.creationDeviceName]];
    cell.originLabel.text = [NSString stringWithFormat:@"via %@", post.creationDeviceName];
    cell.commentLabel.text = [NSString stringWithFormat:@"%lu comments", [post.comments count]];
    
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    WAArticle *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if ( [post.files count ] == 0)
        return 160;
    else
        return 300;
}

- (void) handleAccount:(UIBarButtonItem *)sender {

    
    __block WAUserSelectionViewController *userSelectionVC = nil;
    userSelectionVC = [WAUserSelectionViewController controllerWithElectibleUsers:nil onSelection:^(NSURL *pickedUser) {
        
        NSManagedObjectContext *disposableContext = [[WADataStore defaultStore] disposableMOC];
        WAUser *userObject = (WAUser *)[disposableContext irManagedObjectForURI:pickedUser];
        NSString *userIdentifier = userObject.identifier;
        
        [[NSUserDefaults standardUserDefaults] setObject:userIdentifier forKey:@"WhoAmI"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [userSelectionVC.navigationController dismissModalViewControllerAnimated:YES];
        
    }];

    UINavigationController *nc = [[[UINavigationController alloc] initWithRootViewController:userSelectionVC] autorelease];
	[self.navigationController presentModalViewController:nc animated:YES];
    
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)newOrientation {

	if ([[UIApplication sharedApplication] isIgnoringInteractionEvents])
		return (self.interfaceOrientation == newOrientation);

	return YES;
	
}

- (void) refreshData {

	[[WADataStore defaultStore] updateUsersWithCompletion:nil];
	[[WADataStore defaultStore] updateArticlesWithCompletion:nil];

}

- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {
	
	NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, [NSThread currentThread], controller);
	
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
	
	NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, [NSThread currentThread], controller);
    [self.tableView reloadData];

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    WAArticle *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
    WAPostViewControllerPhone *controller = [WAPostViewControllerPhone controllerWithPost:[[post objectID] URIRepresentation]];
    
    [self.navigationController pushViewController:controller animated:YES];
}

- (void) handleCompose:(UIBarButtonItem *)sender
{
    
    WAComposeViewControllerPhone *cvc = [WAComposeViewControllerPhone controllerWithPost:nil completion:^(NSURL *aPostURLOrNil) {
        
		[[WADataStore defaultStore] uploadArticle:aPostURLOrNil withCompletion: ^ {
            
			[self refreshData];
            
		}];
        
	}];

    [self.navigationController pushViewController:cvc animated:YES];
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

@end
