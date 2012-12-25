//
//  WAWebStreamViewController.m
//  wammer
//
//  Created by Shen Steven on 12/17/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAWebStreamViewController.h"
#import "WAWebStreamViewCell.h"
#import "WADayHeaderView.h"
#import "NSDate+WAAdditions.h"
#import "WAFileAccessLog.h"
#import "NINetworkImageView.h"
#import "WADataStore.h"
#import "WANavigationController.h"
#import "WAWebPreviewViewController.h"
#import "WAAppearance.h"

@interface WAWebStreamViewController () <NSFetchedResultsControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, readwrite, strong) NSDate *currentDate;
@property (nonatomic, readwrite, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, strong) UICollectionView *collectionView;
@property (nonatomic, readwrite, strong) NSArray *webPages;

@end

@implementation WAWebStreamViewController

- (id)initWithDate:(NSDate *)date {
	
	self = [super init];
	if (self) {
		
		self.currentDate = [date dayBegin];
		
		NSManagedObjectContext *context = [[WADataStore defaultStore] defaultAutoUpdatedMOC];
		
		NSFetchRequest *fr = [[NSFetchRequest alloc] init];
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"WAFileAccessLog" inManagedObjectContext:context];
		[fr setEntity:entity];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"dayWebpages.day == %@", self.currentDate];
		[fr setPredicate:predicate];
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"accessTime" ascending:YES];
		[fr setSortDescriptors:@[sortDescriptor]];
		[fr setRelationshipKeyPathsForPrefetching:@[@"file"]];
		[fr setRelationshipKeyPathsForPrefetching:@[@"dayWebpages"]];

		self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
		
		NSError *fetchingError;
		if (![self.fetchedResultsController performFetch:&fetchingError]) {
			NSLog(@"error fetching: %@", fetchingError);
		} else {
			
			NSMutableDictionary *dict = [NSMutableDictionary dictionary];
			for (WAFileAccessLog *log in self.fetchedResultsController.fetchedObjects) {
				if (![dict objectForKey:log.file.identifier]) {
					
					dict[log.file.identifier] = log;
					
				}
			}
			self.webPages = [[dict allValues] copy];
			
		}

	}
	
	return self;
	
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	UICollectionViewFlowLayout *flowlayout = [[UICollectionViewFlowLayout alloc] init];
	flowlayout.itemSize = (CGSize) {320, 270};
	flowlayout.scrollDirection = UICollectionViewScrollDirectionVertical;

	CGRect rect = (CGRect) { CGPointZero, self.view.frame.size };
	self.collectionView = [[UICollectionView alloc] initWithFrame:rect collectionViewLayout:flowlayout];
	
	self.collectionView.dataSource = self;
	self.collectionView.delegate = self;
	self.collectionView.autoresizesSubviews = YES;
	
	self.collectionView.backgroundColor = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1];
	self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:self.collectionView];
	self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	[self.collectionView registerNib:[UINib nibWithNibName:@"WAWebStreamViewCell" bundle:nil] forCellWithReuseIdentifier:@"WAWebStreamViewCell"];
	[self.collectionView registerNib:[UINib nibWithNibName:@"WADayHeaderView" bundle:nil] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"WADayHeaderView"];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSUInteger) supportedInterfaceOrientations {
	
	if (isPad()) {
		
		return UIInterfaceOrientationMaskAll;
		
	} else {
		
		return UIInterfaceOrientationMaskPortrait;
		
	}
	
}

- (BOOL) shouldAutorotate {
	
	return YES;
	
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	
	[self.collectionView.collectionViewLayout invalidateLayout];
	
}


#pragma mark - UICollectionView DataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {

	return 1;

}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	
	return self.webPages.count;
	
}

