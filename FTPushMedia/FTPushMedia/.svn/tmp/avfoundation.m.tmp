/*
 * AVFoundation input device
 * Copyright (c) 2014 Thilo Borgmann <thilo.borgmann@mail.de>
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/**
 * @file
 * AVFoundation input device
 * @author Thilo Borgmann <thilo.borgmann@mail.de>
 */
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#include <pthread.h>

#include "libavutil/pixdesc.h"
#include "libavutil/opt.h"
#include "libavformat/internal.h"
#include "libavutil/internal.h"
#include "libavutil/time.h"
#import "libswscale/swscale.h"
//#include "avdevice.h"
#import "AVCallController.h"

extern AVCallController *ttt;
static const int avf_time_base = 100;

static const AVRational avf_time_base_q = {
    .num = 1,
    .den = avf_time_base
};

struct AVFPixelFormatSpec {
    enum AVPixelFormat ff_id;
    OSType avf_id;
};

static const struct AVFPixelFormatSpec avf_pixel_formats[] = {
    { AV_PIX_FMT_MONOBLACK,    kCVPixelFormatType_1Monochrome },
    { AV_PIX_FMT_RGB555BE,     kCVPixelFormatType_16BE555 },
    { AV_PIX_FMT_RGB555LE,     kCVPixelFormatType_16LE555 },
    { AV_PIX_FMT_RGB565BE,     kCVPixelFormatType_16BE565 },
    { AV_PIX_FMT_RGB565LE,     kCVPixelFormatType_16LE565 },
    { AV_PIX_FMT_RGB24,        kCVPixelFormatType_24RGB },
    { AV_PIX_FMT_BGR24,        kCVPixelFormatType_24BGR },
    { AV_PIX_FMT_0RGB,         kCVPixelFormatType_32ARGB },
    { AV_PIX_FMT_BGR0,         kCVPixelFormatType_32BGRA },//8
    { AV_PIX_FMT_0BGR,         kCVPixelFormatType_32ABGR },
    { AV_PIX_FMT_RGB0,         kCVPixelFormatType_32RGBA },//10
    { AV_PIX_FMT_BGR48BE,      kCVPixelFormatType_48RGB },
    { AV_PIX_FMT_UYVY422,      kCVPixelFormatType_422YpCbCr8 },
    { AV_PIX_FMT_YUVA444P,     kCVPixelFormatType_4444YpCbCrA8R },
    { AV_PIX_FMT_YUVA444P16LE, kCVPixelFormatType_4444AYpCbCr16 },
    { AV_PIX_FMT_YUV444P,      kCVPixelFormatType_444YpCbCr8 },
    { AV_PIX_FMT_YUV422P16,    kCVPixelFormatType_422YpCbCr16 },
    { AV_PIX_FMT_YUV422P10,    kCVPixelFormatType_422YpCbCr10 },
    { AV_PIX_FMT_YUV444P10,    kCVPixelFormatType_444YpCbCr10 },
    { AV_PIX_FMT_YUV420P,      kCVPixelFormatType_420YpCbCr8Planar },//19
    { AV_PIX_FMT_NV12,         kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange },//20
    { AV_PIX_FMT_YUYV422,      kCVPixelFormatType_422YpCbCr8_yuvs },
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
    { AV_PIX_FMT_GRAY8,        kCVPixelFormatType_OneComponent8 },
#endif
    { AV_PIX_FMT_NONE, 0 }
};

//typedef struct
//{
//    AVClass*        class;
//    
//    float           frame_rate;
//    int             frames_captured;
//    int64_t         first_pts;
//    pthread_mutex_t frame_lock;
//    pthread_cond_t  frame_wait_cond;
//    id              avf_delegate;
//    
//    int             list_devices;
//    int             video_device_index;
//    enum AVPixelFormat pixel_format;
//    
//    AVCaptureSession         *capture_session;
//    AVCaptureVideoDataOutput *video_output;
//    CMSampleBufferRef         current_frame;
//} AVFContext;

static void lock_frames(AVFContext* ctx)
{
    pthread_mutex_lock(&ctx->frame_lock);
}

static void unlock_frames(AVFContext* ctx)
{
    pthread_mutex_unlock(&ctx->frame_lock);
}




UIImage* CVImageBufferRef2UIImage(CVImageBufferRef imageBuffer){
#if 1
    //    CVImageBufferRef imageBuffer =  CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);
    
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgbColorSpace);
    
    NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
    image = [UIImage imageWithData:imageData];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return image;
