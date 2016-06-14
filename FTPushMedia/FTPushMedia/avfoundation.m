#if 1
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

#import <AVFoundation/AVFoundation.h>
#include <pthread.h>

#include "libavutil/pixdesc.h"
#include "libavutil/opt.h"
#include "libavutil/avstring.h"
#include "libavformat/internal.h"
#include "libavutil/internal.h"
#include "libavutil/time.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"
#import "Utilities.h"
//#include "avdevice.h"

static const int avf_time_base = 1000000;//1000000

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
    { AV_PIX_FMT_BGR0,         kCVPixelFormatType_32BGRA },
    { AV_PIX_FMT_0BGR,         kCVPixelFormatType_32ABGR },
    { AV_PIX_FMT_RGB0,         kCVPixelFormatType_32RGBA },
    { AV_PIX_FMT_BGR48BE,      kCVPixelFormatType_48RGB },
    { AV_PIX_FMT_UYVY422,      kCVPixelFormatType_422YpCbCr8 },
    { AV_PIX_FMT_YUVA444P,     kCVPixelFormatType_4444YpCbCrA8R },
    { AV_PIX_FMT_YUVA444P16LE, kCVPixelFormatType_4444AYpCbCr16 },
    { AV_PIX_FMT_YUV444P,      kCVPixelFormatType_444YpCbCr8 },
    { AV_PIX_FMT_YUV422P16,    kCVPixelFormatType_422YpCbCr16 },
    { AV_PIX_FMT_YUV422P10,    kCVPixelFormatType_422YpCbCr10 },
    { AV_PIX_FMT_YUV444P10,    kCVPixelFormatType_444YpCbCr10 },
    { AV_PIX_FMT_YUV420P,      kCVPixelFormatType_420YpCbCr8Planar },
    { AV_PIX_FMT_NV12,         kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange },
    { AV_PIX_FMT_YUYV422,      kCVPixelFormatType_422YpCbCr8_yuvs },
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
    { AV_PIX_FMT_GRAY8,        kCVPixelFormatType_OneComponent8 },
#endif
    { AV_PIX_FMT_NONE, 0 }
};

typedef struct
{
    AVClass*        class;
    
    int             frames_captured;
    int             audio_frames_captured;
    int64_t         first_pts;
    int64_t         first_audio_pts;
    pthread_mutex_t frame_lock;
    pthread_cond_t  frame_wait_cond;
    id              avf_delegate;
    id              avf_audio_delegate;
    
    int             list_devices;
    int             video_device_index;
    int             video_stream_index;
    int             audio_device_index;
    int             audio_stream_index;
    
    char            *video_filename;
    char            *audio_filename;
    
    int             num_video_devices;
    
    int             audio_channels;
    int             audio_bits_per_sample;
    int             audio_float;
    int             audio_be;
    int             audio_signed_integer;
    int             audio_packed;
    int             audio_non_interleaved;
    
    int32_t         *audio_buffer;
    int             audio_buffer_size;
    
    enum AVPixelFormat pixel_format;
    
    AVCaptureSession         *capture_session;
    AVCaptureVideoDataOutput *video_output;
    AVCaptureAudioDataOutput *audio_output;
    CMSampleBufferRef         current_frame;
    CMSampleBufferRef         current_audio_frame;
    
    //done by zws
    AVCodecContext *audioContext;
    AVCodecContext *videoContext;
    struct SwrContext* swrCtx;
} AVFContext;

static void lock_frames(AVFContext* ctx)
{
    pthread_mutex_lock(&ctx->frame_lock);
}

static void unlock_frames(AVFContext* ctx)
{
    pthread_mutex_unlock(&ctx->frame_lock);
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

@end

@implementation AVFFrameReceiver

- (id)initWithContext:(AVFContext*)context
{
    if (self = [super init]) {
        _context = context;
    }
    return self;
}

- (void)  captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)videoFrame
         fromConnection:(AVCaptureConnection *)connection
{
    lock_frames(_context);
    
    if (_context->current_frame != nil) {
        CFRelease(_context->current_frame);
    }
    
    _context->current_frame = (CMSampleBufferRef)CFRetain(videoFrame);
    
    pthread_cond_signal(&_context->frame_wait_cond);
    
    unlock_frames(_context);
    
    ++_context->frames_captured;
}

@end

/** AudioReciever class - delegate for AVCaptureSession
 */
@interface AVFAudioReceiver : NSObject
{
    AVFContext* _context;
}

- (id)initWithContext:(AVFContext*)context;

- (void)  captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)audioFrame
         fromConnection:(AVCaptureConnection *)connection;

@end

@implementation AVFAudioReceiver

- (id)initWithContext:(AVFContext*)context
{
    if (self = [super init]) {
        _context = context;
    }
    return self;
}

- (void)  captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)audioFrame
         fromConnection:(AVCaptureConnection *)connection
{
    lock_frames(_context);
    
    if (_context->current_audio_frame != nil) {
        CFRelease(_context->current_audio_frame);
    }
    
    _context->current_audio_frame = (CMSampleBufferRef)CFRetain(audioFrame);
    
    pthread_cond_signal(&_context->frame_wait_cond);
    
    unlock_frames(_context);
    
    ++_context->audio_frames_captured;
}

