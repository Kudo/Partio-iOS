//
//  WACompositionViewPhotoCell.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/11/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import "WACompositionViewPhotoCell.h"
#import "QuartzCore+IRAdditions.h"


@interface WACompositionViewPhotoCell ()
@property (nonatomic, readwrite, retain) UIImageView *imageContainer;
@property (nonatomic, readwrite, retain) UIView *highlightOverlay;	//	Placed in the image container
@property (nonatomic, readwrite, retain) UIButton *removeButton;
@property (nonatomic, readwrite, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, readwrite, weak) WAFile *representedFile;
@property (nonatomic, readwrite, strong) id representedFileHelper;

@end

@implementation WACompositionViewPhotoCell
@synthesize style;
@synthesize image, imageContainer, removeButton, onRemove, highlightOverlay;
@synthesize activityIndicator;
@synthesize canRemove;
@synthesize representedFile, representedFileHelper;

+ (WACompositionViewPhotoCell *) cellRepresentingFile:(WAFile *)aFile reuseIdentifier:(NSString *)identifier {

	WACompositionViewPhotoCell *returnedCell = [[self alloc] initWithFrame:(CGRect){ 0, 0, 128, 128 } reuseIdentifier:identifier];
	returnedCell.representedFile = aFile;
	
	return returnedCell;

}

- (void) setRepresentedFile:(WAFile *)file {

	if (representedFile == file)
		return;
	
	if (self.representedFileHelper) {
		[representedFile irRemoveObservingsHelper:self.representedFileHelper];
		self.representedFileHelper = nil;
	}
	
	representedFile = file;
	
	__weak WACompositionViewPhotoCell *wSelf = self;
	
	self.representedFileHelper = [file irObserve:@"smallestPresentableImage" options:NSKeyValueObservingOptionPrior|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil withBlock:^(NSKeyValueChange kind, id fromValue, id toValue, NSIndexSet *indices, BOOL isPrior) {
	
		if (!toValue || [toValue isKindOfClass:[UIImage class]])
			[wSelf setImage:toValue];
		
	}];

}

- (void) dealloc {

	if (representedFile && representedFileHelper)
		[representedFile irRemoveObservingsHelper:representedFileHelper];

}

