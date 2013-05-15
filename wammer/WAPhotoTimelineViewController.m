//
//  WAPhotoTimelineViewController.m
//  wammer
//
//  Created by Shen Steven on 4/5/13.
//  Copyright (c) 2013 Waveface. All rights reserved.
//

#import "WAPhotoTimelineViewController.h"
#import "WAPhotoTimelineNavigationBar.h"
#import "WAPhotoTimelineCover.h"
#import "WAPhotoTimelineLayout.h"
#import "WATimelineIndexView.h"
#import "WAPartioSignupViewController.h"
#import "WAEventDetailsViewController.h"
#import "WADayPhotoPickerViewController.h"
#import "WAGalleryViewController.h"
#import "WAFBFriendPickerViewController.h"

#import "WAPhotoCollageCell.h"
#import "WADefines.h"

#import "WAAssetsLibraryManager.h"
#import "WAArticle.h"
#import "WADataStore.h"
#import "WAFile.h"
#import "WAFile+LazyImages.h"
#import "WAFileExif.h"
#import "WAFileExif+WAAdditions.h"
#import "WAPeople.h"
#import "WALocation.h"
#import "WACheckin.h"
#import "WAImageProcessing.h"
#import "ALAsset+WAAdditions.h"
#import "IRBindings.h"

#import "WADataStore+FetchingConveniences.h"
#import "WAGeoLocation.h"
#import <CoreLocation/CoreLocation.h>
#import <BlocksKit/BlocksKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "WAOverlayBezel.h"
#import "WATranslucentToolbar.h"
#import "NINetworkImageView.h"
#import <SMCalloutView/SMCalloutView.h>

#import "WADefines.h"
#import "WARemoteInterface.h"
#import "WASyncManager.h"
#import "WAAppDelegate.h"
#import "WAAppDelegate_iOS.h"

static NSString * const kWAPhotoTimelineViewController_CoachMarks = @"kWAPhotoTimelineViewController_CoachMarks";
static NSString * const kWAPhotoTimelineViewController_CoachMarks2 = @"kWAPhotoTimelineViewController_CoachMarks2";

@interface WAPhotoTimelineViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate>

@property (nonatomic, strong) WAPhotoTimelineCover *headerView;
@property (nonatomic, strong) WAPhotoTimelineNavigationBar *navigationBar;
@property (nonatomic, weak) IBOutlet UIToolbar *toolbar;
@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, weak) IBOutlet WATimelineIndexView *indexView;
@property (nonatomic, strong) WAPartioSignupViewController *signupVC;

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSOperationQueue *imageDisplayQueue;

@property (nonatomic, strong) NSManagedObjectID *representingArticleID;
@property (nonatomic, strong) WAArticle *representingArticle;
@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, strong) NSArray *sortedImages;
@property (nonatomic, strong) NSArray *allAssets;
@property (nonatomic, strong) WAGeoLocation *geoLocation;
@property (nonatomic, strong) NSDate *eventDate;
@property (nonatomic, strong) NSDate *beginDate;
@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, strong) NSArray *checkins;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong) NSString *locationName;

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) SMCalloutView *shareInstructionView;
@property (nonatomic, strong) SMCalloutView *addMorePhotosInstructionView;
@property (nonatomic, strong) SMCalloutView *inviteMoreInstructionView;
@end

@implementation WAPhotoTimelineViewController {
  BOOL naviBarShown;
  BOOL toolBarShown;
  CGFloat previousYOffset;
  CLLocationCoordinate2D _coordinate;
}

- (id) initWithAssets:(NSArray *)assets {
  self = [super initWithNibName:@"WAPhotoTimelineViewController" bundle:nil];
  if (self) {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:assets.count];
    NSEnumerator *enumerator = [assets reverseObjectEnumerator];
    for (ALAsset *element in enumerator) {
      [array addObject:element];
    }
    self.allAssets = [NSArray arrayWithArray:array];
    
    _coordinate.latitude = 0;
    _coordinate.longitude = 0;
  }
  return self;
}

