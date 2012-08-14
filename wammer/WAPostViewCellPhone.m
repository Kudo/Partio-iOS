//
//  WAArticleCommentsViewCell.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/12/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WAPostViewCellPhone.h"

#import "UIKit+IRAdditions.h"
#import "QuartzCore+IRAdditions.h"

#import "WADefines.h"
#import "WAPreviewBadge.h"
#import "WARemoteInterface.h"


@interface WAPostViewCellPhone () <IRTableViewCellPrototype>

@end


@implementation WAPostViewCellPhone

@synthesize backgroundImageView;
@synthesize photoImageViews;
@synthesize monthLabel, dayLabel;
@synthesize extraInfoLabel;
@synthesize contentTextView;
@synthesize commentLabel;
@synthesize avatarView, userNicknameLabel, contentDescriptionLabel, dateOriginLabel, dateLabel, originLabel;
@synthesize previewBadge, previewImageView, previewTitleLabel, previewProviderLabel, previewImageBackground;

+ (NSSet *) encodedObjectKeyPaths {

	return [NSSet setWithObjects:@"backgroundImageView", @"monthLabel", @"dayLabel", @"extraInfoLabel", @"contentTextView", @"commentLabel", @"avatarView", @"userNicknameLabel", @"contentDescriptionLabel", @"dateOriginLabel", @"dateLabel", @"originLabel", @"previewBadge", @"previewImageView", @"previewTitleLabel", @"previewProviderLabel", @"previewImageBackground", @"photoImageViews", nil];

}

+ (NSSet *) keyPathsForValuesAffectingArticle {

	return [NSSet setWithObjects:
		
		@"representedObject",
		
	nil];

}

- (WAArticle *) article {

	return (WAArticle *)self.representedObject;

}

+ (WAPostViewCellPhone *) newPrototypeForIdentifier:(NSString *)identifier {

	WAPostViewCellPhone *cell = nil;

	if ([identifier isEqualToString:@"PostCell-Stacked-1-Photo"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:0];
	
	} else if ([identifier isEqualToString:@"PostCell-Stacked-2-Photo"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:1];
	
	} else if ([identifier isEqualToString:@"PostCell-Stacked-3-Photo"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:2];
	
	} else if ([identifier isEqualToString:@"PostCell-WebLink"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-WebLink" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:0];
	
	} else if ([identifier isEqualToString:@"PostCell-WebLinkNoPhoto"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-WebLink" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:1];
	
	} else if ([identifier isEqualToString:@"PostCell-WebLinkOnly"]) {

		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-WebLinkOnly" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];

		cell = [loadedObjects objectAtIndex:0];

	} else if ([identifier isEqualToString:@"PostCell-WebLinkOnlyNoPhoto"]) {

		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-WebLinkOnly" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];

		cell = [loadedObjects objectAtIndex:1];

	} else if ([identifier isEqualToString:@"PostCell-TextOnly"]) {
	
		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-Default" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];
		
		cell = [loadedObjects objectAtIndex:0];
	
	} else if ([identifier isEqualToString:@"PostCell-Stacked-1-PhotoOnly"]) {

		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageOnlyStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];

		cell = [loadedObjects objectAtIndex:0];

	} else if ([identifier isEqualToString:@"PostCell-Stacked-2-PhotoOnly"]) {

		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageOnlyStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];

		cell = [loadedObjects objectAtIndex:1];

	} else if ([identifier isEqualToString:@"PostCell-Stacked-3-PhotoOnly"]) {

		UINib *nib = [UINib nibWithNibName:@"WAPostViewCellPhone-ImageOnlyStack" bundle:[NSBundle mainBundle]];
		NSArray *loadedObjects = [nib instantiateWithOwner:nil options:nil];

		cell = [loadedObjects objectAtIndex:2];

	}
	
	cell.selectedBackgroundView = ((^ {
	
		UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
		view.backgroundColor = [UIColor colorWithWhite:0.65 alpha:1];
		view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		
		return view;
		
	})());
	
	cell.previewBadge.titleFont = [UIFont systemFontOfSize:14.0f];
	cell.previewBadge.textFont = [UIFont systemFontOfSize:14.0f];
	
	return cell;

}

