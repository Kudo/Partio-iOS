//
//  WANewSummaryViewController.m
//  wammer
//
//  Created by kchiu on 13/2/10.
//  Copyright (c) 2013年 Waveface. All rights reserved.
//

#import "WANewSummaryViewController.h"
#import "WANewSummaryDataSource.h"
#import "NSDate+WAAdditions.h"
#import "WANewDaySummaryViewCell.h"
#import "WANewDayEventViewCell.h"
#import "WADayViewController.h"
#import "IIViewDeckController.h"
#import "IRBarButtonItem.h"
#import "UIImageView+WAAdditions.h"
#import "WANewDaySummary.h"
#import "WANewDayEvent.h"
#import "WAOverlayBezel.h"
#import "WAArticle.h"
#import "WAEventViewController.h"
#import "WANavigationController.h"
#import "WAContextMenuViewController.h"
#import "WACalendarPopupViewController_phone.h"
#import "WAAppDelegate_iOS.h"

@interface WANewSummaryViewController ()

@property (nonatomic, strong) WANewSummaryDataSource *dataSource;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) WANewDayEvent *currentDayEvent;
@property (nonatomic, strong) WANewDaySummary *currentDaySummary;
@property (nonatomic) NSUInteger summaryPageIndex;
@property (nonatomic) NSUInteger eventPageIndex;
@property (nonatomic) BOOL scrollingSummaryPage;
@property (nonatomic) BOOL scrollingEventPage;
@property (nonatomic) BOOL reloading;
@property (nonatomic) BOOL contextMenuOpened;
@property (nonatomic) BOOL initializing;
@property (nonatomic) WADayViewSupportedStyle presentingStyle;

@end

@implementation WANewSummaryViewController

- (void)viewDidLoad {

  [super viewDidLoad];

  self.presentingStyle = WAEventsViewStyle;
  self.initializing = YES;
  
  self.backgroundImageView.clipsToBounds = YES;
  
  __weak WANewSummaryViewController *wSelf = self;
  self.navigationItem.leftBarButtonItem = WABarButtonItem([UIImage imageNamed:@"menuWhite"], @"", ^{
    [wSelf.viewDeckController toggleLeftView];
  });
  self.navigationItem.rightBarButtonItem = WABarButtonItem([UIImage imageNamed:@"Cal"], @"", ^{
    [wSelf calButtonPressed];
  });
  
  UIColor *naviBgColor = [[UIColor clearColor] colorWithAlphaComponent:0];
  UIGraphicsBeginImageContext(self.navigationController.navigationBar.frame.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, naviBgColor.CGColor);
  CGContextAddRect(context, self.navigationController.navigationBar.frame);
  CGContextFillPath(context);
  UIImage *naviBg = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  [self.navigationController.navigationBar setBackgroundImage:naviBg forBarMetrics:UIBarMetricsDefault];
  self.navigationController.navigationBar.translucent = YES;

  self.navigationItem.titleView = [WAContextMenuViewController titleViewForContextMenu:self.presentingStyle
							 performSelector:@selector(contextMenuTapped)
							      withObject:self];

  self.dataSource = [[WANewSummaryDataSource alloc] initWithDate:[[NSDate date] dayBegin]];
  self.dataSource.summaryCollectionView = self.summaryCollectionView;
  self.dataSource.eventCollectionView = self.eventCollectionView;
  
  self.summaryCollectionView.dataSource = self.dataSource;
  self.summaryCollectionView.delegate = self;
  self.eventCollectionView.dataSource = self.dataSource;
  self.eventCollectionView.delegate = self;

  self.summaryCollectionView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
  self.eventCollectionView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
  self.eventPageControl.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];

  self.currentDaySummary = [self.dataSource daySummaryAtIndex:0];
  self.eventPageControl.numberOfPages = self.currentDaySummary.numOfEvents;
  [self.currentDaySummary irObserve:@"numOfEvents" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      wSelf.eventPageControl.numberOfPages = [toValue integerValue];
    }];
  }];
  
  self.currentDayEvent = [self.dataSource dayEventAtIndex:0];
  [self.backgroundImageView addCrossFadeAnimationWithTargetImage:self.currentDayEvent.backgroundImage];
  [self.currentDayEvent irObserve:@"backgroundImage" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      [wSelf.backgroundImageView addCrossFadeAnimationWithTargetImage:toValue];
    }];
  }];

}