#else
    
    
    //    CVImageBufferRef imageBuffer =  CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);
    
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgbColorSpace);
    
    NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
    image = [UIImage imageWithData:imageData];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return image;
#endif
    
}

CVPixelBufferRef pixelBufferFromCGImage(CGImageRef image)
{
#if 0
    NSLog(@"imageFromSampleBuffer: called");
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
#else
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (CFDictionaryRef) options,
                                          &pxbuffer);
    //    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
                                                 frameSize.height, 8, 4*frameSize.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipLast);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
#endif
}
/** FrameReciever class - delegate for AVCaptureSession
 */
@interface AVFFrameReceiver : NSObject
{
    AVFContext* _context;
}

- (id)initWithContext:(AVFContext*)context;

- (void)  captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)videoFrame
         fromConnection:(AVCaptureConnection *)connection;

- (void)imageTes:(CMSampleBufferRef)videoFrame;
@end

@implementation AVFFrameReceiver

- (id)initWithContext:(AVFContext*)context
{
    if (self = [super init]) {
        _context = context;
    }
    return self;
}

- (UIImage*)CVPixelBufferRef2UIImage:(CMSampleBufferRef)videoFrame{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoFrame);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];
    
    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
    return uiImage;
}

- (void)imageTes:(CMSampleBufferRef)videoFrame{
    [self performSelectorOnMainThread:@selector(imageLoad:) withObject:videoFrame waitUntilDone:NO];
}

- (void)imageLoad:(CMSampleBufferRef)videoFrame{
    ttt.imageVIew.image = [self CVPixelBufferRef2UIImage:videoFrame];
}

- (void)  captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)videoFrame
         fromConnection:(AVCaptureConnection *)connection
#if 0
{
    
    // sampleBuffer now contains an individual frame of raw video frames
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoFrame);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // access the data
    int width = CVPixelBufferGetWidth(pixelBuffer);
    int height = CVPixelBufferGetHeight(pixelBuffer);
    int bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    
    // Convert the raw pixel base to h.264 format
    AVCodec *codec = 0;
    AVCodecContext *context = 0;
    AVFrame *frame = 0;
    AVPacket packet;
    
    //avcodec_init();
    avcodec_register_all();
    codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    
    if (codec == 0) {
        NSLog(@"Codec not found!!");
        return;
    }
    
    context = avcodec_alloc_context3(codec);
    
    if (!context) {
        NSLog(@"Context no bueno.");
        return;
    }
    
    // Bit rate
    context->bit_rate = 400000; // HARD CODE
    context->bit_rate_tolerance = 10;
    // Resolution
    context->width = width;
    context->height = height;
    // Frames Per Second
    context->time_base = (AVRational) {1,25};
    context->gop_size = 1;
    //context->max_b_frames = 1;
    context->pix_fmt = PIX_FMT_YUV420P;
    
    // Open the codec
    if (avcodec_open2(context, codec, 0) < 0) {
        NSLog(@"Unable to open codec");
        return;
    }
    
    
    // Create the frame
    frame = avcodec_alloc_frame();
    if (!frame) {
        NSLog(@"Unable to alloc frame");
        return;
    }
    frame->format = context->pix_fmt;
    frame->width = context->width;
    frame->height = context->height;
    
    
    avpicture_fill((AVPicture *) frame, rawPixelBase, context->pix_fmt, frame->width, frame->height);
    
    int got_output = 0;
    av_init_packet(&packet);
    avcodec_encode_video2(context, &packet, frame, &got_output);
    
    // Unlock the pixel data
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    // Send the data over the network
    [self uploadData:[NSData dataWithBytes:packet.data length:packet.size] toRTMP:self.rtmp_OutVideoStream];
}
#else
{
    //    [self imageTes:videoFrame];
    //    [self performSelectorOnMainThread:@selector(imageLoad:) withObject:videoFrame waitUntilDone:NO];
    //    NSLog(@"....................");
    lock_frames(_context);
    
    if (_context->current_frame != nil) {
        CFRelease(_context->current_frame);
    }
    
    //    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(videoFrame);
    //    UIImage *image = CVImageBufferRef2UIImage(image_buffer);
    
    //    [self performSelectorOnMainThread:@selector(imageLoad:) withObject:pixelBuffer waitUntilDone:NO];
    //    NSLog(@"im : %@", videoFrame);
    _context->current_frame = (CMSampleBufferRef)CFRetain(videoFrame);
    
    
    pthread_cond_signal(&_context->frame_wait_cond);
    
    unlock_frames(_context);
    
    ++_context->frames_captured;
    //    NSLog(@"....................end");
}
#endif
- (void)dealloc{
    [super dealloc];
}
@end
static void destroy_context(AVFContext* ctx)
{
    [ctx->capture_session stopRunning];
    
    [ctx->capture_session release];
    [ctx->video_output    release];
    [ctx->avf_delegate    release];
    
    ctx->capture_session = NULL;
    ctx->video_output    = NULL;
    ctx->avf_delegate    = NULL;
    
    pthread_mutex_destroy(&ctx->frame_lock);
    pthread_cond_destroy(&ctx->frame_wait_cond);
    
    if (ctx->current_frame) {
        CFRelease(ctx->current_frame);
    }
}

