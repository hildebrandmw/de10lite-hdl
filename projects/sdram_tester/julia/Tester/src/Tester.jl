module Tester

# stdlib dependencies
using Random
using Logging

# external dependencies
using JTAGManager
using ProgressMeter

export JTAG, led, validate

# Set start and stop addresses of DRAM.
dram_addr_start() = 0
dram_addr_end() = 0x03ff_ffff

# Write to the LED of the board
# LED's are at address 0x4000_0000
"""
    led(jtag::JTAG, val)

Write `val` to the LEDs on the DE10 Board.
"""
led(jtag::JTAG, val) = write(jtag, 0x4000_0000, [val])

# Struct for tracking what has been written and where.
mutable struct AddressSlot
    address :: Int
    value :: UInt8
    iswritten :: Bool
    isread :: Bool
end
AddressSlot(address = 0) = AddressSlot(address, 0x00, false, false)

iswritten(a::AddressSlot) = a.iswritten
isread(a::AddressSlot) = a.isread

setvalue(a::AddressSlot, value) = (a.value = value; a.iswritten = true; nothing)
getvalue(a::AddressSlot) = a.value

getaddress(a::AddressSlot) = a.address
Base.read(a::AddressSlot) = (a.isread = true; a.value)


"""
    validate(jtag::JTAG, ntests; kwargs...)

Test the DRAM for the device referenced by `jtag`. Preform approximately 
`ntests` number of reads and writes.

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
"""
function validate(
        jtag :: JTAG,
        ntests :: Integer;
        # kwargs!
        writesize_max = 2 ^ 14,
        writesize_min = 2,
        readsize_max = 2^14,
        readsize_min = 1,
        start_address = dram_addr_start(),
        end_address = dram_addr_end()
    )

    # Keep an array tracking all writes that have occurred. 
    dram = [AddressSlot(i) for i in start_address:end_address]

    # Track number of reads and writes.
    write_actions = 0
    read_actions = 0
    failed_read_actions = 0

    nwrites = 0
    nreads = 0

    # Set up progress bar
    p = Progress(ntests, 1)

    # Get address range.
    # Make sure to only take even addresses because the Intel SDRAM controller
    # doesn't have low-byte/high-byte enables, so we must always write 2 bytes
    # to an even address.
    address_range = start_address:2:end_address

    while write_actions < ntests || read_actions < ntests
        # Perform a random number of writes of random size.
        for _ in 1:rand(1:5)
            # Pick a random starting address
            base = rand(address_range) 

            # Pick a length for the write
            writesize = rand(writesize_min:2:writesize_max)

            # Perform a quick length check to avoid going off the end of the
            # dram.
            if base + writesize > end_address
                writesize = end_address - base
            end

            # Generate the writes - first locally into the local copy of
            # DRAM, then to the actual jtag device.
            for addr in base:base + writesize - 1
                setvalue(dram[addr], rand(UInt8))
            end

            # Create a vector from the values we just wrote and write to jtag.
            data = [getvalue(dram[addr]) for addr in base:base + writesize - 1]
            write(jtag, base, data)

            # Record statistics
            write_actions += 1
            nwrites += writesize
        end

        # Perform a random number of reads
        for _ in 1:rand(1:5)
            # Get a random starting address from addresses written.
            base = getaddress(rand(filter(iswritten, dram)))

            # Inspect DRAM, make sure we only read memory that has been written 
            # to.
            local readsize 
            for outer readsize in readsize_min:rand(readsize_min:readsize_max)
                if !iswritten(dram[base + readsize - 1])
                    readsize -= 1
                    break
                end
            end

            # Perform a read
            data = read(jtag, base, readsize)
            expected = [read(dram[addr]) for addr in base:base + readsize -1]

            if data != expected
                @error """
                Invalid read of size $readsize starting at address $base.
                """
                failed_read_actions += 1
            end

            # Record stats
            read_actions += 1
            nreads += readsize
            next!(p)
        end
    end

    # Compute the precent of addresses read and written.
    addresses_written = count(iswritten, dram)
    addresses_read = count(isread, dram)

    @info """
    Write actions: $write_actions
    Number of writes: $nwrites
    Unique Addresses Written: $addresses_written
    Write Coverage: $(addresses_written / length(dram))
    

    Read actions: $read_actions
    Number of reads: $nreads
    Unique Addresses Read: $addresses_read
    Read Coverage: $(addresses_read / length(dram))
    """

    if failed_read_actions == 0
        @info "All operations successful"
    else
        @error "There were $(failed_read_actions) failed read operations"
    end
end

end
