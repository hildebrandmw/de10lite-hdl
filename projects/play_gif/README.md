# Play GIFs on the DE10-Lite

Complete project allowing displaying of GIFs through the VGA connecter on the DE10-Lite 
board by storing the GIF in SDRAM and iterating through memory.

## Usage

First, the project needs to be synthesized and flashed to the DE10-Lite board. Open 
`synthesis/play_gif/qpf` in Quartus. The project should compile without any errors. Then,
program the DE10 board.

Next, get the software running. Make sure the TCL server is running as outlined in 
[here](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/usb-blaster). 
Once the server is running in System Console, open the `julia/` directory and launch
[Julia](https://julialang.org). Activate the project using
```julia
]activate .

# Create a JTAG object to communicate with the TCL server
julia> jtag = JTAG()
JTAG{IPv4}(ip"127.0.0.1", 2540, false)

# Send the "waterfall" gif
julia> send(jtag, "waterfall.gif")

julia> send(jtag, "waterfall.gif")
[ Info: Loading Image
[ Info: Packing Image
Progress: 100%|█████████████████████████████████████████| Time: 0:00:02
[ Info: Sending Image
Progress: 100%|█████████████████████████████████████████| Time: 0:00:13

# Adjust frame speed
julia> setspeed(jtag, 2)

# Send the slightly larger "abstract.gif"
julia> send(jtag, "abstract.gif")
[ Info: Loading Image
[ Info: Packing Image
Progress: 100%|█████████████████████████████████████████| Time: 0:00:18
[ Info: Sending Image
Progress: 100%|█████████████████████████████████████████| Time: 0:02:12
```

## Architecture

An Avalon Interface (see `qsys/system.qsys`) connects several IP components together, 
allowing images to be send directly from a host machine to the SDRAM through the JTAG to 
Avalon-MM component. Contents of the SDRAM are accessed through an External Bus to Avalon 
Bridge.

The line buffer buffers up the row of image data from the SDRAM. It begins this process 
during each horizontal-sync period of the VGA controller. The VGA controller, in addition to
generating the correct timing signals for the VGA protocol,  records which base address in 
DRAM is being used, as well as the address of the next line.
