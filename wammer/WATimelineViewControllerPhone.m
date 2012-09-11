//
//  WAArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WATimelineViewControllerPhone.h"

#import <objc/runtime.h>

#import <TargetConditionals.h>

#import "UIKit+IRAdditions.h"

#import "WADefines.h"
#import "WARemoteInterface.h"
#import "WADataStore.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"

#import "WAGalleryViewController.h"

#import "WAArticleDraftsViewController.h"
#import "WACompositionViewController.h"
#import "WACompositionViewController+CustomUI.h"

#import "WAArticleViewController.h"

#import "WAUserInfoViewController.h"
#import "IASKAppSettingsViewController.h"

#import "WANavigationController.h"
#import "WANavigationBar.h"

#import "WAPaginationSlider.h"
#import "WAArticleCommentsViewCell.h"
#import "WAPostViewCellPhone.h"
#import "WAPulldownRefreshView.h"
#import "WAOverlayBezel.h"

#import "WARepresentedFilePickerViewController.h"
#import "WARepresentedFilePickerViewController+CustomUI.h"

#import "WADatePickerViewController.h"
#import "WAFilterPickerViewController.h"

#import "WATimelineViewControllerPhone+RowHeightCaching.h"

#import "UIViewController+IRDelayedUpdateAdditions.h"

static NSString * const WAPostsViewControllerPhone_RepresentedObjectURI = @"WAPostsViewControllerPhone_RepresentedObjectURI";

@interface WATimelineViewControllerPhone () <NSFetchedResultsControllerDelegate, UIActionSheetDelegate, IASKSettingsDelegate, WAArticleDraftsViewControllerDelegate>

- (WAPulldownRefreshView *) defaultPulldownRefreshView;

@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) IRActionSheetController *settingsActionSheetController;
@property (nonatomic, readwrite) BOOL scrollToTopmostPost;

- (void) refreshData;

- (void) beginCompositionSessionWithURL:(NSURL *)anURL animated:(BOOL)animate onCompositionViewDidAppear:(void(^)(WACompositionViewController *compositionVC))callback;

- (void) handleCompose:(UIBarButtonItem *)sender;

- (void) handleDateSelect:(UIBarButtonItem *)sender;
- (void) handleFilter:(UIBarButtonItem *)sender;
- (void) handleCameraCapture:(UIBarButtonItem *)sender;
- (void) handleUserInfo:(UIBarButtonItem *)sender;

@end


@implementation WATimelineViewControllerPhone
@synthesize delegate;
@synthesize fetchedResultsController;
@synthesize managedObjectContext;
@synthesize settingsActionSheetController;
@synthesize scrollToTopmostPost;