- (id) initWithArticleID:(NSManagedObjectID *)articleID {
  self = [super initWithNibName:@"WAPhotoTimelineViewController" bundle:nil];
  if (self) {
    
    self.representingArticleID = articleID;
    self.representingArticle = (WAArticle*)[self.managedObjectContext objectWithID:articleID];
    self.sortedImages = [self.representingArticle.files sortedArrayUsingComparator:^NSComparisonResult(WAFile *obj1, WAFile *obj2) {
      return [obj1.created compare:obj2.created];
    }];
  
    self.allAssets = @[];

  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  naviBarShown = NO;
  toolBarShown = YES;
  previousYOffset = 0;
  
  if (self.representingArticle) {
    [self touchArticleForRead];
  }
  
  self.imageDisplayQueue = [[NSOperationQueue alloc] init];
  self.imageDisplayQueue.maxConcurrentOperationCount = 1;
  
  __weak WAPhotoTimelineViewController *wSelf = self;
  self.navigationItem.leftBarButtonItem = WAPartioBackButton(^{
    [wSelf.navigationController popViewControllerAnimated:YES];
  });
    
  self.navigationBar = [[WAPhotoTimelineNavigationBar alloc] initWithFrame:(CGRect)CGRectMake(0, 0, self.view.frame.size.width, 44)];
  self.navigationBar.barStyle = UIBarStyleDefault;
  self.navigationBar.tintColor = [UIColor clearColor];
  self.navigationBar.backgroundColor = [UIColor clearColor];
  self.navigationBar.translucent = YES;
  //  self.navigationBar.items = @[backItem, actionItem];
  [self.navigationBar pushNavigationItem:self.navigationItem animated:NO];
  
  [self.view addSubview:self.navigationBar];
  
  [self.collectionView setBackgroundColor:[UIColor blackColor]];
  ((UICollectionViewFlowLayout*)self.collectionView.collectionViewLayout).minimumLineSpacing = 0.0f;
  
  self.collectionView.showsVerticalScrollIndicator = NO;
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"WAPhotoTimelineCover" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"PhotoTimelineCover"];
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"WAPhotoCollageCell_Stack4" bundle:nil]
        forCellWithReuseIdentifier:@"CollectionItemCell4"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"WAPhotoCollageCell_Stack3" bundle:nil]
        forCellWithReuseIdentifier:@"CollectionItemCell3"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"WAPhotoCollageCell_Stack2" bundle:nil]
        forCellWithReuseIdentifier:@"CollectionItemCell2"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"WAPhotoCollageCell_Stack1" bundle:nil]
        forCellWithReuseIdentifier:@"CollectionItemCell1"];

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter = [[NSDateFormatter alloc] init];
  formatter.dateStyle = NSDateFormatterNoStyle;
  formatter.timeStyle = NSDateFormatterShortStyle;

  [self.indexView addIndex:0.01 label:[formatter stringFromDate:self.beginDate]];
  [self.indexView addIndex:0.99 label:[formatter stringFromDate:self.endDate]];

  [self.toolbar setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
  self.toolbar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
  if (!self.representingArticle) {
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    UIBarButtonItem *nextItem = WAPartioToolbarNextButton(NSLocalizedString(@"PICKCONTACTS_ACTION", @"action pick contacts"), ^{
      [wSelf actionButtonClicked:nil];
    });
    
    self.toolbar.items = @[flexibleSpace, nextItem, flexibleSpace];
    [self.view addSubview:self.toolbar];
  } else {
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    // add contacts button
    UIBarButtonItem *addContacts = WAPartioToolbarButton(nil, [UIImage imageNamed:@"AddPplBtn"],nil, ^{
      WAFBFriendPickerViewController *contactPicker = [[WAFBFriendPickerViewController alloc] init];
      [contactPicker loadData];
      [contactPicker clearSelection];
      
      __weak WAFBFriendPickerViewController *wcp = contactPicker;
      contactPicker.onNextHandler = ^(NSArray *selectedContacts){
        [wcp dismissViewControllerAnimated:YES completion:nil];
        [wSelf updateSharingEventWithPhotoChanges:nil contacts:selectedContacts onComplete:^{
          [WAOverlayBezel showSuccessBezelWithDuration:1.5 handler:nil];
          [wSelf.collectionView reloadData];
        }];

      };
      
      contactPicker.onDismissHandler = ^ {
        [wcp dismissViewControllerAnimated:YES completion:nil];
      };
      
      wSelf.modalPresentationStyle = UIModalPresentationCurrentContext;
      [wSelf presentViewController:contactPicker animated:YES completion:nil];
    });
    
    // add photos button
    UIBarButtonItem *addPhotos = WAPartioToolbarButton(nil, [UIImage imageNamed:@"AddPhotoBtn"], nil, ^{
      WADayPhotoPickerViewController *photoPicker = [[WADayPhotoPickerViewController alloc] initWithSuggestedDateRangeFrom:[self beginDate] to:[self endDate]];
      __weak WADayPhotoPickerViewController *wpp = photoPicker;
      photoPicker.onCancelHandler = ^{
        [wpp dismissViewControllerAnimated:YES completion:nil];
      };
      photoPicker.actionButtonLabelText = NSLocalizedString(@"ACTION_ADD_PHOTOS", @"Add photos");
      
      // doneb
      photoPicker.onNextHandler = ^(NSArray *selectedAssets) {
        [wpp dismissViewControllerAnimated:YES completion:nil];
        
        [wSelf updateSharingEventWithPhotoChanges:selectedAssets contacts:nil onComplete:^{
          dispatch_async(dispatch_get_main_queue(), ^{
            [WAOverlayBezel showSuccessBezelWithDuration:1.5 handler:nil];
            
            wSelf.sortedImages = [self.representingArticle.files sortedArrayUsingComparator:^NSComparisonResult(WAFile *obj1, WAFile *obj2) {
              return [obj1.created compare:obj2.created];
            }];

            [wSelf.collectionView reloadData];
          });
        }];
      };
      wSelf.modalPresentationStyle = UIModalPresentationCurrentContext;
      [wSelf presentViewController:photoPicker animated:YES completion:nil];
    });
    
    self.toolbar.items = @[ addContacts, flexibleSpace, addPhotos];
    [self.view addSubview:self.toolbar];
  }
  
}

