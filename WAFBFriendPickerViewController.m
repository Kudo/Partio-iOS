//
//  WAFBFriendPickerViewController.m
//  wammer
//
//  Created by Greener Chen on 13/5/13.
//  Copyright (c) 2013年 Waveface. All rights reserved.
//

#import "WAFBFriendPickerViewController.h"
#import "WAPartioNavigationBar.h"
#import "WAPartioTableViewSectionHeaderView.h"
#import "WAFBGraphObjectTableDataSource.h"
#import "WAFBGraphObjectTableSelection.h"
#import <FBGraphObjectPagingLoader.h>

#import <SMCalloutView/SMCalloutView.h>
#import <BlocksKit/BlocksKit.h>
#import "IRFoundations.h"

@interface WAFBFriendPickerViewController () <FBFriendPickerDelegate, UITableViewDataSource, UITextViewDelegate>

@property (nonatomic, weak) IBOutlet WAPartioNavigationBar *navigationBar;
@property (nonatomic, weak) IBOutlet UITextField *textField;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIToolbar *toolbar;

@property (nonatomic, strong) NSMutableArray *contacts;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) SMCalloutView *inviteInstructionView;

@property (nonatomic, retain) WAFBGraphObjectTableDataSource *dataSource;
@property (nonatomic, retain) WAFBGraphObjectTableSelection *selectionManager;
@property (nonatomic, retain) FBGraphObjectPagingLoader *loader;

@end

static NSString *kPlaceholderChooseFriends;
static NSString *kWAFBFriendPickerViewController_CoachMarks = @"kWAFBFriendPickerViewController_CoachMarks";
static NSString *defaultImageName = @"FacebookSDKResources.bundle/FBFriendPickerView/images/default.png";
static NSString *kHeaderID = @"WAFBTableViewSectionHeaderView";
static NSString *kWAPartioTableViewSectionHeaderView = @"WAPartioTableViewSectionHeaderView";

@implementation WAFBFriendPickerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
    [self initialize];
    [self.tableView registerNib:[UINib nibWithNibName:kWAPartioTableViewSectionHeaderView bundle:nil] forHeaderFooterViewReuseIdentifier:kHeaderID];
  }
  return self;
}

- (void)initialize
{
  // Data Source
  WAFBGraphObjectTableDataSource *dataSource = [[WAFBGraphObjectTableDataSource alloc] init];
  dataSource.defaultPicture = [UIImage imageNamed:defaultImageName];
  dataSource.controllerDelegate = self;
  dataSource.itemTitleSuffixEnabled = YES;
  
  // Selection Manager
  WAFBGraphObjectTableSelection *selectionManager = [[WAFBGraphObjectTableSelection alloc] initWithDataSource:dataSource];
  selectionManager.delegate = self;
  
  // Paging loader
  id loader = [[FBGraphObjectPagingLoader alloc] initWithDataSource:dataSource
                                                          pagingMode:FBGraphObjectPagingModeImmediate];
  self.loader = loader;
  self.loader.delegate = self;
  
  self.allowsMultipleSelection = YES;
  self.dataSource = dataSource;
  self.delegate = nil;
  self.itemPicturesEnabled = YES;
  self.selectionManager = selectionManager;
  self.userID = @"me";
  self.sortOrdering = FBFriendSortByFirstName;
  self.displayOrdering = FBFriendDisplayByFirstName;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // Do any additional setup after loading the view from its nib.
  BOOL coachmarkShown = [[NSUserDefaults standardUserDefaults] boolForKey:kWAFBFriendPickerViewController_CoachMarks];
  if (!coachmarkShown) {
    __weak WAFBFriendPickerViewController *wSelf = self;
    if (!self.inviteInstructionView) {
      self.inviteInstructionView = [SMCalloutView new];
      self.inviteInstructionView.title = NSLocalizedString(@"INSTRUCTION_IN_ADDRESS_BOOK_PICKER", @"The instruction show to tap contacts then share photos");
      [self.inviteInstructionView presentCalloutFromRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height-44, 1, 1) inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionDown animated:YES];
      self.tapGesture = [[UITapGestureRecognizer alloc] initWithHandler:^(UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location) {
        if (wSelf.inviteInstructionView) {
          [wSelf.inviteInstructionView dismissCalloutAnimated:YES];
          wSelf.inviteInstructionView = nil;
        }
        [wSelf.view removeGestureRecognizer:wSelf.tapGesture];
        wSelf.tapGesture = nil;
      }];
      [self.view addGestureRecognizer:self.tapGesture];
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kWAFBFriendPickerViewController_CoachMarks];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  
  kPlaceholderChooseFriends = NSLocalizedString(@"PLACEHOLER_CHOSEN_FRIENDS_ADDRESS_BOOK_PICKER", @"Placeholer in FB Friends Picker");
  [self.textField setPlaceholder:kPlaceholderChooseFriends];
  [self.textField setFont:[UIFont fontWithName:@"OpenSans-Regular" size:18.f]];
  [self.textField setLeftViewMode:UITextFieldViewModeAlways];
  [self.textField setLeftView:[[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, 10.f, 44.f)]];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(textFieldDidChange:)
                                               name:UITextFieldTextDidChangeNotification
                                             object:self.textField];
  
  __weak WAFBFriendPickerViewController *wSelf = self;
  if (self.navigationController) {
    self.navigationItem.leftBarButtonItem = WAPartioBackButton(^{
      [wSelf.navigationController popViewControllerAnimated:YES];
      if (self.onDismissHandler)
        self.onDismissHandler();
    });
  } else {
    self.navigationItem.leftBarButtonItem = (UIBarButtonItem*)WABarButtonItem(nil, NSLocalizedString(@"ACTION_CANCEL", @"cancel"), ^{
      if (wSelf.onDismissHandler)
        wSelf.onDismissHandler();
    });
  }
  
  [self.navigationController setNavigationBarHidden:YES];
  [self.navigationItem setHidesBackButton:YES];
  [self.navigationBar pushNavigationItem:self.navigationItem animated:NO];
  
  [self.toolbar setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
  self.toolbar.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
  UIBarButtonItem *flexspace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
  self.toolbar.items = @[flexspace, [self shareBarButton], flexspace];
  [self.view addSubview:self.toolbar];
  [self updateNavigationBarTitleAndButtonStatus];
  
  
  if (FBSession.activeSession.isOpen) {
    FBCacheDescriptor *cacheDescriptor = [WAFBFriendPickerViewController cacheDescriptorWithUserID:nil
                                                                                  fieldsForRequest:self.extraFieldsForFriendRequest];
    [cacheDescriptor prefetchAndCacheForSession:FBSession.activeSession];
  }
  
  self.delegate = self;
  self.tableView.delegate = self.selectionManager;
  [self.dataSource bindTableView:self.tableView];
  [self.tableView setBackgroundColor:[UIColor colorWithRed:0.168 green:0.168 blue:0.168 alpha:1]];
  self.loader.tableView = self.tableView;

}

