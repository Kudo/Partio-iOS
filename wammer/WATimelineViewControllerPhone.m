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
#import "NSDate+WAAdditions.h"

#import "WADefines.h"
#import "WAAppDelegate.h"
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
#import "WAPhotoImportManager.h"

#import "IIViewDeckController.h"
#import "WADripdownMenuViewController.h"

static float kWATimelinePageSwitchDuration = 0.4f;
static NSString * const WAPostsViewControllerPhone_RepresentedObjectURI = @"WAPostsViewControllerPhone_RepresentedObjectURI";

@interface WATimelineViewControllerPhone () <NSFetchedResultsControllerDelegate, UIActionSheetDelegate, IASKSettingsDelegate, WAArticleDraftsViewControllerDelegate>

- (WAPulldownRefreshView *) defaultPulldownRefreshView;

@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsControllerForIncomingUpdates;
@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsControllerForPreloaded;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) IRActionSheetController *settingsActionSheetController;
@property (nonatomic, readwrite) BOOL scrollToTopmostPost;
@property (nonatomic, readwrite, retain) NSDate *currentDisplayedDate;

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
@synthesize fetchedResultsControllerForIncomingUpdates;
@synthesize fetchedResultsControllerForPreloaded;
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
	self.navigationItem.titleView = WATitleViewForDripdownMenu(self, @selector(dripdownMenuTapped));
	
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
	
	UIBarButtonItem *leftUIButton = [[UIBarButtonItem alloc] initWithImage:transparentImage style:UIBarButtonItemStylePlain target:self action:@selector(handleSwipeRight:)];
	[leftUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_NEXT_DAY", @"Accessibility label for next day timeline")];
	/*
	UIBarButtonItem *datePickUIButton = [[UIBarButtonItem alloc] initWithImage:transparentImage style:UIBarButtonItemStylePlain target:self action:@selector(handleDateSelect:)];
	[datePickUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_PICK_DATE", @"Accessibility label for date picker in iPhone timeline")];
*/
	UIBarButtonItem *composeUIButton = [[UIBarButtonItem alloc] initWithCustomView:noteButton];
	[composeUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_COMPOSE", @"Accessibility label for composer in iPhone timeline")];

	UIBarButtonItem *cameraUIButton = [[UIBarButtonItem alloc] initWithCustomView:cameraButton];
	[cameraButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_CAMERA", @"Accessibility label for camera in iPhone timeline")];
/*
	UIBarButtonItem *userInfoUIButton = [[UIBarButtonItem alloc] initWithImage:transparentImage style:UIBarButtonItemStylePlain target:self action:@selector(handleUserInfo:)];
	[userInfoUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_ACCOUNT_INFO", @"Accessibility label for account info in iPhone timeline")];
*/
	UIBarButtonItem *rightUIButton = [[UIBarButtonItem alloc] initWithImage:transparentImage style:UIBarButtonItemStylePlain target:self action:@selector(handleSwipeLeft:)];
	[leftUIButton setAccessibilityLabel:NSLocalizedString(@"ACCESS_PREVIOUS_DAY", @"Accessibility label for previous day timeline")];
	
	
	self.toolbarItems = [NSArray arrayWithObjects:
	
		alphaSpacer,
		
//		datePickUIButton,
		leftUIButton,
		
		omegaSpacer,
		
		composeUIButton,
						 
		zeroSpacer,
		
		cameraUIButton,

		omegaSpacer,
		
		//userInfoUIButton,
		rightUIButton,
		
		alphaSpacer,
	
	nil];
		
	UIImage *calImage = [UIImage imageNamed:@"Cal"];
	UIButton *calButton = [UIButton buttonWithType:UIButtonTypeCustom];
	calButton.frame = (CGRect) {CGPointZero, calImage.size};
	[calButton setBackgroundImage:calImage forState:UIControlStateNormal];
	[calButton setBackgroundImage:[UIImage imageNamed:@"CalHL"] forState:UIControlStateHighlighted];
	[calButton setShowsTouchWhenHighlighted:YES];
	[calButton addTarget:self action:@selector(handleDateSelect:) forControlEvents:UIControlEventTouchUpInside];
	
	self.navigationItem.rightBarButtonItem  = [[UIBarButtonItem alloc] initWithCustomView:calButton];
	
	UIImage *menuImage = [UIImage imageNamed:@"menu"];
	UIButton *slidingMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
	slidingMenuButton.frame = (CGRect) {CGPointZero, menuImage.size};
	[slidingMenuButton setBackgroundImage:menuImage forState:UIControlStateNormal];
	[slidingMenuButton setBackgroundImage:[UIImage imageNamed:@"menuHL"] forState:UIControlStateHighlighted];
	[slidingMenuButton setShowsTouchWhenHighlighted:YES];
	[slidingMenuButton addTarget:self.viewDeckController action:@selector(toggleLeftView) forControlEvents:UIControlEventTouchUpInside];
	
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:slidingMenuButton];
		
	[self setScrollToTopmostPost:NO];

	return self;
  
}

- (void) irConfigure {

	[super irConfigure];
	
	self.persistsContentInset = NO;

	self.persistsStateWhenViewWillDisappear = NO;
	self.restoresStateWhenViewWillAppear = NO;
	
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

#pragma mark - MOC and NSFetchResultsController
- (NSManagedObjectContext *) managedObjectContext {

	if (managedObjectContext)
		return managedObjectContext;
	
	managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];

	return managedObjectContext;

}

- (NSFetchedResultsController *) fetchedResultsController {

	if (fetchedResultsController)
		return fetchedResultsController;

	NSDate *latestDateWithArticles = [NSDate date];
	NSFetchRequest *reqForFirst = [[WADataStore defaultStore] newFetchRequestForNewestArticle];
	WAArticle *article = (WAArticle *)[[self.managedObjectContext executeFetchRequest:reqForFirst error:nil] lastObject];
	
	if (article) {
		
		latestDateWithArticles = article.creationDate;
		
	}
	
	self.currentDisplayedDate = latestDateWithArticles;

	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForArticlesOnDate:self.currentDisplayedDate];

	fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	
	fetchedResultsController.delegate = self;
  
  NSError *fetchingError;
	if (![fetchedResultsController performFetch:&fetchingError])
		NSLog(@"error fetching: %@", fetchingError);
	
	if ([self isViewLoaded])
		[self.tableView reloadData];
	
	return fetchedResultsController;
	
}