- (UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	WAFileAccessLog *accessLog = self.webPages[indexPath.row];
	NSAssert(accessLog, @"There should be one access log");
	WAFile *file = accessLog.file;
	NSAssert(file!=nil, @"Web page access log should refer to one WAFile");
	
	WAWebStreamViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"WAWebStreamViewCell" forIndexPath:indexPath];
	
	cell.webTitleLabel.text = file.webTitle;
	cell.webURLLabel.text = file.webURL;

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"hh:mm"];

	cell.dateTimeLabel.text = [formatter stringFromDate:((WAFileAccessLog*)self.webPages[indexPath.row]).accessTime];

	[file irObserve:@"thumbnailImage" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
					context:&kWAWebStreamViewCellKVOContext
				withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
						
						dispatch_async(dispatch_get_main_queue(), ^{
							cell.imageView.image = (UIImage*)toValue;
						});
					
					}];
	
	cell.file = file;
	
	if (file.webFaviconURL) {
		[cell.faviconImageView setPathToNetworkImage:file.webFaviconURL];
		cell.faviconImageView.hidden = NO;

		CGRect newFrame = cell.webURLLabel.frame;
		newFrame.origin = cell.faviconImageView.frame.origin;
		newFrame.origin.x += cell.faviconImageView.frame.size.width + 1;
		cell.webURLLabel.frame = newFrame;

	} else {
		cell.faviconImageView.image = nil;
		cell.faviconImageView.hidden = YES;

		CGRect newFrame = cell.webURLLabel.frame;
		newFrame.origin = cell.faviconImageView.frame.origin;
		cell.webURLLabel.frame = newFrame;

	}

	if ([accessLog.accessSource isEqualToString:@"twitter"]) {

		cell.sourceImageView.image = [UIImage imageNamed:@"twitter"];
		
	} else if([accessLog.accessSource isEqualToString:@"facebook"]) {
		
		cell.sourceImageView.image = [UIImage imageNamed:@"facebook"];
		
	} else if([accessLog.accessSource isEqualToString:@"GoogleReader"]) {
		
		cell.sourceImageView.image = [UIImage imageNamed:@"googlereader"];
		
	} else if([accessLog.accessSource isEqualToString:@"Chrome Extension"]) {
		
		cell.sourceImageView.image = [UIImage imageNamed:@"chrome"];
		
	}
	
	cell.sourceLabel.text = accessLog.accessSource;
	
	return cell;
	
}

CGFloat (^rowSpacingWeb) (UICollectionView *) = ^ (UICollectionView *collectionView) {
	
	CGFloat width = CGRectGetWidth(collectionView.frame);
	CGFloat itemWidth = ((UICollectionViewFlowLayout*)collectionView.collectionViewLayout).itemSize.width;
	int numCell = (int)(width / itemWidth);
	
	CGFloat w = ((int)((int)(width) % (int)(itemWidth))) / (numCell + 1);
	return w;
};

- (CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
	
	CGFloat width = CGRectGetWidth(collectionView.frame);
	CGFloat spacing = rowSpacingWeb(collectionView);
	return CGSizeMake(width - spacing * 2, 50);
	
}

- (UICollectionReusableView *) collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	
	if (![kind isEqualToString:UICollectionElementKindSectionHeader])
		return nil;
	WADayHeaderView *headerView = (WADayHeaderView*)[collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"WADayHeaderView" forIndexPath:indexPath];
	
	CGFloat spacing = rowSpacingWeb(collectionView);
	CGRect newFrame = headerView.placeHolderView.frame;
	newFrame.size.width = collectionView.frame.size.width - spacing * 2;
	newFrame.origin.x = spacing;
	headerView.placeHolderView.frame = newFrame;
	
	headerView.dayLabel.text = [self.currentDate dayString];
	headerView.monthLabel.text = [[self.currentDate localizedMonthShortString] uppercaseString];
	headerView.wdayLabel.text = [[self.currentDate localizedWeekDayFullString] uppercaseString];
	headerView.backgroundColor = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1];
	
//	[headerView.centerButton addTarget:self action:@selector(handleDateSelect:) forControlEvents:UIControlEventTouchUpInside];
	[headerView setNeedsLayout];
	return headerView;
	
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
	
	if (isPad())
		return rowSpacingWeb(collectionView);
	else
		return 0;
	
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
	
	if (isPad())
		return 10.0f;
	else
		return 5.0f;
	
}

- (UIEdgeInsets) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
	
	if (isPad()) {
		CGFloat spacing = rowSpacingWeb(collectionView);
		return UIEdgeInsetsMake(5, spacing, 0, spacing);
	} else {
		return UIEdgeInsetsMake(0, 0, 5, 0);
	}
}

#pragma mark - UICollectionView Delegate
-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	
	WAFile *file = ((WAFileAccessLog*)self.webPages[indexPath.row]).file;
	NSAssert(file!=nil, @"Web page access log should refer to one WAFile");

	WAWebPreviewViewController *webVC = [[WAWebPreviewViewController alloc] init];

	webVC.urlString = file.webURL;

	WAWebStreamViewCell *cell = (WAWebStreamViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
	UIColor *origColor = cell.backgroundColor;
	cell.backgroundColor = [UIColor lightGrayColor];
	[self.navigationController pushViewController:webVC animated:YES];
	cell.backgroundColor = origColor;
	
}

@end