- (void) viewDidAppear:(BOOL)animated {
  
  [super viewDidAppear:animated];

  if (!self.representingArticle) {
    BOOL coachmarkShown = [[NSUserDefaults standardUserDefaults] boolForKey:kWAPhotoTimelineViewController_CoachMarks];
    if (!coachmarkShown) {
      __weak WAPhotoTimelineViewController *wSelf = self;
      if (!self.shareInstructionView) {
        self.shareInstructionView = [SMCalloutView new];
        self.shareInstructionView.title = NSLocalizedString(@"INSTRUCTION_IN_PREVIEW_SHARE_BUTTON", @"The instruction show to go next in the preview view");
        [self.shareInstructionView presentCalloutFromRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height-44, 1, 1) inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionDown animated:YES];
        self.tapGesture = [[UITapGestureRecognizer alloc] initWithHandler:^(UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location) {
          if (wSelf.shareInstructionView) {
            [wSelf.shareInstructionView dismissCalloutAnimated:YES];
            wSelf.shareInstructionView = nil;
          }
          [wSelf.view removeGestureRecognizer:wSelf.tapGesture];
          wSelf.tapGesture = nil;
        }];
        [self.view addGestureRecognizer:self.tapGesture];
      }
      
      [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWAPhotoTimelineViewController_CoachMarks];
      [[NSUserDefaults standardUserDefaults] synchronize];
    }
  } else {
    BOOL coachmarkShown = [[NSUserDefaults standardUserDefaults] boolForKey:kWAPhotoTimelineViewController_CoachMarks2];
    if (!coachmarkShown) {
      __weak WAPhotoTimelineViewController *wSelf = self;
      
      self.addMorePhotosInstructionView = [SMCalloutView new];
      self.addMorePhotosInstructionView.title = NSLocalizedString(@"INSTRUCTION_ADD_MORE_PHOTOS", @"Add more photos");
      [self.addMorePhotosInstructionView presentCalloutFromRect:CGRectMake(self.toolbar.frame.size.width - 50, self.toolbar.frame.origin.y, 1, 1) inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionDown animated:YES];
      [self performBlock:^(id sender) {
        [wSelf.addMorePhotosInstructionView dismissCalloutAnimated:YES];
        wSelf.addMorePhotosInstructionView = nil;
        wSelf.inviteMoreInstructionView = [SMCalloutView new];
        wSelf.inviteMoreInstructionView.title = NSLocalizedString(@"INSTRUCTION_INVITE_MORE", @"Invite more people");
        [wSelf.inviteMoreInstructionView presentCalloutFromRect:CGRectMake(50, self.toolbar.frame.origin.y, 1, 1) inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionDown animated:YES];
        [wSelf performBlock:^(id sender) {
          [wSelf.inviteMoreInstructionView dismissCalloutAnimated:YES];
          wSelf.inviteMoreInstructionView = nil;
        } afterDelay:2.0f];
        
      } afterDelay:2.0f];
      [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWAPhotoTimelineViewController_CoachMarks2];
      [[NSUserDefaults standardUserDefaults] synchronize];
    }
  }
}

- (void) dealloc {
  if (self.tapGesture)
    [self.view removeGestureRecognizer:self.tapGesture];
}

- (void) touchArticleForRead {
  if (self.representingArticle) {
    self.representingArticle.lastRead = [NSDate date];
    NSError *error = nil;
    [self.managedObjectContext save:&error];
  }
}