static int avf_read_header(AVFormatContext *s)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    AVFContext *ctx         = (AVFContext*)s->priv_data;
    ctx->first_pts          = av_gettime();
    
    pthread_mutex_init(&ctx->frame_lock, NULL);
    pthread_cond_init(&ctx->frame_wait_cond, NULL);
    
    // List devices if requested
    if (ctx->list_devices) {
        av_log(ctx, AV_LOG_INFO, "AVFoundation video devices:\n");
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            const char *name = [[device localizedName] UTF8String];
            int index  = [devices indexOfObject:device];
            av_log(ctx, AV_LOG_INFO, "[%d] %s\n", index, name);
        }
        goto fail;
    }
    
    // Find capture device
    AVCaptureDevice *video_device = nil;
    
    // check for device index given in filename
    if (ctx->video_device_index == -1) {
        sscanf(s->filename, "%d", &ctx->video_device_index);
    }
    
    if (ctx->video_device_index >= 0) {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        if (ctx->video_device_index >= [devices count]) {
            av_log(ctx, AV_LOG_ERROR, "Invalid device index\n");
            goto fail;
        }
        
        video_device = [devices objectAtIndex:ctx->video_device_index];
    } else if (strncmp(s->filename, "",        1) &&
               strncmp(s->filename, "default", 7)) {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        for (AVCaptureDevice *device in devices) {
            if (!strncmp(s->filename, [[device localizedName] UTF8String], strlen(s->filename))) {
                video_device = device;
                break;
            }
        }
        
        if (!video_device) {
            av_log(ctx, AV_LOG_ERROR, "Video device not found\n");
            goto fail;
        }
    } else {
        video_device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeMuxed];
    }
    
    // Video capture device not found, looking for AVMediaTypeVideo
    if (!video_device) {
        video_device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        //获取前置摄像头设备
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in cameras)
        {
            if (device.position == AVCaptureDevicePositionFront){
                video_device = device;
                break;
            }
        }
        
        if (!video_device) {
            av_log(s, AV_LOG_ERROR, "No AV capture device found\n");
            goto fail;
        }
    }
    
    NSString* dev_display_name = [video_device localizedName];
    av_log(s, AV_LOG_DEBUG, "'%s' opened\n", [dev_display_name UTF8String]);
    
    // Initialize capture session
    ctx->capture_session = [[AVCaptureSession alloc] init];
    ctx->capture_session.sessionPreset = AVCaptureSessionPresetLow;
    
    NSError *error = nil;
    AVCaptureDeviceInput* capture_dev_input = [[[AVCaptureDeviceInput alloc] initWithDevice:video_device error:&error] autorelease];
    
    if (!capture_dev_input) {
        av_log(s, AV_LOG_ERROR, "Failed to create AV capture input device: %s\n",
               [[error localizedDescription] UTF8String]);
        goto fail;
    }
    
    if (!capture_dev_input) {
        av_log(s, AV_LOG_ERROR, "Failed to add AV capture input device to session: %s\n",
               [[error localizedDescription] UTF8String]);
        goto fail;
    }
    
    if ([ctx->capture_session canAddInput:capture_dev_input]) {
        [ctx->capture_session addInput:capture_dev_input];
    } else {
        av_log(s, AV_LOG_ERROR, "can't add video input to capture session\n");
        goto fail;
    }
    
    // Attaching output
    ctx->video_output = [[AVCaptureVideoDataOutput alloc] init];
    //    for (NSNumber *pxl_fmt in [ctx->video_output availableVideoCVPixelFormatTypes]) {
    //        if ([pxl_fmt intValue] == AV_PIX_FMT_YUV420P){
    //            NSLog(@"%x : %x", [pxl_fmt intValue], AV_PIX_FMT_YUV420P);
    //        }
    //    }
    if (!ctx->video_output) {
        av_log(s, AV_LOG_ERROR, "Failed to init AV video output\n");
        goto fail;
    }
    
    // select pixel format
    struct AVFPixelFormatSpec pxl_fmt_spec;
    pxl_fmt_spec.ff_id = AV_PIX_FMT_NONE;
    
    for (int i = 0; avf_pixel_formats[i].ff_id != AV_PIX_FMT_NONE; i++) {
        if (ctx->pixel_format == avf_pixel_formats[i].ff_id) {
            pxl_fmt_spec = avf_pixel_formats[i];
            break;
        }
    }
    
    // check if selected pixel format is supported by AVFoundation
    if (pxl_fmt_spec.ff_id == AV_PIX_FMT_NONE) {
        av_log(s, AV_LOG_ERROR, "Selected pixel format (%s) is not supported by AVFoundation.\n",
               av_get_pix_fmt_name(pxl_fmt_spec.ff_id));
        goto fail;
    }
    
    // check if the pixel format is available for this device
    if ([[ctx->video_output availableVideoCVPixelFormatTypes] indexOfObject:[NSNumber numberWithInt:pxl_fmt_spec.avf_id]] == NSNotFound) {
        av_log(s, AV_LOG_ERROR, "Selected pixel format (%s) is not supported by the input device.\n",
               av_get_pix_fmt_name(pxl_fmt_spec.ff_id));
        
        pxl_fmt_spec.ff_id = AV_PIX_FMT_NONE;
        
        av_log(s, AV_LOG_ERROR, "Supported pixel formats:\n");
        for (NSNumber *pxl_fmt in [ctx->video_output availableVideoCVPixelFormatTypes]) {
            struct AVFPixelFormatSpec pxl_fmt_dummy;
            pxl_fmt_dummy.ff_id = AV_PIX_FMT_NONE;
            for (int i = 0; avf_pixel_formats[i].ff_id != AV_PIX_FMT_NONE; i++) {
                if ([pxl_fmt intValue] == avf_pixel_formats[i].avf_id) {
                    pxl_fmt_dummy = avf_pixel_formats[i];
                    break;
                }
            }
            
            if (pxl_fmt_dummy.ff_id != AV_PIX_FMT_NONE) {
                av_log(s, AV_LOG_ERROR, "  %s\n", av_get_pix_fmt_name(pxl_fmt_dummy.ff_id));
                
                // select first supported pixel format instead of user selected (or default) pixel format
                if (pxl_fmt_spec.ff_id == AV_PIX_FMT_NONE) {
                    pxl_fmt_spec = pxl_fmt_dummy;
                }
            }
        }
        
        // fail if there is no appropriate pixel format or print a warning about overriding the pixel format
        if (pxl_fmt_spec.ff_id == AV_PIX_FMT_NONE) {
            goto fail;
        } else {
            av_log(s, AV_LOG_WARNING, "Overriding selected pixel format to use %s instead.\n",
                   av_get_pix_fmt_name(pxl_fmt_spec.ff_id));
        }
    }
    
    pxl_fmt_spec = avf_pixel_formats[8];
    //    pxl_fmt_spec.ff_id = kCVPixelFormatType_32BGRA;
    //                pxl_fmt_spec = avf_pixel_formats[20];
    //    pxl_fmt_spec = avf_pixel_formats[19];
    //    pxl_fmt_spec.avf_id = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    NSNumber     *pixel_format = [NSNumber numberWithUnsignedInt:pxl_fmt_spec.avf_id]; //kCVPixelFormatType_32BGRA
    NSDictionary *capture_dict = [NSDictionary dictionaryWithObject:pixel_format
                                                             forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    //    NSDictionary *capture_dict = [[NSDictionary alloc] initWithObjectsAndKeys:
    //                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
    //                              nil];
    
    //    capture_dict = [[NSDictionary alloc] initWithObjectsAndKeys:
    //     [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
    //     nil];
    
    [ctx->video_output setVideoSettings:capture_dict];
    [ctx->video_output setAlwaysDiscardsLateVideoFrames:YES];
    
    ctx->avf_delegate = [[AVFFrameReceiver alloc] initWithContext:ctx];
    
    dispatch_queue_t queue = dispatch_queue_create("avf_queue", NULL);
    [ctx->video_output setSampleBufferDelegate:ctx->avf_delegate queue:queue];
    dispatch_release(queue);
    
    if ([ctx->capture_session canAddOutput:ctx->video_output]) {
        [ctx->capture_session addOutput:ctx->video_output];
    } else {
        av_log(s, AV_LOG_ERROR, "can't add video output to capture session\n");
        goto fail;
    }
    
    [ctx->capture_session startRunning];
    
    // Take stream info from the first frame.
    while (ctx->frames_captured < 1) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);
    }
    
    lock_frames(ctx);
    
    AVStream* stream = avformat_new_stream(s, NULL);
    
    if (!stream) {
        goto fail;
    }
    
    avpriv_set_pts_info(stream, 64, 1, avf_time_base);
    
    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
    CGSize image_buffer_size      = CVImageBufferGetEncodedSize(image_buffer);
    
    stream->codec->codec_id   = AV_CODEC_ID_H264;
    //        stream->codec->codec_id   = AV_CODEC_ID_FLV1;
    stream->codec->codec_type = AVMEDIA_TYPE_VIDEO;
    stream->codec->width      = (int)image_buffer_size.width;
    stream->codec->height     = (int)image_buffer_size.height;
    stream->codec->pix_fmt    = PIX_FMT_YUV420P;//pxl_fmt_spec.ff_id;
    //        stream->codec->pix_fmt    = pxl_fmt_spec.ff_id;
    
    stream->codec ->qmin = 10;
    stream->codec ->qmax = 51;
    stream->codec ->qcompress = 0.6f;
    
    if(0){
        
        avcodec_register_all();
        av_register_all();
        AVCodec *codec;
        
        codec =avcodec_find_encoder(CODEC_ID_H264);//avcodec_find_encoder_by_name("libx264"); //avcodec_find_encoder(CODEC_ID_H264);//CODEC_ID_H264); AV_CODEC_ID_VP6
        if (!codec) {
            fprintf(stderr, "codec not found\n");
            exit(1);
        }
        /* open it */
        if (avcodec_open2(stream->codec, codec,NULL) < 0) {
            fprintf(stderr, "could not open codec\n");
            exit(1);
        }
    }
    CFRelease(ctx->current_frame);
    ctx->current_frame = nil;
    
    unlock_frames(ctx);
    [pool release];
    return 0;
    
