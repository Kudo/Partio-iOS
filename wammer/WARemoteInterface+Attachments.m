//
//  WARemoteInterface+Attachments.m
//  wammer
//
//  Created by Evadne Wu on 11/8/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WARemoteInterface+Attachments.h"
#import "WADataStore.h"

#import "IRWebAPIEngine+FormMultipart.h"
#import "WAAssetsLibraryManager.h"
#import <AssetsLibrary+IRAdditions.h>
#import <Foundation/Foundation.h>

#import "WAFileExif.h"

NSString * const kWARemoteAttachmentType = @"WARemoteAttachmentType";
NSString * const kWARemoteAttachmentTitle = @"WARemoteAttachmentTitle";
NSString * const kWARemoteAttachmentDescription = @"WARemoteAttachmentDescription";
NSString * const kWARemoteAttachmentRepresentingImageURL = @"WARemoteAttachmentRepresentingImageURL";
NSString * const kWARemoteAttachmentUpdatedObjectIdentifier = @"WARemoteAttachmentUpdatedObjectIdentifier";
NSString * const kWARemoteAttachmentSubtype = @"kWARemoteAttachmentDestinationImageType";
NSString * const kWARemoteArticleIdentifier = @"kWARemoteArticleIdentifier";
NSString * const kWARemoteAttachmentExif = @"kWARemoteAttachmentExif";
NSString * const WARemoteAttachmentOriginalSubtype = @"origin";
NSString * const WARemoteAttachmentLargeSubtype = @"large";
NSString * const WARemoteAttachmentMediumSubtype = @"medium";
NSString * const WARemoteAttachmentSmallSubtype = @"small";


@implementation NSNumber (WAAdditions)

/* Convert NSNumber to rational value
 * ref: http://www.ics.uci.edu/~eppstein/numth/frap.c
 */
- (NSArray *) rationalValue {

	long m[2][2];
	double x, startx;
	const long MAXDENOM = 10000;
	long ai;

	startx = x = [self doubleValue];

	/* initialize matrix */
	m[0][0] = m[1][1] = 1;
	m[0][1] = m[1][0] = 0;

	/* loop finding terms until denom gets too big */
	while (m[1][0] *  ( ai = (long)x ) + m[1][1] <= MAXDENOM) {
		long t;
		t = m[0][0] * ai + m[0][1];
		m[0][1] = m[0][0];
		m[0][0] = t;
		t = m[1][0] * ai + m[1][1];
		m[1][1] = m[1][0];
		m[1][0] = t;
		if(x==(double)ai) break;     // AF: division by zero
		x = 1/(x - (double) ai);
		if(x>(double)0x7FFFFFFF) break;  // AF: representation failure
	}

	return @[[NSNumber numberWithLong:m[0][0]], [NSNumber numberWithLong:m[1][0]]];

}

@end


@implementation WARemoteInterface (Attachments)

- (void)createAttachmentWithFile:(NSURL *)aFileURL group:(NSString *)aGroupIdentifier options:(NSDictionary *)options onSuccess:(void (^)(NSString *))successBlock onFailure:(void (^)(NSError *))failureBlock {

	if ([aFileURL isFileURL]) {

		NSURL *copiedFileURL = [[WADataStore defaultStore] persistentFileURLForFileAtURL:aFileURL];
		[self createAttachmentWithCopiedFile:copiedFileURL group:aGroupIdentifier options:options onSuccess:successBlock onFailure:failureBlock];

	} else {

		[[WAAssetsLibraryManager defaultManager] assetForURL:aFileURL resultBlock:^(ALAsset *asset) {

			long long fileSize = [[asset defaultRepresentation] size];
			Byte *byteData = (Byte *)malloc(fileSize);
			[[asset defaultRepresentation] getBytes:byteData fromOffset:0 length:fileSize error:nil];
			NSURL *copiedFileURL = [[WADataStore defaultStore] persistentFileURLForData:[NSData dataWithBytesNoCopy:byteData length:fileSize freeWhenDone:YES] extension:@"jpeg"];
			[self createAttachmentWithCopiedFile:copiedFileURL group:aGroupIdentifier options:options onSuccess:successBlock onFailure:failureBlock];

		} failureBlock:^(NSError *error) {

			failureBlock(error);

		}];

	}

}