- (NSFetchedResultsController *) fetchedResultsControllerForIncomingUpdates {

	if (fetchedResultsControllerForIncomingUpdates)
		return fetchedResultsControllerForIncomingUpdates;
		
	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForNewestArticle];
	
	fetchedResultsControllerForIncomingUpdates = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	
	fetchedResultsControllerForIncomingUpdates.delegate = self;
  
  NSError *fetchingError;
	if (![fetchedResultsControllerForIncomingUpdates performFetch:&fetchingError])
		NSLog(@"error fetching: %@", fetchingError);
	
	return fetchedResultsControllerForIncomingUpdates;

}

- (NSFetchedResultsController *) fetchedResultsControllerForPreloaded {
	
	if (fetchedResultsControllerForPreloaded)
		return fetchedResultsControllerForPreloaded;
	
	NSDate *preDay = [self previousDateWithArticle];
	if (!preDay)
		return nil;
	
	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForArticlesOnDate:preDay];
	
	fetchedResultsControllerForPreloaded = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	
	//fetchedResultsControllerForPreloaded.delegate = self;
  
  NSError *fetchingError;
	if (![fetchedResultsControllerForPreloaded performFetch:&fetchingError])
		NSLog(@"error fetching: %@", fetchingError);
	
	IRTableView *preTbView = [self tableViewRight];
	if (preTbView)
		[preTbView reloadData];
	
	return fetchedResultsControllerForPreloaded;
	
}

#pragma mark -


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

#pragma mark - UIViewController lifecycle
- (void) viewDidLoad {

	[super viewDidLoad];
	
	UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenu:)];
	[self.view addGestureRecognizer:longPressGR];
	
}

