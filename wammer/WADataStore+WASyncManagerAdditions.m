//
//  WADataStore+WASyncManagerAdditions.m
//  wammer
//
//  Created by Evadne Wu on 6/21/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WADataStore+WASyncManagerAdditions.h"

@implementation WADataStore (WASyncManagerAdditions)

- (NSFetchRequest *) fetchRequestForFilesWithSyncableBlobsInContext:(NSManagedObjectContext *)context {

	return [context.persistentStoreCoordinator.managedObjectModel fetchRequestFromTemplateWithName:@"WAFRFilesWithSyncableBlobs" substitutionVariables:@{}];

}

- (void) enumerateFilesWithSyncableBlobsInContext:(NSManagedObjectContext *)context usingBlock:(void(^)(WAFile *aFile, NSUInteger index, BOOL *stop))block {

	NSParameterAssert(block);

	if (!context)
		context = [self disposableMOC];
	
	NSFetchRequest *fr = [self fetchRequestForFilesWithSyncableBlobsInContext:context];
	
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
	
	NSArray *files = [context executeFetchRequest:fr error:nil];
	
	[files enumerateObjectsUsingBlock: ^ (WAFile *aFile, NSUInteger idx, BOOL *stop) {
		
		block(aFile, idx, stop);
		
	}];

}

- (NSFetchRequest *) fetchRequestForDirtyArticlesInContext:(NSManagedObjectContext *)context {

	return [context.persistentStoreCoordinator.managedObjectModel fetchRequestFromTemplateWithName:@"WAFRArticlesNeedingSync" substitutionVariables:@{}];

}

- (void) enumerateDirtyArticlesInContext:(NSManagedObjectContext *)context usingBlock:(void(^)(WAArticle *anArticle, NSUInteger index, BOOL *stop))block {

	NSParameterAssert(block);

	if (!context)
		context = [self disposableMOC];
	
	NSFetchRequest *fr = [self fetchRequestForDirtyArticlesInContext:context];
	
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
	
	NSArray *articles = [context executeFetchRequest:fr error:nil];
	
	[articles enumerateObjectsUsingBlock: ^ (WAArticle *anArticle, NSUInteger idx, BOOL *stop) {
		
		block(anArticle, idx, stop);
		
	}];

}

- (NSArray *)fetchFilesNeedingMetadataSyncUsingContext:(NSManagedObjectContext *)aContext {
	
	NSParameterAssert(aContext);
	
	NSFetchRequest *fr = [aContext.persistentStoreCoordinator.managedObjectModel fetchRequestFromTemplateWithName:@"WAFRFilesNeedingMetaSync" substitutionVariables:@{}];

	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];

	return [aContext executeFetchRequest:fr error:nil];

}

@end
