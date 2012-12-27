//
//  WACalendarPickerDataSource.h
//  wammer
//
//  Created by Greener Chen on 12/11/23.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WADataStore.h"
#import "Kal.h"

typedef NS_ENUM(NSInteger, WACalendarLoadObject) {
	WACalendarLoadObjectEvent,
	WACalendarLoadObjectPhoto,
	WACalendarLoadObjectDoc
};

@interface WACalendarPickerDataSource : NSObject <UITableViewDataSource, KalDataSource>

@property (nonatomic, strong) NSMutableArray *daysWithAttributes;
@property (nonatomic, strong)	NSMutableArray *items;
@property (nonatomic, weak) NSDate *selectedNSDate;

- (WAArticle *)eventAtIndexPath:(NSIndexPath *)indexPath;

@end