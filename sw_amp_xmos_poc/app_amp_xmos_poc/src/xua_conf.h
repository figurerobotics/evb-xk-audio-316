// Copyright 2017-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef _XUA_CONF_H_
#define _XUA_CONF_H_

// Build parameters
//#define DEBUG

// Audio parameters
#ifdef DEBUG
#define NUM_USB_CHAN_OUT      4     /* Number of channels from host to device */
#define NUM_USB_CHAN_IN       8     /* Number of channels from device to host */
#else
#define NUM_USB_CHAN_OUT      1     /* Number of channels from host to device */
#define NUM_USB_CHAN_IN       4     /* Number of channels from device to host */
#endif

#define I2S_STREAMS           1
#define I2S_CHANS_PER_STREAM  2
#define I2S_CHANS_DAC         I2S_STREAMS*I2S_CHANS_PER_STREAM     /* Number of I2S channels out of xCORE */

#define I2S_CHANS_ADC         0     /* Number of I2S channels in to xCORE */
#define XUA_NUM_PDM_MICS      8
#define MCLK_441  (512 * 44100)     /* 44.1kHz family master clock frequency */
#define MCLK_48   (512 * 48000)     /* 48kHz family master clock frequency */
#define MIN_FREQ  48000             /* Minimum sample rate */
#define MAX_FREQ  48000             /* Maximum sample rate */

// USB parameters
#ifdef DEBUG
#define AUDIO_CLASS 2
#else
#define AUDIO_CLASS 2
#endif
#define VENDOR_STR      "ALG"
#define VENDOR_ID       0x20B1      /* Update once assigned by USB-IF */
#define PRODUCT_STR_A2  "AMPLIFY AUDIO 2"
#define PRODUCT_STR_A1  "AMPLIFY AUDIO 1"
#define PID_AUDIO_1     7
#define PID_AUDIO_2     8
#define XUA_DFU_EN      0           /* Disable DFU (for simplicity of example */
#define XUA_SYNCMODE XUA_SYNCMODE_ASYNC

// XMOS parameters
#define MIC_DUAL_ENABLED 0          // Use multi-threaded design
#define AUDIO_IO_TILE 1
#define EXCLUDE_USB_AUDIO_MAIN

#define XUD_UAC_NUM_USB_CHAN_OUT    NUM_USB_CHAN_OUT
#define XUD_UAC_NUM_USB_CHAN_IN     NUM_USB_CHAN_IN

#endif
