//
//  WABlobSyncManager.m
//  wammer
//
//  Created by Evadne Wu on 1/4/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WABlobSyncManager.h"

#import "IRRecurrenceMachine.h"
#import "IRAsyncOperation.h"

#import "WARemoteInterface.h"

#import "WAReachabilityDetector.h"

#import "WAFile+WARemoteInterfaceEntitySyncing.h"


@interface WABlobSyncManager ()

@property (nonatomic, readwrite, retain) IRRecurrenceMachine *recurrenceMachine;
- (void) handleNetworkReachabilityStatusChanged:(NSNotification *)aNotification;

- (IRAsyncOperation *) haulingOperationPrototype;

@end


@implementation WABlobSyncManager
@synthesize recurrenceMachine;

+ (void) load {

	__block id applicationDidFinishLaunchingListener = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
	
		[[NSNotificationCenter defaultCenter] removeObserver:applicationDidFinishLaunchingListener];
		
		[WABlobSyncManager sharedManager];
		
	}];

}

+ (id) sharedManager {

	static dispatch_once_t token = 0;
	static WABlobSyncManager *manager = nil;
	dispatch_once(&token, ^{
		manager = [[self alloc] init];
	});
	
	return manager;

}

- (id) init {

	self = [super init];
	if (!self)
		return nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkReachabilityStatusChanged:) name:kWAReachabilityDetectorDidUpdateStatusNotification object:nil];
	
	[self.recurrenceMachine beginPostponingOperations];
	[self handleNetworkReachabilityStatusChanged:nil];
	
	return self;

}

- (void) dealloc {

	[recurrenceMachine release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];

}

- (IRRecurrenceMachine *) recurrenceMachine {

	if (recurrenceMachine)
		return recurrenceMachine;
	
	recurrenceMachine = [[IRRecurrenceMachine alloc] init];
	recurrenceMachine.queue.maxConcurrentOperationCount = 1;
	recurrenceMachine.recurrenceInterval = 30;
	
	[recurrenceMachine addRecurringOperation:[self haulingOperationPrototype]];
	
	return recurrenceMachine;

}

- (void) beginPostponingBlobSync {

	NSParameterAssert(recurrenceMachine);
	[recurrenceMachine beginPostponingOperations];

}

- (void) endPostponingBlobSync {

	NSParameterAssert(recurrenceMachine);
	[recurrenceMachine endPostponingOperations];

}

- (BOOL) isPerformingBlobSync {

	NSParameterAssert(recurrenceMachine);
	return ![recurrenceMachine isPostponingOperations];

}

- (IRAsyncOperation *) haulingOperationPrototype {

	return [IRAsyncOperation operationWithWorkerBlock: ^ (void(^aCallback)(id)) {
	
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		
			__block NSOperationQueue *tempQueue = [[NSOperationQueue alloc] init];
			tempQueue.maxConcurrentOperationCount = 1;
			[tempQueue setSuspended:YES];
			
			__block NSManagedObjectContext *context = nil;	//	Should be created on the operation queue so thread safety is maintained
			__block NSOperation *lastAddedOperation = nil;	//	For dependencies
			
			void (^enqueue)(NSOperation *) = ^ (NSOperation *anOperation){
				if (lastAddedOperation) {
					[anOperation addDependency:lastAddedOperation];
				}
				[tempQueue addOperation:anOperation];
				lastAddedOperation = anOperation;
			};
			
			enqueue([NSBlockOperation blockOperationWithBlock:^{
				context = [[[WADataStore defaultStore] disposableMOC] retain];
			}]);

			[[WADataStore defaultStore] enumerateFilesWithSyncableBlobsInContext:nil usingBlock:^(WAFile *aFile, NSUInteger index, BOOL *stop) {
			
				NSURL *fileURL = [[aFile objectID] URIRepresentation];
				
				enqueue([IRAsyncOperation operationWithWorkerBlock:^(void(^callback)(id)) {
				
					WAFile *actualFile = (WAFile *)[context irManagedObjectForURI:fileURL];
					if (!actualFile) {
						callback(nil);
						return;
					}
					
					[actualFile synchronizeWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:
						
						kWAFileSyncFullQualityStrategy, kWAFileSyncStrategy,
						
					nil] completion: ^ (BOOL didFinish, NSManagedObjectContext *temporalContext, NSManagedObject *prospectiveUnsavedObject, NSError *anError) {
					
						if (didFinish) {
							didFinish = [temporalContext save:nil];
						}
						
						callback(didFinish ? (id)kCFBooleanTrue : anError);
						
					}];

				} completionBlock:^(id results) {
				
					NSLog(@"Sync for file %@ returns: %@", fileURL, results);
					
				}]);
				
			}];
			
			enqueue([NSBlockOperation blockOperationWithBlock:^{
			
				[context release];
				
				dispatch_async(dispatch_get_main_queue(), ^{					
					[tempQueue autorelease];
				});
				
			}]);
			
			[tempQueue setSuspended:NO];
			
			aCallback(nil);
			
		});
		
	} completionBlock: ^ (id results) {
	
	//	NSLog(@"operation completion block called");
	//	NSLog(@"Results %@", results);
		
	}];

}

- (void) handleNetworkReachabilityStatusChanged:(NSNotification *)aNotification {

	if ([[WARemoteInterface sharedInterface] areExpensiveOperationsAllowed]) {
	
		if ([self.recurrenceMachine isPostponingOperations]) {
		
			[self.recurrenceMachine endPostponingOperations];
		
		}
	
	} else {
	
		//	Stop if have been working, cancel all stuff too

		if (![self.recurrenceMachine isPostponingOperations]) {
			
			[self.recurrenceMachine beginPostponingOperations];
		
		}
		
	}

}

@end


@implementation WADataStore (BlobSyncingAdditions)

- (void) enumerateFilesWithSyncableBlobsInContext:(NSManagedObjectContext *)context usingBlock:(void(^)(WAFile *aFile, NSUInteger index, BOOL *stop))block {

	NSParameterAssert(block);

	if (!context)
		context = [self disposableMOC];
	
	NSFetchRequest *fr = [context.persistentStoreCoordinator.managedObjectModel fetchRequestFromTemplateWithName:@"WAFRFilesWithSyncableBlobs" substitutionVariables:[NSDictionary dictionary]];
	
	fr.sortDescriptors = [NSArray arrayWithObjects:
		[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO],
	nil];
	
	[[context executeFetchRequest:fr error:nil] enumerateObjectsUsingBlock: ^ (WAFile *aFile, NSUInteger idx, BOOL *stop) {
	
		block(aFile, idx, stop);
		
	}];

}

@end