- (void) updateSharingEventWithPhotoChanges:(NSArray*)newAssets contacts:(NSArray*)contacts onComplete:(void(^)(void))completionBlock {
  NSDate *importTime = [NSDate date];
  BOOL changed = NO;
  
  NSManagedObjectContext *moc = [[WADataStore defaultStore] autoUpdatingMOC];
  WAArticle *article = (WAArticle*)[moc objectWithID:self.representingArticleID];
  
  for (ALAsset *asset in newAssets) {
    
    NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"WAFile"];
    fr.predicate = [NSPredicate predicateWithFormat:@"assetURL = %@", [[[asset defaultRepresentation] url] absoluteString]];
    NSError *error = nil;
    NSArray *result = [moc executeFetchRequest:fr error:&error];
    if (result.count) {
      WAFile *file = (WAFile*)result[0];
      if ([article.files containsObject:file])
          continue;
        [[article mutableOrderedSetValueForKey:@"files"] addObject:file];
      changed = YES;
    } else {
      
      WAFile *file = (WAFile*)[WAFile objectInsertingIntoContext:moc withRemoteDictionary:@{}];
      CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
      if (theUUID)
        file.identifier = [((__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, theUUID)) lowercaseString];
      CFRelease(theUUID);
      file.dirty = (id)kCFBooleanTrue;
      
      [[article mutableOrderedSetValueForKey:@"files"] addObject:file];
      
      UIImage *extraSmallThumbnailImage = [UIImage imageWithCGImage:[asset thumbnail]];
      file.extraSmallThumbnailFilePath = [[[WADataStore defaultStore] persistentFileURLForData:UIImageJPEGRepresentation(extraSmallThumbnailImage, 0.85f) extension:@"jpeg"] path];
      
      file.assetURL = [[[asset defaultRepresentation] url] absoluteString];
      file.resourceType = (NSString *)kUTTypeImage;
      file.timestamp = [asset valueForProperty:ALAssetPropertyDate];
      file.created = file.timestamp;
      file.importTime = importTime;
      
      WAFileExif *exif = (WAFileExif *)[WAFileExif objectInsertingIntoContext:moc withRemoteDictionary:@{}];
      NSDictionary *metadata = [[asset defaultRepresentation] metadata];
      [exif initWithExif:metadata[@"{Exif}"] tiff:metadata[@"{TIFF}"] gps:metadata[@"{GPS}"]];
      
      file.exif = exif;
      changed = YES;
    }
  }
  
  if (contacts.count) {
    NSArray *emailsFromContacts = [contacts valueForKey:@"email"];
    NSMutableArray *invitingEmails = [NSMutableArray array];
    for (NSArray *contactEmails in emailsFromContacts) {
      [invitingEmails addObjectsFromArray:[contactEmails filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.length!=0;
      }]]];
    }
    NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"WAPeople"];
    fr.predicate = [NSPredicate predicateWithFormat:@"email IN %@", invitingEmails];
    NSError *error = nil;
    NSArray *peopleFound = [moc executeFetchRequest:fr error:&error];
    if (peopleFound.count) {
      for (WAPeople *person in peopleFound) {
        [[article mutableSetValueForKey:@"sharingContacts"] addObject:person];
        if ([invitingEmails indexOfObject:person.email] != NSNotFound) {
          [invitingEmails removeObject:person.email];
        }
        changed = YES;
      }
    }
    for (NSString *email in invitingEmails) {
      WAPeople *person = (WAPeople*)[WAPeople objectInsertingIntoContext:moc withRemoteDictionary:@{}];
      person.email = email;
      [[article mutableSetValueForKey:@"sharingContacts"] addObject:person];
      changed = YES;
    }
  }
  
  if (self.checkins.count) {
    for (WALocation *checkin in self.checkins) {
      if (![article.checkins containsObject:checkin]) {
        [[article mutableSetValueForKey:@"checkins"] addObject:checkin];
        changed = YES;
      }
    }
  }
  
  if (changed) {
    article.dirty = (id)kCFBooleanTrue;
    article.modificationDate = [NSDate date];
    NSError *savingError = nil;
    if ([moc save:&savingError]) {
      NSLog(@"Sharing event successfully updated");
    } else {
      NSLog(@"error on creating a new import post for error: %@", savingError);
    }
    
    WAAppDelegate_iOS *appDelegate = (WAAppDelegate_iOS*)AppDelegate();
    [appDelegate.syncManager reload];

    if (completionBlock)
      completionBlock();
  }


}

