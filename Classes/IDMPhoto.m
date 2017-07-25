//
//  IDMPhoto.m
//  IDMPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "IDMPhoto.h"
#import "IDMPhotoBrowser.h"
#import <SDWebImage/UIImage+MultiFormat.h>
#import <SDWebImage/UIImage+GIF.h>

// Private
@interface IDMPhoto () {
// Image Sources
    NSString *_photoPath;

// Image
    IDMPhotoImage *_underlyingImage;

    // Other
    NSString *_caption;
    BOOL _loadingInProgress;
}

// Properties
@property (nonatomic, strong) IDMPhotoImage *underlyingImage;
    
// Methods
- (void)imageLoadingComplete;

@end

// IDMPhoto
@implementation IDMPhoto

// Properties
@synthesize underlyingImage = _underlyingImage, 
photoURL = _photoURL,
caption = _caption;

#pragma mark Class Methods

+ (IDMPhoto *)photoWithImage:(UIImage *)image {
	return [[IDMPhoto alloc] initWithImage:image];
}

+ (IDMPhoto *)photoWithFilePath:(NSString *)path {
	return [[IDMPhoto alloc] initWithFilePath:path];
}

+ (IDMPhoto *)photoWithURL:(NSURL *)url {
	return [[IDMPhoto alloc] initWithURL:url];
}

+ (NSArray *)photosWithImages:(NSArray *)imagesArray {
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:imagesArray.count];
    
    for (UIImage *image in imagesArray) {
        if ([image isKindOfClass:[UIImage class]]) {
            IDMPhoto *photo = [IDMPhoto photoWithImage:image];
            [photos addObject:photo];
        }
    }
    
    return photos;
}

+ (NSArray *)photosWithFilePaths:(NSArray *)pathsArray {
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:pathsArray.count];
    
    for (NSString *path in pathsArray) {
        if ([path isKindOfClass:[NSString class]]) {
            IDMPhoto *photo = [IDMPhoto photoWithFilePath:path];
            [photos addObject:photo];
        }
    }
    
    return photos;
}

+ (NSArray *)photosWithURLs:(NSArray *)urlsArray {
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:urlsArray.count];
    
    for (id url in urlsArray) {
        if ([url isKindOfClass:[NSURL class]]) {
            IDMPhoto *photo = [IDMPhoto photoWithURL:url];
            [photos addObject:photo];
        }
        else if ([url isKindOfClass:[NSString class]]) {
            IDMPhoto *photo = [IDMPhoto photoWithURL:[NSURL URLWithString:url]];
            [photos addObject:photo];
        }
    }
    
    return photos;
}

#pragma mark NSObject

- (id)initWithImage:(UIImage *)image {
	if ((self = [super init])) {
        IDMPhotoImage *photoImage = [[IDMPhotoImage alloc] init];
        photoImage.image = image;
        
		self.underlyingImage = photoImage;
	}
	return self;
}

- (id)initWithFilePath:(NSString *)path {
	if ((self = [super init])) {
		_photoPath = [path copy];
	}
	return self;
}

- (id)initWithURL:(NSURL *)url {
	if ((self = [super init])) {
		_photoURL = [url copy];
	}
	return self;
}

#pragma mark IDMPhoto Protocol Methods

- (IDMPhotoImage *)underlyingImage {
    return _underlyingImage;
}

- (void)loadUnderlyingImageAndNotify {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    _loadingInProgress = YES;
    if (self.underlyingImage) {
        // Image already loaded
        [self imageLoadingComplete];
    } else {
        if (_photoPath) {
            // Load async from file
            [self performSelectorInBackground:@selector(loadImageFromFileAsync) withObject:nil];
        } else if (_photoURL) {
            // Load async from web (using SDWebImageManager)
			
            
            [[SDWebImageManager sharedManager] downloadImageWithURL:_photoURL options:SDWebImageRetryFailed progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                    CGFloat progress = ((CGFloat)receivedSize)/((CGFloat)expectedSize);
                    
                    if (self.progressUpdateBlock) {
                        self.progressUpdateBlock(progress);
                    }
            } completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                self.underlyingImage = [[IDMPhotoImage alloc] init];
                
                self.underlyingImage = [[IDMPhotoImage alloc] init];
                
                if ([image isGIF]) {
                    self.underlyingImage.animatedImage = [FLAnimatedImage animatedImageWithGIFData:data];
                    self.underlyingImage.image = nil;
                } else {
                    self.underlyingImage.animatedImage = nil;
                    self.underlyingImage.image = image;
                }
                
                if (image) {
                    [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                }
            }];
        } else {
            // Failed - no source
            self.underlyingImage = nil;
            [self imageLoadingComplete];
        }
    }
}

