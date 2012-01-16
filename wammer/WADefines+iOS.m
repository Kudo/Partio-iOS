//
//  WADefines+iOS.m
//  wammer
//
//  Created by Evadne Wu on 12/17/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WADefines.h"
#import "WADefines+iOS.h"

#import "IRBorder.h"
#import "IRShadow.h"
#import "IRBarButtonItem.h"

#import "UIImage+IRAdditions.h"
#import "WAAppDelegate.h"

#import "WAAppDelegate_iOS.h"

#import "IRWebAPIHelpers.h"


WAAppDelegate * AppDelegate (void) {

	return (WAAppDelegate_iOS *)[UIApplication sharedApplication].delegate;

}




BOOL WAIsXCallbackURL (NSURL *anURL, NSString **outCommand, NSDictionary **outParams) {

	if (![[anURL host] isEqualToString:@"x-callback-url"])
		return NO;
	
	if (outCommand) {
		*outCommand = [[anURL path] stringByReplacingOccurrencesOfString:@"/" withString:@"" options:0 range:(NSRange){ 0, 1 }];
	}

	if (outParams)
		*outParams = IRQueryParametersFromString([anURL query]);
	
	return YES;

}





static IRBorder *kWADefaultBarButtonBorder;
static IRShadow *kWADefaultBarButtonInnerShadow;
static IRShadow *kWADefaultBarButtonShadow;

static UIFont *kWADefaultBarButtonTitleFont;
static UIColor *kWADefaultBarButtonTitleColor;
static IRShadow *kWADefaultBarButtonTitleShadow;

static UIColor *kWADefaultBarButtonGradientFromColor;
static UIColor *kWADefaultBarButtonGradientToColor;
static NSArray *kWADefaultBarButtonGradientColors;
static UIColor *kWADefaultBarButtonBackgroundColor;

static UIColor *kWADefaultBarButtonHighlightedGradientFromColor;
static UIColor *kWADefaultBarButtonHighlightedGradientToColor;
static NSArray *kWADefaultBarButtonHighlightedGradientColors;
static UIColor *kWADefaultBarButtonHighlightedBackgroundColor;

void kWADefaultBarButtonInitialize (void);






void kWADefaultBarButtonInitialize (void) {

	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		
		kWADefaultBarButtonBorder = [IRBorder borderForEdge:IREdgeNone withType:IRBorderTypeInset width:1 color:[UIColor colorWithRed:0 green:0 blue:0 alpha:.5]];
		kWADefaultBarButtonInnerShadow = [IRShadow shadowWithColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:.55] offset:(CGSize){ 0, 1 } spread:2];
		kWADefaultBarButtonShadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:1] offset:(CGSize){ 0, 1 } spread:1];
		
		kWADefaultBarButtonTitleFont = [UIFont boldSystemFontOfSize:12];
		kWADefaultBarButtonTitleColor = [UIColor colorWithRed:.3 green:.3 blue:.3 alpha:1];
		kWADefaultBarButtonTitleShadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:.35] offset:(CGSize){ 0, 1 } spread:0];

		kWADefaultBarButtonGradientFromColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1];
		kWADefaultBarButtonGradientToColor = [UIColor colorWithRed:.5 green:.5 blue:.5 alpha:1];
		
		kWADefaultBarButtonGradientColors = [NSArray arrayWithObjects:(id)kWADefaultBarButtonGradientFromColor.CGColor, (id)kWADefaultBarButtonGradientToColor.CGColor, nil];
		
		kWADefaultBarButtonBackgroundColor = nil;

		kWADefaultBarButtonHighlightedGradientFromColor = [kWADefaultBarButtonGradientFromColor colorWithAlphaComponent:.95];
		kWADefaultBarButtonHighlightedGradientToColor = [kWADefaultBarButtonGradientToColor colorWithAlphaComponent:.95];
		kWADefaultBarButtonHighlightedGradientColors = [NSArray arrayWithObjects:(id)kWADefaultBarButtonHighlightedGradientFromColor.CGColor, (id)kWADefaultBarButtonHighlightedGradientToColor.CGColor, nil];
		kWADefaultBarButtonHighlightedBackgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
		
		[kWADefaultBarButtonBorder retain];
		[kWADefaultBarButtonInnerShadow retain];
		[kWADefaultBarButtonShadow retain];

		[kWADefaultBarButtonTitleFont retain];
		[kWADefaultBarButtonTitleColor retain];
		[kWADefaultBarButtonTitleShadow retain];

		[kWADefaultBarButtonGradientFromColor retain];
		[kWADefaultBarButtonGradientToColor retain];
		[kWADefaultBarButtonGradientColors retain];
		[kWADefaultBarButtonBackgroundColor retain];

		[kWADefaultBarButtonHighlightedGradientFromColor retain];
		[kWADefaultBarButtonHighlightedGradientToColor retain];
		[kWADefaultBarButtonHighlightedGradientColors retain];
		[kWADefaultBarButtonHighlightedBackgroundColor retain];

	});

}