- (void)viewDidAppear:(BOOL)animated {

  [super viewDidAppear:animated];

  if (self.initializing) {
    NSDate *date = self.currentDaySummary.date;
    NSIndexPath *daySummaryIndex = [self.dataSource indexPathOfDaySummaryOfDate:date];
    NSIndexPath *dayEventIndex = [self.dataSource indexPathOfFirstDayEventOfDate:date];
    [self scrollToDaySummaryAtIndexPath:daySummaryIndex animated:NO];
    [self scrollToDayEventAtIndexPath:dayEventIndex animated:NO];
    self.initializing = NO;
  }

}

- (void)scrollToDaySummaryAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
  
  if (animated) {
    [self.summaryCollectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
  } else {
    [self.summaryCollectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
  }

  self.summaryPageIndex = indexPath.item;
  self.currentDaySummary = [self.dataSource daySummaryAtIndex:self.summaryPageIndex];

}

- (void)scrollToDayEventAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {

  if (animated) {
    [self.eventCollectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
  } else {
    [self.eventCollectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
  }

  self.eventPageIndex = indexPath.item;
  self.currentDayEvent = [self.dataSource dayEventAtIndex:self.eventPageIndex];

}

- (void)dealloc {

  [self.currentDaySummary irRemoveObserverBlocksForKeyPath:@"numOfEvents"];
  [self.currentDayEvent irRemoveObserverBlocksForKeyPath:@"backgroundImage"];

}

- (NSUInteger) supportedInterfaceOrientations {
  
  if (isPad())
    return UIInterfaceOrientationMaskAll;
  else
    return UIInterfaceOrientationMaskPortrait;
  
}

- (BOOL) shouldAutorotate {
  
  return YES;
  
}

#pragma mark - Target actions

- (void)calButtonPressed {
  
  if (isPad()) {
    
    // NO OP
    
  } else {
    
    __block WACalendarPopupViewController_phone *calendarPopup = [[WACalendarPopupViewController_phone alloc] initWithDate:self.currentDaySummary.date viewStyle:WAEventsViewStyle completion:^{
      
      [calendarPopup willMoveToParentViewController:nil];
      [calendarPopup removeFromParentViewController];
      [calendarPopup.view removeFromSuperview];
      [calendarPopup didMoveToParentViewController:nil];
      calendarPopup = nil;
      
    }];
    
    [self.viewDeckController addChildViewController:calendarPopup];
    [self.viewDeckController.view addSubview:calendarPopup.view];
    
  }
  
}

- (void)contextMenuTapped {
  
  __weak WANewSummaryViewController *wSelf = self;
  
  if (self.contextMenuOpened) {
    [self.childViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      if ([obj isKindOfClass:[WAContextMenuViewController class]]) {
        
        *stop = YES;
        WAContextMenuViewController *ddMenu = (WAContextMenuViewController*)obj;
        [ddMenu dismissContextMenu];
        
      }
    }];
    return;
  }
  
  __block WAContextMenuViewController *ddMenu = [[WAContextMenuViewController alloc] initForViewStyle:self.presentingStyle completion:^{
    
    [wSelf.navigationItem.leftBarButtonItem setEnabled:YES];
    [wSelf.navigationItem.rightBarButtonItem setEnabled:YES];
    
    wSelf.contextMenuOpened = NO;
    
  }];
  
  ddMenu.delegate = self;
  
  [ddMenu presentContextMenuInViewController:self];
  [self.navigationItem.leftBarButtonItem setEnabled:NO];
  [self.navigationItem.rightBarButtonItem setEnabled:NO];
  self.contextMenuOpened = YES;
  
}

#pragma mark - UICollectionView delegates

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

  if (collectionView == self.eventCollectionView) {
    WANewDayEventViewCell *cell = (WANewDayEventViewCell*)[self.eventCollectionView cellForItemAtIndexPath:indexPath];
    WAArticle *article = cell.representingDayEvent.representingArticle;
    NSURL *articleURL = [[article objectID] URIRepresentation];
    __weak WANewSummaryViewController *wSelf = self;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      WAEventViewController *eventVC = [WAEventViewController controllerForArticleURL:articleURL];
      WANavigationController *navVC = [[WANavigationController alloc] initWithRootViewController:eventVC];
      [wSelf presentViewController:navVC animated:YES completion:nil];
    }];
  }

}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

  CGFloat pageWidth = scrollView.frame.size.width;
  if (scrollView.contentOffset.x > scrollView.contentSize.width - pageWidth) {
    [self.dataSource loadMoreDays:20 since:self.currentDaySummary.date];
    NSDate *fromDate = [self.currentDaySummary.date dateOfPreviousDay];
    NSDate *toDate = [self.currentDaySummary.date dateOfPreviousNumOfDays:20];
    NSArray *daySummaryIndexes = [self.dataSource indexesOfDaySummariesFromDate:fromDate toDate:toDate];
    NSArray *dayEventIndexes = [self.dataSource indexesOfDayEventsFromDate:fromDate toDate:toDate];
    [self.summaryCollectionView insertItemsAtIndexPaths:daySummaryIndexes];
    [self.eventCollectionView insertItemsAtIndexPaths:dayEventIndexes];
    return;
  }
  if (scrollView.contentOffset.x < 0) {
    return;
  }
  
  NSInteger pageIndex = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
  
  if (scrollView == self.summaryCollectionView) {

    // scroll event scrollview only if user scrolls the summary scrollview manually
    if (self.reloading || self.scrollingEventPage) {
      return;
    }
    
    if (self.summaryPageIndex != pageIndex) {
      
      self.summaryPageIndex = pageIndex;

      __weak WANewSummaryViewController *wSelf = self;
      
      [self.currentDaySummary irRemoveObserverBlocksForKeyPath:@"numOfEvents"];
      WANewDaySummary *daySummary = [self.dataSource daySummaryAtIndex:self.summaryPageIndex];
      self.eventPageControl.numberOfPages = daySummary.numOfEvents;
      self.eventPageControl.currentPage = 0;
      [daySummary irObserve:@"numOfEvents" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          wSelf.eventPageControl.numberOfPages = [toValue integerValue];
        }];
      }];
      self.currentDaySummary = daySummary;

      [self.currentDayEvent irRemoveObserverBlocksForKeyPath:@"backgroundImage"];
      NSDate *date = [self.dataSource dateOfDaySummaryAtIndex:pageIndex];
      NSIndexPath *eventIndexPath = [self.dataSource indexPathOfFirstDayEventOfDate:date];
      [self scrollToDayEventAtIndexPath:eventIndexPath animated:YES];
      [self.backgroundImageView addCrossFadeAnimationWithTargetImage:self.currentDayEvent.backgroundImage];
      [self.currentDayEvent irObserve:@"backgroundImage" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          [wSelf.backgroundImageView addCrossFadeAnimationWithTargetImage:toValue];
        }];
      }];

    }
    
  } else {
    
    // scroll summary scrollview only if user scrolls the event scrollview manually
    if (self.reloading || self.scrollingSummaryPage) {
      return;
    }
    
    if (self.eventPageIndex != pageIndex) {
      
      self.eventPageControl.currentPage += (pageIndex-self.eventPageIndex);
      self.eventPageIndex = pageIndex;
      
      __weak WANewSummaryViewController *wSelf = self;

      [self.currentDayEvent irRemoveObserverBlocksForKeyPath:@"backgroundImage"];
      WANewDayEvent *dayEvent = [self.dataSource dayEventAtIndex:self.eventPageIndex];
      [self.backgroundImageView addCrossFadeAnimationWithTargetImage:dayEvent.backgroundImage];
      [dayEvent irObserve:@"backgroundImage" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
          [wSelf.backgroundImageView addCrossFadeAnimationWithTargetImage:toValue];
        }];
      }];
      self.currentDayEvent = dayEvent;

      NSDate *eventDate = [self.dataSource dateOfDayEventAtIndex:pageIndex];
      NSDate *summaryDate = [self.dataSource dateOfDaySummaryAtIndex:self.summaryPageIndex];
      if ([eventDate compare:summaryDate] != NSOrderedSame) {
        
        [self.currentDaySummary irRemoveObserverBlocksForKeyPath:@"numOfEvents"];
        NSIndexPath *summaryIndexPath = [self.dataSource indexPathOfDaySummaryOfDate:eventDate];
        [self scrollToDaySummaryAtIndexPath:summaryIndexPath animated:YES];
        self.eventPageControl.numberOfPages = self.currentDaySummary.numOfEvents;
        [self.currentDaySummary irObserve:@"numOfEvents" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
          [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            wSelf.eventPageControl.numberOfPages = [toValue integerValue];
          }];
        }];
        
        if ([eventDate compare:summaryDate] == NSOrderedAscending) {
          self.eventPageControl.currentPage = 0;
        } else {
          self.eventPageControl.currentPage = wSelf.eventPageControl.numberOfPages-1;
        }
        
      }      

    }

  }

}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  
  if (scrollView == self.summaryCollectionView) {
    self.scrollingSummaryPage = YES;
  } else {
    self.scrollingEventPage = YES;
  }
  
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  
  if (scrollView == self.summaryCollectionView) {
    self.scrollingSummaryPage = NO;
  } else {
    self.scrollingEventPage = NO;
  }
  
}

