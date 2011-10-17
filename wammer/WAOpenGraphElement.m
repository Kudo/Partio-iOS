//
//  WAOpenGraphElement.m
//  wammer-iOS
//
//  Created by Evadne Wu on 9/8/11.
//  Copyright (c) 2011 Iridia Productions. All rights reserved.
//

#import "WAOpenGraphElement.h"
#import "WADataStore.h"


@implementation WAOpenGraphElement

@dynamic providerName;
@dynamic providerURL;
@dynamic text;
@dynamic title;
@dynamic thumbnailFilePath;
@dynamic thumbnailURL;
@dynamic type;
@dynamic url;

@synthesize thumbnail;

- (void) dealloc {

	[thumbnail release];
	[super dealloc];

}

+ (BOOL) skipsNonexistantRemoteKey {

	//	Allows piecemeal data patching, by skipping code path that assigns a placeholder value for any missing value
	//	that -configureWithRemoteDictionary: gets
	return YES;
	
}

+ (NSDictionary *) remoteDictionaryConfigurationMapping {

	static NSDictionary *mapping = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    
		mapping = [NSDictionary dictionaryWithObjectsAndKeys:
			@"providerName", @"provider_name",
			@"providerURL", @"provider_url",
			@"thumbnailURL", @"thumbnail_url",
			@"text", @"description",
			@"title", @"title",
			@"url", @"url",
			@"type", @"type",
		nil];
		
		[mapping retain];
		
	});

	return mapping;

}

+ (IRRemoteResourcesManager *) sharedRemoteResourcesManager {

	static IRRemoteResourcesManager *sharedManager = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
    
		sharedManager = [IRRemoteResourcesManager sharedManager];
		sharedManager.delegate = (id<IRRemoteResourcesManagerDelegate>)[UIApplication sharedApplication].delegate;
		
		id notificationObject = [[NSNotificationCenter defaultCenter] addObserverForName:kIRRemoteResourcesManagerDidRetrieveResourceNotification object:nil queue:[self remoteResourceHandlingQueue] usingBlock:^(NSNotification *aNotification) {
		
			NSURL *representingURL = (NSURL *)[aNotification object];
			NSData *resourceData = [sharedManager resourceAtRemoteURL:representingURL skippingUncachedFile:NO];
			
			if (![resourceData length])
			return;
			
			NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
			NSArray *matchingObjects = [context executeFetchRequest:((^ {
				
				NSFetchRequest *fr = [[[NSFetchRequest alloc] init] autorelease];
				fr.entity = [WAOpenGraphElement entityDescriptionForContext:context];
				fr.predicate = [NSPredicate predicateWithFormat:@"thumbnailURL == %@", [representingURL absoluteString]];
				
				return fr;
			
			})()) error:nil];
			
			for (WAOpenGraphElement *matchingObject in matchingObjects)
				matchingObject.thumbnailFilePath = [[[WADataStore defaultStore] persistentFileURLForData:resourceData] path];
			
			if (![[context updatedObjects] count])
				return;
			
			NSError *savingError;
			if (![context save:&savingError])
				NSLog(@"Error saving: %@", savingError);
			
		}];
		
		objc_setAssociatedObject(sharedManager, @"boundNotificationObject", notificationObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC); 

	});
	
	return sharedManager;

}

+ (NSOperationQueue *) remoteResourceHandlingQueue {

	static NSOperationQueue *returnedQueue = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		returnedQueue = [[NSOperationQueue alloc] init];
	});
	
	return returnedQueue;

}

- (NSString *) thumbnailFilePath {

	NSString *primitivePath = [self primitiveValueForKey:@"thumbnailFilePath"];
	
	if (primitivePath)
		return primitivePath;
	
	if (!self.thumbnailURL)
		return nil;
	
	NSURL *thumbnailURL = [NSURL URLWithString:self.thumbnailURL];
	
	if (![thumbnailURL isFileURL]) {
		[[[self class] sharedRemoteResourcesManager] retrieveResourceAtRemoteURL:thumbnailURL forceReload:YES];
		return nil;
	}
	
	primitivePath = [thumbnailURL path];
	
	if (primitivePath) {
		[self willChangeValueForKey:@"thumbnailFilePath"];
		[self setPrimitiveValue:primitivePath forKey:@"thumbnailFilePath"];
		[self didChangeValueForKey:@"thumbnailFilePath"];
	}
	
	return primitivePath;

}

- (UIImage *) thumbnail {

	if (thumbnail)
		return thumbnail;
	
	if (!self.thumbnailFilePath)
		return nil;
	
	[self willChangeValueForKey:@"thumbnail"];
	thumbnail = [[UIImage imageWithContentsOfFile:self.thumbnailFilePath] retain];
	[self didChangeValueForKey:@"thumbnail"];
	
	return thumbnail;

}





+ (id) transformedValue:(id)aValue fromRemoteKeyPath:(NSString *)aRemoteKeyPath toLocalKeyPath:(NSString *)aLocalKeyPath {

	if ([aLocalKeyPath isEqualToString:@"thumbnailURL"])
		return [aValue isEqualToString:@""] ? nil : aValue;
	
	return aValue;

}


- (BOOL) validateForUpdate:(NSError **)error {

	if (self.thumbnailURL)
	if (![[NSURL URLWithString:self.thumbnailURL] host]) {
		
		*error = [NSError errorWithDomain:@"com.waveface.wammer" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Objects having a thumbnail URL should also have a host in the URL.", NSLocalizedDescriptionKey,
			self.thumbnailURL, @"offendingThumbnailURL",
		nil]];
		
		return NO;
		
	}
	
	return YES;

}

@end
