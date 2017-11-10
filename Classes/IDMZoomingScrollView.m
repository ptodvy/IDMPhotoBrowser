//
//  IDMZoomingScrollView.m
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "IDMZoomingScrollView.h"
#import "IDMPhotoBrowser.h"
#import "IDMPhoto.h"

// Declare private methods of browser
@interface IDMPhotoBrowser ()
- (void)cancelControlHiding;
- (void)hideControlsAfterDelay;
- (void)handleZoomOut;
- (void)handleSingleTap;
@end

// Private methods and properties
@interface IDMZoomingScrollView ()
@property (nonatomic, weak) IDMPhotoBrowser *photoBrowser;
@property (nonatomic, assign) CGFloat lastestZoomScale;
@property(nonatomic) CGFloat verticalContentRatio;
- (void)handleSingleTap:(CGPoint)touchPoint;
- (void)handleDoubleTap:(CGPoint)touchPoint;
@end

@implementation IDMZoomingScrollView

@synthesize photoImageView = _photoImageView, photoBrowser = _photoBrowser, photo = _photo, captionView = _captionView, lastestZoomScale = _lastestZoomScale;

- (id)initWithPhotoBrowser:(IDMPhotoBrowser *)browser {
    if ((self = [super init])) {
        // Delegate
        self.photoBrowser = browser;
        
        _lastestZoomScale = -1;
        
		// Tap view for background
		_tapView = [[IDMTapDetectingView alloc] initWithFrame:self.bounds];
		_tapView.tapDelegate = self;
		_tapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tapView.backgroundColor = [UIColor clearColor];
		[self addSubview:_tapView];
        
		// Image view
		_photoImageView = [[IDMTapDetectingImageView alloc] initWithFrame:CGRectZero];
		_photoImageView.tapDelegate = self;
		_photoImageView.backgroundColor = [UIColor clearColor];
		[self addSubview:_photoImageView];
        
        CGRect screenBound = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenBound.size.width;
        CGFloat screenHeight = screenBound.size.height;
        
        // Progress view
        _progressView = [[DACircularProgressView alloc] initWithFrame:CGRectMake((screenWidth-28.)/2., (screenHeight-28.)/2, 28.0f, 28.0f)];
        [_progressView setProgress:0.0f];
        _progressView.tag = 101;
        _progressView.thicknessRatio = 0.1;
        _progressView.roundedCorners = NO;
        _progressView.trackTintColor    = browser.trackTintColor    ? self.photoBrowser.trackTintColor    : [UIColor colorWithWhite:0.2 alpha:1];
        _progressView.progressTintColor = browser.progressTintColor ? self.photoBrowser.progressTintColor : [UIColor colorWithWhite:1.0 alpha:1];
        [self addSubview:_progressView];
        
		// Setup
		self.backgroundColor = [UIColor clearColor];
		self.delegate = self;
		self.showsHorizontalScrollIndicator = NO;
		self.showsVerticalScrollIndicator = NO;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        _verticalContentRatio = self.frame.size.height / self.frame.size.width;
    }
    
    return self;
}

- (void)setPhoto:(id<IDMPhoto>)photo {
    _photoImageView.image = nil; // Release image
    _photoImageView.animatedImage = nil;
    
    if (_photo != photo) {
        _photo = photo;
    }
    [self displayImage];
}

- (void)prepareForReuse {
    self.photo = nil;
    [_captionView removeFromSuperview];
    self.captionView = nil;
}

#pragma mark - Image

// Get and display image
- (void)displayImage {
	if (_photo) {
		// Reset
		self.maximumZoomScale = 1;
		self.minimumZoomScale = 1;
		self.zoomScale = 1;
        
		self.contentSize = CGSizeMake(0, 0);
		
		// Get image from browser as it handles ordering of fetching
        IDMPhotoImage *img = [_photo imageIfLoaded];

		if (img && (img.image || img.animatedImage)) {
            // Hide ProgressView
            //_progressView.alpha = 0.0f;
            [_progressView removeFromSuperview];
            
            // Set image
            CGSize size;
            
            if (img.image) {
                _photoImageView.image = img.image;
                size = img.image.size;
            } else {
                _photoImageView.animatedImage = img.animatedImage;
                size = img.animatedImage.size;
            }
            
			_photoImageView.hidden = NO;
        
            // Setup photo frame
			CGRect photoImageViewFrame;
			photoImageViewFrame.origin = CGPointZero;
			photoImageViewFrame.size = size;
            
			_photoImageView.frame = photoImageViewFrame;
			self.contentSize = photoImageViewFrame.size;

			// Set zoom to minimum zoom
			[self setMaxMinZoomScalesForCurrentBounds];
        } else {
			// Hide image view
			_photoImageView.hidden = YES;
            
            _progressView.alpha = 1.0f;
		}
        
		[self setNeedsLayout];
	}
}

