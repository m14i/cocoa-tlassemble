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

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

void usage() {
    fprintf(stderr, "%s","Usage: tlassemble INPUTDIRECTORY OUTPUTFILENAME [OPTIONS]\n"
            "Try 'tlassemble --help' for more information.\n");
}

void help() {
    printf("%s","\nUsage: tlassemble INPUTDIRECTORY OUTPUTFILENAME [OPTIONS]\n\n"
           "EXAMPLES\n"
           "tlassemble ./images time_lapse.mov\n"
           "tlassemble ./images time_lapse.mov -fps 30 -height 720\n\n"
           "OPTIONS\n"
           "-fps: Frames per second for final movie can be anywhere between 0.1 and 60.0.\n"
           "-height: If specified images are resized proportionally to height given.\n"
           "-reverse: Set to 'yes' to reverse the order that images are displayed in the movie.\n"
           "\n"
           "DEFAULTS\n"
           "fps = 30\n"
           "height = original image size\n"
           "INFO\n"
           "- Images should be no larger than 1920 x 1080 pixels.\n"
           "- Images have to be jpegs and have the extension '.jpg' or '.jpeg' (case insensitive).\n\n"
           "tlassemble 1.0\n\n"
           "This software is provided in the hope that it will be useful, but without any warranty, without even the implied warranty for merchantability or fitness for a particular purpose. The software is provided as is and its designer is not to be held responsible for any lost data or other corruption.\n\n");
}


int main(int argc, const char *argv[]) {
    
    NSInteger height;
    NSInteger fps;
    
    NSString *destPath;
    NSString *inputPath;
	NSArray *imageFiles;
	NSError *err = nil;
    
	BOOL isDir;
    BOOL reverseArray;
    
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
    
    height = [args integerForKey:@"height"];
    fps = [args integerForKey:@"fps"];
    reverseArray = [args boolForKey:@"reverse"];
    
    if (height > 1080) {
        fprintf(stderr, "%s",
                "Error: Maximum movie height is 1080px, use option "
                "-height to automatically resize images.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
    }
    
    if (fps == 0) {
        fps = 30;
    }
    
    if (fps < 1 || fps > 60) {
        fprintf(stderr, "%s","Error: Framerate must be between 1 and 60 fps.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
    }
    
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
    
    NSInteger numImages = [imageFiles count];
    
    if (numImages == 0) {
        fprintf(stderr, "Error: Directory '%s' %s",
                [[inputPath stringByAbbreviatingWithTildeInPath] UTF8String],
                "does not contain any jpeg images.\n"
                "Try 'tlassemble --help' for more information.\n");
        return 1;
    }
    
    if (reverseArray) {
        imageFiles = [[imageFiles reverseObjectEnumerator] allObjects];
    }
    
    printf("Height: %ld\nFPS:    %ld\nInput:  %s\nOutput: %s\n", height, fps, [inputPath UTF8String], [destPath UTF8String]);
    
    NSString *fullFilename;
    NSInteger counter = 0;
    
    AVAssetWriterInput *input;
    AVAssetWriter *writer;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    
    printf("Working...");
    
    for (NSString *file in imageFiles) {
        
        CGSize frameSize;
        CGRect rectangle;
        
        fullFilename = [inputPath stringByAppendingPathComponent:file];
        
        CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename([fullFilename UTF8String]);
        CGImageRef image = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);
        
        if (counter == 0) {
            
            frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
            rectangle = CGRectMake(0, 0, frameSize.width, frameSize.height);
            
            NSInteger videoWidth = frameSize.width;
            NSInteger videoHeight = frameSize.height;
            
            if (height != 0) {
                
                CGFloat ratio = frameSize.width / frameSize.height;
                videoWidth = ratio * height;
                videoHeight = height;
            }
            
            NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                           AVVideoCodecH264, AVVideoCodecKey,
                                           [NSNumber numberWithUnsignedLong:videoWidth], AVVideoWidthKey,
                                           [NSNumber numberWithUnsignedLong:videoHeight], AVVideoHeightKey,
                                           nil];
            
            NSDictionary *bufferSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey,
                                            [NSNumber numberWithUnsignedLong:frameSize.width], kCVPixelBufferWidthKey,
                                            [NSNumber numberWithUnsignedLong:frameSize.height], kCVPixelBufferHeightKey,
                                            nil];
            
            writer = [[AVAssetWriter alloc]
                      initWithURL:[NSURL fileURLWithPath:destPath]
                      fileType:AVFileTypeQuickTimeMovie
                      error:&err];
            
            input = [AVAssetWriterInput
                     assetWriterInputWithMediaType:AVMediaTypeVideo
                     outputSettings:videoSettings];
            input.expectsMediaDataInRealTime = YES;
            
            adaptor = [AVAssetWriterInputPixelBufferAdaptor
                       assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                       sourcePixelBufferAttributes:bufferSettings];
            
            [writer addInput:input];
            [writer startWriting];
            [writer startSessionAtSourceTime: kCMTimeZero];
        }
        
        CVPixelBufferRef pxbuffer = NULL;
        
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pxbuffer);
        
        if (status != kCVReturnSuccess) {
            NSLog(@"Pixel buffer pool error %d.", status);
            return 1;
        }
        
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
        
        printf(".");
    }
    
    [input markAsFinished];
    [writer finishWriting];
    
    printf("done.\n");
    
    return 0;
}

