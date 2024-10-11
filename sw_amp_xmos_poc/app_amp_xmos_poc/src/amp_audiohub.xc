// Copyright 2011-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
/**
 * @file xua_audiohub.xc
 * @brief XMOS USB 2.0 Audio Reference Design.  Audio Functions.
 * @author Ross Owen, XMOS Semiconductor Ltd
 *
 * This thread handles I2S and forwards samples to the SPDIF Tx core.
 * Additionally this thread handles clocking and CODEC/DAC/ADC config.
 **/

#include <syscall.h>
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xs1_su.h>
#include <string.h>
#include <xassert.h>

#include "xua.h"
#include "amp_audiohub.h"

#include "audiohw.h"
#include "audioports.h"
#include "mic_array_conf.h"

#if (XUA_NUM_PDM_MICS > 0)
#include "xua_pdm_mic.h"
#endif

#include "xua_commands.h"
#include "xc_ptr.h"

unsigned samples_in_mics  [XUA_NUM_PDM_MICS]  = {0};
unsigned samples_out_dac  [I2S_CHANS_DAC]     = {0};
unsigned samples_to_usb   [NUM_USB_CHAN_IN]   = {0};
unsigned samples_from_usb [NUM_USB_CHAN_OUT]  = {0};

void InitPorts_master(buffered _XUA_CLK_DIR port:32 p_lrclk, buffered _XUA_CLK_DIR port:32 p_bclk, buffered out port:32 (&?p_i2s_dac)[I2S_WIRES_DAC],
    buffered in port:32  (&?p_i2s_adc)[I2S_WIRES_ADC]);

unsigned dsdMode = DSD_MODE_OFF;

static inline int HandleSampleClock(int frameCount, buffered _XUA_CLK_DIR port:32 p_lrclk)
{
    unsigned clkVal;
    if(frameCount == 0)
        clkVal = 0x80000000;
    else
        clkVal = 0x7fffffff;

    p_lrclk <: clkVal;

    return 0;
}

#pragma unsafe arrays
unsigned static AudioHub_MainLoop(chanend ?c_out, chanend ?c_spd_out
    , unsigned divide, unsigned curSamFreq
#if (XUA_NUM_PDM_MICS > 0)
    , chanend c_pdm_pcm
#endif
    , buffered _XUA_CLK_DIR port:32 ?p_lrclk,
    buffered _XUA_CLK_DIR port:32 ?p_bclk,
    buffered out port:32 (&?p_i2s_dac)[I2S_WIRES_DAC],
    buffered in port:32  (&?p_i2s_adc)[I2S_WIRES_ADC]
) {

    unsigned command;
    int tmp, i;

    #if ((DEBUG_MIC_ARRAY == 1) && (XUA_NUM_PDM_MICS > 0))
    /* Get initial samples from PDM->PCM converter to avoid stalling the decimators */
    // TO DO - figure out if we need to do this
    c_pdm_pcm <: 1;
    master {
    #pragma loop unroll
    for(i = 0; i < XUA_NUM_PDM_MICS; i++) {
        c_pdm_pcm :> samples_in_mics[i];
    }
    }
    #endif // ((DEBUG_MIC_ARRAY == 1) && (XUA_NUM_PDM_MICS > 0))

    InitPorts_master(p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);

    /* Main Audio I/O loop */
    while (1) {
        
        HandleSampleClock(0, p_lrclk); // Set LR clock to slot 0

        /* Output "even" channel to DAC (i.e. left) */
        for (i = 0; i < I2S_STREAMS; i++) {
            p_i2s_dac[i] <: bitrev(samples_out_dac[i*I2S_CHANS_PER_STREAM]); // I2C0 L
        }
       
        c_pdm_pcm <: 1; // Get samples from PDM->PCM converter
        master {
        #pragma loop unroll
        for (i = 0; i < XUA_NUM_PDM_MICS; i++) {
            c_pdm_pcm :> samples_in_mics[i];
        }
        }
        
        HandleSampleClock(1, p_lrclk); // Set LR clock to slot 1

        /* Output "odd" channel to DAC (i.e. right) */
        for (i = 0; i < I2S_STREAMS; i++) {
            p_i2s_dac[i] <: bitrev(samples_out_dac[i*I2S_CHANS_PER_STREAM+1]); // I2C0 R
        }

        outuint(c_out, 0); // usb sample transfer (receive), from xua_audiohub_st.h
        
        if(testct(c_out)) {
            command = inct(c_out);
            p_lrclk <: 0; // set clocks low
            p_bclk <: 0;
            return command;
        }

        // usb to audiohub
        #pragma loop unroll
        for(i = 0; i < NUM_USB_CHAN_OUT; i++) {
            tmp = inuint(c_out);
            samples_from_usb[i] = tmp;
        }

        // audiohub to usb
        #pragma loop unroll
        for (i = 0; i < NUM_USB_CHAN_IN; i++) {
            outuint(c_out, samples_to_usb[i]);
        }

        // signal routing

        // mics input
        #pragma unroll
        for(i = 0; i < NUM_USB_CHAN_IN; i++) samples_to_usb[i] = samples_in_mics[i];
        
        // dac output
        #pragma unroll
        for(i = 0; i < I2S_CHANS_DAC; i++) samples_out_dac[i] = samples_from_usb[0]; // copy same stream to each dac output
    }
    return 0;
}