+ (NSString *) identifierRepresentingObject:(WAArticle *)article {

	switch ([article.files count]) {
	
		case 0: {
		
			WAPreview *anyPreview = [article.previews anyObject];
			
			if (anyPreview.text || anyPreview.url || anyPreview.graphElement.text || anyPreview.graphElement.title) {
			
				if ([anyPreview.graphElement.representingImage.imageRemoteURL length] != 0) {
					if ([article.text length] > 0) {
						return @"PostCell-WebLink";
					}
					return @"PostCell-WebLinkOnly";
				} else {
					if ([article.text length] > 0) {
						return @"PostCell-WebLinkNoPhoto";
					}
					return @"PostCell-WebLinkOnlyNoPhoto";
				}
			
			}
			
			return @"PostCell-TextOnly";
		
		}
		
		case 1: {

			if ([article.text length] > 0) {

				return @"PostCell-Stacked-1-Photo";

			} else {

				return @"PostCell-Stacked-1-PhotoOnly";

			}

		}
		
		case 2: {

			if ([article.text length] > 0) {

				return @"PostCell-Stacked-2-Photo";

			} else {

				return @"PostCell-Stacked-2-PhotoOnly";

			}

		}
		
		default: {

			if ([article.text length] > 0) {

				return @"PostCell-Stacked-3-Photo";

			} else {

				return @"PostCell-Stacked-3-PhotoOnly";

			}

		}

	}
	
}

- (CGFloat) heightForRowRepresentingObject:(WAArticle *)object inTableView:(UITableView *)tableView {

	NSString *identifier = [[self class] identifierRepresentingObject:object];
	WAPostViewCellPhone *prototype = (WAPostViewCellPhone *)[[self class] prototypeForIdentifier:identifier];
	NSParameterAssert([prototype isKindOfClass:[WAPostViewCellPhone class]]);
	
	prototype.frame = (CGRect){
		CGPointZero,
		(CGSize){
			CGRectGetWidth(tableView.bounds),
			CGRectGetHeight(prototype.bounds)
		}
	};
	
	CGRect oldLabelFrame = prototype.commentLabel.frame;
	CGFloat cellLabelHeightDelta = CGRectGetHeight(prototype.bounds) - CGRectGetHeight(oldLabelFrame);
	
	prototype.commentLabel.frame = (CGRect){
		CGPointZero,
		(CGSize){
			CGRectGetWidth(prototype.commentLabel.bounds),
			0
		}
	};
	
	prototype.commentLabel.text = object.text;
	
	[prototype.commentLabel sizeToFit];
	
	CGFloat answer = roundf(MIN(prototype.commentLabel.font.leading * 3, CGRectGetHeight(prototype.commentLabel.bounds)) + cellLabelHeightDelta);
	prototype.commentLabel.frame = oldLabelFrame;
	
	return MAX(answer, CGRectGetHeight(prototype.bounds));
	
}