- (void) viewWillAppear:(BOOL)animated {

	[self fetchedResultsControllerForIncomingUpdates];
	[self fetchedResultsController];
	[self fetchedResultsControllerForPreloaded];
	
	NSLog(@"loaded at current date: %@", self.currentDisplayedDate);

	[super viewWillAppear:animated];
	
	self.navigationItem.titleView.alpha = 1;

	[self.navigationController.toolbar setTintColor:[UIColor colorWithWhite:128.0/255.0 alpha:1]];
	[self.navigationController.toolbar setBackgroundImage:[UIImage imageNamed:@"ToolbarWithButtons"] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
	
	[self refreshData];
	//[self restoreState];
	
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

#pragma mark - 

- (void) didReceiveMemoryWarning {

	[super didReceiveMemoryWarning];
	
	[self removeCachedRowHeights];

}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

	if ([self isViewLoaded])
	if (object == [WARemoteInterface sharedInterface])
		if ([[change objectForKey:NSKeyValueChangeNewKey] isEqual:(id)kCFBooleanFalse]) {
			[self.tableView performSelector:@selector(resetPullDown) withObject:nil afterDelay:2];
			
		}

}

- (void) handleCompositionSessionRequest:(NSNotification *)incomingNotification {

	if (![self isViewLoaded])
		return;

	NSURL *contentURL = [[incomingNotification userInfo] objectForKey:@"foundURL"];
	[self beginCompositionSessionWithURL:contentURL animated:YES onCompositionViewDidAppear:nil];
	
}

#pragma mark - UITableView delegate/datasource protocol
- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {

	if (tableView == self.tableView)
		return [[self.fetchedResultsController sections] count];
	else
		return [[self.fetchedResultsControllerForPreloaded sections] count];
	
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	if (tableView == self.tableView)
		return [(id<NSFetchedResultsSectionInfo>)[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
	else
		return [(id<NSFetchedResultsSectionInfo>)[[self.fetchedResultsControllerForPreloaded sections] objectAtIndex:section] numberOfObjects];

	
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	NSFetchedResultsController *frc = nil;
	
	if (tableView == self.tableView)
		frc = self.fetchedResultsController;
	else
		frc = self.fetchedResultsControllerForPreloaded;
		
  WAArticle *post = [frc objectAtIndexPath:indexPath];
	
	WAPostViewCellPhone *cell = [WAPostViewCellPhone cellRepresentingObject:post inTableView:tableView];
	NSParameterAssert(cell.article == post);
	
	return cell;
	
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

	NSParameterAssert([NSThread isMainThread]);
	
	NSFetchedResultsController *frc = nil;
	if (tableView == self.tableView)
		frc = self.fetchedResultsController;
	else
		frc = self.fetchedResultsControllerForPreloaded;

	
	@autoreleasepool {
    
		WAArticle *post = [frc objectAtIndexPath:indexPath];
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

CGFloat startTableViewOffset;
CGFloat lastTableViewOffset;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {

	startTableViewOffset = lastTableViewOffset = scrollView.contentOffset.y;
	
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	CGFloat currentOffset = scrollView.contentOffset.y;
	CGFloat diff = lastTableViewOffset - currentOffset;
	
	if (currentOffset - startTableViewOffset > 0) {

		if (scrollView.isTracking && abs(diff) > 1)
			[self.navigationController setToolbarHidden:YES animated:YES];

	} else {

		if (scrollView.isTracking && abs(diff) > 1)
			[self.navigationController setToolbarHidden:NO animated:YES];

	}
	
	lastTableViewOffset = currentOffset;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {

	[self.navigationController setToolbarHidden:NO animated:YES];

}

#pragma mark -

- (IBAction) actionSettings:(id)sender {

  [self.settingsActionSheetController.managedActionSheet showFromBarButtonItem:sender animated:YES];

}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)newOrientation {
  
	return newOrientation == UIInterfaceOrientationPortrait;
	
}

- (NSUInteger) supportedInterfaceOrientations {
	
	return UIInterfaceOrientationMaskPortrait;
	
}

- (void) refreshData {

	[[WARemoteInterface sharedInterface] rescheduleAutomaticRemoteUpdates];

}

#pragma mark - NSFetchedResultsController delegate protocol
- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {

	if (![self isViewLoaded])
		return;
	
	if (controller == self.fetchedResultsController) {
//		[self persistState];
		[self.tableView beginUpdates];
	}

}

- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {

	if (![self isViewLoaded])
		return;
	
	// only update rows for the tableView, which is currently shown on screen
	if (controller != self.fetchedResultsController)
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
	
	if (controller == self.fetchedResultsControllerForIncomingUpdates) {

		// TODO: jump to date?
		
		return;
	}
	
	// only update for the tableView, which is currently shown on the screen
	if (controller != self.fetchedResultsController)
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
//	[self restoreState];
	
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

#pragma mark - 

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

#pragma mark - handle the left/right swiping gesture 
- (void) loadDataForDate:(NSDate *)date {

	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForArticlesOnDate:date];
	if (fr) {
		
		self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
		
		self.fetchedResultsController.delegate = self;
		[self.fetchedResultsController performFetch:nil];
		
		[self.tableView setContentOffset:CGPointZero animated:NO];
//		[self.tableView reloadData];
		
	}
	
}

- (void) preloadDataForDateOnRight:(NSDate*)date {
	
//	NSDate *preDate = [self previousDateWithArticle];
	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForArticlesOnDate:date];
	if (fr) {
		
		self.fetchedResultsControllerForPreloaded = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
		
		self.fetchedResultsControllerForPreloaded.delegate = self;
		[self.fetchedResultsControllerForPreloaded performFetch:nil];
		
		IRTableView *preTableView = [self tableViewRight];
		[preTableView setContentOffset:CGPointZero animated:NO];
		[preTableView reloadData];
		
	}
	
}

- (void) preloadDataForDateOnLeft:(NSDate*)date {
	
	//	NSDate *preDate = [self previousDateWithArticle];
	NSFetchRequest *fr = [[WADataStore defaultStore] newFetchRequestForArticlesOnDate:date];
	if (fr) {
		
		self.fetchedResultsControllerForPreloaded = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
		
		self.fetchedResultsControllerForPreloaded.delegate = self;
		[self.fetchedResultsControllerForPreloaded performFetch:nil];
		
		IRTableView *preTableView = [self tableViewLeft];
		[preTableView setContentOffset:CGPointZero animated:NO];
		[preTableView reloadData];
		
	}
	
}

- (NSDate *)nextDateWithArticle {
	
	NSAssert(self.currentDisplayedDate, @"current date should be determined first");

	NSDate *nextDay = nil;
	NSFetchRequest *reqForFirst = [[WADataStore defaultStore] newFetchRequestForOldestArticleAfterDate:
																 [self.currentDisplayedDate dayEnd]];
	if (reqForFirst) {
		
		WAArticle *article = (WAArticle *)[[self.managedObjectContext executeFetchRequest:reqForFirst error:nil] lastObject];
		
		if (article) {
			
			nextDay = article.creationDate;

		}
		
	}
	
	return nextDay;
}

- (NSDate *)previousDateWithArticle {
		
	NSAssert(self.currentDisplayedDate, @"current date should be determined first");
	
	NSDate *nextDay = nil;
	NSFetchRequest *reqForFirst = [[WADataStore defaultStore] newFetchRequestForNewestArticleOnDate:
																 [self.currentDisplayedDate dayBegin]];
	if (reqForFirst) {
		
		WAArticle *article = (WAArticle *)[[self.managedObjectContext executeFetchRequest:reqForFirst error:nil] lastObject];
		
		if (article) {
			
			nextDay = article.creationDate;
			
		}
		
	}
	
	return nextDay;
}

- (void) handleSwipeRight:(UISwipeGestureRecognizer *)swipe {
	
	NSLog(@"swipe right");
	
	__block NSDate *nextDay = [self nextDateWithArticle];
	
	if (!nextDay) {
		NSLog(@"There is no articles in the next day");
		return;
	}
	
	__weak WATimelineViewControllerPhone *wSelf = self;
	
	[self pullTableViewFromRightWithDuration:kWATimelinePageSwitchDuration completion:^{
		
		[wSelf loadDataForDate:nextDay];
		wSelf.currentDisplayedDate = nextDay;
		nextDay = [wSelf nextDateWithArticle];
		if (nextDay)
			[wSelf preloadDataForDateOnLeft:nextDay];
		
	}];
	
}

- (void) handleSwipeLeft:(UISwipeGestureRecognizer *)swipe {
	
	NSLog(@"swipe left");
	
	__block NSDate *preDay = [self previousDateWithArticle];
	
	if (!preDay) {
		NSLog(@"There is no articles in the next day");
		return;
	}
		
	__weak WATimelineViewControllerPhone *wSelf = self;
	
	[self pushTableViewToLeftWithDuration:kWATimelinePageSwitchDuration completion:^{
		
		[wSelf loadDataForDate:preDay];
		wSelf.currentDisplayedDate = preDay;
		preDay = [wSelf previousDateWithArticle];
		if (preDay)
			[wSelf preloadDataForDateOnRight:preDay];
		
	}];

}

#pragma mark - handle long pressed gesture
- (void) handleMenu:(UILongPressGestureRecognizer *)longPress {

	UIMenuController * const menuController = [UIMenuController sharedMenuController];
	if (menuController.menuVisible)
		return;
	
	BOOL didBecomeFirstResponder = [self becomeFirstResponder];
	NSAssert1(didBecomeFirstResponder, @"%s must require cell to become first responder", __PRETTY_FUNCTION__);

	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[longPress locationInView:self.tableView]];
	WAArticle *article = [self.fetchedResultsController objectAtIndexPath:indexPath];
	
	WAPostViewCellPhone *cell = (WAPostViewCellPhone *
															 )[self.tableView cellForRowAtIndexPath:indexPath];
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
	if (article.modificationDate) {
		// set modification only when updating articles
		article.modificationDate = [NSDate date];
	}
	
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
		if (article.modificationDate) {
			// set modification only when updating articles
			article.modificationDate = [NSDate date];
		}
		
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

#pragma mark - date picker to switch timeline
- (void) jumpToToday {

	[self jumpToTimelineOnDate:[NSDate date]];
	
}

- (void) jumpToTimelineOnDate:(NSDate*)date{

	self.currentDisplayedDate = [date dayEnd];
	
	NSDate *toDate = [self previousDateWithArticle];
	
	if (!toDate)
		toDate = [self nextDateWithArticle];
	
	NSAssert1(toDate != nil, @"No article around date: %@ ?", date);
	
	[self loadDataForDate:toDate];
	[self.tableView reloadData];
	self.currentDisplayedDate = toDate;
	
	NSDate *preDate = [self previousDateWithArticle];
	if (preDate)
		[self preloadDataForDateOnRight:preDate];
	
	NSDate *nextDate = [self nextDateWithArticle];
	if (nextDate)
		[self preloadDataForDateOnLeft:nextDate];
}

- (void) handleDateSelect:(UIBarButtonItem *)sender {
	
	__block WADatePickerViewController *dpVC = [WADatePickerViewController controllerWithCompletion:^(NSDate *date) {
		
		if (date) {
			
			[self jumpToTimelineOnDate:date];
			
		}
		
		[dpVC willMoveToParentViewController:nil];
		[dpVC removeFromParentViewController];
		[dpVC.view removeFromSuperview];
		[dpVC didMoveToParentViewController:nil];
		
		dpVC = nil;
		
	}];
	
	NSFetchRequest *newestFr = [[WADataStore defaultStore] newFetchRequestForNewestArticle];
	NSFetchRequest *oldestFr = [[WADataStore defaultStore] newFetchRequestForOldestArticle];
	
	WAArticle *newestArticle = (WAArticle*)[[managedObjectContext executeFetchRequest:newestFr error:nil] lastObject];
	WAArticle *oldestArticle = (WAArticle*)[[managedObjectContext executeFetchRequest:oldestFr error:nil] lastObject];
	
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

#pragma mark - slinding menu
- (void) slidingMenuItemDidSelected:(id)result {
	
	NSFetchRequest *fr = (NSFetchRequest*)result;
	if (fr) {
		
		self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
		
		self.fetchedResultsController.delegate = self;
		[self.fetchedResultsController performFetch:nil];
		
		[self.tableView setContentOffset:CGPointZero animated:NO];
		[self.tableView reloadData];
		
	}
	
	[self.viewDeckController closeLeftView];

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

#pragma mark - Dripdown menu
BOOL dripdownMenuOpened = NO;
- (void) dripdownMenuTapped {
	
	if (dripdownMenuOpened)
		return;
	
	[self.navigationController setToolbarHidden:YES animated:YES];
	__block WADripdownMenuViewController *ddMenu = [[WADripdownMenuViewController alloc] initWithCompletion:^{
		
		[ddMenu willMoveToParentViewController:nil];
		[ddMenu removeFromParentViewController];
		[ddMenu.view removeFromSuperview];
		[ddMenu didMoveToParentViewController:nil];
		
		ddMenu = nil;
		[self.navigationController setToolbarHidden:NO animated:YES];

		dripdownMenuOpened = NO;
		
	}];
		
	[self addChildViewController:ddMenu];
	[self.view addSubview:ddMenu.view];
	[ddMenu didMoveToParentViewController:self];
	dripdownMenuOpened = YES;
}

#pragma mark - buttons (camera/compose/userinfo) in toolbar
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
	
	userInfoVC.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemDone wiredAction:^(IRBarButtonItem *senderItem) {
		
		[wUserInfoVC.navigationController dismissViewControllerAnimated:YES completion:nil];
		
	}];
	
	userInfoVC.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) action:^{

		IRAction *cancelAction = [IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", nil) block:nil];
		
		NSString *alertTitle = NSLocalizedString(@"ACTION_SIGN_OUT", nil);
		NSString *alertText = NSLocalizedString(@"SIGN_OUT_CONFIRMATION", nil);
		
		[[IRAlertView alertViewWithTitle:alertTitle message:alertText cancelAction:cancelAction otherActions:[NSArray arrayWithObjects:
			
			[IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", nil) block: ^ {

				WAOverlayBezel *bezel = [WAOverlayBezel bezelWithStyle:WADefaultBezelStyle];
				[bezel show];
				[[WAPhotoImportManager defaultManager] cancelPhotoImportWithCompletionBlock:^{
					
					[((WAAppDelegate*)AppDelegate()) unsubscribeRemoteNotification];
					
					[bezel dismiss];
					[wSelf.delegate applicationRootViewControllerDidRequestReauthentication:nil];
				}];
				
			}],
			
		nil]] show];
		
	}];
	
	[self presentViewController:navC animated:YES completion:nil];
	
}

@end