- (void) finishCreatingSharingEventForSharingTargets:(NSArray *)contacts {
  
  NSDate *importTime = [NSDate date];
  
  NSManagedObjectContext *moc = [[WADataStore defaultStore] autoUpdatingMOC];
  WAArticle *article = [WAArticle objectInsertingIntoContext:moc withRemoteDictionary:@{}];
  
  for (ALAsset *asset in self.allAssets) {
    @autoreleasepool {
      
      NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"WAFile"];
      fr.predicate = [NSPredicate predicateWithFormat:@"assetURL = %@", [[[asset defaultRepresentation] url] absoluteString]];
      NSError *error = nil;
      NSArray *result = [moc executeFetchRequest:fr error:&error];
      if (result.count) {
        
        [[article mutableOrderedSetValueForKey:@"files"] addObject:(WAFile*)result[0]];
        
      } else {
        
        WAFile *file = (WAFile *)[WAFile objectInsertingIntoContext:moc withRemoteDictionary:@{}];
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        if (theUUID)
          file.identifier = [((__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, theUUID)) lowercaseString];
        CFRelease(theUUID);
        file.dirty = (id)kCFBooleanTrue;
        
        [[article mutableOrderedSetValueForKey:@"files"] addObject:file];
        
        UIImage *extraSmallThumbnailImage = [UIImage imageWithCGImage:[asset thumbnail]];
        file.extraSmallThumbnailFilePath = [[[WADataStore defaultStore] persistentFileURLForData:UIImageJPEGRepresentation(extraSmallThumbnailImage, 0.85f) extension:@"jpeg"] path];
        
        file.assetURL = [[[asset defaultRepresentation] url] absoluteString];
        file.resourceType = (NSString *)kUTTypeImage;
        file.timestamp = [asset valueForProperty:ALAssetPropertyDate];
        file.created = file.timestamp;
        file.importTime = importTime;
        
        WAFileExif *exif = (WAFileExif *)[WAFileExif objectInsertingIntoContext:moc withRemoteDictionary:@{}];
        NSDictionary *metadata = [[asset defaultRepresentation] metadata];
        [exif initWithExif:metadata[@"{Exif}"] tiff:metadata[@"{TIFF}"] gps:metadata[@"{GPS}"]];
        
        file.exif = exif;
        
      }
    }
  }
  
  article.event = (id)kCFBooleanTrue;
  article.eventType = [NSNumber numberWithInt:WAEventArticleSharedType];
  article.draft = (id)kCFBooleanFalse;
  CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
  if (theUUID)
    article.identifier = [((__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, theUUID)) lowercaseString];
  CFRelease(theUUID);
  article.dirty = (id)kCFBooleanTrue;
  article.creationDeviceName = [UIDevice currentDevice].name;
  article.eventStartDate = [self beginDate];
  article.eventEndDate = [self endDate];
  article.creationDate = [NSDate date];
  
  if (contacts.count) {
    NSArray *emailsFromContacts = [contacts valueForKey:@"email"];
    NSMutableArray *invitingEmails = [NSMutableArray array];
    for (NSArray *contactEmails in emailsFromContacts) {
      [invitingEmails addObjectsFromArray:[contactEmails filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.length!=0;
      }]]];
    }
    NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"WAPeople"];
    fr.predicate = [NSPredicate predicateWithFormat:@"email IN %@", invitingEmails];
    NSError *error = nil;
    NSArray *peopleFound = [moc executeFetchRequest:fr error:&error];
    if (peopleFound.count) {
      for (WAPeople *person in peopleFound) {
        [[article mutableSetValueForKey:@"sharingContacts"] addObject:person];
        if ([invitingEmails indexOfObject:person.email] != NSNotFound) {
          [invitingEmails removeObject:person.email];
        }
      }
    }
    for (NSString *email in invitingEmails) {
      if (email.length) {
        WAPeople *person = (WAPeople*)[WAPeople objectInsertingIntoContext:moc withRemoteDictionary:@{}];
        person.email = email;
        [[article mutableSetValueForKey:@"sharingContacts"] addObject:person];
      }
    }
  }
  
  WALocation *location = (WALocation*)[WALocation objectInsertingIntoContext:moc withRemoteDictionary:@{}];
  location.latitude = [NSNumber numberWithFloat:self.coordinate.latitude];
  location.longitude = [NSNumber numberWithFloat:self.coordinate.longitude];
  location.name = self.locationName;
  article.location = location;
  
  if (self.checkins.count) {
    for (WACheckin *checkin in self.checkins) {
      if (![article.checkins containsObject:checkin]) {
        [[article mutableSetValueForKey:@"checkins"] addObject:checkin];
      }
    }
  }
  
  NSError *savingError = nil;
  if ([moc save:&savingError]) {
    NSLog(@"Sharing event successfully created");
  } else {
    NSLog(@"error on creating a new import post for error: %@", savingError);
  }
  
  WAAppDelegate_iOS *appDelegate = (WAAppDelegate_iOS*)AppDelegate();
  [appDelegate.syncManager reload];
  
}

- (NSManagedObjectContext*)managedObjectContext {
  
  if (_managedObjectContext)
    return _managedObjectContext;
  
  _managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];
  return _managedObjectContext;
  
}

- (BOOL) shouldAutorotate {
  
  return YES;
  
}

- (NSUInteger) supportedInterfaceOrientations {
  
  return UIInterfaceOrientationMaskPortrait;

}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
  if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation)) {
    if (self.representingArticle) {
      WAGalleryViewController *gallery = [WAGalleryViewController controllerRepresentingArticleAtURI:[[self.representingArticle objectID] URIRepresentation] context:nil];
      [self.navigationController pushViewController:gallery animated:YES];

    }
  }
}