IRBarButtonItem * WAStandardBarButtonItem (NSString *labelText, void(^aBlock)(void)) {

	kWADefaultBarButtonInitialize();

	UIImage *normalImage = [IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBordered withTitle:labelText font:kWADefaultBarButtonTitleFont color:kWADefaultBarButtonTitleColor shadow:kWADefaultBarButtonTitleShadow backgroundColor:kWADefaultBarButtonBackgroundColor gradientColors:kWADefaultBarButtonGradientColors innerShadow:kWADefaultBarButtonInnerShadow border:kWADefaultBarButtonBorder shadow:kWADefaultBarButtonShadow];
	
	UIImage *highlightedImage = [IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBordered withTitle:labelText font:kWADefaultBarButtonTitleFont color:kWADefaultBarButtonTitleColor shadow:kWADefaultBarButtonTitleShadow backgroundColor:kWADefaultBarButtonHighlightedBackgroundColor gradientColors:kWADefaultBarButtonHighlightedGradientColors innerShadow:kWADefaultBarButtonInnerShadow border:kWADefaultBarButtonBorder shadow:kWADefaultBarButtonShadow];

	__block IRBarButtonItem *item = [IRBarButtonItem itemWithCustomImage:normalImage highlightedImage:highlightedImage];
	
	if (aBlock)
		item.block = aBlock;

	return item;

}

IRBarButtonItem * WABackBarButtonItem (NSString *labelText, void(^aBlock)(void)) {

	kWADefaultBarButtonInitialize();
	
	UIImage *normalImage = [IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBack withTitle:labelText font:kWADefaultBarButtonTitleFont color:kWADefaultBarButtonTitleColor shadow:kWADefaultBarButtonTitleShadow backgroundColor:kWADefaultBarButtonBackgroundColor gradientColors:kWADefaultBarButtonGradientColors innerShadow:kWADefaultBarButtonInnerShadow border:kWADefaultBarButtonBorder shadow:kWADefaultBarButtonShadow];
	
	UIImage *highlightedImage = [IRBarButtonItem buttonImageForStyle:IRBarButtonItemStyleBack withTitle:labelText font:kWADefaultBarButtonTitleFont color:kWADefaultBarButtonTitleColor shadow:kWADefaultBarButtonTitleShadow backgroundColor:kWADefaultBarButtonHighlightedBackgroundColor gradientColors:kWADefaultBarButtonHighlightedGradientColors innerShadow:kWADefaultBarButtonInnerShadow border:kWADefaultBarButtonBorder shadow:kWADefaultBarButtonShadow];

	__block IRBarButtonItem *item = [IRBarButtonItem itemWithCustomImage:normalImage highlightedImage:highlightedImage];
	
	if (aBlock)
		item.block = aBlock;

	return item;

}

UIButton * WAButtonForImage (UIImage *anImage) {

	//NSParameterAssert(anImage);
	UIButton *returnedButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[returnedButton setImage:anImage forState:UIControlStateNormal];
	[returnedButton setAdjustsImageWhenHighlighted:YES];
	[returnedButton setShowsTouchWhenHighlighted:YES];
	[returnedButton setContentEdgeInsets:(UIEdgeInsets){ 0, 5, 0, 0 }];
	[returnedButton sizeToFit];
	return returnedButton;
	
}

UIButton * WAToolbarButtonForImage (UIImage *anImage) {

  UIButton *button = WAButtonForImage(anImage);
  button.bounds = (CGRect){ CGPointZero, (CGSize){ 44, 44 }};
  
  return button;
  
}

