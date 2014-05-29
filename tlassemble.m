/*
 *  Copyright (c) 2012, Daniel Bridges
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *      * Redistributions of source code must retain the above copyright
 *        notice, this list of conditions and the following disclaimer.
 *      * Redistributions in binary form must reproduce the above copyright
 *        notice, this list of conditions and the following disclaimer in the
 *        documentation and/or other materials provided with the distribution.
 *      * Neither the name of the Daniel Bridges nor the
 *        names of its contributors may be used to endorse or promote products
 *        derived from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *  DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 *  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.*
 */

#ifdef DEBUG
#define DLOG(fmt, args...) NSLog(@"%s:%d "fmt,__FILE__,__LINE__,args)
#else
#define DLOG(fmt, args...)
#endif

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <QTKit/QTKit.h>

void usage() {
    fprintf(stderr, "%s","Usage: tlassemble INPUTDIRECTORY OUTPUTFILENAME [OPTIONS]\n"
            "Try 'tlassemble --help' for more information.\n");
}

void help() {
    printf("%s","\nUsage: tlassemble INPUTDIRECTORY OUTPUTFILENAME [OPTIONS]\n\n"
           "EXAMPLES\n"
           "tlassemble ./images time_lapse.mov\n"
           "tlassemble ./images time_lapse.mov -fps 30 -height 720 -codec h264 -quality high\n"
           "tlassemble ./images time_lapse.mov -quiet yes\n\n"
           "OPTIONS\n"
           "-fps: Frames per second for final movie can be anywhere between 0.1 and 60.0.\n"
           "-height: If specified images are resized proportionally to height given.\n"
           "-codec: Codec to use to encode can be 'h264' 'photojpeg' 'raw' or 'mpv4'.\n"
           "-quality: Quality to encode with can be 'high' 'normal' 'low'.\n"
           "-quiet: Set to 'yes' to suppress output during encoding.\n"
           "-reverse: Set to 'yes' to reverse the order that images are displayed in the movie.\n"
           "\n"
           "DEFAULTS\n"
           "fps = 30\n"
           "height = original image size\n"
           "codec = h264\n"
           "quality = high\n\n"
           "INFO\n"
           "- Images should be no larger than 1920 x 1080 pixels.\n"
           "- Images have to be jpegs and have the extension '.jpg' or '.jpeg' (case insensitive).\n\n"
           "tlassemble 1.0\n\n"
           "This software is provided in the hope that it will be useful, but without any warranty, without even the implied warranty for merchantability or fitness for a particular purpose. The software is provided as is and its designer is not to be held responsible for any lost data or other corruption.\n\n");
}

