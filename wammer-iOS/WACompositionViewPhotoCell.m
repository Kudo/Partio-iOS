//
//  WACompositionViewPhotoCell.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/11/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "WACompositionViewPhotoCell.h"


@interface WACompositionViewPhotoCell ()
@property (nonatomic, readwrite, retain) UIView *imageContainer;
@property (nonatomic, readwrite, retain) UIButton *removeButton;
@end

@implementation WACompositionViewPhotoCell
@synthesize image, imageContainer, removeButton;

+ (WACompositionViewPhotoCell *) cellRepresentingFile:(WAFile *)aFile reuseIdentifier:(NSString *)identifier {

	WACompositionViewPhotoCell *returnedCell = [[[self alloc] initWithFrame:(CGRect){ 0, 0, 128, 128 } reuseIdentifier:identifier] autorelease];
	
	return returnedCell;

}

- (id) initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {

	self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	
	self.backgroundColor = nil;
	self.contentView.backgroundColor = nil;
	self.selectionStyle = AQGridViewCellSelectionStyleNone;
	self.contentView.layer.shouldRasterize = YES;
	self.contentView.layer.shadowOffset = (CGSize){ 0, 0 };
	self.contentView.layer.shadowOpacity = 0.95f;
	self.contentView.layer.shadowRadius = 1.0f;

	self.imageContainer = [[[UIView alloc] initWithFrame:UIEdgeInsetsInsetRect(self.contentView.bounds, (UIEdgeInsets){ 8, 8, 8, 8 })] autorelease];
	self.imageContainer.layer.contentsGravity = kCAGravityResizeAspect;
	self.imageContainer.layer.minificationFilter = kCAFilterTrilinear;
	[self.contentView addSubview:self.imageContainer];
	
	self.removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.removeButton setImage:[UIImage imageNamed:@"WAButtonSpringBoardRemove"] forState:UIControlStateNormal];
	[self.removeButton sizeToFit];
	[self.contentView addSubview:self.removeButton];
	
	return self;

}

- (void) setImage:(UIImage *)newImage {

	if (image == newImage)
		return;
	
	[self willChangeValueForKey:@"image"];
	[image release];
	image = [newImage retain];
	[self didChangeValueForKey:@"image"];
	
	self.imageContainer.layer.contents = (id)newImage.CGImage;
	self.removeButton.hidden = (BOOL)(!newImage);
	
	CGRect imageRect = IRCGSizeGetCenteredInRect(newImage.size, self.imageContainer.frame, 0.0f, YES);
	
	self.removeButton.center = (CGPoint) {
		CGRectGetMinX(imageRect),
		CGRectGetMinY(imageRect)
	};

}

- (void) dealloc {

	[imageContainer release];
	[image release];
	[removeButton release];
	[super dealloc];

}

@end