@end


static void destroy_context(AVFContext* ctx)
{
    [ctx->capture_session stopRunning];
    
    [ctx->capture_session release];
    [ctx->video_output    release];
    [ctx->audio_output    release];
    [ctx->avf_delegate    release];
    [ctx->avf_audio_delegate release];
    
    avcodec_free_context(&(ctx->audioContext));
    avcodec_free_context(&(ctx->videoContext));
    swr_free(&(ctx->swrCtx));
    
    ctx->capture_session = NULL;
    ctx->video_output    = NULL;
    ctx->audio_output    = NULL;
    ctx->avf_delegate    = NULL;
    ctx->avf_audio_delegate = NULL;
    ctx->audioContext = NULL;
    ctx->videoContext = NULL;
    ctx->swrCtx = NULL;
    
    av_freep(&ctx->audio_buffer);
    
    pthread_mutex_destroy(&ctx->frame_lock);
    pthread_cond_destroy(&ctx->frame_wait_cond);
    
    if (ctx->current_frame) {
        CFRelease(ctx->current_frame);
    }
}

static void parse_device_name(AVFormatContext *s)
{
    AVFContext *ctx = (AVFContext*)s->priv_data;
    char *tmp = av_strdup(s->filename);
    char *save;
    
    if (tmp[0] != ':') {
        ctx->video_filename = av_strtok(tmp,  ":", &save);
        ctx->audio_filename = av_strtok(NULL, ":", &save);
    } else {
        ctx->audio_filename = av_strtok(tmp,  ":", &save);
    }
}

static int add_video_device(AVFormatContext *s, AVCaptureDevice *video_device)
{
    AVFContext *ctx = (AVFContext*)s->priv_data;
    NSError *error  = nil;
    AVCaptureInput* capture_input = nil;
    
    if (ctx->video_device_index < ctx->num_video_devices) {
        capture_input = (AVCaptureInput*) [[[AVCaptureDeviceInput alloc] initWithDevice:video_device error:&error] autorelease];
    } else {
        capture_input = (AVCaptureInput*) video_device;
    }
    
    if (!capture_input) {
        av_log(s, AV_LOG_ERROR, "Failed to create AV capture input device: %s\n",
               [[error localizedDescription] UTF8String]);
        return 1;
    }
    
    if ([ctx->capture_session canAddInput:capture_input]) {
        [ctx->capture_session addInput:capture_input];
    } else {
        av_log(s, AV_LOG_ERROR, "can't add video input to capture session\n");
        return 1;
    }
    
    // Attaching output
    ctx->video_output = [[AVCaptureVideoDataOutput alloc] init];
    
    if (!ctx->video_output) {
        av_log(s, AV_LOG_ERROR, "Failed to init AV video output\n");
        return 1;
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
        return 1;
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
            return 1;
        } else {
            av_log(s, AV_LOG_WARNING, "Overriding selected pixel format to use %s instead.\n",
                   av_get_pix_fmt_name(pxl_fmt_spec.ff_id));
        }
    }
    
    pxl_fmt_spec = avf_pixel_formats[8];
    ctx->pixel_format          = pxl_fmt_spec.ff_id;
    NSNumber     *pixel_format = [NSNumber numberWithUnsignedInt:pxl_fmt_spec.avf_id];
    NSDictionary *capture_dict = [NSDictionary dictionaryWithObject:pixel_format
                                                             forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
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
        return 1;
    }
    
    return 0;
}

static int add_audio_device(AVFormatContext *s, AVCaptureDevice *audio_device)
{
    AVFContext *ctx = (AVFContext*)s->priv_data;
    NSError *error  = nil;
    AVCaptureDeviceInput* audio_dev_input = [[[AVCaptureDeviceInput alloc] initWithDevice:audio_device error:&error] autorelease];
    
    if (!audio_dev_input) {
        av_log(s, AV_LOG_ERROR, "Failed to create AV capture input device: %s\n",
               [[error localizedDescription] UTF8String]);
        return 1;
    }
    
    if ([ctx->capture_session canAddInput:audio_dev_input]) {
        [ctx->capture_session addInput:audio_dev_input];
    } else {
        av_log(s, AV_LOG_ERROR, "can't add audio input to capture session\n");
        return 1;
    }
    
    // Attaching output
    ctx->audio_output = [[AVCaptureAudioDataOutput alloc] init];
    //   NSDictionary *d = ctx->audio_output->audioSettings;
    if (!ctx->audio_output) {
        av_log(s, AV_LOG_ERROR, "Failed to init AV audio output\n");
        return 1;
    }
    
    ctx->avf_audio_delegate = [[AVFAudioReceiver alloc] initWithContext:ctx];
    
    dispatch_queue_t queue = dispatch_queue_create("avf_audio_queue", NULL);
    [ctx->audio_output setSampleBufferDelegate:ctx->avf_audio_delegate queue:queue];
    dispatch_release(queue);
    
    if ([ctx->capture_session canAddOutput:ctx->audio_output]) {
        [ctx->capture_session addOutput:ctx->audio_output];
    } else {
        av_log(s, AV_LOG_ERROR, "adding audio output to capture session failed\n");
        return 1;
    }
    
    return 0;
}

