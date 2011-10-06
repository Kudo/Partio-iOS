//
//  WAFile.m
//  wammer-iOS
//
//  Created by Evadne Wu on 7/27/11.
//  Copyright (c) 2011 Iridia Productions. All rights reserved.
//

#import "WAFile.h"
#import "WAArticle.h"
#import "WAUser.h"
#import "WADataStore.h"
#import "UIImage+IRAdditions.h"
#import "CGGeometry+IRAdditions.h"


@implementation WAFile

@dynamic identifier;
@dynamic resourceFilePath;
@dynamic resourceType;
@dynamic resourceURL;
@dynamic text;
@dynamic thumbnailFilePath;
@dynamic thumbnailURL;
@dynamic timestamp;
@dynamic article;
@dynamic owner;
@dynamic thumbnail;

@synthesize resourceImage, thumbnailImage;

- (void) dealloc { 

	[resourceImage release];
	[thumbnailImage release];
	[super dealloc];

}

+ (NSString *) keyPathHoldingUniqueValue {

	return @"identifier";

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
			@"identifier", @"id",
			@"text", @"text",
			@"thumbnailURL", @"thumbnail_url",
			@"resourceURL", @"url",
			@"resourceType", @"type",
			@"timestamp", @"timestamp",
		nil];
		
		[mapping retain];
		
	});

	return mapping;

}

+ (id) transformedValue:(id)aValue fromRemoteKeyPath:(NSString *)aRemoteKeyPath toLocalKeyPath:(NSString *)aLocalKeyPath {

	if ([aLocalKeyPath isEqualToString:@"timestamp"])
		return [[WADataStore defaultStore] dateFromISO8601String:aValue];
	
	if ([aLocalKeyPath isEqualToString:@"identifier"])
		return IRWebAPIKitStringValue(aValue);
		
	if ([aLocalKeyPath isEqualToString:@"resourceType"]) {
	
		if (UTTypeConformsTo((CFStringRef)aValue, kUTTypeItem))
			return aValue;
		
		id returnedValue = IRWebAPIKitStringValue(aValue);
		
		CFArrayRef possibleTypes = UTTypeCreateAllIdentifiersForTag(kUTTagClassMIMEType, (CFStringRef)returnedValue, nil);
		
		if (CFArrayGetCount(possibleTypes) > 0) {
			//	NSLog(@"Warning: tried to set a MIME type for a UTI tag.");
			returnedValue = CFArrayGetValueAtIndex(possibleTypes, 0);
		}
	
		return returnedValue;
		
	}
	
	return [super transformedValue:aValue fromRemoteKeyPath:aRemoteKeyPath toLocalKeyPath:aLocalKeyPath];

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
				fr.entity = [WAFile entityDescriptionForContext:context];
				fr.predicate = [NSPredicate predicateWithFormat:@"(resourceURL == %@) || (thumbnailURL == %@)", [representingURL absoluteString], [representingURL absoluteString]];
				
				return fr;
			
			})()) error:nil];
			
			for (WAFile *matchingObject in matchingObjects) {
			
				if ([matchingObject.resourceURL isEqualToString:[representingURL absoluteString]])
					matchingObject.resourceFilePath = [[[WADataStore defaultStore] persistentFileURLForData:resourceData] path];
					
				if ([matchingObject.thumbnailURL isEqualToString:[representingURL absoluteString]])
					matchingObject.thumbnailFilePath = [[[WADataStore defaultStore] persistentFileURLForData:resourceData] path];
				
			}
			
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

- (NSString *) resourceFilePath {

	NSString *primitivePath = [self primitiveValueForKey:@"resourceFilePath"];
	
	if (primitivePath)
		return primitivePath;
	
	if (!self.resourceURL)
		return nil;
	
	NSURL *resourceURL = [NSURL URLWithString:self.resourceURL];
	
	if (![resourceURL isFileURL]) {
		[[[self class] sharedRemoteResourcesManager] retrieveResourceAtRemoteURL:resourceURL forceReload:YES];
		return nil;
	}
	
	primitivePath = [resourceURL path];
	
	if (primitivePath) {
		[self willChangeValueForKey:@"resourceFilePath"];
		[self setPrimitiveValue:primitivePath forKey:@"resourceFilePath"];
		[self didChangeValueForKey:@"resourceFilePath"];
	}
	
	return primitivePath;

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

	UIImage *primitiveThumbnail = [self primitiveValueForKey:@"thumbnail"];
	
	if (primitiveThumbnail)
		return primitiveThumbnail;
	
	if (!self.resourceImage)
		return nil;
	
	primitiveThumbnail = [self.resourceImage irScaledImageWithSize:IRCGSizeGetCenteredInRect(resourceImage.size, (CGRect){ CGPointZero, (CGSize){ 128, 128 } }, 0.0f, YES).size];
	[self setPrimitiveValue:primitiveThumbnail forKey:@"thumbnail"];
	
	return self.thumbnail;

}

- (UIImage *) resourceImage {
	
	if (resourceImage)
		return resourceImage;
	
	if (!self.resourceFilePath)
		return nil;
	
	[self willChangeValueForKey:@"resourceImage"];
	resourceImage = [[UIImage imageWithContentsOfFile:self.resourceFilePath] retain];
	[self didChangeValueForKey:@"resourceImage"];
	
	if (!resourceImage) {
		
		if (self.resourceURL)
		if (![[NSURL URLWithString:self.resourceURL] isFileURL])
		if (self.resourceFilePath) {
		
			[[NSFileManager defaultManager] removeItemAtPath:self.resourceFilePath error:nil];
			self.resourceFilePath = nil;
			
			//	Trigger reload
			
			[self resourceFilePath];
		
		}
	
	}

	return resourceImage;
	
}

- (UIImage *) thumbnailImage {
	
	if (thumbnailImage)
		return thumbnailImage;
	
	if (!self.thumbnailFilePath)
		return nil;
	
	[self willChangeValueForKey:@"thumbnailImage"];
	thumbnailImage = [[UIImage imageWithContentsOfFile:self.thumbnailFilePath] retain];
	[self didChangeValueForKey:@"thumbnailImage"];
	
	if (!thumbnailImage) {
		
		if (self.thumbnailURL)
		if (![[NSURL URLWithString:self.thumbnailURL] isFileURL])
		if (self.thumbnailFilePath) {
		
			[[NSFileManager defaultManager] removeItemAtPath:self.thumbnailFilePath error:nil];
			self.thumbnailFilePath = nil;
			
			//	Trigger reload
			
			[self thumbnailFilePath];
		
		}
	
	}

	return thumbnailImage;
	
}

@end