- (void)viewDidAppear:(BOOL)animated
{
  // add joined members into member list
  self.members = [[NSMutableArray alloc] init];
  
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void) dealloc {
  if (self.tapGesture)
    [self.view removeGestureRecognizer:self.tapGesture];
}

- (BOOL) shouldAutorotate {
  return YES;
}

- (NSUInteger) supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskPortrait;
}

- (UIBarButtonItem *)shareBarButton
{
  return WAPartioToolbarNextButton(@"Share", ^{
    if (self.onNextHandler) {
      NSLog(@"Invited friends: %@", self.members);      
      self.onNextHandler([self extractedUserData:self.members]);
    }
  });
}

- (NSArray *)extractedUserData:(NSArray *)rawData
{
  NSMutableArray *extractedData = [NSMutableArray array];
  for (id<CacheGraphFriend> user in rawData) {
    [extractedData addObject:@{@"name": [user name], @"email": @"", @"fbid":[user id]}];
  }
  
  return [extractedData copy];
}

- (void)updateNavigationBarTitleAndButtonStatus
{
  if (!self.members.count) {
    [[self.toolbar.items objectAtIndex:1] setEnabled:NO];
    self.navigationItem.title = NSLocalizedString(@"TITLE_INVITE_CONTACTS", @"TITLE_INVITE_CONTACTS");
  } else {
    [[self.toolbar.items objectAtIndex:1] setEnabled:YES];
    self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"TITLE_INVITATION_NUMBERS", @"TITLE_INVITATION_NUMBERS"), self.members.count];
  }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
  if (self.inviteInstructionView) {
    [self.inviteInstructionView dismissCalloutAnimated:YES];
    self.inviteInstructionView = nil;
    [self.view removeGestureRecognizer:self.tapGesture];
    self.tapGesture = nil;
  }

}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  [textField resignFirstResponder];
  
  return YES;
}


- (IBAction)textFieldDidChange:(id)sender
{
  [self updateView];
}

#pragma mark - FBFriendPickerDelegate

- (void)friendPickerViewController:(FBFriendPickerViewController *)friendPicker handleError:(NSError *)error
{
  NSLog(@"Error during FB friend data fetch.");
}

- (BOOL)friendPickerViewController:(FBFriendPickerViewController *)friendPicker shouldIncludeUser:(id<FBGraphUser>)user
{
  if (![self.textField.text isEqualToString:@""]) {
    NSRange result = [user.name rangeOfString:self.textField.text
                                      options:NSCaseInsensitiveSearch];
    if (result.location != NSNotFound) {
      return YES;
    } else {
      return NO;
    }
  }

  return YES;
}

- (void)friendPickerViewControllerDataDidChange:(FBFriendPickerViewController *)friendPicker
{
  NSLog(@"FB friend data loaded.");
}

- (void)friendPickerViewControllerSelectionDidChange:(FBFriendPickerViewController *)friendPicker
{
  NSLog(@"Current friend selections: %@", friendPicker.selection);
 
  __weak WAFBFriendPickerViewController *wSelf = self;
  [self irObserve:@"selection" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
    
    NSArray *newSelection = (NSArray *)toValue;
    
    if (wSelf.members.count > newSelection.count) {
      for (id<FBGraphUser> user in wSelf.members) {
        if (![newSelection containsObject:user]) {
          [wSelf.members removeObject:user];
        }
      }
      
    } else {
      id<FBGraphUser> newSelectedUser = [newSelection lastObject];
      if (![wSelf.members containsObject:newSelectedUser]) {
        [wSelf.members addObject:newSelectedUser];
      }
    
    }
    
  }];

  [self updateNavigationBarTitleAndButtonStatus];

}

@end
