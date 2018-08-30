# SDRAM Tester

This project implements a simple SDRAM testing infrastructure and Julia source
code to automate (slowly) the testing process. This serves as both validation
for the SDRAM module on the DE10-Lite board, validation of the timing parameters
for the SDRAM controller IP component outlined [here](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/dram),
and for the [USB-Blaster](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/usb-blaster)
connection mechanism.

All files/code needed to synthesize the design can be found in the `project/`
folder. Code provided in `julia/` is a simple test harness.

## Loading the Quartus Project

This project is self contained to run on the DE10-Lite board. Simply open
`sdram_tester.qpf` using Quartus, synthesize the design, and program the FPGA.

To view the QSYS system (particularly how the JTAG-to-Avalon-MM bridge is
connected to the Avalon system and how the SDRAM controller is configured), open
`qsys_system.qsys` using Platform Designer.

## Using the Julia Code

When the FPGA has been programmed, open System Console and launch 
`jtag_server.tcl` as outlined in [this tutorial](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/usb-blaster).
Once the server is running, launch `Julia` and navigate to the `julia/` folder.
Run the command
```julia
pkg> activate .
```
to activate the Julia environment described by the `Project.toml` and 
`Manifest.toml` files. This will fetch [JTAGManager.jl](https://github.com/hildebrandmw/JTAGManager.jl)
if not already installed and make the tester code visible. Usage of the test 
code then looks like this
```julia
(julia) pkg> activate .

julia> using Tester

julia> jtag = JTAG()
JTAG{IPv4}(ip"127.0.0.1", 2540, false)

# Write a bit pattern to the DE10-Lite LEDs
julia> led(jtag, 255)

julia> led(jtag, 0xaa)

julia> led(jtag, 0x55)

# Perform a test of the System and SDRAM
julia> validate(jtag, 1000)
Progress: 100%|█████████████████████████████████████████| Time: 0:06:01
┌ Info: Write actions: 1035
│ Number of writes: 8433164
│ Unique Addresses Written: 7972410
│ Write Coverage: 0.118798166513443
│
│
│ Read actions: 1002
│ Number of reads: 4282443
│ Unique Addresses Read: 2692694
└ Read Coverage: 0.04012426733970642
[ Info: All operations successful

# Finish up
julia> close(jtag)
```

With some directed testing, it will be possible to obtain full coverage of the
DRAM address space.

Much of the time overhead involves data navigating its way from the computer
into the FPGA as the USB-Blaster JTAG connection should not be considered in
any way a high speed link.

## Documentation of `validate`
```julia
validate(jtag::JTAG, ntests; kwargs...)
```

Test the DRAM for the device referenced by `jtag`. Preform approximately 
`ntests` number of reads and writes. Reads and writes occur to random addresses
and are of a random size.

Key Word Agruments
------------------
* `writesize_max = 2^14` - The maximum number of bytes to write in any single 
    write action.
* `writesize_min = 2` - The minimum number of bytes to write in any single write
    action.
* `readsize_max = 2^14` - The maximum number of bytes to read in any single read 
    action.
* `readsize_min = 1` - The minimum number of bytes to read in any single read 
    action.
* `start_address = 0` - The first memory mapped address of the DRAM. If the
    SDRAM is mapped to another address, change this.
* `end_address = 0x3ff_ffff` - The final memory mapped address of the DRAM.