- (void) dealloc {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kWACompositionSessionRequestedNotification object:nil];
	[[WARemoteInterface sharedInterface] removeObserver:self forKeyPath:@"isPostponingDataRetrievalTimerFiring"];
  
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if (!self)
		return nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCompositionSessionRequest:) name:kWACompositionSessionRequestedNotification object:nil];
		
	[[WARemoteInterface sharedInterface] addObserver:self forKeyPath:@"isPostponingDataRetrievalTimerFiring" options:NSKeyValueObservingOptionPrior|NSKeyValueObservingOptionNew context:nil];
  
	self.title = NSLocalizedString(@"APP_TITLE", @"Title for application");
	self.navigationItem.titleView = WAStandardTitleView();
	
	CGRect rect = (CGRect){ CGPointZero, (CGSize){ 1, 1 } };
	UIGraphicsBeginImageContext(rect.size);
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
	CGContextFillRect(context, rect);
	UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	UIImage *cameraPressed = [UIImage imageNamed:@"CameraPressed"];
	UIButton *cameraButton = [[UIButton alloc] initWithFrame:(CGRect){ CGPointZero, cameraPressed.size }];
	[cameraButton setBackgroundImage:cameraPressed forState:UIControlStateHighlighted];
	[cameraButton addTarget:self action:@selector(handleCameraCapture:) forControlEvents:UIControlEventTouchUpInside];
	[cameraButton setShowsTouchWhenHighlighted:YES];	
	
	UIImage *notePressed = [UIImage imageNamed:@"NotePressed"];
	UIButton *noteButton = [[UIButton alloc] initWithFrame:(CGRect){ CGPointZero, notePressed.size }];
	[noteButton setBackgroundImage:notePressed forState:UIControlStateHighlighted];
	[noteButton addTarget:self action:@selector(handleCompose:) forControlEvents:UIControlEventTouchUpInside];
	[noteButton setShowsTouchWhenHighlighted:YES];
	
	UIBarButtonItem *alphaSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	alphaSpacer.width = 14.0;
	
	UIBarButtonItem *omegaSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	omegaSpacer.width = 34.0;
	
	UIBarButtonItem *zeroSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	zeroSpacer.width = -10;
	
	UIBarButtonItem *datePickUIButton = [[UIBarButtonItem alloc] initWithImage:transparentImage style:UIBarButtonItemStylePlain target:self action:@selector(handleDateSelect:)];
	[datePickUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_PICK_DATE", @"Accessibility label for date picker in iPhone timeline")];

	UIBarButtonItem *composeUIButton = [[UIBarButtonItem alloc] initWithCustomView:noteButton];
	[composeUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_COMPOSE", @"Accessibility label for composer in iPhone timeline")];

	UIBarButtonItem *cameraUIButton = [[UIBarButtonItem alloc] initWithCustomView:cameraButton];
	[cameraButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_CAMERA", @"Accessibility label for camera in iPhone timeline")];

	UIBarButtonItem *userInfoUIButton = [[UIBarButtonItem alloc] initWithImage:transparentImage style:UIBarButtonItemStylePlain target:self action:@selector(handleUserInfo:)];
	[userInfoUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_ACCOUNT_INFO", @"Accessibility label for account info in iPhone timeline")];

	
	self.toolbarItems = [NSArray arrayWithObjects:
	
		alphaSpacer,
		
		datePickUIButton,
		
		omegaSpacer,
		
		composeUIButton,
						 
		zeroSpacer,
		
		cameraUIButton,

		omegaSpacer,
		
		userInfoUIButton,
		
		alphaSpacer,
	
	nil];
	
	[self setScrollToTopmostPost:NO];

	return self;
  
}

- (void) irConfigure {

	[super irConfigure];
	
	self.persistsContentInset = NO;

}





- (NSString *) persistenceIdentifier {

	return NSStringFromClass([self class]);

}





NSString * const kWAPostsViewControllerLastVisibleObjectURIs = @"WAPostsViewControllerLastVisiblePostURIs";
NSString * const kWAPostsViewControllerLastVisibleRects = @"WAPostsViewControllerLastVisibleRects";

- (NSMutableDictionary *) persistenceRepresentation {

	NSMutableDictionary *answer = [super persistenceRepresentation];
	
	if ([self isViewLoaded]) {
	
		NSArray *currentIndexPaths = [self.tableView indexPathsForVisibleRows];
		
		if (currentIndexPaths) {
		
			[answer setObject:[currentIndexPaths irMap: ^ (NSIndexPath *anIndexPath, NSUInteger index, BOOL *stop) {
				
				NSManagedObject *rowObject = [self.fetchedResultsController objectAtIndexPath:anIndexPath];
				return [[[rowObject objectID] URIRepresentation] absoluteString];
				
			}] forKey:kWAPostsViewControllerLastVisibleObjectURIs];
			
			[answer setObject:[currentIndexPaths irMap: ^ (NSIndexPath *anIndexPath, NSUInteger index, BOOL *stop) {
			
				return NSStringFromCGRect([self.tableView rectForRowAtIndexPath:anIndexPath]);
				
			}] forKey:kWAPostsViewControllerLastVisibleRects];
		
		}
	
	}
	
	return answer;

}

- (void) restoreFromPersistenceRepresentation:(NSDictionary *)inPersistenceRepresentation {

	[super restoreFromPersistenceRepresentation:inPersistenceRepresentation];
	
	if ([self isViewLoaded]) {
	
		NSArray *oldVisibleObjectURIs = [[inPersistenceRepresentation objectForKey:kWAPostsViewControllerLastVisibleObjectURIs] irMap: ^ (NSString *aString, NSUInteger index, BOOL *stop) {
			return [NSURL URLWithString:aString];
		}];
		NSArray *oldVisibleRects = [inPersistenceRepresentation objectForKey:kWAPostsViewControllerLastVisibleRects];
		
		if (oldVisibleObjectURIs && oldVisibleRects)
		if ([oldVisibleObjectURIs count] == [oldVisibleRects count]) {
		
			NSArray *newVisibleRects = [oldVisibleObjectURIs irMap: ^ (NSURL *anObjectURI, NSUInteger index, BOOL *stop) {
				NSIndexPath *newIndexPath = [self.fetchedResultsController indexPathForObject:[self.managedObjectContext irManagedObjectForURI:anObjectURI]];
				if (newIndexPath) {
					return (id)NSStringFromCGRect([self.tableView rectForRowAtIndexPath:newIndexPath]);
				} else {
					return (id)[NSNull null];
				}
			}];
			
			NSIndexSet *stillListedObjectIndexes = [oldVisibleObjectURIs indexesOfObjectsPassingTest: ^ (NSURL *anURI, NSUInteger idx, BOOL *stop) {
				return (BOOL)!![[newVisibleRects objectAtIndex:idx] isKindOfClass:[NSString class]];
			}];
			
			if ([stillListedObjectIndexes count]) {
				
				NSUInteger index = [stillListedObjectIndexes firstIndex];
				CGRect oldRect = CGRectFromString([oldVisibleRects objectAtIndex:index]);
				CGRect newRect = CGRectFromString([newVisibleRects objectAtIndex:index]);
				
				CGFloat deltaY = CGRectGetMinY(newRect) - CGRectGetMinY(oldRect);
				
				CGPoint oldContentOffset = self.tableView.contentOffset;
				CGPoint newContentOffset = oldContentOffset;
				newContentOffset.y += deltaY;
				
				if (deltaY != 0)
					[self.tableView setContentOffset:newContentOffset animated:NO];
				
			}
		
		}
	
	}

}





- (void) settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender {

	//	Do nothing

}

- (void) settingsViewController:(IASKAppSettingsViewController *)sender buttonTappedForKey:(NSString *)key {

	[[NSNotificationCenter defaultCenter] postNotificationName:kWASettingsDidRequestActionNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
	
		key, @"key",
	
	nil]];

}

- (IRActionSheetController *) settingsActionSheetController {

	if (settingsActionSheetController)
		return settingsActionSheetController;
	
	__weak WATimelineViewControllerPhone *wSelf = self;
	
	IRAction *cancelAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", nil) block:nil];
	IRAction *signOutAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) block:^{
	
		NSString *alertTitle = NSLocalizedString(@"ACTION_SIGN_OUT", nil);
		NSString *alertText = NSLocalizedString(@"SIGN_OUT_CONFIRMATION", nil);
		
		[[IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:cancelAction otherActions:[NSArray arrayWithObjects:
			
			[IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) block: ^ {
				
				[wSelf.delegate applicationRootViewControllerDidRequestReauthentication:nil];
				
			}],
			
		nil]] show];
		
	}];
	
	settingsActionSheetController = [IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:cancelAction destructiveAction:signOutAction otherActions:nil];

	return settingsActionSheetController;

}