UIImage * WABarButtonImageFromImageNamed (NSString *aName) {

  UIColor *fillColor = [UIColor colorWithRed:114.0/255.0 green:49.0/255.0 blue:23.0/255.0 alpha:1];      
  IRShadow *shadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.35f] offset:(CGSize){ 0, 1 } spread:0];
  
	//  switch ([UIDevice currentDevice].userInterfaceIdiom) {
	//    
	//    case UIUserInterfaceIdiomPhone: {
	//      fillColor = [UIColor colorWithRed:114.0/255.0 green:49.0/255.0 blue:23.0/255.0 alpha:1];      
	//      shadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.35f] offset:(CGSize){ 0, 1 } spread:0];
	//      break;
	//    }
	//
	//    default: {
	//      fillColor = [UIColor colorWithRed:.3 green:.3 blue:.3 alpha:1];
	//      shadow = [IRShadow shadowWithColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.75f] offset:(CGSize){ 0, 1 } spread:0];
	//      break;
	//    }
	//  }
  
	return [[UIImage imageNamed:aName] irSolidImageWithFillColor:fillColor shadow:shadow];

}

UIView * WAStandardTitleView (void) {

	UIImageView *logotype = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"WALogo"]] autorelease];
	logotype.contentMode = UIViewContentModeScaleAspectFit;
	logotype.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	logotype.frame = (CGRect){ CGPointZero, (CGSize){ 128, 40 }};
	
	UIView *containerView = [[UIView alloc] initWithFrame:(CGRect){	CGPointZero, (CGSize){ 128, 44 }}];
	logotype.frame = IRGravitize(containerView.bounds, logotype.bounds.size, kCAGravityResizeAspect);
	[containerView addSubview:logotype];
	
	return containerView;

}

UIView * WAStandardTitleLabel (void) {

	UILabel *label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	label.text = NSLocalizedString(@"APP_TITLE", @"Application Title");
	label.textColor = [UIColor colorWithWhite:0.35 alpha:1];
	label.font = [UIFont fontWithName:@"Sansus Webissimo" size:24.0f];
	label.shadowColor = [UIColor whiteColor];
	label.shadowOffset = (CGSize){ 0, 1 };
	label.backgroundColor = nil;
	label.opaque = NO;
	[label sizeToFit];
	return label;

}

UIView * WAStandardPostCellBackgroundView (void) {

	static UIEdgeInsets const backgroundViewPatternInsets = (UIEdgeInsets){ 8, 0, 0, 0 };
	
	UIView *backgroundView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 320 }] autorelease];
	backgroundView.backgroundColor = [UIColor clearColor];
  
  [backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:CGRectInset(backgroundView.bounds, 1, 0)] autorelease];
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    returnedView.layer.contents = (id)[UIImage imageNamed:@"WASquarePanelBackdrop"].CGImage;
    returnedView.layer.contentsScale = [UIScreen mainScreen].scale;
    returnedView.layer.contentsCenter = (CGRect){ 12.0/32.0f, 12.0/32.0f, 8.0/32.0f, 8.0/32.0f };
		
		returnedView.frame = UIEdgeInsetsInsetRect(returnedView.frame, backgroundViewPatternInsets);
    
    UIView *paperView = [[[UIView alloc] initWithFrame:CGRectInset(returnedView.bounds, 11, 11)] autorelease];
    paperView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    paperView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternPaper"]];
    [returnedView addSubview:paperView];
    
    return returnedView;
  
  })())];
	
	return backgroundView;

}

UIView * WAStandardPostCellSelectedBackgroundView (void) {

	static UIEdgeInsets const backgroundViewPatternInsets = (UIEdgeInsets){ 8, 0, 0, 0 };
	
	UIView *selectedBackgroundView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 320 }] autorelease];
	selectedBackgroundView.backgroundColor = [UIColor clearColor];
  
  [selectedBackgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:CGRectInset(selectedBackgroundView.bounds, 10, 10)] autorelease];
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    returnedView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
    
		returnedView.frame = UIEdgeInsetsInsetRect(returnedView.frame, backgroundViewPatternInsets);
		
    return returnedView;
    
  })())];

	return selectedBackgroundView;

}