- (void) setRepresentedObject:(id)representedObject {

	WAArticle *previousPost = self.representedObject;
	if (previousPost) {
		for (WAFile *file in previousPost.files) {
			[file irRemoveObserverBlocksForKeyPath:@"smallThumbnailFilePath"];
			[file irRemoveObserverBlocksForKeyPath:@"thumbnailFilePath"];
		}
	}

	[super setRepresentedObject:representedObject];
	
	WAArticle *post = representedObject;
	NSParameterAssert([post isKindOfClass:[WAArticle class]]);
	
	BOOL const postHasFiles = (BOOL)!![post.files count];
	BOOL const postHasPreview = (BOOL)!![post.previews count];
	
	NSDate *postDate = post.presentationDate;
	NSString *deviceName = post.creationDeviceName;
	NSString *timeString = [[[self class] timeFormatter] stringFromDate:postDate];
	
	self.originLabel.text = [NSString stringWithFormat:NSLocalizedString(@"CREATE_TIME_FROM_DEVICE", @"iPhone Timeline"), timeString, deviceName];
	self.dateLabel.text = [[[IRRelativeDateFormatter sharedFormatter] stringFromDate:postDate] lowercaseString];
	self.commentLabel.text = post.text;
	
	if (postHasPreview) {

		WAPreview *preview = [post.previews anyObject];
		
		self.extraInfoLabel.text = @"";
	 
		self.previewBadge.preview = preview;
		
		self.accessibilityLabel = @"Preview";
		self.accessibilityHint = preview.graphElement.title;
		self.accessibilityValue = preview.graphElement.text;
		
		UIImageView *piv = self.previewImageView;
		
		[piv irUnbind:@"image"];
		
		[piv irBind:@"image" toObject:preview keyPath:@"graphElement.representingImage.image" options:[NSDictionary dictionaryWithObjectsAndKeys:
		
			(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
		
		nil]];
		
		self.previewTitleLabel.text = preview.graphElement.title;
		self.previewProviderLabel.text = preview.graphElement.providerDisplayName;
			
	} else if (postHasFiles) {

		self.accessibilityValue = post.text;
		
		NSArray *allFiles = [post.files array];
		NSArray *allPhotoImageViews = self.photoImageViews;
		NSUInteger numberOfFiles = [allFiles count];
		NSUInteger numberOfPhotoImageViews = [allPhotoImageViews count];

		self.accessibilityLabel = @"Photo";

		NSString *photoInfo = NSLocalizedString(@"PHOTO_PLURAL", @"in iPhone timeline");
		if ([post.files count] == 1)
			photoInfo = NSLocalizedString(@"PHOTO_SINGULAR", @"in iPhone timeline");

		self.accessibilityHint = [NSString stringWithFormat:photoInfo, [post.files count]];

		__block NSUInteger numberOfDownloadedSmallThumbnails = 0;
		__block NSUInteger numberOfDownloadedMediumThumbnails = 0;

		BOOL (^downloadCompleted)(void)	= ^ {
			if (numberOfDownloadedSmallThumbnails == numberOfFiles && numberOfDownloadedMediumThumbnails == numberOfFiles) {
				return YES;
			}
			return NO;
		};

		__weak WAPostViewCellPhone *wSelf = self;
		for (WAFile *file in allFiles) {
			if (![file smallThumbnailFilePath]) {
				[file irObserve:@"smallThumbnailFilePath" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
					if (!fromValue && toValue) {
						numberOfDownloadedSmallThumbnails += 1;
						if (downloadCompleted()) {
							dispatch_async(dispatch_get_main_queue(), ^{
								WAArticle *article = wSelf.representedObject;
								wSelf.originLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUMBER_OF_PHOTOS_CREATE_TIME_FROM_DEVICE", @"iPhone Timeline"), wSelf.accessibilityHint, [[[wSelf class] timeFormatter] stringFromDate:article.presentationDate], article.creationDeviceName];
							});
						} else {
							dispatch_async(dispatch_get_main_queue(), ^{
								wSelf.originLabel.text = [NSString stringWithFormat:@"small:%d/%d  medium:%d/%d", numberOfDownloadedSmallThumbnails, numberOfFiles, numberOfDownloadedMediumThumbnails, numberOfFiles];
							});
						}
					}
				}];
			} else {
				numberOfDownloadedSmallThumbnails += 1;
			}
			if (![file thumbnailFilePath]) {
				[file irObserve:@"thumbnailFilePath" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
					if (!fromValue && toValue) {
						numberOfDownloadedMediumThumbnails += 1;
						if (downloadCompleted()) {
							dispatch_async(dispatch_get_main_queue(), ^{
								WAArticle *article = wSelf.representedObject;
								wSelf.originLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUMBER_OF_PHOTOS_CREATE_TIME_FROM_DEVICE", @"iPhone Timeline"), wSelf.accessibilityHint, [[[wSelf class] timeFormatter] stringFromDate:article.presentationDate], article.creationDeviceName];
							});
						} else {
							dispatch_async(dispatch_get_main_queue(), ^{
								wSelf.originLabel.text = [NSString stringWithFormat:@"small:%d/%d  medium:%d/%d", numberOfDownloadedSmallThumbnails, numberOfFiles, numberOfDownloadedMediumThumbnails, numberOfFiles];
							});
						}
					}
				}];
			} else {
				numberOfDownloadedMediumThumbnails += 1;
			}
		}

		if (downloadCompleted()) {
			self.originLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUMBER_OF_PHOTOS_CREATE_TIME_FROM_DEVICE", @"iPhone Timeline"), self.accessibilityHint, timeString, deviceName];
		} else if ([[WARemoteInterface sharedInterface] hasReachableCloud]){
//			self.originLabel.text = [NSString stringWithFormat:NSLocalizedString(@"DOWNLOADING_PHOTOS", @"Downloading Status on iPhone Timeline")];
			self.originLabel.text = [NSString stringWithFormat:@"small:%d/%d  medium:%d/%d", numberOfDownloadedSmallThumbnails, numberOfFiles, numberOfDownloadedMediumThumbnails, numberOfFiles];
		} else {
			self.originLabel.text = [NSString stringWithFormat:NSLocalizedString(@"UNABLE_TO_DOWNLOADING_PHOTOS", @"Downloading Status on iPhone Timeline")];
		}

		NSMutableArray *displayedFiles = [[allFiles subarrayWithRange:(NSRange){ 0, MIN(numberOfPhotoImageViews, numberOfFiles)}] mutableCopy];
		
		WAFile *coverFile = post.representingFile;
		if ([displayedFiles containsObject:coverFile]) {
			
			[displayedFiles removeObject:coverFile];
			[displayedFiles insertObject:coverFile atIndex:0];
			
		} else {
			
			[displayedFiles insertObject:coverFile atIndex:0];
			
			if ([displayedFiles count] > numberOfPhotoImageViews)
				[displayedFiles removeLastObject];
			
		}
		
		[allPhotoImageViews enumerateObjectsUsingBlock:^(UIImageView *iv, NSUInteger idx, BOOL *stop) {
		
			if ([displayedFiles count] < idx) {
				
				iv.image = nil;
				
				return;
				
			}
				
			WAFile *file = (WAFile *)[displayedFiles objectAtIndex:idx];
			
			[iv irUnbind:@"image"];

			if (!file.smallestPresentableImage && file.assetURL) {

				ALAssetsLibrary * const library = [[self class] assetsLibrary];
				[library assetForURL:[NSURL URLWithString:file.assetURL] resultBlock:^(ALAsset *asset) {

					dispatch_async(dispatch_get_main_queue(), ^{
						
						iv.image = [UIImage imageWithCGImage:[asset aspectRatioThumbnail]];
						
					});

				} failureBlock:^(NSError *error) {

					NSLog(@"Unable to retrieve assets for URL %@", file.assetURL);

				}];

			} else {

				[iv irBind:@"image" toObject:file keyPath:@"smallestPresentableImage" options:[NSDictionary dictionaryWithObjectsAndKeys:
																																											 
					(id)kCFBooleanTrue, kIRBindingsAssignOnMainThreadOption,
																																											 
				nil]];
			}
			
		}];
		
		if ([post.files count] > 3) {
			
			self.extraInfoLabel.text = [NSString stringWithFormat:NSLocalizedString(@"NUMBER_OF_PHOTOS", @"Photo information in cell"), [post.files count]];
			
		}
		
  } else {
		
		self.commentLabel.text = post.text;
		self.extraInfoLabel.text = @"";
	 
		self.accessibilityLabel = @"Text Post";
		self.accessibilityValue = post.text;
		
	}
		
	self.commentLabel.text = post.text;
	
	UIColor *textColor;
	UIColor *shadowColor;

	if ([post.favorite isEqual:(id)kCFBooleanTrue]) {
		
		self.backgroundImageView.image = [UIImage imageNamed:@"tagFavorite"];
		textColor = [UIColor whiteColor];
		shadowColor = [UIColor colorWithHue:155/360 saturation:0.0 brightness:0.8 alpha:1.0];
		
	} else {
		
		self.backgroundImageView.image = [UIImage imageNamed:@"tagDefault"];
		textColor = [UIColor colorWithHue:111/360 saturation:0.0 brightness:0.56 alpha:1.0];
		shadowColor = [UIColor colorWithHue:111/360 saturation:0.0 brightness:1.0 alpha:1.0];
		
	} 
	
	self.dayLabel.textColor = textColor;
	self.dayLabel.shadowColor = shadowColor;
	
	self.monthLabel.textColor = textColor;
	self.monthLabel.shadowColor = shadowColor;
	
	self.dayLabel.text = [[[self class] dayFormatter] stringFromDate:postDate];
	self.monthLabel.text = [[[[self class] monthFormatter] stringFromDate:postDate] uppercaseString];
	
	[self setNeedsLayout];
	
}

