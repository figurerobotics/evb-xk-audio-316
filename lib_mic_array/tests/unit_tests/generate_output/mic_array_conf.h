// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef MIC_ARRAY_CONF_H_
#define MIC_ARRAY_CONF_H_

//#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 0
//#define MIC_ARRAY_NUM_MICS 4

#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 0
#define MIC_ARRAY_FRAME_SIZE 1
#define MIC_ARRAY_NUM_MICS 4

#define MIC_ARRAY_CH0      PIN0
#define MIC_ARRAY_CH1      PIN4
#define MIC_ARRAY_CH2      PIN1
#define MIC_ARRAY_CH3      PIN3

#define MIC_DECIMATION_FACTOR 6
#define MIC_FRAME_BUFFERS  4
#define MIC_CHANNELS 4
#define MIC_DECIMATORS 1

#endif /* MIC_ARRAY_CONF_H_ */