// Release if we can get it again from path or url
- (void)unloadUnderlyingImage {
    _loadingInProgress = NO;

	if (self.underlyingImage && (_photoPath || _photoURL)) {
        self.underlyingImage = nil;
	}
}

#pragma mark - Async Loading
- (UIImage *)decodedImageWithImage:(UIImage *)image {
    if (image.images) {
        // Do not decode animated images
        return image;
    }
    
    CGImageRef imageRef = image.CGImage;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    CGRect imageRect = (CGRect){.origin = CGPointZero, .size = imageSize};
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    int infoMask = (bitmapInfo & kCGBitmapAlphaInfoMask);
    BOOL anyNonAlpha = (infoMask == kCGImageAlphaNone ||
                        infoMask == kCGImageAlphaNoneSkipFirst ||
                        infoMask == kCGImageAlphaNoneSkipLast);
    
    // CGBitmapContextCreate doesn't support kCGImageAlphaNone with RGB.
    // https://developer.apple.com/library/mac/#qa/qa1037/_index.html
    if (infoMask == kCGImageAlphaNone && CGColorSpaceGetNumberOfComponents(colorSpace) > 1)
    {
        // Unset the old alpha info.
        bitmapInfo &= ~kCGBitmapAlphaInfoMask;
        
        // Set noneSkipFirst.
        bitmapInfo |= kCGImageAlphaNoneSkipFirst;
    }
    // Some PNGs tell us they have alpha but only 3 components. Odd.
    else if (!anyNonAlpha && CGColorSpaceGetNumberOfComponents(colorSpace) == 3)
    {
        // Unset the old alpha info.
        bitmapInfo &= ~kCGBitmapAlphaInfoMask;
        bitmapInfo |= kCGImageAlphaPremultipliedFirst;
    }
    
    // It calculates the bytes-per-row based on the bitsPerComponent and width arguments.
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 imageSize.width,
                                                 imageSize.height,
                                                 CGImageGetBitsPerComponent(imageRef),
                                                 0,
                                                 colorSpace,
                                                 bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    
    // If failed, return undecompressed image
    if (!context) return image;
	
    CGContextDrawImage(context, imageRect, imageRef);
    CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);
	
    CGContextRelease(context);
	
    UIImage *decompressedImage = [UIImage imageWithCGImage:decompressedImageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(decompressedImageRef);
    return decompressedImage;
}

// Called in background
// Load image in background from local file
- (void)loadImageFromFileAsync {
    @autoreleasepool {
        @try {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath:_photoPath];
            UIImage *image = [UIImage sd_imageWithData:data];
            
            if (image) {
                self.underlyingImage = [[IDMPhotoImage alloc] init];
                
                if ([image isGIF]) {
                    self.underlyingImage.animatedImage = [FLAnimatedImage animatedImageWithGIFData:data];
                    self.underlyingImage.image = nil;
                } else {
                    self.underlyingImage.animatedImage = nil;
                    self.underlyingImage.image = image;
                }
            }
        } @finally {
            if (_underlyingImage && _underlyingImage.image) {
                self.underlyingImage.image = [self decodedImageWithImage: self.underlyingImage.image];
            }
            
            if (_underlyingImage) {
                [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
            }
        }
    }
}

// Called on main
- (void)imageLoadingComplete {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    // Complete so notify
    _loadingInProgress = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:IDMPhoto_LOADING_DID_END_NOTIFICATION
                                                        object:self];
}

- (IDMPhotoImage *)imageIfLoaded {
    // Get image or obtain in background
    if ([self underlyingImage]) {
        return [self underlyingImage];
    } else {
        [self loadUnderlyingImageAndNotify];
        if ([self respondsToSelector:@selector(placeholderImage)]) {
            return [self placeholderImage];
        }
    }
    
    return nil;
}

@end