- (void)setProgress:(CGFloat)progress forPhoto:(IDMPhoto*)photo {
    IDMPhoto *p = (IDMPhoto*)self.photo;

    if ([photo.photoURL.absoluteString isEqualToString:p.photoURL.absoluteString]) {
        if (_progressView.progress < progress) {
            [_progressView setProgress:progress animated:YES];
        }
    }
}

// Image failed so just show black!
- (void)displayImageFailure {
    [_progressView removeFromSuperview];
}

#pragma mark - Setup

- (void)setMaxMinZoomScalesForCurrentBounds {
    CGRect screenBound = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenBound.size.width;
    CGFloat screenHeight = screenBound.size.height;
    
    CGRect rect = _progressView.frame;
    rect.origin.x = (screenWidth-28.)/2.;
    rect.origin.y = (screenHeight-28.)/2.;
    
    _progressView.frame = rect;
    
	// Bail
    if (!_photoImageView || (!_photoImageView.image && !_photoImageView.animatedImage)) {
        return;
    }
    
	// Sizes
	CGSize boundsSize = self.frame.size;
	boundsSize.width -= 0.1;
	boundsSize.height -= 0.1;
    CGSize imageSize;
    
    if (_photoImageView.image) {
        imageSize = _photoImageView.image.size;
    } else {
        imageSize = _photoImageView.animatedImage.size;
    }
    
    // Calculate Min
    CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = MIN(xScale, yScale);                 // use minimum of these to allow the image to become fully visible
    
	// If image is smaller than the screen then ensure we show it at
	// min scale of 1
	if (minScale > 4.0) {
        
        if (minScale > 10.0) {
            minScale = 4.0;
        } else {
            minScale = 1.0;
        }
	}
    
    CGFloat letterBoxRatio = (imageSize.width * minScale * imageSize.height * minScale) / ([UIScreen mainScreen].bounds.size.width * [UIScreen mainScreen].bounds.size.height);

	// Calculate Max
	CGFloat maxScale = 8.0; // Allow four times scale
    // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
    // maximum zoom scale to 0.5.
	if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
		maxScale = maxScale / [[UIScreen mainScreen] scale];
		
		if (maxScale <= minScale) {
			maxScale = minScale * 2;
		}
	}

	// Calculate Max Scale Of Double Tap
    CGFloat maxDoubleTapZoomScale = 0;
    
    if (letterBoxRatio <= 0.5) {
        if (imageSize.width > imageSize.height) {
            maxDoubleTapZoomScale =  boundsSize.height / imageSize.height;
        } else if (imageSize.width < imageSize.height) {
            maxDoubleTapZoomScale =  boundsSize.width / imageSize.width;
        } else {
            if (self.bounds.size.width > boundsSize.height) {
                maxDoubleTapZoomScale =  boundsSize.width / imageSize.width;
            } else {
                maxDoubleTapZoomScale =  boundsSize.height / imageSize.height;
            }
        }
        
        if (maxDoubleTapZoomScale <= minScale) {
            maxDoubleTapZoomScale = minScale * 2;
        }
    } else {
        maxDoubleTapZoomScale = 4.0 * minScale; // Allow four times scale
        // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
        // maximum zoom scale to 0.5.
        if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
            maxDoubleTapZoomScale = maxDoubleTapZoomScale / [[UIScreen mainScreen] scale];
            
            if (maxDoubleTapZoomScale <= minScale) {
                maxDoubleTapZoomScale = minScale * 2;
            }
        }
    }
    
    // Make sure maxDoubleTapZoomScale isn't larger than maxScale
    maxDoubleTapZoomScale = MIN(maxDoubleTapZoomScale, maxScale);
    
	// Set
	self.maximumZoomScale = maxScale;
	self.minimumZoomScale = minScale;
	self.zoomScale = _lastestZoomScale == -1 ? minScale : _lastestZoomScale;
	self.maximumDoubleTapZoomScale = maxDoubleTapZoomScale;
    
	// Reset position
	_photoImageView.frame = CGRectMake(0, 0, _photoImageView.frame.size.width, _photoImageView.frame.size.height);
	[self setNeedsLayout];    
}

#pragma mark - Layout

