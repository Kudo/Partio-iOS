//
//  WAFBGraphObjectTableDataSource.h
//  wammer
//
//  Created by Greener Chen on 13/5/16.
//  Copyright (c) 2013年 Waveface. All rights reserved.
//

#import <FBGraphObjectTableDataSource.h>

@interface WAFBGraphObjectTableDataSource : FBGraphObjectTableDataSource

@property (nonatomic, retain) NSDictionary *indexMap;

- (NSString *)titleForSection:(NSInteger)sectionIndex;
- (NSString *)indexKeyOfItem:(FBGraphObject *)item;
- (NSIndexPath *)indexPathForItem:(FBGraphObject *)item;
- (NSIndexPath *)indexPathForLastItem;
- (void)addItemIntoData:(FBGraphObject *)item;
- (void)popItemFromData;
- (NSString *)nameOfLastItem;
- (FBGraphObject *)lastObject;

@end

static NSString *kFrequentFriendList = @"FrenquentFriendList";