fail:
    [pool release];
    destroy_context(ctx);
    return AVERROR(EIO);
}


static AVCodecContext* AVCodecContextFor(AVFormatContext *s) {
    static AVCodecContext *context;
    if (context) {
        return context;
    }
    // Convert the raw pixel base to h.264 format
    AVCodecContext *deContext = s->streams[0]->codec;
    {
        
        avcodec_register_all();
        av_register_all();
        static AVCodec *codec;
        
        codec =avcodec_find_encoder(CODEC_ID_H264);//avcodec_find_encoder_by_name("libx264"); //avcodec_find_encoder(CODEC_ID_H264);//CODEC_ID_H264); AV_CODEC_ID_VP6
        if (!codec) {
            fprintf(stderr, "codec not found\n");
            exit(1);
        }
        
        context = avcodec_alloc_context3(codec);
        
        avcodec_copy_context(context, deContext);
        
        /* open it */
        if (avcodec_open2(context, codec,NULL) < 0) {
            fprintf(stderr, "could not open codec\n");
            exit(1);
        }
    }
    return context;
}

/*
 [avfoundation @ 0x162c2600] Selected pixel format (yuv420p) is not supported by the input device.
 [avfoundation @ 0x162c2600] Supported pixel formats:
 [avfoundation @ 0x162c2600]   nv12
 [avfoundation @ 0x162c2600]   bgr0
 [avfoundation @ 0x162c2600] Overriding selected pixel format to use nv12 instead.
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [h264 @ 0x162a7a00] no frame!
 [avfoundation @ 0x162c2600] decoding for stream 0 failed
 Output #0, flv, to 'rtmp://172.16.0.28/live/t2':
 Stream #0:0: Video: h264, nv12, 640x480, q=2-31, 200 tbc
 [rtmp @ 0x15e96ee0] Server error: Specified stream not found in call to releaseStream
 [rtmp @ 0x15e96ee0] Server error: call to function _checkbw failed
 [flv @ 0x16aa2a00] Using AVStream.codec.time_base as a timebase hint to the muxer is deprecated. Set AVStream.time_base instead.
 Send        0 video frames to output URL
 Error muxing packet
 [flv @ 0x16aa2a00] Failed to update header with correct duration.
 [flv @ 0x16aa2a00] Failed to update header with correct filesize.
 */