- (NSManagedObjectContext *) managedObjectContext {

	if (managedObjectContext)
		return managedObjectContext;
	
	managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];

	return managedObjectContext;

}

- (NSFetchedResultsController *) fetchedResultsController {

	if (fetchedResultsController)
		return fetchedResultsController;

	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForAllArticles];

	fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	
	fetchedResultsController.delegate = self;
  
  NSError *fetchingError;
	if (![fetchedResultsController performFetch:&fetchingError])
		NSLog(@"error fetching: %@", fetchingError);
	
	if ([self isViewLoaded])
		[self.tableView reloadData];
	
	return fetchedResultsController;
	
}

- (WAPulldownRefreshView *) defaultPulldownRefreshView {

	return [WAPulldownRefreshView viewFromNib];
		
}

- (void) debugCreateArticle:(NSTimer *)timer {

	WADataStore *ds = [WADataStore defaultStore];
	NSManagedObjectContext *ctx = [ds disposableMOC];
	
	[WAArticle insertOrUpdateObjectsUsingContext:ctx withRemoteResponse:[NSArray arrayWithObjects:
	
		[NSDictionary dictionaryWithObjectsAndKeys:
		
			IRDataStoreNonce(), @"content",
			[ds ISO8601StringFromDate:[NSDate date]], @"timestamp",
		
		nil],
	
	nil] usingMapping:nil options:0];
	
	[ctx save:nil];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	//	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(debugCreateArticle:) userInfo:nil repeats:YES];
	//	[timer fire];
	
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		
	WAPulldownRefreshView *pulldownHeader = [self defaultPulldownRefreshView];
	
	self.tableView.pullDownHeaderView = pulldownHeader;
	self.tableView.onPullDownMove = ^ (CGFloat progress) {
		[pulldownHeader setProgress:progress animated:YES];
	};
	self.tableView.onPullDownEnd = ^ (BOOL didFinish) {
		if (didFinish) {
			pulldownHeader.progress = 0;
			[pulldownHeader setBusy:YES animated:YES];
			[[WARemoteInterface sharedInterface] performAutomaticRemoteUpdatesNow];
		}
	};
	self.tableView.onPullDownReset = ^ {
		[pulldownHeader setBusy:NO animated:YES];
	};
	
	self.tableView.separatorColor = [UIColor colorWithRed:232.0/255.0 green:232/255.0 blue:226/255.0 alpha:1.0];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	
	UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenu:)];
	[self.tableView addGestureRecognizer:longPressGR];
	
	UIBarButtonItem *filterButton = [[UIBarButtonItem alloc] initWithTitle:@"View"
																	 style:UIBarButtonItemStylePlain
																	target:self
																	action:@selector(handleFilter:)];
	[self.navigationItem setRightBarButtonItem: filterButton];
}