- (void) createAttachmentWithCopiedFile:(NSURL *)aCopiedFileURL group:(NSString *)aGroupIdentifier options:(NSDictionary *)options onSuccess:(void(^)(NSString *attachmentIdentifier))successBlock onFailure:(void(^)(NSError *error))failureBlock {

	NSParameterAssert([aCopiedFileURL isFileURL] && [[NSFileManager defaultManager] fileExistsAtPath:[aCopiedFileURL path]]);
	NSParameterAssert([[aCopiedFileURL pathExtension] length]);
	NSParameterAssert(aGroupIdentifier);
		
	NSMutableDictionary *mergedOptions = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedInteger:WARemoteAttachmentUnknownType], kWARemoteAttachmentType,
		WARemoteAttachmentOriginalSubtype, kWARemoteAttachmentSubtype,
	nil];
	
	[mergedOptions addEntriesFromDictionary:options];
	
	
	WARemoteAttachmentType type = [[mergedOptions objectForKey:kWARemoteAttachmentType] unsignedIntegerValue];
	WARemoteAttachmentSubtype subtype = [mergedOptions objectForKey:kWARemoteAttachmentSubtype];
	NSString *title = [mergedOptions objectForKey:kWARemoteAttachmentTitle];
	NSString *description = [mergedOptions objectForKey:kWARemoteAttachmentDescription];
	NSURL *proxyImage = [mergedOptions objectForKey:kWARemoteAttachmentRepresentingImageURL];
	NSString *updatedObjectID = [mergedOptions objectForKey:kWARemoteAttachmentUpdatedObjectIdentifier];
	NSString *articleIdentifier = [mergedOptions objectForKey:kWARemoteArticleIdentifier];
	WAFileExif *exif = [mergedOptions objectForKey:kWARemoteAttachmentExif];
	NSString *exifJsonString = nil;
	if (exif) {
		NSMutableDictionary *exifData = [[NSMutableDictionary alloc] init];
		if (exif.dateTimeOriginal) {
			[exifData setObject:exif.dateTimeOriginal forKey:@"DateTimeOriginal"];
		}
		if (exif.dateTimeDigitized) {
			[exifData setObject:exif.dateTimeDigitized forKey:@"DateTimeDigitized"];
		}
		if (exif.dateTime) {
			[exifData setObject:exif.dateTime forKey:@"DateTime"];
		}
		if (exif.model) {
			[exifData setObject:exif.model forKey:@"Model"];
		}
		if (exif.make) {
			[exifData setObject:exif.make forKey:@"Make"];
		}
		if (exif.exposureTime) {
			[exifData setObject:[exif.exposureTime rationalValue] forKey:@"ExposureTime"];
		}
		if (exif.fNumber) {
			[exifData setObject:[exif.fNumber rationalValue] forKey:@"FNumber"];
		}
		if (exif.apertureValue) {
			[exifData setObject:[exif.apertureValue rationalValue] forKey:@"ApertureValue"];
		}
		if (exif.focalLength) {
			[exifData setObject:[exif.focalLength rationalValue] forKey:@"FocalLength"];
		}
		if (exif.flash) {
			[exifData setObject:exif.flash forKey:@"Flash"];
		}
		if (exif.isoSpeedRatings) {
			[exifData setObject:exif.isoSpeedRatings forKey:@"ISOSpeedRatings"];
		}
		if (exif.colorSpace) {
			[exifData setObject:exif.colorSpace forKey:@"ColorSpace"];
		}
		if (exif.whiteBalance) {
			[exifData setObject:exif.whiteBalance forKey:@"WhiteBalance"];
		}
		if (exif.gpsLongitude && exif.gpsLatitude) {
			[exifData setObject:@{@"longitude":exif.gpsLongitude, @"latitude":exif.gpsLatitude} forKey:@"gps"];
		}

		if ([NSJSONSerialization isValidJSONObject:exifData]) {
			NSError *error = nil;
			NSData *exifJsonData = [NSJSONSerialization dataWithJSONObject:exifData options:0 error:&error];
			if (error) {
				NSLog(@"Unable to create EXIF JSON data from %@", exifData);
			}
			exifJsonString = [[NSString alloc] initWithData:exifJsonData encoding:NSUTF8StringEncoding];
		}
	}
	
	if (type == WARemoteAttachmentUnknownType) {
	
		//	Time for some inference
		
		NSString *pathExtension = [aCopiedFileURL pathExtension];
		BOOL fileIsImage = NO;
		if (pathExtension) {
			CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)pathExtension, kUTTypeItem);
			if (fileUTI) {
				fileIsImage = UTTypeConformsTo(fileUTI, kUTTypeImage);
				CFRelease(fileUTI);
			}
		}
		
		if (fileIsImage) {
			type = WARemoteAttachmentImageType;
		} else {
			type = WARemoteAttachmentDocumentType;
		}
	
	}
	
	
	NSMutableDictionary *sentRemoteOptions = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		aCopiedFileURL, @"file",
		aGroupIdentifier, @"group_id",
	nil];
	
	switch (type) {
		case WARemoteAttachmentImageType: {
			[sentRemoteOptions setObject:@"image" forKey:@"type"];
			[sentRemoteOptions setObject:subtype forKey:@"image_meta"];
			break;
		}
		case WARemoteAttachmentDocumentType: {
			[sentRemoteOptions setObject:@"doc" forKey:@"type"];
			break;
		}
		case WARemoteAttachmentUnknownType:
		default: {
			[NSException raise:NSInternalInconsistencyException format:@"Could not send a file %@ with unknown remote type", aCopiedFileURL];
			break;
		}
	}
	
	void (^stitch)(id, NSString *) = ^ (id anObject, NSString *aKey) {
		if (anObject && aKey)
			[sentRemoteOptions setObject:anObject forKey:aKey];
	};
	
	stitch(title, @"title");
	stitch(description, @"description");
	stitch(proxyImage, @"image");
	stitch(updatedObjectID, @"object_id");
	stitch(articleIdentifier, @"post_id");
	stitch(exifJsonString, @"exif");
	
	[self.engine fireAPIRequestNamed:@"attachments/upload" withArguments:nil options:[NSDictionary dictionaryWithObjectsAndKeys:
	
		sentRemoteOptions, kIRWebAPIEngineRequestContextFormMultipartFieldsKey,
		@"POST", kIRWebAPIEngineRequestHTTPMethod,
	
	nil] validator:WARemoteInterfaceGenericNoErrorValidator() successHandler: ^ (NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
	
		if (successBlock)
			successBlock([inResponseOrNil objectForKey:@"object_id"]);
		
		[[NSFileManager defaultManager] removeItemAtURL:aCopiedFileURL error:nil];
		
	} failureHandler:WARemoteInterfaceGenericFailureHandler(^ (NSError *anError){
	
		if (failureBlock)
			failureBlock(anError);
			
		[[NSFileManager defaultManager] removeItemAtURL:aCopiedFileURL error:nil];
	
	})];

}