#if XUA_DFU_EN
[[distributable]]
void DFUHandler(server interface i_dfu i, chanend ?c_user_cmd);
#endif

/* This function is a dummy version of the deliver thread that does not
   connect to the codec ports. It is used during DFU reset. */

#pragma select handler
void testct_byref(chanend c, int &returnVal)
{
    returnVal = 0;
    if(testct(c))
        returnVal = 1;
}

#if (XUA_DFU_EN == 1)
[[combinable]]
static void dummy_deliver(chanend ?c_out, unsigned &command)
{
    int ct;

    while (1)
    {
        select
        {
            /* Check for sample freq change or new samples from mixer*/
            case testct_byref(c_out, ct):
                if(ct)
                {
                    unsigned command = inct(c_out);
                    return;
                }
                else
                {

#pragma loop unroll
                    for(int i = 0; i < NUM_USB_CHAN_OUT; i++)
                    {
                        int tmp = inuint(c_out);
                        samplesOut[i] = tmp;
                    }

#pragma loop unroll
                    for(int i = 0; i < NUM_USB_CHAN_IN; i++)
                    {
                        outuint(c_out, 0);
                    }
                }

                outuint(c_out, 0);
            break;
        }
    }
}
#endif

#if XUA_DFU_EN
 [[distributable]]
 void DFUHandler(server interface i_dfu i, chanend ?c_user_cmd);
#endif