- (void) viewWillAppear:(BOOL)animated {

	[self fetchedResultsController];
  
	[super viewWillAppear:animated];
	
	self.navigationItem.titleView.alpha = 1;

	[self.navigationController.toolbar setTintColor:[UIColor colorWithWhite:128.0/255.0 alpha:1]];
	[self.navigationController.toolbar setBackgroundImage:[UIImage imageNamed:@"ToolbarWithButtons"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
	
	[self refreshData];
	[self restoreState];
	
	self.tableView.contentInset = UIEdgeInsetsZero;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMenuWillHide:) name:UIMenuControllerWillHideMenuNotification object:nil];
	
	IRTableView *tv = self.tableView;
	NSFetchedResultsController *frc = self.fetchedResultsController;
	
	for (NSIndexPath *ip in [tv indexPathsForVisibleRows]) {
		WAPostViewCellPhone *cell = (WAPostViewCellPhone *)[tv cellForRowAtIndexPath:ip];
		if ([cell isKindOfClass:[WAPostViewCellPhone class]]) {
			[cell setRepresentedObject:[frc objectAtIndexPath:ip]];
		}
	}

}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	
	[self.navigationController setToolbarHidden:NO animated:animated];

	if ([self scrollToTopmostPost]) {
		[[self tableView] scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
		[self setScrollToTopmostPost:NO];
	}

}

- (void) viewWillDisappear:(BOOL)animated {

	UIToolbar *toolbar = self.navigationController.toolbar;

	[toolbar setBackgroundImage:[UIImage imageNamed:@"Toolbar"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
	
	[toolbar setNeedsLayout];
	
	[toolbar.layer addAnimation:((^ {
		
		CATransition *transition = [CATransition animation];
		transition.duration = animated ? 0.5 : 0;
		transition.type = kCATransitionFade;
		
		return transition;
	
	})()) forKey:kCATransition];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerWillHideMenuNotification object:nil];

	NSArray *shownArticleIndexPaths = [self.tableView indexPathsForVisibleRows];

	NSArray *shownArticles = [shownArticleIndexPaths irMap: ^ (NSIndexPath *anIndexPath, NSUInteger index, BOOL *stop) {
		return [self.fetchedResultsController objectAtIndexPath:anIndexPath];
	}];
	
	NSArray *shownRowRects = [shownArticleIndexPaths irMap: ^ (NSIndexPath *anIndexPath, NSUInteger index, BOOL *stop) {
		return [NSValue valueWithCGRect:[self.tableView rectForRowAtIndexPath:anIndexPath]];
	}];
	
	__block WAArticle *sentArticle = [shownArticles count] ? [shownArticles objectAtIndex:0] : nil;
	
	if ([shownRowRects count] > 1) {
	
		//	If more than one rows were shown, find the first row that was fully visible
	
		[shownRowRects enumerateObjectsUsingBlock: ^ (NSValue *rectValue, NSUInteger idx, BOOL *stop) {
		
			CGRect rect = [rectValue CGRectValue];
			if (CGRectContainsRect(self.tableView.bounds, rect)) {
				sentArticle = [shownArticles objectAtIndex:idx];
				*stop = YES;
			}
			
		}];
	
	}
		
	[self.tableView resetPullDown];
	
	[super viewWillDisappear:animated];
	
}

- (void) viewDidUnload {

	[super viewDidUnload];

}

- (void) didReceiveMemoryWarning {

	[super didReceiveMemoryWarning];
	
	[self removeCachedRowHeights];

}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

	if ([self isViewLoaded])
	if (object == [WARemoteInterface sharedInterface])
	if ([[change objectForKey:NSKeyValueChangeNewKey] isEqual:(id)kCFBooleanFalse])
		[self.tableView performSelector:@selector(resetPullDown) withObject:nil afterDelay:2];

}

- (void) handleCompositionSessionRequest:(NSNotification *)incomingNotification {

	if (![self isViewLoaded])
		return;

	NSURL *contentURL = [[incomingNotification userInfo] objectForKey:@"foundURL"];
	[self beginCompositionSessionWithURL:contentURL animated:YES onCompositionViewDidAppear:nil];
	
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {

	return [[self.fetchedResultsController sections] count];
	
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	return [(id<NSFetchedResultsSectionInfo>)[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
	
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
  WAArticle *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
	
	WAPostViewCellPhone *cell = [WAPostViewCellPhone cellRepresentingObject:post inTableView:tableView];
	NSParameterAssert(cell.article == post);
	
	return cell;
	
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

	NSParameterAssert([NSThread isMainThread]);
	
	@autoreleasepool {
    
		WAArticle *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
		NSCParameterAssert([post isKindOfClass:[WAArticle class]]);
		
		NSString *identifier = [WAPostViewCellPhone identifierRepresentingObject:post];
		
		id context = nil;
		CGFloat height = [self cachedRowHeightForObject:post context:&context];
		if (!height || ![context isEqual:identifier]) {
		
			height = [WAPostViewCellPhone heightForRowRepresentingObject:post inTableView:tableView];
			[self cacheRowHeight:height forObject:post context:identifier];
		
		}
	
		return height;
		
	}

}

- (IBAction) actionSettings:(id)sender {

  [self.settingsActionSheetController.managedActionSheet showFromBarButtonItem:sender animated:YES];

}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)newOrientation {
  
	return newOrientation == UIInterfaceOrientationPortrait;
	
}

- (void) refreshData {

	[[WARemoteInterface sharedInterface] rescheduleAutomaticRemoteUpdates];

}

- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {

	if (![self isViewLoaded])
		return;
	
	[self persistState];
	[self.tableView beginUpdates];

}

- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {

	if (![self isViewLoaded])
		return;
	
	switch (type) {
		case NSFetchedResultsChangeDelete: {
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationNone];
			break;
		}
		case NSFetchedResultsChangeInsert: {
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationNone];
			break;
		}
		default: {
			NSParameterAssert(NO);
		}
	}

}

- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {

	[self removeCachedRowHeightForObject:anObject];

	if (![self isViewLoaded])
		return;
	
	switch (type) {
		case NSFetchedResultsChangeDelete: {
			NSParameterAssert(indexPath && !newIndexPath);
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
			break;
		}
		case NSFetchedResultsChangeInsert: {
			NSParameterAssert(!indexPath && newIndexPath);
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationNone];
			break;
		}
		case NSFetchedResultsChangeMove: {
		
			if (indexPath && newIndexPath) {
		
				NSParameterAssert(indexPath && newIndexPath);
				if ([self.tableView respondsToSelector:@selector(moveRowAtIndexPath:toIndexPath:)]) {
					[self.tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
				} else {
					[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
					[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationNone];
				}
			
			} else {
			
				NSParameterAssert(!indexPath && newIndexPath);
				[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationNone];
			
			}
			break;
		}
		case NSFetchedResultsChangeUpdate: {
			[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
			break;
		}
		
	}
	
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {

	if (![self isViewLoaded])
		return;
	
	UITableView *tv = self.tableView;
	[tv endUpdates];
	[self restoreState];
	
	NSArray *allVisibleIndexPaths = [tv indexPathsForVisibleRows];
	
	if ([allVisibleIndexPaths count]) {
	
		NSIndexPath *firstCellIndexPath = [allVisibleIndexPaths objectAtIndex:0];
		CGRect firstCellRect = [tv rectForRowAtIndexPath:firstCellIndexPath];
		
		if (tv.contentOffset.y < 0)
		if (!CGPointEqualToPoint(tv.frame.origin, [tv.superview convertPoint:firstCellRect.origin fromView:tv])) {
		
			[tv setContentOffset:CGPointZero animated:YES];
		
		}
	
	}
	
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	NSCParameterAssert([NSThread isMainThread]);
	NSCParameterAssert([self isViewLoaded]);
	NSCParameterAssert(self.view.window);
	
	UIMenuController *mc = [UIMenuController sharedMenuController];
	if ([mc isMenuVisible]) {
	
		[mc setMenuVisible:NO animated:YES];
		
		NSIndexPath *selectedRowIP = [tableView indexPathForSelectedRow];
		if (selectedRowIP)
			[tableView deselectRowAtIndexPath:selectedRowIP animated:YES];
		
		return;
		
	}
	
	WAArticle *post = [self.fetchedResultsController objectAtIndexPath:indexPath];
	NSCParameterAssert([post isKindOfClass:[WAArticle class]]);
	
	UIViewController *pushedVC = [WAArticleViewController controllerForArticle:post style:(WAFullScreenArticleStyle|WASuggestedStyleForArticle(post))];

	[self.navigationController pushViewController:pushedVC animated:YES];

}

- (void) beginCompositionSessionWithURL:(NSURL *)anURL animated:(BOOL)animate onCompositionViewDidAppear:(void (^)(WACompositionViewController *))callback {

	__block WACompositionViewController *compositionVC = [WACompositionViewController defaultAutoSubmittingCompositionViewControllerForArticle:anURL completion:^(NSURL *anURI) {
		
		if (![compositionVC.article hasMeaningfulContent] && [compositionVC shouldDismissSelfOnCameraCancellation]) {
			
			__block void (^dismissModal)(UIViewController *) = [^ (UIViewController *aVC) {
			
				if (aVC.modalViewController) {
					dismissModal(aVC.modalViewController);
					return;
				}
				
				[aVC dismissModalViewControllerAnimated:NO];
			
			} copy];
			
			UIWindow *usedWindow = [[UIApplication sharedApplication] keyWindow];
			
			if ([compositionVC isViewLoaded] && compositionVC.view.window)
				usedWindow = compositionVC.view.window;
			
			NSCParameterAssert(usedWindow);
			
			[CATransaction begin];
			
			dismissModal(compositionVC);
			dismissModal = nil;
			
			[compositionVC dismissModalViewControllerAnimated:NO];
			
			CATransition *fadeTransition = [CATransition animation];
			fadeTransition.duration = 0.3f;
			fadeTransition.type = kCATransitionFade;
			fadeTransition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
			fadeTransition.removedOnCompletion = YES;
			fadeTransition.fillMode = kCAFillModeForwards;
			
			[usedWindow.layer addAnimation:fadeTransition forKey:kCATransition];
			
			[CATransaction commit];
			
		} else {
	
			[compositionVC dismissModalViewControllerAnimated:YES];
			
			if (!anURL && [compositionVC.article hasMeaningfulContent]) {
				[self setScrollToTopmostPost:YES];
			}

		}
		
		compositionVC = nil;
		
	}];
	
	[self presentViewController:[compositionVC wrappingNavigationController] animated:animate completion:^{
		
		if (callback)
			callback(compositionVC);
		
	}];
	
}

- (BOOL) articleDraftsViewController:(WAArticleDraftsViewController *)aController shouldEnableArticle:(NSURL *)anObjectURIOrNil {

	return ![[WADataStore defaultStore] isUpdatingArticle:anObjectURIOrNil];

}

- (void) articleDraftsViewController:(WAArticleDraftsViewController *)aController didSelectArticle:(NSURL *)anObjectURIOrNil {

  [aController dismissViewControllerAnimated:YES completion:^{

		[self beginCompositionSessionWithURL:anObjectURIOrNil animated:YES onCompositionViewDidAppear:nil];
		
	}];

}

- (void) handleCompose:(UIBarButtonItem *)sender {

	if ([[WADataStore defaultStore] hasDraftArticles]) {
		
		WAArticleDraftsViewController *draftsVC = [[WAArticleDraftsViewController alloc] init];
		draftsVC.delegate = self;
		
		WANavigationController *navC = [[WANavigationController alloc] initWithRootViewController:draftsVC];
		
		__weak WATimelineViewControllerPhone *wSelf = self;
				
		draftsVC.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemCancel wiredAction:^(IRBarButtonItem *senderItem) {
			
			[wSelf dismissViewControllerAnimated:YES completion:nil];
			
		}];
		
		[self presentViewController:navC animated:YES completion:nil];
	
	} else {

		[self beginCompositionSessionWithURL:nil animated:YES onCompositionViewDidAppear:nil];
	
	}
  
}

- (BOOL) canBecomeFirstResponder {

	return [self isViewLoaded];

}

- (BOOL) canPerformAction:(SEL)anAction withSender:(id)sender {

	if (anAction == @selector(toggleFavorite:))
		return YES;
	
	if (anAction == @selector(editCoverImage:))
		return YES;
	
	if (anAction == @selector(removeArticle:))
		return YES;

#if TARGET_IPHONE_SIMULATOR
	
	if (anAction == @selector(makeDirty:))
		return YES;

#endif
	
	return NO;

}

- (void) handleMenu:(UILongPressGestureRecognizer *)longPress {

	UIMenuController * const menuController = [UIMenuController sharedMenuController];
	if (menuController.menuVisible)
		return;
	
	BOOL didBecomeFirstResponder = [self becomeFirstResponder];
	NSAssert1(didBecomeFirstResponder, @"%s must require cell to become first responder", __PRETTY_FUNCTION__);

	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[longPress locationInView:self.tableView]];
	WAArticle *article = [self.fetchedResultsController objectAtIndexPath:indexPath];
	
	WAPostViewCellPhone *cell = (WAPostViewCellPhone *)[self.tableView cellForRowAtIndexPath:indexPath];
	NSParameterAssert(cell.article == article);	//	Bleh
	
	if (![cell isSelected])
		[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	
	menuController.arrowDirection = UIMenuControllerArrowDown;
		
	NSMutableArray *menuItems = [NSMutableArray array];

#if TARGET_IPHONE_SIMULATOR

	[menuItems addObject:[[UIMenuItem alloc] initWithTitle:@"Make Dirty" action:@selector(makeDirty:)]];

#endif

	[menuItems addObject:[[UIMenuItem alloc] initWithTitle:([article.favorite isEqual:(id)kCFBooleanTrue] ?
		NSLocalizedString(@"ACTION_UNMARK_FAVORITE", @"Action marking article as not favorite") :
		NSLocalizedString(@"ACTION_MARK_FAVORITE", @"Action marking article as favorite")) action:@selector(toggleFavorite:)]];
	
	[menuItems addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"ACTION_DELETE", @"Action deleting an article") action:@selector(removeArticle:)]];
	
	if ([cell.article.files count] > 1)
		[menuItems addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"ACTION_CHANGE_REPRESENTING_FILE", @"Action changing representing file of an article") action:@selector(editCoverImage:)]];
	
	[menuController setMenuItems:menuItems];
	[menuController update];
	
	CGRect onScreenCellBounds = CGRectIntersection(cell.bounds, [self.tableView convertRect:self.tableView.bounds toView:cell]);
	
	[menuController setTargetRect:IRGravitize(onScreenCellBounds, (CGSize){ 8, 8}, kCAGravityCenter) inView:cell];
	[menuController setMenuVisible:YES animated:NO];
	
}