- (void) retrieveAttachment:(NSString *)anIdentifier onSuccess:(void(^)(NSDictionary *attachmentRep))successBlock onFailure:(void(^)(NSError *error))failureBlock {

	[self.engine fireAPIRequestNamed:@"attachments/get" withArguments:[NSDictionary dictionaryWithObjectsAndKeys:
	
		anIdentifier, @"object_id",
	
	nil] options:nil validator:WARemoteInterfaceGenericNoErrorValidator() successHandler:^(NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
		
		if (!successBlock)
			return;
		
		successBlock(inResponseOrNil);
		
	} failureHandler:WARemoteInterfaceGenericFailureHandler(failureBlock)];

}

- (void) deleteAttachment:(NSString *)anIdentifier onSuccess:(void(^)(void))successBlock onFailure:(void(^)(NSError *error))failureBlock {

	[self.engine fireAPIRequestNamed:@"attachments/delete" withArguments:nil options:WARemoteInterfaceEnginePostFormEncodedOptionsDictionary([NSDictionary dictionaryWithObjectsAndKeys:
	
		anIdentifier, @"object_id",
	
	nil], nil) validator:WARemoteInterfaceGenericNoErrorValidator() successHandler:^(NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
		
		if (successBlock)
			successBlock();
		
	} failureHandler:WARemoteInterfaceGenericFailureHandler(failureBlock)];

}

- (void) retrieveThumbnailForAttachment:(NSString *)anIdentifier ofType:(WARemoteAttachmentType)aType onSuccess:(void(^)(NSURL *aThumbnailURL))successBlock onFailure:(void(^)(NSError *error))failureBlock {

	[self.engine fireAPIRequestNamed:@"attachments/view" withArguments:[NSDictionary dictionaryWithObjectsAndKeys:
	
		anIdentifier, @"object_id",
		@"large", @"image_meta",
	
	nil] options:nil validator:WARemoteInterfaceGenericNoErrorValidator() successHandler:^(NSDictionary *inResponseOrNil, IRWebAPIRequestContext *inResponseContext) {
		
		if (successBlock)
			successBlock([inResponseOrNil valueForKeyPath:@"redirect_to"]);
		
	} failureHandler:WARemoteInterfaceGenericFailureHandler(failureBlock)];

}

- (void) createAttachmentWithFileAtURL:(NSURL *)aFileURL inGroup:(NSString *)aGroupIdentifier representingImageURL:(NSURL *)aRepresentingImageForBinaryTypesOrNil withTitle:(NSString *)aTitle description:(NSString *)aDescription replacingAttachment:(NSString *)replacedAttachmentIdentifierOrNil asType:(WARemoteAttachmentType)aType onSuccess:(void(^)(NSString *attachmentIdentifier))successBlock onFailure:(void(^)(NSError *error))failureBlock {

	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	
	if (aRepresentingImageForBinaryTypesOrNil)
		[options setObject:aRepresentingImageForBinaryTypesOrNil forKey:kWARemoteAttachmentRepresentingImageURL];
	
	if (aTitle)
		[options setObject:aTitle forKey:kWARemoteAttachmentTitle];
		
	if (aDescription)
		[options setObject:aDescription forKey:kWARemoteAttachmentDescription];
		
	if (replacedAttachmentIdentifierOrNil)
		[options setObject:replacedAttachmentIdentifierOrNil forKey:kWARemoteAttachmentUpdatedObjectIdentifier];
	
	if (aType)
		[options setObject:[NSNumber numberWithUnsignedInteger:aType] forKey:kWARemoteAttachmentType];

	[self createAttachmentWithFile:aFileURL group:aGroupIdentifier options:options onSuccess:successBlock onFailure:failureBlock];

}

@end
