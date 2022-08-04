# GD32VF103-I2C-example-transmit-and-receive-in-ASSEMBLY.-LONGAN-NANO
crude RISCV assembly language example to transmit and receive on I2C bus . tested on CHIP = GD32VF103 , LONGAN NANO board
The program is written with simple light weight BRONZEBEARD assembler available on GITHUB. The assembler works fine on windows 10. Uploading to GD32VF103 longan nano board
was by USB DFU. GIGADEVICES web site has the programming tool and is available for free download. The bronzebeard assembler is capable to output file in INTEL HEX format
which can be uploaded by the DFU tool.
PB7 = SDA
PB6 = SCL
external pullup = 4.7k
if multiple bytes to be received ,the number of bytes to be received needs to be set up in t0 register inside I2C_READ_MULTI routine.