- (void) handleMenuWillHide:(NSNotification *)note {

	NSIndexPath *selectedRowIndexPath = [self.tableView indexPathForSelectedRow];

	if (selectedRowIndexPath)
		[self.tableView deselectRowAtIndexPath:selectedRowIndexPath animated:YES];

}

- (void) toggleFavorite:(id)sender {
	
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	WAArticle *article = [self.fetchedResultsController objectAtIndexPath:selectedIndexPath];
	
	NSAssert1(selectedIndexPath && article, @"Selected index path %@ and underlying object must exist", selectedIndexPath);
	
	article.favorite = (NSNumber *)([article.favorite isEqual:(id)kCFBooleanTrue] ? kCFBooleanFalse : kCFBooleanTrue);
	article.dirty = (id)kCFBooleanTrue;
	article.modificationDate = [NSDate date];
	
	NSError *savingError = nil;
	if (![article.managedObjectContext save:&savingError])
		NSLog(@"Error saving: %@", savingError);
	
	[[WARemoteInterface sharedInterface] beginPostponingDataRetrievalTimerFiring];
	
	[[WADataStore defaultStore] updateArticle:[[article objectID] URIRepresentation] withOptions:nil onSuccess:^{
		
		[[WARemoteInterface sharedInterface] endPostponingDataRetrievalTimerFiring];
		
	} onFailure:^(NSError *error) {
		
		[[WARemoteInterface sharedInterface] endPostponingDataRetrievalTimerFiring];
		
	}];
	
}