int main(int argc, const char *argv[]) {
    // Command line options:
    //
    // codec (h264, mp4v, photojpeg, raw)
    // fps (between 0.1 and 60)
    // quality (high, normal, low)
    // width (resize proportionally)
    
    int n;
    
    double height;
    double fps;
    NSString *codecSpec;
    NSString *qualitySpec;
    NSString *destPath;
    NSString *inputPath;
	NSArray *imageFiles;
	NSError *err;
	err = nil;
	BOOL isDir;
    BOOL quiet;
    BOOL reverseArray;
    
    // Parse command line options
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    if (argc == 2) {
        if (strcmp(argv[1], "--help") == 0 ||
            strcmp(argv[1], "-help") == 0) {
            help();
            return 1;
        }
    }
    if (argc < 3) {
        usage();
        return 1;
    }
    
    height = [args doubleForKey:@"height"];
    fps = [args doubleForKey:@"fps"];
    codecSpec = [args stringForKey:@"codec"];
    qualitySpec = [args stringForKey:@"quality"];
    quiet = [args boolForKey:@"quiet"];
    reverseArray = [args boolForKey:@"reverse"];
    
    NSDictionary *codec = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"avc1", @"h264",
                           @"mpv4", @"mpv4",
                           @"jpeg", @"photojpeg",
                           @"raw ", @"raw", nil];
    
    NSDictionary *quality = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithLong:codecLowQuality], @"low",
                             [NSNumber numberWithLong:codecNormalQuality], @"normal",
                             [NSNumber numberWithLong:codecMaxQuality], @"high", nil];
    
    if (height > 1080) {
        fprintf(stderr, "%s",
                "Error: Maximum movie height is 1080px, use option "
                "-height to automatically resize images.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
    }
    
    if (fps == 0.0) {
        fps = 30.0;
    }
    
    if (fps < 0.1 || fps > 60) {
        fprintf(stderr, "%s","Error: Framerate must be between 0.1 and 60 fps.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
    }
    
    if (codecSpec == nil) {
        codecSpec = @"h264";
    }
    
    if (![[codec allKeys] containsObject:codecSpec]) {
        usage();
        return 1;
    }
    
    if (qualitySpec == nil) {
        qualitySpec = @"high";
    }
    
    if ([[quality allKeys] containsObject:qualitySpec] == NO) {
        usage();
        return 1;
    }
    
    DLOG(@"quality: %@",qualitySpec);
    DLOG(@"codec: %@",codecSpec);
    DLOG(@"fps: %f",fps);
    DLOG(@"height: %f",height);
    DLOG(@"quiet: %i", quiet);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    inputPath = [[NSURL fileURLWithPath:[[NSString stringWithUTF8String:argv[1]]
                                         stringByExpandingTildeInPath]] path];
    destPath = [[NSURL fileURLWithPath:[[NSString stringWithUTF8String:argv[2]]
                                        stringByExpandingTildeInPath]] path];
    
    if (![destPath hasSuffix:@".mov"]) {
        fprintf(stderr, "Error: Output filename must be of type '.mov'\n");
        return 1;
    }
    
    if ([fileManager fileExistsAtPath:destPath]) {
        fprintf(stderr, "Error: Output file already exists.\n");
        return 1;
    }
    
    if (!([fileManager fileExistsAtPath:[destPath stringByDeletingLastPathComponent]
                            isDirectory:&isDir] && isDir)) {
        fprintf(stderr,
                "Error: Output file is not writable. "
                "Does the destination directory exist?\n");
        return 1;
    }
    
    DLOG(@"Input Path: %@", inputPath);
    DLOG(@"Destination Path: %@", destPath);
    
    if ((([fileManager fileExistsAtPath:inputPath isDirectory:&isDir] && isDir) &&
         [fileManager isWritableFileAtPath:inputPath]) == NO) {
        fprintf(stderr, "%s","Error: Input directory does not exist.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
	}
    
    NSPredicate *testForImageFile = [NSPredicate predicateWithBlock:^BOOL(id file, NSDictionary *bindings) {
        return [[file pathExtension] caseInsensitiveCompare:@"jpeg"] == NSOrderedSame ||
        [[file pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame ||
        [[file pathExtension] caseInsensitiveCompare:@"jpg"] == NSOrderedSame;
    }];
    
    imageFiles = [fileManager contentsOfDirectoryAtPath:inputPath error:&err];
    imageFiles = [imageFiles filteredArrayUsingPredicate:testForImageFile];
    imageFiles = [imageFiles sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    
    if ([imageFiles count] == 0) {
        fprintf(stderr, "Error: Directory '%s' %s",
                [[inputPath stringByAbbreviatingWithTildeInPath] UTF8String],
                "does not contain any jpeg images.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
    }
    
    if (reverseArray) {
        imageFiles = [[imageFiles reverseObjectEnumerator] allObjects];
    }
    
    NSString *fullFilename;
    int counter = 0;
    
    // BEGIN
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    AVAssetWriterInput *input;
    AVAssetWriter *writer;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    
    for (NSString *file in imageFiles) {
        
        CGSize frameSize;
        CGRect rectangle;
        
        NSLog(@"File name %@.", file);
        
        fullFilename = [inputPath stringByAppendingPathComponent:file];
        
        CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename([fullFilename UTF8String]);
        CGImageRef image = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);
        
        if (counter == 0) {
            
            frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
            rectangle = CGRectMake(0, 0, frameSize.width, frameSize.height);
            
            NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                                      AVVideoCodecH264, AVVideoCodecKey,
                                      [NSNumber numberWithUnsignedLong:frameSize.width], AVVideoWidthKey,
                                      [NSNumber numberWithUnsignedLong:frameSize.height], AVVideoHeightKey,
                                      nil];
            
            writer = [[AVAssetWriter alloc]
                      initWithURL:[NSURL fileURLWithPath:destPath]
                      fileType:AVFileTypeQuickTimeMovie
                      error:&err];
            
            input = [AVAssetWriterInput
                     assetWriterInputWithMediaType:AVMediaTypeVideo
                     outputSettings:settings];
            input.expectsMediaDataInRealTime = YES;
            
            adaptor = [AVAssetWriterInputPixelBufferAdaptor
                       assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                       sourcePixelBufferAttributes:nil];
            
            [writer addInput:input];
            [writer startWriting];
            [writer startSessionAtSourceTime: kCMTimeZero];
        }
        
        CVPixelBufferRef pxbuffer;
        
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            frameSize.width,
                            frameSize.height,
                            kCVPixelFormatType_32ARGB,
                            (__bridge CFDictionaryRef)options,
                            &pxbuffer);
        
        CVPixelBufferLockBaseAddress(pxbuffer, 0);
        
        void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
        
        CGContextRef context = CGBitmapContextCreate(pxdata,
                                                     frameSize.width,
                                                     frameSize.height,
                                                     8,
                                                     4 * frameSize.width,
                                                     rgbColorSpace,
                                                     kCGImageAlphaNoneSkipFirst);
        
        CGContextDrawImage(context, rectangle, image);
        CGColorSpaceRelease(rgbColorSpace);
        CGContextRelease(context);
        
        CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
        
        CMTime frameTime = CMTimeMake(counter, (int32_t) fps);
        
        BOOL append_ok = NO;
        
        while (!append_ok) {
            
            if (adaptor.assetWriterInput.readyForMoreMediaData) {
                
                append_ok = [adaptor appendPixelBuffer:pxbuffer withPresentationTime:frameTime];
                
                if (!append_ok) {
                    
                    NSError *error = writer.error;
                    
                    if (error != nil) {
                        NSLog(@"Unresolved error %@,%@.", error, [error userInfo]);
                        break;
                    }
                }
            }
        }
        counter++;
    }
    
    [input markAsFinished];
    [writer finishWriting];
    
    return 0;
}

