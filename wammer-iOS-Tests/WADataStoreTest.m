//
//  WADataStoreTest.m
//  wammer
//
//  Created by Evadne Wu on 3/26/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WADataStoreTest.h"
#import "WADataStore.h"
#import "Foundation+IRAdditions.h"

@implementation WADataStoreTest

- (void) assertFileEquivalancy:(WAArticle *)article {

	NSSet *files = article.files;
	
	STAssertEquals([files count], [article.fileOrder count], @"Number of files in the backing array must equal the number of files in the unordered to-many relationship.");

	NSSet *fileIDs = [article.files irMap: ^ (NSManagedObject *obj, BOOL *stop) {
		return [[obj objectID] URIRepresentation];
	}];
	
	NSSet *orderedFileIDs = [NSSet setWithArray:article.fileOrder];
	
	STAssertEqualObjects(fileIDs, orderedFileIDs, @"Number of files in the backing array must equal the number of files in the unordered to-many relationship.");

}

- (WAArticle *) disposableArticleWithContext:(NSManagedObjectContext **)outContext {

	WADataStore *ds = [WADataStore defaultStore];
	NSManagedObjectContext *context = [ds disposableMOC];
	WAArticle *article = [WAArticle objectInsertingIntoContext:context withRemoteDictionary:nil];

	STAssertNotNil(article, @"Article must instantiate correctly");
	
	if (outContext)
		*outContext = context;
	
	return article;

}

- (void) testOrderedRelationshipMutationFromSet {

	NSManagedObjectContext *context = nil;
	WAArticle *article = [self disposableArticleWithContext:&context];
	
	WAFile *file = [WAFile objectInsertingIntoContext:context withRemoteDictionary:[NSDictionary dictionaryWithObjectsAndKeys:IRDataStoreNonce(), @"identifier", nil]];
	
	NSLog(@"Before: files %@", article.files);
	NSLog(@"Before: fileOrder %@", article.fileOrder);
	
	[article addFilesObject:file];
	[self assertFileEquivalancy:article];
	
	NSLog(@"After: files %@", article.files);
	NSLog(@"After: fileOrder %@", article.fileOrder);
	
	STAssertTrue([article.fileOrder containsObject:[[file objectID] URIRepresentation]], @"After inserting an entity to the unordered to-many relationship,  the object ID should show up in the backing order array");

}

- (void) testOrderedRelationshipMutationFromArray {

	NSManagedObjectContext *context = nil;
	WAArticle *article = [self disposableArticleWithContext:&context];
	
	WAFile *file = [WAFile objectInsertingIntoContext:context withRemoteDictionary:[NSDictionary dictionaryWithObjectsAndKeys:IRDataStoreNonce(), @"identifier", nil]];
	
	NSMutableArray *newOrder = [article.fileOrder mutableCopy];
	[newOrder addObject:[[file objectID] URIRepresentation]];
	
	NSLog(@"Before: files %@", article.files);
	NSLog(@"Before: fileOrder %@", article.fileOrder);
	
	article.fileOrder = newOrder;
	[self assertFileEquivalancy:article];
	
	NSLog(@"After: files %@", article.files);
	NSLog(@"After: fileOrder %@", article.fileOrder);
	
	STAssertTrue([article.fileOrder containsObject:[[file objectID] URIRepresentation]], @"After inserting an entity to the unordered to-many relationship,  the object ID should show up in the backing order array.");

}

@end
