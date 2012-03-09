//
//  WADataStore+WARemoteInterfaceAdditions.m
//  wammer
//
//  Created by Evadne Wu on 11/4/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WADefines.h"
#import "WARemoteInterface.h"

#import "WADataStore+WARemoteInterfaceAdditions.h"


@interface WADataStore (WARemoteInterfaceAdditions_Private)

- (NSMutableSet *) articlesCurrentlyBeingUploaded;

@end


@implementation WADataStore (WARemoteInterfaceAdditions)

- (BOOL) hasDraftArticles {

  NSManagedObjectContext *context = [self disposableMOC];
 
  NSFetchRequest *fr = [[self managedObjectModel] fetchRequestTemplateForName:@"WAFRArticleDrafts"];
  
  NSError *fetchingError = nil;
  NSArray *fetchedDrafts = [context executeFetchRequest:fr error:&fetchingError];
  
  if (!fetchedDrafts)
    NSLog(@"Error fetching: %@", fetchingError);
  
  return (BOOL)!![fetchedDrafts count];

}

- (void) updateArticlesWithCompletion:(void(^)(NSError *))aBlock {

	[self updateArticlesOnSuccess: ^ {
	
		if (aBlock)
			aBlock(nil);
	
	} onFailure:aBlock];

}

- (void) updateArticlesOnSuccess:(void (^)(void))successBlock onFailure:(void (^)(NSError *error))failureBlock {

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		
		kWAArticleSyncDefaultStrategy, kWAArticleSyncStrategy,
		
	nil];
	
	switch ([UIDevice currentDevice].userInterfaceIdiom) {
		
		case UIUserInterfaceIdiomPad: {
			[options setObject:kWAArticleSyncFullyFetchOnlyStrategy forKey:kWAArticleSyncStrategy];
			break;
		}
		
		default: {
			break;
		}
		
	}

	[WAArticle synchronizeWithOptions:options completion:^(BOOL didFinish, NSManagedObjectContext *temporalContext, NSArray *prospectiveUnsavedObjects, NSError *anError) {
	
		if (didFinish) {

			if (successBlock)
				successBlock();
			
		} else {
		
			if (failureBlock)
				failureBlock(anError);
		
		}
		
	}];
	
}

- (void) uploadArticle:(NSURL *)anArticleURI withCompletion:(void(^)(NSError *))aBlock {

	[self uploadArticle:anArticleURI onSuccess:^ {
	
		if (aBlock)
			aBlock(nil);
	
	} onFailure:aBlock];

}

- (void) uploadArticle:(NSURL *)anArticleURI onSuccess:(void (^)(void))successBlock onFailure:(void (^)(NSError *error))failureBlock {

	NSParameterAssert([NSThread isMainThread]);

	__block __typeof__(self) nrSelf = self;
	__block NSManagedObjectContext *context = [[self disposableMOC] retain];
	__block WAArticle *updatedArticle = (WAArticle *)[context irManagedObjectForURI:anArticleURI];
	
	[[nrSelf articlesCurrentlyBeingUploaded] addObject:anArticleURI];
	
	void (^cleanup)() = ^ {
		[context autorelease];
		[[nrSelf articlesCurrentlyBeingUploaded] removeObject:anArticleURI];
	};
	
	[[nrSelf articlesCurrentlyBeingUploaded] addObject:anArticleURI];
	
	[updatedArticle synchronizeWithCompletion:^(BOOL didFinish, NSManagedObjectContext *context, NSArray *objects, NSError *error) {
		
		NSParameterAssert([NSThread isMainThread]);

		if (!didFinish) {
			
			if (failureBlock)
				failureBlock(error);
			
		} else {

			if (successBlock)
				successBlock();
		
		}
		
		cleanup();
		
	}];
	
}

- (BOOL) isUploadingArticle:(NSURL *)anObjectURI {

	return [[self articlesCurrentlyBeingUploaded] containsObject:anObjectURI];

}

- (void) addComment:(NSString *)commentText onArticle:(NSURL *)anArticleURI onSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock {
	
	__block NSManagedObjectContext *context = [self disposableMOC];
	__block WAArticle *updatedArticle = (WAArticle *)[context irManagedObjectForURI:anArticleURI];
	
	NSString *postIdentifier = updatedArticle.identifier;
	NSString *groupIdentifier = updatedArticle.group.identifier;
	
	if (!postIdentifier) {
		[NSException raise:NSInternalInconsistencyException format:@"Article %@ has not been saved, and was not assigned a remote identifier."];
		return;
	}
	
	if (!groupIdentifier) {
		[NSException raise:NSInternalInconsistencyException format:@"Article %@ has not yet been assigned a group."];
		return;
	}
	
	[[WARemoteInterface sharedInterface] createCommentForPost:postIdentifier inGroup:groupIdentifier withContentText:commentText onSuccess:^(NSDictionary *updatedPostRep) {
	
		NSManagedObjectContext *context = [self disposableMOC];
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
		
		[WAArticle insertOrUpdateObjectsUsingContext:context withRemoteResponse:[NSArray arrayWithObject:updatedPostRep] usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
		
		NSError *savingError = nil;
		if (![context save:&savingError])
			NSLog(@"Error Saving: %@", savingError);
		
		if (successBlock)
			successBlock();
		
	} onFailure:^(NSError *error) {
	
		if (failureBlock)
			failureBlock();
		
	}];

}

- (void) updateCurrentUserOnSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock {

	WARemoteInterface *ri = [WARemoteInterface sharedInterface];
	NSString *userIdentifier = ri.userIdentifier;
	NSParameterAssert(userIdentifier);
	
	__block __typeof__(self) nrSelf = self;
	
	[ri retrieveUser:userIdentifier onSuccess: ^ (NSDictionary *userRep, NSArray *groupReps) {
	
		NSManagedObjectContext *context = [nrSelf disposableMOC];
		context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
		
		[WAUser insertOrUpdateObjectsUsingContext:context withRemoteResponse:[NSArray arrayWithObject:userRep] usingMapping:nil options:IRManagedObjectOptionIndividualOperations];
		
		NSError *savingError = nil;
		if (![context save:&savingError])
			NSLog(@"%@: %@", NSStringFromSelector(_cmd), savingError);
			
		if (successBlock)
			successBlock();
		
	} onFailure:^(NSError *error) {
	
		NSLog(@"%@: %@", NSStringFromSelector(_cmd), error);
		
		if (failureBlock)
			failureBlock();
		
	}];

}

@end


@implementation WADataStore (WARemoteInterfaceAdditions_Private)

- (NSMutableSet *) articlesCurrentlyBeingUploaded {

	static NSString * const key = @"WADataStore_WARemoteInterfaceAdditions_articlesCurrentlyBeingUploaded";
	
	NSMutableSet *returnedSet = objc_getAssociatedObject(self, &key);
	if (!returnedSet) {
		returnedSet = [NSMutableSet set];
		objc_setAssociatedObject(self, &key, returnedSet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return returnedSet;

}

@end