#pragma mark - UICollectionView FlowLayout delegates

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

  if (collectionView == self.summaryCollectionView) {
    return self.summaryCollectionView.frame.size;
  } else if (collectionView == self.eventCollectionView) {
    return CGSizeMake(298, 148);
  } else {
    NSAssert(NO, @"unexpected collection view %@", collectionView);
    return CGSizeZero;
  }

}

#pragma mark - Context menu delegates

- (void) contextMenuItemDidSelect:(WADayViewSupportedStyle)itemStyle {
  
  WAAppDelegate_iOS *appDelegate = (WAAppDelegate_iOS*)AppDelegate();
  [appDelegate.slidingMenu switchToViewStyle:itemStyle onDate:self.currentDaySummary.date];
  
}

#pragma mark - WADaysControlling delegates

- (BOOL)jumpToDate:(NSDate *)date animated:(BOOL)animated {
  
  self.dataSource = [[WANewSummaryDataSource alloc] initWithDate:date];
  self.dataSource.summaryCollectionView = self.summaryCollectionView;
  self.dataSource.eventCollectionView = self.eventCollectionView;
  self.summaryCollectionView.dataSource = self.dataSource;
  self.eventCollectionView.dataSource = self.dataSource;

  __weak WANewSummaryViewController *wSelf = self;

  [self.currentDaySummary irRemoveObserverBlocksForKeyPath:@"numOfEvents"];
  self.currentDaySummary = [self.dataSource daySummaryAtIndex:0];
  self.eventPageControl.numberOfPages = self.currentDaySummary.numOfEvents;
  [self.currentDaySummary irObserve:@"numOfEvents" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      wSelf.eventPageControl.numberOfPages = [toValue integerValue];
    }];
  }];

  [self.currentDayEvent irRemoveObserverBlocksForKeyPath:@"backgroundImage"];
  self.currentDayEvent = [self.dataSource dayEventAtIndex:0];
  [self.backgroundImageView addCrossFadeAnimationWithTargetImage:self.currentDayEvent.backgroundImage];
  [self.currentDayEvent irObserve:@"backgroundImage" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      [wSelf.backgroundImageView addCrossFadeAnimationWithTargetImage:toValue];
    }];
  }];

  [self.dataSource loadMoreDays:20 since:date];

  [self.summaryCollectionView reloadData];
  [self.eventCollectionView reloadData];

  return YES;
  
}

- (void)jumpToRecentDay {

  [self jumpToDate:[[NSDate date] dayBegin] animated:NO];

}

@end