+ (NSDateFormatter *) monthFormatter {

	static dispatch_once_t onceToken;
	static NSDateFormatter *formatter;
	dispatch_once(&onceToken, ^{
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateFormat = @"MMM";
	});

	return formatter;

}

+ (NSDateFormatter *) dayFormatter {

	static dispatch_once_t onceToken;
	static NSDateFormatter *formatter;
	dispatch_once(&onceToken, ^{
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateFormat = @"dd";
	});

	return formatter;

}

+ (NSDateFormatter *) timeFormatter {

	static dispatch_once_t onceToken;
	static NSDateFormatter *formatter;
	dispatch_once(&onceToken, ^{
		formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterNoStyle;
		formatter.timeStyle = NSDateFormatterShortStyle;
	});

	return formatter;

}

- (void) setActive:(BOOL)active animated:(BOOL)animated {

	CGFloat alpha = active ? 0.65f : 1.0f;
	UIColor *backgroundColor = [UIColor colorWithWhite:0.5 alpha:1];
	
	for (UIImageView *iv in self.photoImageViews) {
		iv.alpha = alpha;
		iv.backgroundColor = backgroundColor;
	}
	
	self.previewImageView.alpha = alpha;
	self.previewImageView.backgroundColor = backgroundColor;

}

- (void) setHighlighted:(BOOL)highlighted animated:(BOOL)animated {

	[super setHighlighted:highlighted animated:animated];
	
	[self setActive:(self.highlighted || self.selected) animated:animated];

}

- (void) setSelected:(BOOL)selected animated:(BOOL)animated {

	[super setSelected:selected animated:animated];
	
	[self setActive:(self.highlighted || self.selected) animated:animated];

}

+ (ALAssetsLibrary *) assetsLibrary {

	static ALAssetsLibrary *library = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{

    library = [ALAssetsLibrary new];

	});

	return library;

}
@end