static int avf_read_packet(AVFormatContext *s, AVPacket *pkt)
{
    AVFContext* ctx = (AVFContext*)s->priv_data;
    
    do {
        lock_frames(ctx);
        
        //        [ctx->avf_delegate imageTes:ctx->current_frame];
        CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
        //        {
        //
        //            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
        //            int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        //            switch (pixelFormat) {
        //                case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        //                    //TMEDIA_PRODUCER(producer)->video.chroma = tmedia_nv12; // iPhone 3GS or 4
        //                    NSLog(@"Capture pixel format=NV12");
        //                    break;
        //                case kCVPixelFormatType_422YpCbCr8:
        //                    //TMEDIA_PRODUCER(producer)->video.chroma = tmedia_uyvy422; // iPhone 3
        //                    NSLog(@"Capture pixel format=UYUY422");
        //                    break;
        //                default:
        //                    //                    TMEDIA_PRODUCER(producer)->video.chroma = tmedia_rgb32;
        //                    NSLog(@"Capture pixel format=RGB32");
        //                    break;
        //            }
        //        }
        if (ctx->current_frame != nil) {
            if (0){
                //                av_free_packet(pkt);
                //                AVPacket * p;
                //                if (av_new_packet(p, (int)CVPixelBufferGetDataSize(image_buffer)) < 0) {
                //                    return AVERROR(EIO);
                //                }
                //                av_free_packet(p);
                //
                //                pkt->pts = pkt->dts = av_rescale_q(av_gettime() - ctx->first_pts,
                //                                                   AV_TIME_BASE_Q,
                //                                                   avf_time_base_q);
                //                pkt->stream_index  = 0;
                //                pkt->flags        |= AV_PKT_FLAG_KEY;
                
                CVPixelBufferLockBaseAddress(image_buffer, 0);
                
                void* data = CVPixelBufferGetBaseAddress(image_buffer);
                memcpy(pkt->data, data, pkt->size);
                
                CVPixelBufferUnlockBaseAddress(image_buffer, 0);
            }else{
                
                AVFContext* ctx = (AVFContext*)s->priv_data;
                // sampleBuffer now contains an individual frame of raw video frames
                CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
                
                CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                
                unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
                
                // Convert the raw pixel base to h.264 format
                AVCodecContext *context = AVCodecContextFor(s);
                AVPicture frame;
                // Create the frame
                AVFrame *outpic;
                outpic = av_frame_alloc();
                avpicture_alloc((AVPicture*)outpic, context->pix_fmt, context->width, context->height);
                
                avpicture_fill(&frame, rawPixelBase, PIX_FMT_RGB32, context->width, context->height);
                
                struct SwsContext* fooContext = sws_getContext(context->width, context->height,
                                                               PIX_FMT_RGB32,
                                                               context->width, context->height,
                                                               context->pix_fmt,
                                                               SWS_POINT, NULL, NULL, NULL);
                //
                //
                //                int width = CVPixelBufferGetWidth(pixelBuffer);
                //                int height = CVPixelBufferGetHeight(pixelBuffer);
                //                //                //perform the conversion
                //                frame.data[0]  += frame.linesize[0] * (height - 1);
                //                frame.linesize[0] *= -1;
                //                frame.data[1]  += frame.linesize[1] * (height / 2 - 1);
                //                frame.linesize[1] *= -1;
                //                frame.data[2]  += frame.linesize[2] * (height / 2 - 1);
                //                frame.linesize[2] *= -1;
                
                sws_scale(fooContext,(const uint8_t**)frame.data, frame.linesize, 0, context->height, outpic->data, outpic->linesize);
                
                int got_output = 0;
                pkt->data = NULL;
                pkt->size = 0;
                static int n = 0;
                outpic->pts = n++;
//                do {
                    avcodec_encode_video2(context, pkt, (AVFrame *)outpic, &got_output); //*... handle received packet*/
//                } while(!got_output);
                
                int64_t tt = av_gettime();
                static int64_t oldTt = 0;
                pkt->pts = pkt->dts = av_rescale_q(tt - ctx->first_pts,
                                                   AV_TIME_BASE_Q,
                                                   avf_time_base_q);
                //                pkt->pts = pkt->dts = i++;
                pkt->stream_index  = 0;
                pkt->flags        |= AV_PKT_FLAG_KEY;
                
                pkt->duration = tt - oldTt;
                oldTt = tt;
                
                avpicture_free((AVPicture*)outpic);
                av_frame_free(&outpic);
                //                av_free_packet(pkt);
                sws_freeContext(fooContext);
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                // Send the data over the network
                //        [self uploadData:[NSData dataWithBytes:packet.data length:packet.size] toRTMP:self.rtmp_OutVideoStream];
            }
            
            
            CFRelease(ctx->current_frame);
            ctx->current_frame = nil;
        } else {
            pkt->data = NULL;
            pthread_cond_wait(&ctx->frame_wait_cond, &ctx->frame_lock);
        }
        
        unlock_frames(ctx);
    } while (!pkt->data);
    
    return 0;
}