- (void) editCoverImage:(id)sender {

	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	WAArticle *article = [self.fetchedResultsController objectAtIndexPath:selectedIndexPath];
	
	if (!selectedIndexPath || !article)
		return;
	
	__block WARepresentedFilePickerViewController *picker = [WARepresentedFilePickerViewController defaultAutoSubmittingControllerForArticle:[[article objectID] URIRepresentation] completion: ^ (NSURL *selectedFileURI) {
	
		[picker.navigationController dismissViewControllerAnimated:YES completion:nil];
		picker = nil;
		
	}];
	
	picker.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemCancel wiredAction:^(IRBarButtonItem *senderItem) {
	
		[picker.navigationController dismissViewControllerAnimated:YES completion:nil];
		picker = nil;
				
	}];
	
	WANavigationController *navC = [[WANavigationController alloc] initWithRootViewController:picker];
	[self.navigationController presentViewController:navC animated:YES completion:nil];
	
}

- (void) removeArticle:(id)sender {

	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	WAArticle *article = [self.fetchedResultsController objectAtIndexPath:selectedIndexPath];
	
	NSAssert1(selectedIndexPath && article, @"Selected index path %@ and underlying object must exist", selectedIndexPath);
	
	IRAction *cancelAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", @"Title for cancelling an action") block:nil];
	
	IRAction *deleteAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_DELETE", @"Title for deleting an article from the Timeline") block:^ {
	
		article.hidden = (id)kCFBooleanTrue;
		article.dirty = (id)kCFBooleanTrue;
		article.modificationDate = [NSDate date];
		
		NSError *savingError = nil;
		if (![article.managedObjectContext save:&savingError])
			NSLog(@"Error saving: %@", savingError);
		
		[[WARemoteInterface sharedInterface] beginPostponingDataRetrievalTimerFiring];
		
		[[WADataStore defaultStore] updateArticle:[[article objectID] URIRepresentation] withOptions:nil onSuccess:^{
			
			[[WARemoteInterface sharedInterface] endPostponingDataRetrievalTimerFiring];
			
		} onFailure:^(NSError *error) {
			
			[[WARemoteInterface sharedInterface] endPostponingDataRetrievalTimerFiring];
			
		}];
	
	}];
	
	NSString *deleteTitle = NSLocalizedString(@"DELETE_POST_CONFIRMATION_DESCRIPTION", @"Title for confirming a post deletion");
	
	IRActionSheetController *controller = [IRActionSheetController actionSheetControllerWithTitle:deleteTitle cancelAction:cancelAction destructiveAction:deleteAction otherActions:nil];
	
	[[controller managedActionSheet] showInView:self.navigationController.view];
		
}

- (void) makeDirty:(id)sender {

	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	WAArticle *article = [self.fetchedResultsController objectAtIndexPath:selectedIndexPath];
	
	NSAssert1(selectedIndexPath && article, @"Selected index path %@ and underlying object must exist", selectedIndexPath);
	
	article.dirty = (id)kCFBooleanTrue;
	[article.managedObjectContext save:nil];

}