- (UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event {

	UIView *buttonAnswer = [self.removeButton hitTest:[self convertPoint:point toView:self.removeButton] withEvent:event];
	if (buttonAnswer)
		return buttonAnswer;

	return [super hitTest:point withEvent:event];

}

- (id) initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {

	self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	
	self.backgroundColor = nil;
	self.contentView.backgroundColor = nil;
	self.selectionStyle = AQGridViewCellSelectionStyleNone;
	self.contentView.layer.shouldRasterize = YES;
	self.contentView.layer.rasterizationScale = [UIScreen mainScreen].scale;
	
	self.contentView.clipsToBounds = NO;
	
	self.imageContainer = [[UIImageView alloc] initWithImage:nil];
	self.imageContainer.frame = self.contentView.bounds;
	self.imageContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.imageContainer.contentMode = UIViewContentModeScaleAspectFit;
	self.imageContainer.layer.minificationFilter = kCAFilterTrilinear;

	[self.contentView addSubview:self.imageContainer];
	
	self.highlightOverlay = [[UIView alloc] initWithFrame:self.imageContainer.bounds];
	self.highlightOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
	self.highlightOverlay.userInteractionEnabled = NO;
	self.highlightOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.highlightOverlay.hidden = YES;
	[self.imageContainer addSubview:self.highlightOverlay];
	
	self.removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.removeButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
	[self.removeButton addTarget:self action:@selector(handleRemove:) forControlEvents:UIControlEventTouchUpInside];
	[self.removeButton setImage:[UIImage imageNamed:@"WAButtonSpringBoardRemove"] forState:UIControlStateNormal];
	[self.removeButton sizeToFit];
	self.removeButton.frame = UIEdgeInsetsInsetRect(self.removeButton.frame, (UIEdgeInsets){ -16, -16, -16, -16 });
	self.removeButton.imageView.contentMode = UIViewContentModeCenter;
	[self.contentView addSubview:self.removeButton];
	
	self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
	self.activityIndicator.center = (CGPoint){ CGRectGetMidX(self.imageContainer.bounds), CGRectGetMidY(self.imageContainer.bounds) };
	self.activityIndicator.frame = CGRectIntegral(self.activityIndicator.frame);
	[self.activityIndicator startAnimating];
	[self.imageContainer addSubview:self.activityIndicator];
	
	self.canRemove = YES;
	
	[self setNeedsLayout];
	
	return self;

}

- (IBAction) handleRemove:(id)sender {

	if (self.onRemove)
		self.onRemove();

}

- (void) setImage:(UIImage *)newImage {

	if (image == newImage)
		return;
	
	[self willChangeValueForKey:@"image"];
	image = newImage;
	[self didChangeValueForKey:@"image"];
	
	self.imageContainer.image = newImage;
	
	if (newImage) {
	
		CGRect imageRect = IRGravitize(self.imageContainer.bounds, newImage.size, self.imageContainer.layer.contentsGravity);
		self.removeButton.center = (CGPoint) {
			CGRectGetMinX(imageRect) + 8,
			CGRectGetMinY(imageRect) + 8
		};
		
		self.highlightOverlay.frame = imageRect;
		
	}
	
	[self setNeedsLayout];

}

- (void) setStyle:(WACompositionViewPhotoCellStyle)aStyle {

	style = aStyle;
	
	[self setNeedsLayout];

}

- (void) layoutSubviews {

	[super layoutSubviews];
	
	switch (self.style) {
	
		case WACompositionViewPhotoCellShadowedStyle: {
			self.imageContainer.frame = UIEdgeInsetsInsetRect(self.contentView.bounds, (UIEdgeInsets){ 8, 8, 8, 8 });
			self.imageContainer.layer.shadowOffset = (CGSize){ 0, 1 };
			self.imageContainer.layer.shadowOpacity = 0.5f;
			self.imageContainer.layer.shadowRadius = 2.0f;
			self.imageContainer.layer.contentsGravity = kCAGravityResizeAspect;
			self.imageContainer.layer.borderColor = nil;
			self.imageContainer.layer.borderWidth = 0;
			self.imageContainer.clipsToBounds = NO;
			break;
		}
		
		case WACompositionViewPhotoCellBorderedPlainStyle: {
			self.imageContainer.frame = self.contentView.bounds;
			self.imageContainer.layer.shadowOpacity = 0.0f;
			self.imageContainer.layer.contentsGravity = kCAGravityResizeAspectFill;
			self.imageContainer.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1].CGColor;
			self.imageContainer.layer.borderWidth = 1.0f;
			self.imageContainer.clipsToBounds = YES;
			break;
		}
	
	}
	
	if (canRemove) {
		self.removeButton.alpha = 1;
		self.removeButton.enabled = YES;
	} else {
		self.removeButton.alpha = 0;
		self.removeButton.enabled = NO;
	}
	
	if (self.image) {

		self.removeButton.hidden = NO;
		self.activityIndicator.alpha = 0;
		self.imageContainer.backgroundColor = nil;
		self.imageContainer.layer.shadowPath = [UIBezierPath bezierPathWithRect:IRCGSizeGetCenteredInRect(self.image.size, self.imageContainer.bounds, 0.0f, YES)].CGPath;
	
	} else {
	
		self.removeButton.hidden = YES;
		self.activityIndicator.alpha = 1;
		self.imageContainer.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
		self.imageContainer.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.imageContainer.bounds].CGPath;
	
	}

}

- (void) setHighlighted:(BOOL)highlighted animated:(BOOL)animated {

	[super setHighlighted:highlighted animated:animated];
	
	self.highlightOverlay.alpha = self.highlightOverlay.hidden ? 0 : 1;
	self.highlightOverlay.hidden = NO;
	
	[UIView animateWithDuration:(animated ? 0.3 : 0) animations:^{

		self.highlightOverlay.alpha = highlighted ? 1 : 0;
		
	} completion:^(BOOL finished) {
	
		self.highlightOverlay.hidden = !highlighted;
		
	}];

}

- (void) prepareForReuse {

	self.image = nil;

}

@end