UIView * WAStandardArticleStackCellBackgroundView (void) {

	UIView *backgroundView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 320 }] autorelease];
	backgroundView.backgroundColor = [UIColor clearColor];
  
  [backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = UIEdgeInsetsInsetRect(returnedView.frame, (UIEdgeInsets){ -32, -32, 0, -32 });
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    returnedView.layer.contents = (id)[UIImage imageNamed:@"WAPlaintextArticleStackCellBackdrop"].CGImage;
    returnedView.layer.contentsScale = [UIScreen mainScreen].scale;
    returnedView.layer.contentsCenter = (CGRect){ 128.0/384.0, 48.0/128.0, 128.0/384.0, 32.0/128.0 };
		
    return returnedView;
  
  })())];
	
	return backgroundView;	

}

UIView * WAStandardArticleStackCellTopBackgroundView (void) {

	UIView *backgroundView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 320 }] autorelease];
	
  [backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = UIEdgeInsetsInsetRect(returnedView.frame, (UIEdgeInsets){ 0, -32, 0, -32 });
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    returnedView.layer.contents = (id)[UIImage imageNamed:@"WAPlaintextArticleStackCellBackdrop"].CGImage;
    returnedView.layer.contentsScale = [UIScreen mainScreen].scale;
		returnedView.layer.contentsRect = (CGRect){ 0.0/384.0, 32.0/128.0, 384.0/384.0, 16.0/128.0 };
		returnedView.layer.contentsCenter = (CGRect){ 128.0/384.0, 40.0/48.0, 128.0/384.0, 8.0/48.0 };
		
    return returnedView;
  
  })())];
	
	[backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = returnedView.frame;
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		returnedView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternSoftWallpaper"]];
		returnedView.alpha = 0.35f;
		
    return returnedView;
  
  })())];
	
	return backgroundView;

}

UIView * WAStandardArticleStackCellCenterBackgroundView (void) {

	UIView *backgroundView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 320 }] autorelease];
	backgroundView.backgroundColor = [UIColor clearColor];
  
  [backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = UIEdgeInsetsInsetRect(returnedView.frame, (UIEdgeInsets){ 0, -32, 0, -32 });
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    returnedView.layer.contents = (id)[UIImage imageNamed:@"WAPlaintextArticleStackCellBackdrop"].CGImage;
    returnedView.layer.contentsScale = [UIScreen mainScreen].scale;
		returnedView.layer.contentsRect = (CGRect){ 0.0/384.0, 48.0/128.0, 384.0/384.0, 32.0/128.0 };
		returnedView.layer.contentsCenter = (CGRect){ 128.0/384.0, 0.0/32.0, 128.0/384.0, 32.0/32.0 };
		
    return returnedView;
  
  })())];
	
	[backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = returnedView.frame;
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		returnedView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternSoftWallpaper"]];
		returnedView.alpha = 0.35f;
		
    return returnedView;
  
  })())];

	return backgroundView;	

}

UIView * WAStandardArticleStackCellBottomBackgroundView (void) {

	UIView *backgroundView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 320 }] autorelease];
	backgroundView.backgroundColor = [UIColor clearColor];
  
  [backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = UIEdgeInsetsInsetRect(returnedView.frame, (UIEdgeInsets){ 0, -32, -32, -32 });
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    returnedView.layer.contents = (id)[UIImage imageNamed:@"WAPlaintextArticleStackCellBackdrop"].CGImage;
    returnedView.layer.contentsScale = [UIScreen mainScreen].scale;
		returnedView.layer.contentsRect = (CGRect){ 0.0/384.0, 80.0/128.0, 384.0/384.0, 48.0/128.0 };
		returnedView.layer.contentsCenter = (CGRect){ 128.0/384.0, 0.0/48.0, 128.0/384.0, 8.0/48.0 };
		
    return returnedView;
  
  })())];
	
	[backgroundView addSubview:((^ {
  
    UIView *returnedView = [[[UIView alloc] initWithFrame:backgroundView.bounds] autorelease];
		returnedView.frame = returnedView.frame;
    returnedView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		returnedView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternSoftWallpaper"]];
		returnedView.alpha = 0.35f;
		
    return returnedView;
  
  })())];
	
	return backgroundView;

}