- (void) handleDateSelect:(UIBarButtonItem *)sender {

	__block WADatePickerViewController *dpVC = [WADatePickerViewController controllerWithCompletion:^(NSDate *date) {
	
		if (date) {

			NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForNewestArticleOnDate:date];
			
			WAArticle *article = (WAArticle *)[[self.managedObjectContext executeFetchRequest:fr error:nil] lastObject];
			
			if (article) {
				
				NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:article];
				
				if (indexPath) {
				
					[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
				
				}
				
			}
		
		}
	
		[dpVC willMoveToParentViewController:nil];
		[dpVC removeFromParentViewController];
		[dpVC.view removeFromSuperview];
		[dpVC didMoveToParentViewController:nil];
		
		dpVC = nil;
		
	}];
	
		
	NSFetchedResultsController *frc = self.fetchedResultsController;
	NSFetchRequest *fr = frc.fetchRequest;
	NSPredicate *currentPredicate = fr.predicate;

	WADataStore *ds = [WADataStore defaultStore];
	NSFetchRequest *oldestArticleFR = [ds newFetchRequestForOldestArticle];
	oldestArticleFR.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:oldestArticleFR.predicate, currentPredicate, nil]];
	
	NSFetchRequest *newestArticleFR = [ds newFetchRequestForNewestArticle];
	newestArticleFR.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:newestArticleFR.predicate, currentPredicate, nil]];
	
	WAArticle *oldestArticle = [[self.managedObjectContext executeFetchRequest:oldestArticleFR error:nil] lastObject];
	
	WAArticle *newestArticle = [[self.managedObjectContext executeFetchRequest:newestArticleFR error:nil] lastObject];
	
	if (oldestArticle == nil){ // empty timeline
		return;
	}
	
	NSDate *minDate = oldestArticle.modificationDate ? oldestArticle.modificationDate : oldestArticle.creationDate;
	
	NSDate *maxDate = newestArticle.modificationDate ? newestArticle.modificationDate : newestArticle.creationDate;
	
	NSCParameterAssert(minDate && maxDate);
	dpVC.minDate = minDate;
	dpVC.maxDate = maxDate;
	
	UIViewController *hostingVC = self.navigationController;
	if (!hostingVC)
		hostingVC = self;
	
	[hostingVC addChildViewController:dpVC];
	
	dpVC.view.frame = hostingVC.view.bounds;
	[hostingVC.view addSubview:dpVC.view];
	[dpVC didMoveToParentViewController:hostingVC];

}

- (void) handleFilter:(UIBarButtonItem *)sender {

	__block WAFilterPickerViewController *fpVC = [WAFilterPickerViewController controllerWithCompletion:^(NSFetchRequest *fr) {
	
		if (fr) {
		
			self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
			
			self.fetchedResultsController.delegate = self;
			[self.fetchedResultsController performFetch:nil];
			
			[self.tableView setContentOffset:CGPointZero animated:NO];
			[self.tableView reloadData];
		
		}
		
		[fpVC willMoveToParentViewController:nil];
		[fpVC removeFromParentViewController];
		[fpVC.view removeFromSuperview];
		[fpVC didMoveToParentViewController:nil];
		
		fpVC = nil;
		
	}];
	
	UIViewController *hostingVC = self.navigationController;
	if (!hostingVC)
		hostingVC = self;
	
	[hostingVC addChildViewController:fpVC];
	
	fpVC.view.frame = hostingVC.view.bounds;
	[hostingVC.view addSubview:fpVC.view];
	[fpVC didMoveToParentViewController:hostingVC];

}

- (void) handleCameraCapture:(UIBarButtonItem *)sender  {

	[self beginCompositionSessionWithURL:nil animated:NO onCompositionViewDidAppear:^(WACompositionViewController *compositionVC) {
	
		[compositionVC handleImageAttachmentInsertionRequestWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:
		
			(id)kCFBooleanTrue, WACompositionImageInsertionUsesCamera,
			(id)kCFBooleanFalse, WACompositionImageInsertionAnimatePresentation,
			(id)kCFBooleanTrue, WACompositionImageInsertionCancellationTriggersSessionTermination,
		
		nil] sender:compositionVC.view];
		
		[[UIApplication sharedApplication].keyWindow.layer addAnimation:((^ {
		
			CATransition *transition = [CATransition animation];
			transition.duration = 0.3f;
			transition.type = kCATransitionFade;
			
			return transition;
		
		})()) forKey:kCATransition];
	
	}];

}

- (void) handleUserInfo:(UIBarButtonItem *)sender  {

	UINavigationController *navC = nil;
	WAUserInfoViewController *userInfoVC = [WAUserInfoViewController controllerWithWrappingNavController:&navC];
	
	__weak WATimelineViewControllerPhone *wSelf = self;
	__weak WAUserInfoViewController *wUserInfoVC = userInfoVC;
	
	userInfoVC.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemDone wiredAction:^(IRBarButtonItem *senderItem) {
		
		[wUserInfoVC.navigationController dismissViewControllerAnimated:YES completion:nil];
		
	}];
	
	userInfoVC.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) action:^{

		IRAction *cancelAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", nil) block:nil];
		
		NSString *alertTitle = NSLocalizedString(@"ACTION_SIGN_OUT", nil);
		NSString *alertText = NSLocalizedString(@"SIGN_OUT_CONFIRMATION", nil);
		
		[[IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:cancelAction otherActions:[NSArray arrayWithObjects:
			
			[IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) block: ^ {
				
				[wSelf.delegate applicationRootViewControllerDidRequestReauthentication:nil];
				
			}],
			
		nil]] show];
		
	}];
	
	[self presentViewController:navC animated:YES completion:nil];
	
}

@end
