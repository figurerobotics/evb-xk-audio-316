# Prototype XMOS firware for Figure use case

## Channel routing

### Host USB outputs:

1 -> DAC output (I2S)

### Host USB inputs:

1..4 -> PDM mic input (data pins X1D26..X1D29, )

## PDM mic inputs

Four mics enabled and exposed on pins X1D26 ... X1D29 (connector J42).

Clock pin X1D25, labelled ADC D1 on silk screen (connector J7).

All mics should clocked on rising edge.