- (void) backButtonClicked:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)actionButtonClicked:(id)sender
{
  if (!FBSession.activeSession.isOpen) {
    // if the session is closed, then we open it here, and establish a handler for state changes
    [FBSession openActiveSessionWithReadPermissions:nil
                                       allowLoginUI:YES
                                  completionHandler:^(FBSession *session,
                                                      FBSessionState state,
                                                      NSError *error) {
                                    if (error) {
                                      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                                          message:error.localizedDescription
                                                                                         delegate:nil
                                                                                cancelButtonTitle:@"OK"
                                                                                otherButtonTitles:nil];
                                      [alertView show];
                                    } else if (session.isOpen) {
                                      [self actionButtonClicked:sender];
                                    }
                                  }];
    return;
  }
  
  __weak WAPhotoTimelineViewController *wSelf = self;
  WAFBFriendPickerViewController *contactPicker = [[WAFBFriendPickerViewController alloc] init];
  [contactPicker loadData];
  [contactPicker clearSelection];
  
  if (self.navigationController) {
    contactPicker.onNextHandler = ^(NSArray *results) {
      
      WARemoteInterface *ri = [WARemoteInterface sharedInterface];
      if (ri.userToken) {
        [wSelf finishCreatingSharingEventForSharingTargets:results];

        [WAOverlayBezel showSuccessBezelWithDuration:1.5 handler:^{
          
          [wSelf.navigationController dismissViewControllerAnimated:YES completion:nil];
        }];
      
      } else {
        
        WAPartioSignupViewController *createAccountVC = [[WAPartioSignupViewController alloc] initWithCompleteHandler:nil];
        __weak WAPartioSignupViewController *sCreateAccountVC = createAccountVC;
        createAccountVC.completeHandler = ^(NSError *error) {
        
          [wSelf finishCreatingSharingEventForSharingTargets:results];

          [[NSNotificationCenter defaultCenter] postNotificationName:kWACoreDataReinitialization object:self];

          [WAOverlayBezel showSuccessBezelWithDuration:1.5 handler:^{
            
            [sCreateAccountVC dismissViewControllerAnimated:YES completion:^{
              [wSelf.navigationController dismissViewControllerAnimated:YES completion:nil];
            }];
        
          }];

          
        };
        
        wSelf.signupVC = createAccountVC;
        wSelf.navigationController.modalPresentationStyle = UIModalPresentationCurrentContext;
        createAccountVC.view.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
        createAccountVC.view.alpha = 0;
        [wSelf presentViewController:createAccountVC animated:NO completion:nil];
        [UIView animateWithDuration:0.5 animations:^{
          createAccountVC.view.alpha = 1;
        }];
      }
    };
    [self.navigationController pushViewController:contactPicker animated:YES];
    
  }
  
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CLLocationCoordinate2D)coordinate {
  
  if (_coordinate.latitude!=0 && _coordinate.longitude!=0)
    return _coordinate;

  if (self.representingArticle) {
    _coordinate.latitude = [self.representingArticle.location.latitude floatValue];
    _coordinate.longitude = [self.representingArticle.location.longitude floatValue];
  } else {
    for (ALAsset *asset in self.allAssets) {
      NSDictionary *meta = [asset defaultRepresentation].metadata;
      if (meta) {
        NSDictionary *gps = meta[@"{GPS}"];
        if (gps) {
          _coordinate.latitude = [(NSNumber*)[gps valueForKey:@"Latitude"] doubleValue];
          _coordinate.longitude = [(NSNumber*)[gps valueForKey:@"Longitude"] doubleValue];
          if ([gps[@"LongitudeRef"] isEqualToString:@"W"]) {
            _coordinate.longitude = -_coordinate.longitude;
          }
          if ([gps[@"LatitudeRef"] isEqualToString:@"S"]) {
            _coordinate.latitude = -_coordinate.latitude;
          }

          break;
        }
      }
    }
  }
  return _coordinate;
}

- (NSDate*) eventDate {
  
  if (_eventDate)
    return _eventDate;

  if (self.representingArticle)
    _eventDate = self.representingArticle.eventStartDate;
  else
    _eventDate = [self.allAssets[0] valueForProperty:ALAssetPropertyDate];
  return _eventDate;
  
}

- (NSDate *) beginDate {
  if (_beginDate)
    return _beginDate;
 
  if (self.representingArticle)
    _beginDate = self.representingArticle.eventStartDate;
  else
    _beginDate = [self.allAssets[0] valueForProperty:ALAssetPropertyDate];
  return _beginDate;
}

- (NSDate *) endDate {
  if (_endDate)
    return _endDate;
  
  if (self.representingArticle)
    _endDate = self.representingArticle.eventEndDate;
  else
    _endDate = [self.allAssets.lastObject valueForProperty:ALAssetPropertyDate];
  return _endDate;
}

- (NSArray *)checkins {
  
  if (self.representingArticle) {
    return self.representingArticle.uniqueCheckins;
  } else {
    NSDate *beginDate = [NSDate dateWithTimeInterval:(-30*60) sinceDate:self.beginDate];
    NSDate *endDate = [NSDate dateWithTimeInterval:(30*60) sinceDate:self.endDate];
    NSFetchRequest * fetchRequest = [[WADataStore defaultStore] newFetchReuqestForCheckinFrom:beginDate to:endDate];
    
    NSError *error = nil;
    NSArray *checkins = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {
      NSLog(@"error to query checkin db: %@", error);
      _checkins = @[];
      return _checkins;
    } else if (checkins.count) {
      _checkins = checkins;
      return _checkins;
    }
  }
  return @[];
}

- (NSArray *)contacts {
  if (self.representingArticle) {
    return [self.representingArticle.sharingContacts allObjects];
  } else {
    return @[];
  }
}

- (NSDictionary*) userInfo {

  if (self.representingArticle) {
    NSString *creatorID = self.representingArticle.owner.identifier;
    WAPeople *contact = nil;
    for (WAPeople *person in self.representingArticle.sharingContacts) {
      if ([person.identifier isEqualToString:creatorID]) {
        contact = person;
        break;
      }
    }

    if (contact) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      if (contact.avatarURL)
        dict[@"avatarURL"] = contact.avatarURL;
      if (contact.email)
        dict[@"email"] = contact.email;
      return dict;
    } else {
      return nil;
    }
  } else {
    WAUser *user = [[WADataStore defaultStore] mainUserInContext:self.managedObjectContext];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (user.avatarURL)
      dict[@"avatarURL"] = user.avatarURL;
    if (user.avatar)
      dict[@"avatar"] = user.avatar;
    if (user.email)
      dict[@"email"] = user.email;
    return dict;
  }
  
}

#pragma mark - UICollectionView datasource
- (NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return 1;
}

- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  
  NSUInteger numOfPhotos = self.allAssets.count;
  if (self.representingArticle)
    numOfPhotos = self.sortedImages.count;
  NSUInteger totalItem = (numOfPhotos / 10) * 4;
  NSUInteger mod = numOfPhotos % 10;
  if (mod == 0)
    return totalItem;
  else if (mod < 5)
    return totalItem + 1;
  else if (mod < 8)
    return totalItem + 2;
  else if (mod < 10)
    return totalItem + 3;
  else
    return totalItem + 4;
  
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  
  NSUInteger totalNumber = self.allAssets.count;
  if (self.representingArticle)
    totalNumber = self.sortedImages.count;

  NSUInteger numOfPhotos = 4 - (indexPath.row % 4);
  NSString *identifier = [NSString stringWithFormat:@"CollectionItemCell%d", numOfPhotos];
  
  WAPhotoCollageCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
  
  NSUInteger base = 0;
  switch(indexPath.row % 4) {
    case 3:
      base = (indexPath.row / 4) * 10 + 9;
      break;
    case 2:
      base = (indexPath.row / 4) * 10 + 7;
      break;
    case 1:
      base = (indexPath.row / 4) * 10 + 4;
      break;
    case 0:
      base = (indexPath.row / 4) * 10;
      break;
  }
  
  __weak WAPhotoTimelineViewController *wSelf = self;
  for (NSUInteger i = 0; i < numOfPhotos; i++) {
    
    if ((base+i) < totalNumber) {
      if (self.representingArticle) {
        
        [self.sortedImages[base+i]
         irObserve:@"thumbnailImage"
         options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
         context:nil
         withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
           
           UIImage *image = (UIImage*)toValue;
           [[NSOperationQueue mainQueue] addOperationWithBlock:^{
             ((UIImageView *)cell.imageViews[i]).image = image;
           }];
           
         }];
        
      } else {
        ALAsset *asset = wSelf.allAssets[base+i];
        
        [cell.imageViews[i] irUnbind:@"image"];
        [cell.imageViews[i] irBind:@"image" toObject:asset keyPath:@"cachedPresentableImage" options:@{kIRBindingsAssignOnMainThreadOption: (id)kCFBooleanTrue}];
        
      }
    } else {
      [(UIImageView*)cell.imageViews[i] setBackgroundColor:[UIColor clearColor]];
    }
  }
  
  return cell;
}

- (UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
  
  __weak WAPhotoTimelineViewController *wSelf = self;
  if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        
    WAPhotoTimelineCover *cover = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"PhotoTimelineCover" forIndexPath:indexPath];
    
    if (self.representingArticle) {
    
      [self.sortedImages[self.sortedImages.count/3]
       irObserve:@"thumbnailImage"
       options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
       context:nil
       withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {

         UIImage *image = (UIImage*)toValue;
         [[NSOperationQueue mainQueue] addOperationWithBlock:^{
           cover.coverImageView.image = image;
         }];
         
       }];
      
    } else {
      ALAsset *coverAsset = self.allAssets[(NSInteger)(self.allAssets.count/3)];
      
      NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        
        UIImage *coverImage = [UIImage imageWithCGImage:[coverAsset defaultRepresentation].fullScreenImage];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          cover.coverImageView.image = coverImage;
        }];
      }];

      [self.imageDisplayQueue addOperation:op];
    }
    
    self.headerView = cover;
    
//    NSUInteger zoomLevel = 15; // hardcoded, but we may tune this in the future
    
    MKCoordinateRegion region = MKCoordinateRegionMake(self.coordinate, MKCoordinateSpanMake(0.03, 0.03));
//    cover.mapView.region = [cover.mapView regionThatFits:region];
    cover.mapView.region = region;