- (void)layoutSubviews {
	// Update tap view frame
	_tapView.frame = self.bounds;
    
	// Super
	[super layoutSubviews];
    
    // Center the image as it becomes smaller than the size of the screen
    CGSize boundsSize = self.bounds.size;
    CGRect frameToCenter = _photoImageView.frame;
    
    // Horizontally
    if (frameToCenter.size.width < boundsSize.width) {
        frameToCenter.origin.x = floorf((boundsSize.width - frameToCenter.size.width) / 2.0);
	} else {
        frameToCenter.origin.x = 0;
	}
    
    // Vertically
    if (frameToCenter.size.height < boundsSize.height) {
        frameToCenter.origin.y = floorf((boundsSize.height - frameToCenter.size.height) / 2.0);
	} else {
        frameToCenter.origin.y = 0;
	}
    
	// Center
	if (!CGRectEqualToRect(_photoImageView.frame, frameToCenter))
		_photoImageView.frame = frameToCenter;
    
    _verticalContentRatio = self.frame.size.height / self.frame.size.width;
}


- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center {
    CGRect zoomRect = CGRectZero;
    CGSize size = _photoImageView.frame.size;
    
    zoomRect.size.height = self.frame.size.height / scale;
    zoomRect.size.width = self.frame.size.width / scale;
    
    CGFloat ratio = size.height / size.width;

    if ([self frame].size.width < [self frame].size.height && ratio >= _verticalContentRatio) {
        CGFloat height = size.height;
        if (height > [self frame].size.height) {
            height = [self frame].size.height;
        }
        
        CGFloat width = height / ratio;
        
        if (width * scale > [self frame].size.width) {
            zoomRect.origin.x = center.x - ((zoomRect.size.width / 2.0));
            zoomRect.origin.y = center.y - ((zoomRect.size.height / 2.0));
        } else {
            zoomRect.origin.x = [self frame].size.width / 2 - ((zoomRect.size.width / 2.0));
            zoomRect.origin.y = center.y - ((zoomRect.size.height / 2.0));
        }
    } else {
        zoomRect.origin.x = center.x - ((zoomRect.size.width / 2.0));
        zoomRect.origin.y = center.y - ((zoomRect.size.height / 2.0));
    }
    
    return zoomRect;
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _photoImageView;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	[_photoBrowser hideControlsAfterDelay];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Tap Detection

- (void)handleSingleTap:(CGPoint)touchPoint {
//	[_photoBrowser performSelector:@selector(toggleControls) withObject:nil afterDelay:0.2];
	[_photoBrowser performSelector:@selector(handleSingleTap) withObject:nil afterDelay:0.2];
}

- (void)handleDoubleTap:(CGPoint)touchPoint {
    IDMPhotoImage *img = [_photo underlyingImage];
    
    if (img && (img.image || img.animatedImage)) {
        
        // Cancel any single tap handling
        [NSObject cancelPreviousPerformRequestsWithTarget:_photoBrowser];
        
        // Zoom
        if (self.zoomScale > self.minimumZoomScale) {
            // Zoom out
            [self setZoomScale:self.minimumZoomScale animated:YES];
            _lastestZoomScale = self.minimumZoomScale;
            
            [_photoBrowser handleZoomOut];
        } else {
            // Zoom in
            [self zoomToRect:[self zoomRectForScale:self.maximumDoubleTapZoomScale withCenter:touchPoint] animated:YES];
            _lastestZoomScale = self.maximumDoubleTapZoomScale;
            
            if ([_photoBrowser.delegate respondsToSelector:@selector(setControlsHidden:animated:)]) {
                [_photoBrowser.delegate setControlsHidden:YES animated:YES];
            }
        }
        
        // Delay controls
        if (![_photoBrowser.delegate respondsToSelector:@selector(setControlsHidden:animated:)]) {
            [_photoBrowser hideControlsAfterDelay];
        }
    }
}

// Image View
- (void)imageView:(UIImageView *)imageView singleTapDetected:(UITouch *)touch { 
    [self handleSingleTap:[touch locationInView:imageView]];
}
- (void)imageView:(UIImageView *)imageView doubleTapDetected:(UITouch *)touch {
    [self handleDoubleTap:[touch locationInView:imageView]];
}

// Background View
- (void)view:(UIView *)view singleTapDetected:(UITouch *)touch {
    [self handleSingleTap:[touch locationInView:view]];
}
- (void)view:(UIView *)view doubleTapDetected:(UITouch *)touch {
    [self handleDoubleTap:[touch locationInView:view]];
}

@end
