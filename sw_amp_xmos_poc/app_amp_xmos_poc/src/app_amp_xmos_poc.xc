// Copyright 2024 Amplify Labs

#include <stddef.h>
#include "xua.h"

#include "amp_audiohub.h"

#include <syscall.h>
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include "sw_pll.h"
#include "xud_device.h"                 /* XMOS USB Device Layer defines and functions */
#include "xua_endpoint0.h"
#include "uac_hwresources.h"
#include "xua_pdm_mic.h"

//[[distributable]]
//void DFUHandler(server interface i_dfu i, chanend ?c_user_cmd);

// // I2S ports (DACs/amps)
on tile[AUDIO_IO_TILE] : buffered out port:32 p_i2s_dac[I2S_WIRES_DAC] = {PORT_I2S_DAC0, PORT_I2S_DAC1};
on tile[AUDIO_IO_TILE] : buffered out port:32 p_lrclk                  = PORT_I2S_LRCLK;
on tile[AUDIO_IO_TILE] : buffered out port:32 p_bclk                   = PORT_I2S_BCLK;

// Clock ports
on tile[AUDIO_IO_TILE] :  in port p_mclk_in                 = PORT_MCLK_IN;
on tile[XUD_TILE] : in port p_for_mclk_count                = PORT_MCLK_COUNT;

/*** Clock blocks ***/
clock clk_pdm                                               = on tile[PDM_TILE]: XS1_CLKBLK_1;

// PDM ports
in port p_pdm_clk                                           = PORT_PDM_CLK;
in buffered port:32 p_pdm_mics                              = PORT_PDM_DATA;

on tile[AUDIO_IO_TILE] : clock clk_audio_mclk               = CLKBLK_MCLK;       /* Master clock */
on tile[AUDIO_IO_TILE] : clock clk_audio_bclk               = CLKBLK_I2S_BIT;    /* Bit clock */

/* Separate clock/port for USB feedback calculation */
on tile[XUD_TILE] : clock clk_audio_mclk_usb                = CLKBLK_MCLK;       /* Master clock */
on tile[XUD_TILE] : in port p_mclk_in_usb                   = PORT_MCLK_IN_USB;

/* p_ctrl: (GPIO used on the EVK)
 * [0:3] - Unused
 * [4]   - EN_3v3_N
 * [5]   - EN_3v3A
 * [6]   - EXT_PLL_SEL (CS2100:0, SI: 1)
 * [7]   - MCLK_DIR    (Out:0, In: 1)
 */

on tile[XUD_TILE]: out port p_ctrl = XS1_PORT_8D;

/* Endpoint type tables for XUD */
XUD_EpType epTypeTableOut[ENDPOINT_COUNT_OUT] = { XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_ISO};
XUD_EpType epTypeTableIn[ENDPOINT_COUNT_IN] = { XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_ISO, XUD_EPTYPE_ISO};

void amp_clock_init() {

    // configure sw pll to 48 kHz
    delay_milliseconds(100);
    sw_pll_fixed_clock(MCLK_48);
    delay_milliseconds(100);
    /* Clock master clock-block from master-clock port */
    /* Note, marked unsafe since other cores may be using this mclk port */
    configure_clock_src(clk_audio_mclk, p_mclk_in);

    // PDM CLOCK CONFIG. divide the audio mckl by a factor of 4
    configure_clock_src_divide(clk_pdm, p_mclk_in, 4);
    configure_port_clock_output(p_pdm_clk, clk_pdm);
    configure_in_port(p_pdm_mics, clk_pdm);

    delay_microseconds(5);

    start_clock(clk_audio_mclk);
    start_clock(clk_pdm);

    delay_microseconds(5);
}

// this is specific to the xmos evk
void ctrlPort() {
    // Drive control port to turn on 3V3 and set MCLK_DIR
    // Note, "soft-start" to reduce current spike
    // Note, 3v3_EN is inverted
    #define EXT_PLL_SEL__MCLK_DIR    (0x80)

    for (int i = 0; i < 30; i++) {
        p_ctrl <: EXT_PLL_SEL__MCLK_DIR | 0x30; /* 3v3: off, 3v3A: on */
        delay_microseconds(5);
        p_ctrl <: EXT_PLL_SEL__MCLK_DIR | 0x20; /* 3v3: on, 3v3A: on */
        delay_microseconds(5);
    }
}

int main() {

    //interface i_dfu dfuInterface;
    chan c_sof;
    chan c_xud_out[ENDPOINT_COUNT_OUT];              /* Endpoint channels for XUD */
    chan c_xud_in[ENDPOINT_COUNT_IN];
    chan c_aud_ctl;
    chan c_pdm_pcm;
    chan c_mix_out;
    streaming chan c_ds_output[2];

    par {

        on tile[XUD_TILE]: {

            unsigned usbSpeed = (AUDIO_CLASS == 2) ? XUD_SPEED_HS : XUD_SPEED_FS;
            unsigned xudPwrCfg = (XUA_POWERMODE == XUA_POWERMODE_SELF) ? XUD_PWR_SELF : XUD_PWR_BUS;

            ctrlPort();

            // set up usb clocks
            set_clock_src(clk_audio_mclk_usb, p_mclk_in_usb);
            set_port_clock(p_for_mclk_count, clk_audio_mclk_usb);
            start_clock(clk_audio_mclk_usb);

            par {

                // we want the dfu to run on the XUD tile
                //[[distribute]]
                //DFUHandler(dfuInterface, null);

                XUD_Main(c_xud_out, ENDPOINT_COUNT_OUT, c_xud_in, ENDPOINT_COUNT_IN, c_sof, epTypeTableOut, epTypeTableIn, usbSpeed, xudPwrCfg);
                XUA_Buffer(c_xud_out[ENDPOINT_NUMBER_OUT_AUDIO], c_xud_in[ENDPOINT_NUMBER_IN_AUDIO],c_xud_in[ENDPOINT_NUMBER_IN_FEEDBACK], c_sof, c_aud_ctl, p_for_mclk_count, c_mix_out);
                XUA_Endpoint0( c_xud_out[0], c_xud_in[0], c_aud_ctl, null, null, null, null); //dfuInterface VENDOR_REQUESTS_PARAMS_);

            }
        }

        on tile[AUDIO_IO_TILE]: {

            amp_clock_init();

            par {
                /* Audio I/O core */
                XUA_AudioHub(c_mix_out, clk_audio_mclk, clk_audio_bclk, p_mclk_in, p_lrclk, p_bclk, p_i2s_dac, null, c_pdm_pcm);
                xua_pdm_mic(c_ds_output, p_pdm_mics);
                XUA_PdmBuffer(c_ds_output, c_pdm_pcm);
            }
        }
    }

    return 0;
}