static int get_video_config(AVFormatContext *s)
{
    AVFContext *ctx = (AVFContext*)s->priv_data;
    
    // Take stream info from the first frame.
    while (ctx->frames_captured < 1) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);
    }
    
    lock_frames(ctx);
    
    AVStream* stream = avformat_new_stream(s, NULL);
    
    if (!stream) {
        return 1;
    }
    
    ctx->video_stream_index = stream->index;
    
    avpriv_set_pts_info(stream, 64, 1, avf_time_base);
    
    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
    CGSize image_buffer_size      = CVImageBufferGetEncodedSize(image_buffer);
    
    //    AVCodecContext* videDecode = videoDecode();
    //    avcodec_copy_context(stream->codec, videDecode);
    {
        //        stream->codec->codec_id   = videDecode->codec_id;//AV_CODEC_ID_RAWVIDEO AV_CODEC_ID_H264
        //        stream->codec->codec_type = videDecode->codec_type;
        //        stream->codec->width      = videDecode->width;
        //        stream->codec->height     = videDecode->height;
        //        //    stream->codec->pix_fmt    = ctx->pixel_format;
        //        stream->codec->pix_fmt    = videDecode->pix_fmt;
        //
        //
        //        stream->codec ->qmin = videDecode->qmin;
        //        stream->codec ->qmax = videDecode->qmax;
        //        stream->codec ->qcompress = videDecode->qcompress;
    }
    
    stream->codec->codec_id   = AV_CODEC_ID_H264;//AV_CODEC_ID_RAWVIDEO AV_CODEC_ID_H264
    stream->codec->codec_type = AVMEDIA_TYPE_VIDEO;
    stream->codec->width      = (int)image_buffer_size.width;
    stream->codec->height     = (int)image_buffer_size.height;
    //    stream->codec->pix_fmt    = ctx->pixel_format;
    stream->codec->pix_fmt    = PIX_FMT_YUV420P;
    
    
    stream->codec ->qmin = 10;
    stream->codec ->qmax = 51;
    stream->codec ->qcompress = 0.6f;
    
    CFRelease(ctx->current_frame);
    ctx->current_frame = nil;
    
    unlock_frames(ctx);
    
    return 0;
}

static int get_audio_config(AVFormatContext *s)
{
    AVFContext *ctx = (AVFContext*)s->priv_data;
    
    // Take stream info from the first frame.
    while (ctx->audio_frames_captured < 1) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);
    }
    
    lock_frames(ctx);
    
    AVStream* stream = avformat_new_stream(s, NULL);
    
    if (!stream) {
        return 1;
    }
    
    ctx->audio_stream_index = stream->index;
    
    avpriv_set_pts_info(stream, 64, 1, avf_time_base);
    
    CMFormatDescriptionRef format_desc = CMSampleBufferGetFormatDescription(ctx->current_audio_frame);
    const AudioStreamBasicDescription *basic_desc = CMAudioFormatDescriptionGetStreamBasicDescription(format_desc);
    
    if (!basic_desc) {
        av_log(s, AV_LOG_ERROR, "audio format not available\n");
        return 1;
    }
    
    
    //    AVCodecContext* videDecode = audioDecode();
    //    AVCodecContext* codec1 = stream->codec;
    //        avcodec_copy_context(stream->codec, videDecode);
    //        stream->codec->extradata = videDecode->extradata;
    //        stream->codec->extradata_size = videDecode->extradata_size;
    
    
    stream->codec->profile = 1;
    stream->codec->bit_rate = 62828; //62828;// 64000 32000
    stream->codec->codec_type     = AVMEDIA_TYPE_AUDIO;
    stream->codec->sample_rate    = basic_desc->mSampleRate;
    stream->codec->channels       = basic_desc->mChannelsPerFrame;
    stream->codec->channel_layout = av_get_default_channel_layout(stream->codec->channels);
    //    stream->codec->channels       = av_get_channel_layout_nb_channels(AV_CH_LAYOUT_MONO);//basic_desc->mChannelsPerFrame;
    //    stream->codec->channel_layout = AV_CH_LAYOUT_MONO;//av_get_default_channel_layout(stream->codec->channels);
    stream->codec->codec_id = AV_CODEC_ID_AAC;//AV_SAMPLE_FMT_FLTP AV_CODEC_ID_AAC AV_CODEC_ID_PCM_F32BE; AV_SAMPLE_FMT_FLTP
    
    ctx->audio_channels        = basic_desc->mChannelsPerFrame;
    ctx->audio_bits_per_sample = basic_desc->mBitsPerChannel;
    //    int dd =  av_get_bytes_per_sample(AV_SAMPLE_FMT_S32)*8;
    ctx->audio_float           = basic_desc->mFormatFlags & kAudioFormatFlagIsFloat;
    ctx->audio_be              = basic_desc->mFormatFlags & kAudioFormatFlagIsBigEndian;
    ctx->audio_signed_integer  = basic_desc->mFormatFlags & kAudioFormatFlagIsSignedInteger;
    ctx->audio_packed          = basic_desc->mFormatFlags & kAudioFormatFlagIsPacked;
    ctx->audio_non_interleaved = basic_desc->mFormatFlags & kAudioFormatFlagIsNonInterleaved;
    {
        //        AVCodecContext *deContext = adioDecode();//音频文件解码器
        //        avcodec_copy_context(stream->codec, deContext);
        //        ctx->audio_channels        = deContext->channels;
        //        ctx->audio_bits_per_sample = deContext->bits_per_raw_sample;
        //        ctx->audio_float           = basic_desc->mFormatFlags & kAudioFormatFlagIsFloat;
        //        ctx->audio_be              = basic_desc->mFormatFlags & kAudioFormatFlagIsBigEndian;
        //        ctx->audio_signed_integer  = basic_desc->mFormatFlags & kAudioFormatFlagIsSignedInteger;
        //        ctx->audio_packed          = basic_desc->mFormatFlags & kAudioFormatFlagIsPacked;
        //        ctx->audio_non_interleaved = basic_desc->mFormatFlags & kAudioFormatFlagIsNonInterleaved;
    }
    //        if (basic_desc->mFormatID == kAudioFormatLinearPCM &&
    //            ctx->audio_float &&
    //            ctx->audio_packed) {
    //            stream->codec->codec_id = ctx->audio_be ? AV_CODEC_ID_PCM_F32BE : AV_CODEC_ID_PCM_F32LE;
    //        } else {
    //            av_log(s, AV_LOG_ERROR, "audio format is not supported\n");
    //            return 1;
    //        }
    
    
    if (ctx->audio_non_interleaved) {
        CMBlockBufferRef block_buffer = CMSampleBufferGetDataBuffer(ctx->current_audio_frame);
        ctx->audio_buffer_size        = CMBlockBufferGetDataLength(block_buffer);
        ctx->audio_buffer             = av_malloc(ctx->audio_buffer_size);
        if (!ctx->audio_buffer) {
            av_log(s, AV_LOG_ERROR, "error allocating audio buffer\n");
            return 1;
        }
    }
    
    CFRelease(ctx->current_audio_frame);
    ctx->current_audio_frame = nil;
    
    unlock_frames(ctx);
    
    return 0;
}

