//
//  WACollectionTests.m
//  wammer
//
//  Created by jamie on 12/11/2.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WACollectionTests.h"
#import "CoreData+MagicalRecord.h"
#import "WACollection.h"
#import "WAUser.h"
#import "WAFile.h"

@implementation WACollectionTests

- (void)setUp {
	[MagicalRecord setDefaultModelFromClass:[self class]];
	[MagicalRecord setupCoreDataStackWithInMemoryStore];
}

- (void)tearDown {
	[MagicalRecord cleanUp];
}

- (void)testSomethingReallySimple {
	WACollection *collection = [WACollection MR_createEntity];
	STAssertNotNil(collection, @"Should not be nil");
	
	collection.createDate = [NSDate distantPast];
	collection.modifyDate = [NSDate date];
	collection.title = @"This should be collection title";
	collection.creator = [WAUser MR_createEntity];
	NSArray *collections = [WACollection MR_findAll];
	STAssertEquals(collection.title, ((WACollection *) collections[0]).title,
								 @"Should be the same.");

	WAFile *photo1 = [WAFile MR_createEntity];
	photo1.thumbnailURL = @"URL1";
	WAFile *photo2 = [WAFile MR_createEntity];
	photo2.thumbnailURL = @"URL2";
	collection.files = [NSOrderedSet orderedSetWithArray:@[photo1, photo2]];
	NSOrderedSet *photos = ((WACollection *) collections[0]).files;
	STAssertEqualObjects(@"URL1", ((WAFile*)photos[0]).thumbnailURL,
								 @"Thumbnail URL persistent");
}

@end