#if 1
static void avf_read_fill(AVFormatContext *s, AVPacket *pkt){
    
    AVFContext* ctx = (AVFContext*)s->priv_data;
    // sampleBuffer now contains an individual frame of raw video frames
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // access the data
    int width = CVPixelBufferGetWidth(pixelBuffer);
    int height = CVPixelBufferGetHeight(pixelBuffer);
    int bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    
    // Convert the raw pixel base to h.264 format
    AVCodec *codec = 0;
    AVCodecContext *context = 0;
    AVFrame *frame = 0;
    AVPacket packet;
    
    //avcodec_init();
    avcodec_register_all();
    codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    
    if (codec == 0) {
        NSLog(@"Codec not found!!");
        return;
    }
    
    context = avcodec_alloc_context3(codec);
    
    if (!context) {
        NSLog(@"Context no bueno.");
        return;
    }
    
    // Bit rate
    context->bit_rate = 400000; // HARD CODE
    context->bit_rate_tolerance = 10;
    // Resolution
    context->width = width;
    context->height = height;
    // Frames Per Second
    context->time_base = (AVRational) {1,25};
    context->gop_size = 1;
    //context->max_b_frames = 1;
    context->pix_fmt = PIX_FMT_YUV420P;
    
    // Open the codec
    if (avcodec_open2(context, codec, 0) < 0) {
        NSLog(@"Unable to open codec");
        return;
    }
    
    
    // Create the frame
    frame = avcodec_alloc_frame();
    if (!frame) {
        NSLog(@"Unable to alloc frame");
        return;
    }
    frame->format = context->pix_fmt;
    frame->width = context->width;
    frame->height = context->height;
    
    
    avpicture_fill((AVPicture *) frame, rawPixelBase, context->pix_fmt, frame->width, frame->height);
    
    int got_output = 0;
    av_init_packet(&packet);
    avcodec_encode_video2(context, &packet, frame, &got_output);
    
    // Unlock the pixel data
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    // Send the data over the network
    //        [self uploadData:[NSData dataWithBytes:packet.data length:packet.size] toRTMP:self.rtmp_OutVideoStream];
}
#else
void avf_read_CVImageBufferRef(AVFormatContext *s, AVPacket *pkt){
    AVFContext* ctx = (AVFContext*)s->priv_data;
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // access the data
    int width = CVPixelBufferGetWidth(pixelBuffer);
    int height = CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    
    AVFrame *pFrame = avcodec_alloc_frame();
    pFrame->quality = 0;
    AVFrame* outpic = avcodec_alloc_frame();
    
    avpicture_fill((AVPicture*)pFrame, rawPixelBase, PIX_FMT_BGR32, width, height);//PIX_FMT_RGB32//PIX_FMT_RGB8
    
    avcodec_register_all();
    av_register_all();
    
    AVCodec *codec;
    AVCodecContext *c= NULL;
    int  out_size, size, outbuf_size;
    //FILE *f;
    uint8_t *outbuf;
    
    printf("Video encoding\n");
    
    /* find the mpeg video encoder */
    codec =avcodec_find_encoder(CODEC_ID_H264);//avcodec_find_encoder_by_name("libx264"); //avcodec_find_encoder(CODEC_ID_H264);//CODEC_ID_H264);
    
    if (!codec) {
        fprintf(stderr, "codec not found\n");
        exit(1);
    }
    
    c= avcodec_alloc_context3(codec);
    
    /* put sample parameters */
    c->bit_rate = 400000;
    //    c->bit_rate_tolerance = 10;
    //    c->me_method = 2;
    /* resolution must be a multiple of two */
    c->width = 192;//width;//352;
    c->height = 144;//height;//288;
    /* frames per second */
    c->time_base= (AVRational){1,25};
    c->gop_size = 10;//25; /* emit one intra frame every ten frames */
    c->max_b_frames=1;
    c->pix_fmt = PIX_FMT_YUV420P;
    c->thread_count = 1;
    
    //    c ->me_range = 16;
    //    c ->max_qdiff = 4;
    //    c ->qmin = 10;
    //    c ->qmax = 51;
    //    c ->qcompress = 0.6f;
    
    /* open it */
    if (avcodec_open2(c, codec,NULL) < 0) {
        fprintf(stderr, "could not open codec\n");
        exit(1);
    }
    
    /* alloc image and output buffer */
    outbuf_size = 100000;
    outbuf = malloc(outbuf_size);
    size = c->width * c->height;
    AVPacket avpkt;
    
    int nbytes = avpicture_get_size(PIX_FMT_YUV420P, c->width, c->height);
    //create buffer for the output image
    uint8_t* outbuffer = (uint8_t*)av_malloc(nbytes);
    
    fflush(stdout);
    for (int i=0;i<15;++i){
        avpicture_fill((AVPicture*)outpic, outbuffer, PIX_FMT_YUV420P, c->width, c->height);
        
        struct SwsContext* fooContext = sws_getContext(c->width, c->height,
                                                       PIX_FMT_BGR32,
                                                       c->width, c->height,
                                                       PIX_FMT_YUV420P,
                                                       SWS_POINT, NULL, NULL, NULL);
        
        //perform the conversion
        
        pFrame->data[0]  += pFrame->linesize[0] * (height - 1);
        pFrame->linesize[0] *= -1;
        pFrame->data[1]  += pFrame->linesize[1] * (height / 2 - 1);
        pFrame->linesize[1] *= -1;
        pFrame->data[2]  += pFrame->linesize[2] * (height / 2 - 1);
        pFrame->linesize[2] *= -1;
        
        int xx = sws_scale(fooContext,(const uint8_t**)pFrame->data, pFrame->linesize, 0, c->height, outpic->data, outpic->linesize);
        // Here is where I try to convert to YUV
        NSLog(@"xxxxx=====%d",xx);
        
        /* encode the image */
        int got_packet_ptr = 0;
        av_init_packet(&avpkt);
        avpkt.size = outbuf_size;
        avpkt.data = outbuf;
        
        out_size = avcodec_encode_video2(c, &avpkt, outpic, &got_packet_ptr);
        
        printf("encoding frame (size=%5d)\n", out_size);
        printf("encoding frame %s\n", avpkt.data);
        
        fwrite(avpkt.data,1,avpkt.size ,fp);
    }
    
    free(outbuf);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    avcodec_close(c);
    av_free(c);
    av_free(pFrame);
    av_free(outpic);
}
#endif
static int avf_close(AVFormatContext *s)
{
    AVFContext* ctx = (AVFContext*)s->priv_data;
    destroy_context(ctx);
    return 0;
}