static int AVCodecContextForAudioConfig(AVFormatContext *s) {
    AVFContext* ctx = (AVFContext*)s->priv_data;
    AVCodecContext *deContext = s->streams[ctx->audio_stream_index]->codec;
    avcodec_register_all();
    av_register_all();
    AVCodec *codec;
    
    //        codec =avcodec_find_decoder(AV_CODEC_ID_AAC);//
    codec =avcodec_find_encoder(AV_CODEC_ID_AAC);//
    if (!codec) {
        fprintf(stderr, "codec not found\n");
        return 1;
    }
    ctx->audioContext = avcodec_alloc_context3(codec);
    
    avcodec_copy_context(ctx->audioContext, deContext);
    
    //有三种传输方式：tcp udp_multicast udp，强制采用tcp传输
    
    AVDictionary* options = NULL;
    
    //        av_dict_set(&options, "rtsp_transport", "tcp", 0);
    //                av_dict_set(&options, "experimental", "-strict -2", 0); // add an entry
    //                av_opt_find();
    //                av_dict_set(&options, "strict", "experimental", 0);
    
    //        context->channels = 2;
    ctx->audioContext->sample_fmt = AV_SAMPLE_FMT_FLTP;
    //        context->sample_rate = 48000;
    //        context->bit_rate = 128000;
    //        context->profile = FF_PROFILE_AAC_LTP;
    ctx->audioContext->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    //        context->bit_rate = 62828;
    //        context->bits_per_coded_sample = 16;
    
    /* open it */
    if (avcodec_open2(ctx->audioContext, codec, NULL) < 0) {
        fprintf(stderr, "could not open codec\n");
        av_dict_free(&options);
        return 1;
    }
    return 0;
}

static int AVCodecContextForVideoConfig(AVFormatContext *s) {
    // Convert the raw pixel base to h.264 format
    AVFContext* ctx = (AVFContext*)s->priv_data;
    AVCodecContext *deContext = s->streams[ctx->video_stream_index]->codec;
    {
        
        avcodec_register_all();
        av_register_all();
        AVCodec *codec;
        
        codec =avcodec_find_encoder(CODEC_ID_H264);//avcodec_find_encoder_by_name("libx264"); //avcodec_find_encoder(CODEC_ID_H264);//CODEC_ID_H264); AV_CODEC_ID_VP6
        if (!codec) {
            fprintf(stderr, "codec not found\n");
            return -1;
        }
        
        ctx->videoContext = avcodec_alloc_context3(codec);
        
        avcodec_copy_context(ctx->videoContext, deContext);
        
        /* open it */
        if (avcodec_open2(ctx->videoContext, codec,NULL) < 0) {
            fprintf(stderr, "could not open codec\n");
            return -1;
        }
    }
    return 0;
}

