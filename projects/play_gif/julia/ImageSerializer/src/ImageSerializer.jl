module ImageSerializer

export send, setspeed, setcount, load

using Sockets

# For opening and working with images
using Images

# Communicating with the device.
using JTAGManager
export JTAG

# For progress information
using ProgressMeter

# Address of the max_frame_count register.
# System counts to this value before moving to the next frame.
framecount_reg_address() = 0x0400_0000

# Address of the max_image_count register.
# Number of images in the GIF.
imagecount_reg_address() = 0x0400_0010

dram_base_address() = zero(UInt)

function Sockets.send(jtag::JTAG, image::String)
    @info "Loading Image"
    img = load(image)

    # Configure frame count register.
    write(jtag, imagecount_reg_address(), size(img, 3) - 1)

    @info "Packing Image" 
    # By default, use 4 bits per color and 16 bits per pixel.
    data = pack(flatten(img), 4, 16)

    @info "Sending Image"
    write(jtag, dram_base_address(), data)
end

setspeed(jtag::JTAG, speed) = write(jtag, framecount_reg_address(), speed)
setcount(jtag::JTAG, count) = write(jtag, imagecount_reg_address(), count)


# Orient images correctly so standard iteration ends up in the correct format
# for the display unit. 
# 
# Display unit expects images to be row major.
flatten(img::AbstractArray{T,2}) where T = reshape(img', :)
flatten(img::AbstractArray{T,3}) where T = permutedims(img, (2,1,3))

function pack(img::Array, bits_per_color, bits_per_pixel)
    # Make sure numbers match.
    num_colors = 3 
    if num_colors * bits_per_color > bits_per_pixel
        throw(Error())
    end
    # Final return type, just a collection of bytes.
    packed_data = UInt8[] 

    # Basic Idea:
    #
    # Go through each item in the flattened image. Pull out the red, green, and
    # blue channels, taking the requested number of bits from the top of each
    # value. As these are decoded, they will be appended to a vector.
    #
    # Each time the vector exceeds 8 bits, we will convert the leading 8 bits
    # to a UInt8 and remove them from the vector.
    #
    # Pad zeros to the desired "bits_per_pixel".
    #
    # Note that this is not super efficient.
    bit_buffer = UInt8[]
    colors = (red, green, blue)

    @showprogress 1 for pixel in img
        newbits = upperbits.(bits.(colors, pixel), bits_per_color)
        for vec in newbits
            append!(bit_buffer, vec) 
        end

        # Zero pad if necessary
        pad = zeros(UInt8, bits_per_pixel - 3 * bits_per_color)
        append!(bit_buffer, pad)

        # Pull out groups of 8 bits and put them in the return data.
        groupbits!(packed_data, bit_buffer)
    end

    return packed_data
end

bits(f, x) = f(x).i
upperbits(x::Unsigned, n) = digits(UInt8, x; base = 2, pad = 8 * sizeof(UInt8))[end+1-n:end]

function groupbits!(target, buffer)
    while length(buffer) >= 8
        result = zero(UInt8)
        for i in 0:7
            b = popfirst!(buffer)
            result |= UInt8(b * 2^(i))
        end
        push!(target, result)
    end
end

end # module