//    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.coordinate.latitude
//                                                            longitude:self.coordinate.longitude
//                                                                 zoom:zoomLevel];
//    
//    [cover.mapView setCamera:camera];
//    cover.mapView.myLocationEnabled = NO;
    
    if (self.checkins.count) {
      NSArray *checkinNames = [self.checkins valueForKey:@"name"];
      cover.titleLabel.text = [checkinNames componentsJoinedByString:@","];
    } else
      cover.titleLabel.text = @"";
    
    self.geoLocation = [[WAGeoLocation alloc] init];
    [self.geoLocation identifyLocation:self.coordinate onComplete:^(NSArray *results) {
      wSelf.locationName = [results componentsJoinedByString:@","];
      if (cover.titleLabel.text.length == 0)
        cover.titleLabel.text = [results componentsJoinedByString:@","];
      else
        cover.titleLabel.text = [NSString stringWithFormat:@"%@,%@", cover.titleLabel.text, [results componentsJoinedByString:@","]];
    } onError:^(NSError *error) {
      NSLog(@"Unable to identify location: %@", error);
    }];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    cover.dateLabel.text = [formatter stringFromDate:self.eventDate];
    
    [cover.detailButton addTarget:self action:@selector(detailButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cover.nameDetailButton addTarget:self action:@selector(detailButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    NSDictionary *user = [self userInfo];
    cover.avatarView.image = [UIImage imageNamed:@"Avatar"];
    if (user[@"avatarURL"]) {
      [cover.avatarView setPathToNetworkImage:user[@"avatarURL"] forDisplaySize:cover.avatarView.frame.size];
    } else {
      if (user[@"avatar"]) {
        cover.avatarView.image = user[@"avatar"];
      }
    }

    if (self.representingArticle)
      cover.informationLabel.text = [NSString stringWithFormat:NSLocalizedString(@"INFO_EVENT_FRIENDS", @"show how many friends with creator"), self.representingArticle.sharingContacts.count - 1];
    else
      cover.informationLabel.text = NSLocalizedString(@"INFO_HINT", @"information in event view to show hint");
    return cover;
    
  }
  return nil;
}

- (IBAction)detailButtonTapped:(id)sender {
  NSDictionary *detailInfo = @{
                               @"eventStartDate": [self beginDate],
                               @"eventEndDate":[self endDate],
                               @"latitude": @(self.coordinate.latitude),
                               @"longitude":@(self.coordinate.longitude),
                               @"checkins": [self checkins],
                               @"contacts": [self contacts]
                               };
  WAEventDetailsViewController *detail = [WAEventDetailsViewController wrappedNavigationControllerForDetailInfo:detailInfo];
  [self presentViewController:detail animated:YES completion:nil];
}

#pragma mark - UICollectionViewFlowLayout delegate

- (CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
  
  return CGSizeMake(self.collectionView.frame.size.width, 250);
  
}

- (CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  
  CGFloat height = 200;
  switch (indexPath.row % 4) {
    case 0:
      height = 210;
      break;
    case 1:
      height = 90;
      break;
    case 2:
      height = 130;
      break;
    case 3:
      height = 210;
      break;
  }
  return CGSizeMake(self.collectionView.frame.size.width, height);
  
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (self.representingArticle) {
    WAFile *file = self.sortedImages[indexPath.row];
    WAGalleryViewController *gallery = [WAGalleryViewController controllerRepresentingArticleAtURI:[[self.representingArticle objectID] URIRepresentation] context:@{kWAGalleryViewControllerContextPreferredFileObjectURI: file.objectID.URIRepresentation}];
    [self.navigationController pushViewController:gallery animated:YES];
  }
}

- (void) showingNavigationBar {
  UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(25, 0, 200, 44)];
  label.text = self.headerView.titleLabel.text;
  label.tag = 99;
  label.textColor = [UIColor colorWithWhite:255 alpha:0.2];
  label.backgroundColor = [UIColor clearColor];
  label.alpha = 0.2f;
  [self.navigationBar addSubview:label];
  
  [UIView animateWithDuration:0.3
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionShowHideTransitionViews
                   animations:^{
                     
                     label.textColor = [UIColor whiteColor];
                     label.frame = CGRectMake(50, 0, 200, 44);
                     label.alpha = 1.0f;
                   } completion:^(BOOL finished) {
                     
                   }];
  self.navigationBar.solid = YES;
  [self.navigationBar setNeedsDisplay];
  
}

- (void) hideNavigationBar {
  [self.navigationBar.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([obj isKindOfClass:[UILabel class]] && [obj tag] == 99) {
      UILabel *label = (UILabel*)obj;
      
      [UIView animateWithDuration:1
                            delay:0
                          options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionShowHideTransitionViews
                       animations:^{
                         label.textColor = [UIColor colorWithWhite:255 alpha:0.2];
                         label.alpha = 0.0f;
                       } completion:^(BOOL finished) {
                         
                         [label removeFromSuperview];
                         
                       }];
      
    }
  }];
  
  self.navigationBar.solid = NO;
  [self.navigationBar setNeedsDisplay];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
  
  if (self.shareInstructionView) {
    [self.shareInstructionView dismissCalloutAnimated:YES];
    self.shareInstructionView = nil;
    [self.view removeGestureRecognizer:self.tapGesture];
    self.tapGesture = nil;
  }
  
  if (self.indexView.hidden && scrollView.contentOffset.y > 0)
    self.indexView.hidden = NO;
  
  if (!naviBarShown && scrollView.contentOffset.y >= (250-44-50)) {
    
    [self performSelectorOnMainThread:@selector(showingNavigationBar) withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
    naviBarShown = YES;
    
  }
  
  if (naviBarShown && scrollView.contentOffset.y <= (250-44-50)) {
    [self performSelectorOnMainThread:@selector(hideNavigationBar) withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
    naviBarShown = NO;
  }
    
  if (scrollView.contentOffset.y > 0) {
//    CGFloat ratio = scrollView.contentSize.height / (scrollView.contentSize.height - scrollView.frame.size.height);
    CGFloat percent = (scrollView.contentOffset.y / (scrollView.contentSize.height - self.collectionView.frame.size.height));
    self.indexView.percentage = percent;
  }
  
  if (scrollView.contentOffset.y > 0) {
    if (scrollView.contentOffset.y > previousYOffset) {
      if (toolBarShown) {
        toolBarShown = NO;
        [UIView animateWithDuration:0.5 animations:^{
          self.toolbar.alpha = 0;
        } completion:nil];
      }
    } else {
      if (!toolBarShown) {
        toolBarShown = YES;
        [UIView animateWithDuration:0.5 animations:^{
          self.toolbar.alpha = 1;
        }];
      }
    }
    previousYOffset = scrollView.contentOffset.y;
  }

}

- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  if (!self.indexView.hidden) {
    [UIView animateWithDuration:1 animations:^{
      self.indexView.hidden = YES;
      
    }];
  }
}

@end