int swrContextConfig(AVFormatContext *s)
{
    BOOL ret = YES;
    
    AVFContext* ctx = (AVFContext*)s->priv_data;
    AVCodecContext* pCodecCtx = ctx->audioContext;
    //    ctx->swrCtx = swr_alloc_set_opts(nil,
    //                                pCodecCtx->channel_layout,
    //                                AV_SAMPLE_FMT_S16,
    //                                pCodecCtx->sample_rate,
    //                                pCodecCtx->channel_layout,
    //                                pCodecCtx->sample_fmt,
    //                                pCodecCtx->sample_rate,
    //                                0,
    //                                nil);
    ctx->swrCtx = swr_alloc_set_opts(nil,
                                     pCodecCtx->channel_layout,
                                     pCodecCtx->sample_fmt,
                                     pCodecCtx->sample_rate,
                                     pCodecCtx->channel_layout,
                                     AV_SAMPLE_FMT_S16,
                                     pCodecCtx->sample_rate,
                                     0,
                                     nil);
    
    if (!ctx->swrCtx || swr_init(ctx->swrCtx) < 0) {
        ret = -1;
    }
    return 0;
}

static int avf_read_header(AVFormatContext *s)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    AVFContext *ctx         = (AVFContext*)s->priv_data;
    ctx->first_pts          = av_gettime();
    ctx->first_audio_pts    = av_gettime();
    ctx->video_device_index = 1;
    ctx->audio_device_index = 0;
    uint32_t num_screens    = 0;
    
    pthread_mutex_init(&ctx->frame_lock, NULL);
    pthread_cond_init(&ctx->frame_wait_cond, NULL);
    
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    CGGetActiveDisplayList(0, NULL, &num_screens);
#endif
    
    // List devices if requested
    if (ctx->list_devices) {
        av_log(ctx, AV_LOG_INFO, "AVFoundation video devices:\n");
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        int index = 0;
        for (AVCaptureDevice *device in devices) {
            const char *name = [[device localizedName] UTF8String];
            index            = [devices indexOfObject:device];
            av_log(ctx, AV_LOG_INFO, "[%d] %s\n", index, name);
            index++;
        }
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
        if (num_screens > 0) {
            CGDirectDisplayID screens[num_screens];
            CGGetActiveDisplayList(num_screens, screens, &num_screens);
            for (int i = 0; i < num_screens; i++) {
                av_log(ctx, AV_LOG_INFO, "[%d] Capture screen %d\n", index + i, i);
            }
        }
#endif
        
        av_log(ctx, AV_LOG_INFO, "AVFoundation audio devices:\n");
        devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
        for (AVCaptureDevice *device in devices) {
            const char *name = [[device localizedName] UTF8String];
            int index  = [devices indexOfObject:device];
            av_log(ctx, AV_LOG_INFO, "[%d] %s\n", index, name);
        }
        goto fail;
    }
    
    // Find capture device
    AVCaptureDevice *video_device = nil;
    AVCaptureDevice *audio_device = nil;
    
    NSArray *video_devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    ctx->num_video_devices = [video_devices count];
    
    // parse input filename for video and audio device
    parse_device_name(s);
    
    // check for device index given in filename
    if (ctx->video_device_index == -1 && ctx->video_filename) {
        sscanf(ctx->video_filename, "%d", &ctx->video_device_index);
    }
    if (ctx->audio_device_index == -1 && ctx->audio_filename) {
        sscanf(ctx->audio_filename, "%d", &ctx->audio_device_index);
    }
    
    if (ctx->video_device_index >= 0) {
        if (ctx->video_device_index < ctx->num_video_devices) {
            video_device = [video_devices objectAtIndex:ctx->video_device_index];
        } else if (ctx->video_device_index < ctx->num_video_devices + num_screens) {
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
            CGDirectDisplayID screens[num_screens];
            CGGetActiveDisplayList(num_screens, screens, &num_screens);
            AVCaptureScreenInput* capture_screen_input = [[[AVCaptureScreenInput alloc] initWithDisplayID:screens[ctx->video_device_index - ctx->num_video_devices]] autorelease];
            video_device = (AVCaptureDevice*) capture_screen_input;
#endif
        } else {
            av_log(ctx, AV_LOG_ERROR, "Invalid device index\n");
            goto fail;
        }
    } else if (ctx->video_filename &&
               strncmp(ctx->video_filename, "none", 4)) {
        if (!strncmp(ctx->video_filename, "default", 7)) {
            video_device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        } else {
            // looking for video inputs
            for (AVCaptureDevice *device in video_devices) {
                if (!strncmp(ctx->video_filename, [[device localizedName] UTF8String], strlen(ctx->video_filename))) {
                    video_device = device;
                    break;
                }
            }
            
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
            // looking for screen inputs
            if (!video_device) {
                int idx;
                if(sscanf(ctx->video_filename, "Capture screen %d", &idx) && idx < num_screens) {
                    CGDirectDisplayID screens[num_screens];
                    CGGetActiveDisplayList(num_screens, screens, &num_screens);
                    AVCaptureScreenInput* capture_screen_input = [[[AVCaptureScreenInput alloc] initWithDisplayID:screens[idx]] autorelease];
                    video_device = (AVCaptureDevice*) capture_screen_input;
                    ctx->video_device_index = ctx->num_video_devices + idx;
                }
            }
#endif
        }
        
        if (!video_device) {
            av_log(ctx, AV_LOG_ERROR, "Video device not found\n");
            goto fail;
        }
    }
    
    // get audio device
    if (ctx->audio_device_index >= 0) {
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
        
        if (ctx->audio_device_index >= [devices count]) {
            av_log(ctx, AV_LOG_ERROR, "Invalid audio device index\n");
            goto fail;
        }
        
        audio_device = [devices objectAtIndex:ctx->audio_device_index];
    } else if (ctx->audio_filename &&
               strncmp(ctx->audio_filename, "none", 4)) {
        if (!strncmp(ctx->audio_filename, "default", 7)) {
            audio_device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        } else {
            NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
            
            for (AVCaptureDevice *device in devices) {
                if (!strncmp(ctx->audio_filename, [[device localizedName] UTF8String], strlen(ctx->audio_filename))) {
                    audio_device = device;
                    break;
                }
            }
        }
        
        if (!audio_device) {
            av_log(ctx, AV_LOG_ERROR, "Audio device not found\n");
            goto fail;
        }
    }
    
    
    // Video nor Audio capture device not found, looking for AVMediaTypeVideo/Audio
    if (!video_device && !audio_device) {
        av_log(s, AV_LOG_ERROR, "No AV capture device found\n");
        goto fail;
    }
    
    if (video_device) {
        if (ctx->video_device_index < ctx->num_video_devices) {
            av_log(s, AV_LOG_DEBUG, "'%s' opened\n", [[video_device localizedName] UTF8String]);
        } else {
            av_log(s, AV_LOG_DEBUG, "'%s' opened\n", [[video_device description] UTF8String]);
        }
    }
    if (audio_device) {
        av_log(s, AV_LOG_DEBUG, "audio device '%s' opened\n", [[audio_device localizedName] UTF8String]);
    }
    
    // Initialize capture session
    ctx->capture_session = [[AVCaptureSession alloc] init];
    ctx->capture_session.sessionPreset = AVCaptureSessionPresetLow;
