//
//  WACollectionTests.m
//  wammer
//
//  Created by jamie on 12/11/2.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WACollectionTests.h"
#import <MagicalRecord/CoreData+MagicalRecord.h>
#import "WACollection.h"
#import "WAUser.h"
#import "WAFile.h"

@implementation WACollectionTests

- (id)loadDataFile: (NSString *)fileString {
	NSString *filePath = [[NSBundle bundleForClass:[self class]]
												pathForResource:fileString
												ofType:@"json"];
	
	NSData *inputData = [NSData dataWithContentsOfFile:filePath];
	return [NSJSONSerialization
					JSONObjectWithData:inputData
					options:NSJSONReadingMutableContainers
					error:nil];
}

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
	
	collection.creationDate = [NSDate distantPast];
	collection.modificationDate = [NSDate date];
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

- (void)testGetSingleCollection {
	NSArray *collectionsRep = [self loadDataFile:@"GetCollections"];
	STAssertNotNil(collectionsRep, @"need to be a vaild JSON");
	
	NSArray *aCollection = collectionsRep;
	
	NSArray *transformed;
	@autoreleasepool {
		transformed = [WACollection
									 insertOrUpdateObjectsUsingContext:[NSManagedObjectContext MR_context]
									 withRemoteResponse:aCollection
									 usingMapping:nil
									 options:IRManagedObjectOptionIndividualOperations];
	}
	
	for (WACollection *coll in transformed) {
		STAssertNotNil(coll.identifier, @"identifier should not be nil");
		if ([coll.identifier isEqualToString:@"abca95d7-9b72-463d-931f-de9fa8f9a2f3"]) {
			assertThat(coll.isHidden, equalTo(@(0)));
			assertThat(coll.isSmart, equalTo(@(0)));
			assertThat(coll.sequenceNumber, equalTo(@(33784)));
			STAssertEquals([coll.files count], (NSUInteger)3, @"With Object IDs");
		}
		if ([coll.identifier isEqualToString:@"38627127-dff1-4892-91bd-bd29415b46ed"]) {
			assertThat(coll.isHidden, equalTo(@(1)));
		}
  }
}

@end