static const AVOption options[] = {
    { "frame_rate", "set frame rate", offsetof(AVFContext, frame_rate), AV_OPT_TYPE_FLOAT, { .dbl = 30.0 }, 0.1, 30.0, AV_OPT_TYPE_VIDEO_RATE, NULL },
    { "list_devices", "list available devices", offsetof(AVFContext, list_devices), AV_OPT_TYPE_INT, {.i64=0}, 0, 1, AV_OPT_FLAG_DECODING_PARAM, "list_devices" },
    { "true", "", 0, AV_OPT_TYPE_CONST, {.i64=1}, 0, 0, AV_OPT_FLAG_DECODING_PARAM, "list_devices" },
    { "false", "", 0, AV_OPT_TYPE_CONST, {.i64=0}, 0, 0, AV_OPT_FLAG_DECODING_PARAM, "list_devices" },
    { "video_device_index", "select video device by index for devices with same name (starts at 0)", offsetof(AVFContext, video_device_index), AV_OPT_TYPE_INT, {.i64 = -1}, -1, INT_MAX, AV_OPT_FLAG_DECODING_PARAM },
    { "pixel_format", "set pixel format", offsetof(AVFContext, pixel_format), AV_OPT_TYPE_PIXEL_FMT, {.i64 = AV_PIX_FMT_YUV420P}, 0, INT_MAX, AV_OPT_FLAG_DECODING_PARAM},
    { NULL },
};

static const AVClass avf_class = {
    .class_name = "AVFoundation input device",
    .item_name  = av_default_item_name,
    .option     = options,
    .version    = LIBAVUTIL_VERSION_INT,
    .category   = AV_CLASS_CATEGORY_DEVICE_VIDEO_INPUT,
};

AVInputFormat ff_avfoundation_demuxer = {
    .name           = "avfoundation",
    .long_name      = NULL_IF_CONFIG_SMALL("AVFoundation input device"),
    .priv_data_size = sizeof(AVFContext),
    .read_header    = avf_read_header,
    .read_packet    = avf_read_packet,
    .read_close     = avf_close,
    .flags          = AVFMT_NOFILE,
    .priv_class     = &avf_class,
};