#define DebugFFmpeg
    //#define Alone_Video
    //#define Alone_Audio
#ifndef Alone_Audio
    if (video_device && add_video_device(s, video_device)) {
        goto fail;
    }
#endif
#ifndef Alone_Video
    if (audio_device && add_audio_device(s, audio_device)) {
    }
#endif
    [ctx->capture_session startRunning];
    
#ifndef Alone_Audio
    
    if (video_device && get_video_config(s)) {
        goto fail;
    }
    
    if (AVCodecContextForVideoConfig(s)) {
        goto fail;
    }
#endif
    // set audio stream
#ifndef Alone_Video
    if (audio_device && get_audio_config(s)) {
        goto fail;
    }
    if (AVCodecContextForAudioConfig(s)) {
        goto fail;
    }
    if (swrContextConfig(s)) {
        goto fail;
    }
#endif
    [pool release];
    return 0;
    
fail:
    [pool release];
    destroy_context(ctx);
    return AVERROR(EIO);
}

static int avf_read_packet(AVFormatContext *s, AVPacket *pkt)
{
    AVFContext* ctx = (AVFContext*)s->priv_data;
    
    do {
        lock_frames(ctx);
        
        if (ctx->current_frame != nil) {
            {
                //                AVFContext* ctx = (AVFContext*)s->priv_data;
                // sampleBuffer now contains an individual frame of raw video frames
                CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(ctx->current_frame);
                
                CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                
                unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
                
                // Convert the raw pixel base to h.264 format
                //                AVCodecContext *context = AVCodecContextFor(s);
                AVCodecContext *context = ctx->videoContext;
                AVPicture outpic;
                
                
                avpicture_fill(&outpic, rawPixelBase, PIX_FMT_RGB32, context->width, context->height);
                
                struct SwsContext* fooContext = sws_getContext(context->width, context->height,
                                                               PIX_FMT_RGB32,
                                                               context->width, context->height,
                                                               context->pix_fmt,
                                                               SWS_POINT, NULL, NULL, NULL);
                
                
                // Create the frame
                AVFrame *frame;
                frame = av_frame_alloc();
                avpicture_alloc((AVPicture*)frame, context->pix_fmt, context->width, context->height);
                
                sws_scale(fooContext,(const uint8_t**)outpic.data, outpic.linesize, 0, context->height, frame->data, frame->linesize);
                
                int got_output = 0;
                pkt->data = NULL;
                pkt->size = 0;
                static int n = 0;
                frame->pts = n++;
//                n = n + 30;
//                                do {
                avcodec_encode_video2(context, pkt, frame, &got_output); //*... handle received packet*/
//                                } while(!got_output);
                
                int64_t tt = av_gettime();
                static int64_t oldTt = 0;
                if (oldTt == 0) {
                    oldTt = tt;
                }
                /*
                 2016-04-11 11:39:42.520 FTPushMedia[6299:60b] <FMDatabase: 0x165a84d0> executeQuery: select * from history where path=?
                 2016-04-11 11:39:42.521 FTPushMedia[6299:60b] obj: rtmp://172.16.0.83/live/t4
                 2016-04-11 11:39:42.825 FTPushMedia[6299:60b] We've got 2 output channels
                 2016-04-11 11:39:42.827 FTPushMedia[6299:60b] Current sampling rate: 44100.000000
                 2016-04-11 11:39:42.830 FTPushMedia[6299:60b] Current output volume: 0.750000
                 2016-04-11 11:39:42.833 FTPushMedia[6299:8407] We've got 2 output channels
                 2016-04-11 11:39:42.836 FTPushMedia[6299:60b] Current output bytes per sample: 4
                 2016-04-11 11:39:42.837 FTPushMedia[6299:60b] Current output num channels: 2
                 2016-04-11 11:39:42.838 FTPushMedia[6299:8407] Current sampling rate: 44100.000000
                 2016-04-11 11:39:42.839 FTPushMedia[6299:8407] Current output volume: 0.750000
                 [rtmp @ 0x165b9d00] Handshaking...
                 [rtmp @ 0x165b9d00] Type answer 3
                 [rtmp @ 0x165b9d00] Server version 0.0.0.0
                 [rtmp @ 0x165b9d00] Proto = rtmp, path = /live/t4, app = live, fname = t4
                 [rtmp @ 0x165b9d00] Server bandwidth = 2500000
                 [rtmp @ 0x165b9d00] Client bandwidth = 2500000
                 [rtmp @ 0x165b9d00] Creating stream...
                 [rtmp @ 0x165b9d00] Sending play command for 't4'
                 [libx264 @ 0x172afe00] frame=  39 QP=23.69 NAL=2 Slice:P Poc:6   I:3    P:51   SKIP:54   size=184 bytes
                 Send       39 video frames to output URL pts 5956, dts 5956 duration 503
                 */
                //                pkt->pts = pkt->dts = AV_NOPTS_VALUE;
                pkt->pts = pkt->dts = av_rescale_q(tt - ctx->first_pts,
                                                   AV_TIME_BASE_Q,
                                                   avf_time_base_q);
                //                pkt->pts = pkt->dts = i++;
                pkt->stream_index  = ctx->video_stream_index;
                pkt->flags        |= AV_PKT_FLAG_KEY;
                
                pkt->duration = (int)(tt - oldTt);
                oldTt = tt;
                
                //                avpicture_free(&frame);
                avpicture_free((AVPicture*)frame);
                av_frame_free(&frame);
                //                av_free_packet(pkt);
                sws_freeContext(fooContext);
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            }
            
            CFRelease(ctx->current_frame);
            ctx->current_frame = nil;
        } else if (ctx->current_audio_frame != nil){
            CMBlockBufferRef block_buffer = CMSampleBufferGetDataBuffer(ctx->current_audio_frame);
            
            if (ctx->audio_non_interleaved) {
                int sample, c, shift;
                
                OSStatus ret = CMBlockBufferCopyDataBytes(block_buffer, 0, pkt->size, ctx->audio_buffer);
                if (ret != kCMBlockBufferNoErr) {
                    return AVERROR(EIO);
                }
                
                int num_samples = pkt->size / (ctx->audio_channels * (ctx->audio_bits_per_sample >> 3));
                
                // transform decoded frame into output format
#define INTERLEAVE_OUTPUT(bps)                                         \
{                                                                      \
int##bps##_t **src;                                                \
int##bps##_t *dest;                                                \
src = av_malloc(ctx->audio_channels * sizeof(int##bps##_t*));      \
if (!src) return AVERROR(EIO);                                     \
for (c = 0; c < ctx->audio_channels; c++) {                        \
src[c] = ((int##bps##_t*)ctx->audio_buffer) + c * num_samples; \
}                                                                  \
dest  = (int##bps##_t*)pkt->data;                                  \
shift = bps - ctx->audio_bits_per_sample;                          \
for (sample = 0; sample < num_samples; sample++)                   \
for (c = 0; c < ctx->audio_channels; c++)                      \
*dest++ = src[c][sample] << shift;                         \
av_freep(&src);                                                    \
}
                
                if (ctx->audio_bits_per_sample <= 16) {
                    INTERLEAVE_OUTPUT(16)
                } else {
                    INTERLEAVE_OUTPUT(32)
                }
            } else {
                
#if 1
                
                uint8_t *samples = NULL;
                AVFrame* aframe;
                //                AVCodecContextForAudioConfig(s);
                AVCodecContext* pCodecCtx = ctx->audioContext;
                //                AVCodecContext* pCodecCtx = AVCodecContextForAudio(s);
                int size;
                
                aframe = av_frame_alloc();  //AVFrame *aframe;
                int ret;
                
                CMBlockBufferRef audioBlockBuffer = CMSampleBufferGetDataBuffer(ctx->current_audio_frame);
                
                
                size_t lengthAtOffset = 0;
                
                size_t totalLength = 0;
                
                
                CMBlockBufferGetDataPointer(audioBlockBuffer, 0, &lengthAtOffset, &totalLength, (char **)(&samples));
                
                const AudioStreamBasicDescription *audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(ctx->current_audio_frame));
                assert(audioDescription->mFormatID == kAudioFormatLinearPCM);
                aframe->nb_samples = pCodecCtx->frame_size;
                aframe->format= pCodecCtx->sample_fmt;
                aframe->channel_layout = pCodecCtx->channel_layout;
                aframe->channels=pCodecCtx->channels;
                aframe->sample_rate=(int)audioDescription->mSampleRate;
                
                
                
                uint8_t* frame_buf;
                size = av_samples_get_buffer_size(NULL, pCodecCtx->channels,pCodecCtx->frame_size,pCodecCtx->sample_fmt, 0);
                //
                frame_buf = av_mallocz(size);
                //                av_malloc(<#size_t size#>)
                //my webCamera configured to produce 16bit 16kHz LPCM mono, so sample format hardcoded here, and seems to be correct
                avcodec_fill_audio_frame(aframe, aframe->channels, pCodecCtx->sample_fmt,
                                         (uint8_t *)frame_buf,
                                         size,
                                         0);
                
                if (pCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLTP){
                    struct SwrContext* swrCtx = ctx->swrCtx;
                    int ret = swr_convert(swrCtx, aframe->extended_data, aframe->nb_samples, (const uint8_t**)&samples, aframe->nb_samples);
                    if (ret < 0)
                        return 0;
                } else {
                    memcpy(samples,aframe->data[0],size);
                }
                
                int got_frame=0;
                
                do{
                    ret = avcodec_encode_audio2(pCodecCtx, pkt, aframe, &got_frame);
                }while (!got_frame);
                int64_t tt = av_gettime();
                static int64_t oldTt = 0;
                if (oldTt == 0) {
                    oldTt = tt;
                }
                //                pkt->pts = pkt->dts = AV_NOPTS_VALUE;
                pkt->pts = pkt->dts = av_rescale_q(tt - ctx->first_audio_pts,
                                                   AV_TIME_BASE_Q,
                                                   avf_time_base_q);
                
                
                //                pkt->pts = pkt->dts = i++;
                pkt->flags        |= AV_PKT_FLAG_KEY;
                
                pkt->duration = (int)(tt - oldTt);
                oldTt = tt;
                
                pkt->stream_index  = ctx->audio_stream_index;
                
                av_free(frame_buf);
                av_frame_free(&aframe);
#else
                OSStatus ret = CMBlockBufferCopyDataBytes(block_buffer, 0, pkt->size, pkt->data);
                if (ret != kCMBlockBufferNoErr) {
                    return AVERROR(EIO);
                }
#endif
            }
            
            CFRelease(ctx->current_audio_frame);
            ctx->current_audio_frame = nil;
        }else {
            pkt->data = NULL;
            pthread_cond_wait(&ctx->frame_wait_cond, &ctx->frame_lock);
        }
        
        unlock_frames(ctx);
    } while (!pkt->data);
    
    return 0;
}

static int avf_close(AVFormatContext *s)
{
    AVFContext* ctx = (AVFContext*)s->priv_data;
    destroy_context(ctx);
    return 0;
}

static const AVOption options[] = {
    { "list_devices", "list available devices", offsetof(AVFContext, list_devices), AV_OPT_TYPE_INT, {.i64=0}, 0, 1, AV_OPT_FLAG_DECODING_PARAM, "list_devices" },
    { "true", "", 0, AV_OPT_TYPE_CONST, {.i64=1}, 0, 0, AV_OPT_FLAG_DECODING_PARAM, "list_devices" },
    { "false", "", 0, AV_OPT_TYPE_CONST, {.i64=0}, 0, 0, AV_OPT_FLAG_DECODING_PARAM, "list_devices" },
    { "video_device_index", "select video device by index for devices with same name (starts at 0)", offsetof(AVFContext, video_device_index), AV_OPT_TYPE_INT, {.i64 = -1}, -1, INT_MAX, AV_OPT_FLAG_DECODING_PARAM },
    { "audio_device_index", "select audio device by index for devices with same name (starts at 0)", offsetof(AVFContext, audio_device_index), AV_OPT_TYPE_INT, {.i64 = -1}, -1, INT_MAX, AV_OPT_FLAG_DECODING_PARAM },
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

AVInputFormat ff_avfoundation_demuxer_zws = {
    .name           = "avfoundation",
    .long_name      = NULL_IF_CONFIG_SMALL("AVFoundation input device"),
    .priv_data_size = sizeof(AVFContext),
    .read_header    = avf_read_header,
    .read_packet    = avf_read_packet,
    .read_close     = avf_close,
    .flags          = AVFMT_NOFILE,
    .priv_class     = &avf_class,
};
#endif


