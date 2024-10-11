# Prototype XMOS XU316 Firmware

## Channel routing

### Host USB outputs:

1 -> DAC output (I2S)

### Host USB inputs:

1..4 -> PDM mic input (data pins X1D26..X1D29, )

## PDM mic inputs

Four mics enabled and exposed on pins X1D26 ... X1D29 (connector J42).

Clock pin X1D25, labelled ADC D1 on silk screen (connector J7).

All mics should be clocked on rising edge.

## Building

1. Install XMOS toolchain and open development environment. (https://www.xmos.com/documentation/XM-014363-PC/html/installation/install-configure/install-tools/install.html & https://www.xmos.com/documentation/XM-014363-PC/html/installation/install-configure/getting-started.html)
2. Navigate to the 'sw_amp_xmos_poc/app_amp_xmos_poc/' sub directory.
3. Run 'xmake'.
4. This will generate a .xe binary in the subdirectory 'bin'.

## Flashing
1. Run 'xflash bin/app_amp_xmos_poc.xe'
2. Currently there is a known issue where the flash command will give you a warning and ask if you want to continue. Say 'y' and the flash will finish without error.