void XUA_AudioHub(chanend ?c_aud, clock ?clk_audio_mclk, clock ?clk_audio_bclk,
    in port p_mclk_in,
    buffered _XUA_CLK_DIR port:32 ?p_lrclk,
    buffered _XUA_CLK_DIR port:32 ?p_bclk,
    buffered out port:32 (&?p_i2s_dac)[I2S_WIRES_DAC],
    buffered in port:32  (&?p_i2s_adc)[I2S_WIRES_ADC]
#if (XUA_NUM_PDM_MICS > 0)
    , chanend c_pdm_in
#endif
)
{
    unsigned curSamFreq = DEFAULT_FREQ * AUD_TO_USB_RATIO;
    unsigned curSamRes_DAC = STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS; /* Default to something reasonable */
    unsigned curSamRes_ADC = STREAM_FORMAT_INPUT_1_RESOLUTION_BITS; /* Default to something reasonable - note, currently this never changes*/
    unsigned command;
    unsigned mClk;
    unsigned divide;
    unsigned firstRun = 1;

    /* Perform required CODEC/ADC/DAC initialisation */
    AudioHwInit();

    while(1)
    {
        /* Calculate what master clock we should be using */
        if (((MCLK_441) % curSamFreq) == 0)
        {
            mClk = MCLK_441;
        }
        else if (((MCLK_48) % curSamFreq) == 0)
        {
            mClk = MCLK_48;
        }

        /* Calculate master clock to bit clock (or DSD clock) divide for current sample freq
         * e.g. 11.289600 / (176400 * 64)  = 1 */
        {
            unsigned numBits = XUA_I2S_N_BITS * I2S_CHANS_PER_FRAME;

            divide = mClk / (curSamFreq * numBits);

            //Do some checks
            xassert((divide > 0) && "Error: divider is 0, BCLK rate unachievable");

            unsigned remainder = mClk % ( curSamFreq * numBits);
            xassert((!remainder) && "Error: MCLK not divisible into BCLK by an integer number");

            unsigned divider_is_odd =  divide & 0x1;
            xassert((!divider_is_odd) && "Error: divider is odd, clockblock cannot produce desired BCLK");

        }
        {
            ConfigAudioPortsWrapper(p_i2s_dac, I2S_WIRES_DAC, p_lrclk, p_bclk, p_mclk_in, clk_audio_bclk, divide, curSamFreq);
        }

        {
            unsigned curFreq = curSamFreq;
            /* Configure Clocking/CODEC/DAC/ADC for SampleFreq/MClk */

            /* User should mute audio hardware */
            AudioHwConfig_Mute();

            /* User code should configure audio harware for SampleFreq/MClk etc */
            //AudioHwConfig(curFreq, mClk, dsdMode, curSamRes_DAC, curSamRes_ADC);

            /* User should unmute audio hardware */
            AudioHwConfig_UnMute();
        }

        if(!firstRun)
        {
            /* TODO wait for good mclk instead of delay */
            /* No delay for DFU modes */
            if (((curSamFreq / AUD_TO_USB_RATIO) != AUDIO_STOP_FOR_DFU) && command)
            {
#if 0
                /* User should ensure MCLK is stable in AudioHwConfig */
                if(retVal1 == SET_SAMPLE_FREQ)
                {
                    timer t;
                    unsigned time;
                    t :> time;
                    t when timerafter(time+AUDIO_PLL_LOCK_DELAY) :> void;
                }
#endif
                /* Handshake back */
                outct(c_aud, XS1_CT_END);
            }
        }
        firstRun = 0;

        par
        {

            {
#if (XUA_NUM_PDM_MICS > 0)
                /* Send decimation factor to PDM task(s) */
                c_pdm_in <: curSamFreq / AUD_TO_MICS_RATIO;
#endif

                command = AudioHub_MainLoop(c_aud, null, divide, curSamFreq
#if (XUA_NUM_PDM_MICS > 0)
                   , c_pdm_in
#endif
                  , p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);

                if(command == SET_SAMPLE_FREQ)
                {
                    curSamFreq = inuint(c_aud) * AUD_TO_USB_RATIO;
                }
                else if(command == SET_STREAM_FORMAT_OUT)
                {
                    /* Off = 0
                     * DOP = 1
                     * Native = 2
                     */
                    dsdMode = inuint(c_aud);
                    curSamRes_DAC = inuint(c_aud);
                }

#if (XUA_DFU_EN == 1)
                /* Currently no more audio will happen after this point */
                if ((curSamFreq / AUD_TO_USB_RATIO) == AUDIO_STOP_FOR_DFU)
                {
                    outct(c_aud, XS1_CT_END);

                    outuint(c_aud, 0);

                    while (1)
                    {
                        dummy_deliver(c_aud, command);
                        
                        /* Note, we do not expect to reach here */
                        curSamFreq = inuint(c_aud);
                        outct(c_aud, XS1_CT_END);
                    }
                }
#endif

#if XUA_NUM_PDM_MICS > 0
                c_pdm_in <: 0;
#endif
            }
        }
    }
}
