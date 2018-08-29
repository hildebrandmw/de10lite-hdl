# -----------------------------------------------------------------
# jtag_server_cmds.tcl
#
# 9/14/2011 D. W. Hawkins (dwh@ovro.caltech.edu)
#
# Altera JTAG socket server Tcl commands.
#
# The JTAG server provides remote hardware access/control functions
# to clients.
#
# The server accept Tcl string commands from the client, issues the
# command to the hardware, and then returns any response data
# to the client.
#
# -----------------------------------------------------------------
# Notes:
# ------
#
# 1. To use the commands via a console, use:
#
#    quartus_stp -s
#    tcl> source jtag_server_cmds.tcl
#
#    This same procedure can be used with SystemConsole
#
# 2. When this script is run under quartus_stp, it requires
#    the package: altera_jtag_to_avalon_stp.
#
#    The package contains Tcl scripts for accessing
#    JTAG-to-Avalon-ST/MM bridges from quartus_stp.
#
#    See jtag_server.tcl for how to load the package.
#
# -----------------------------------------------------------------
# References
# ----------
#
# 1. Brent Welch, "Practical Programming in Tcl and Tk",
#    3rd Ed, 2000.
#
# -----------------------------------------------------------------

# =================================================================
# Tool detection
# =================================================================
#
# The server can be run from either quartus_stp or SystemConole.
#
# Tcl usually allows you to detect the toolname using
# 'info nameofexecutable', however, under SystemConsole this
# is an empty string. In other cases, the global argv0
# holds the application name, but under the Quartus Tcl console
# there is no argv0! However, nameofexecutable does work there,
# so start with that, and if its empty, try argv0.
#
proc detect_tool {} {
	global jtag argv0

	# Get the tool name
	set toolname [info nameofexecutable]
	if {[string length $toolname] == 0} {
		if {[info exists argv0]} {
			set toolname $argv0
		}
	}

	# Strip the name to just that of the application
	set toolname [file rootname [file tail $toolname]]

	# Test for the two allowed tools
	set jtag(tool_ok) 0
	if {[string compare $toolname quartus_stp] == 0} {
		set jtag(tool) stp
		set jtag(tool_ok) 1
	} elseif {[string compare $toolname system-console] == 0} {
		set jtag(tool) sc
		set jtag(tool_ok) 1
	}
	return
}

proc is_tool_ok {} {
	global jtag
	if {![info exists jtag(tool_ok)]} {
		detect_tool
	}
	return $jtag(tool_ok)
}

proc is_system_console {} {
	global jtag
	if {![info exists jtag(tool_ok)]} {
		detect_tool
	}
	if {[string compare $jtag(tool) sc] == 0} {
		return 1
	} else {
		return 0
	}
}

proc has_fileevent {} {
	if {[string compare [info command fileevent] "fileevent"] == 0} {
		return 1
	} else {
		return 0
	}
}

# =================================================================
# Debug mode
# =================================================================
#
# In debug mode, the global array 'jtag' is used  as fake
# memory for read/write accesses
#
proc jtag_debug_mode {val} {
	global jtag
	set jtag(debug) $val
	return
}

proc is_debug_mode {} {
	global jtag
	if {$jtag(debug) == 1} {
		return 1
	} else {
		return 0
	}
}

# =================================================================
# JTAG access
# =================================================================
#
proc jtag_open {{index 0}} {
	global jtag

	if {[is_system_console]} {
		# Close any open service
		if {[info exists jtag(master)]} {
			close_service master $jtag(master)
		}

		# Get the list of masters
		set masters [get_service_paths master]
		if {[llength $masters] == 0} {
			error "Error: No JTAG-to-Avalon-MM device found!"
		}

		# Access the first master in the masters list
		set jtag(master) [lindex $masters $index]
		open_service master $jtag(master)

	} else {

		# Use the quartus_stp procedures to find the first
		# JTAG-to-Avalon-MM bridge (master)
		#
		# First check if a board is found
		if {[catch {altera_jtag_to_avalon_stp::jtag_open} result]} {
			error "Error: JTAG device open failed\n -> $result"
		}
		# Find the first master
		set len [altera_jtag_to_avalon_stp::jtag_number_of_nodes]
		for {set i 0} {$i < $len} {incr i} {
			if {[altera_jtag_to_avalon_stp::jtag_node_is_master $i]} {
				set jtag(master) $i
				break;
			}
		}
		if {![info exists jtag(master)]} {
			error "Error: No JTAG-to-Avalon-MM device found!"
		}
	}
	return
}

proc jtag_close {} {
	global jtag

	if {[is_system_console]} {
		if {[info exists jtag(master)]} {
			close_service master $jtag(master)
			unset jtag(master)
		}
	} else {
		altera_jtag_to_avalon_stp::jtag_close
	}
	return
}

proc jtag_read {addr bytes} {
	global jtag

	# Check the argument is a valid value by reformatting
	# the address as an 8-bit hex value
	set addr [expr {$addr & 0xFFFFFFFF}]
	if {[catch {format "0x%.8X" $addr} addr]} {
		error "Error: Invalid address\n -> '$addr'"
	}

	if {[is_debug_mode]} {

		# Check if the fake address exists, if it does not,
		# then create it and initialize it to 0.
		if {![info exists jtag(addr_$addr)]} {
			set jtag(addr_$addr) 0
		}
		puts "DEBUG: jtag_read $addr"
		return $jtag(addr_$addr)
	} else {
		if {![info exists jtag(master)]} {
			jtag_open
		}
	}

	# Read 32-bits
	puts "SERVER: jtag_read $addr $bytes"
	if {[is_system_console]} {
		if {[catch {master_read_memory $jtag(master) $addr $bytes} result]} {
			# JTAG connection lost?
			jtag_close
			error "Error: Check the JTAG interface\n -> '$result'"
		}
	} else {
		if {[catch {altera_jtag_to_avalon_stp::jtag_read $jtag(master) $addr} result]} {
			# JTAG connection lost?
			jtag_close
			error "Error: Check the JTAG interface\n -> '$result'"
		}
	}
	return $result
}

proc jtag_write {addr args} {
	global jtag


	# Check the arguments are valid values by reformatting
	# them as 8-bit hex values
	set addr [expr {$addr & 0xFFFFFFFF}]
	if {[catch {format "0x%.8X" $addr} addr]} {
		error "Error: Invalid address\n -> '$addr'"
	}

#	set data [expr {$data & 0xFFFFFFFF}]
#	if {[catch {format "0x%.8X" $data} data]} {
#		error "Error: Invalid write data\n -> '$data'"
#	}

	if {[is_debug_mode]} {

		# Write to the address
		set jtag(addr_$addr) $args

		puts "DEBUG: jtag_write $addr $args"
		return
	} else {
		if {![info exists jtag(master)]} {
			jtag_open
		}
	}

	# Write 32-bits
	puts "SERVER: jtag_write $addr"
	if {[is_system_console]} {
		if {[catch {master_write_memory $jtag(master) $addr $args} result]} {
			# JTAG connection lost?
			jtag_close
			error "Error: Check the JTAG interface\n -> '$result'"
		}
	} else {
		if {[catch {altera_jtag_to_avalon_stp::jtag_write $jtag(master) $addr $args} result]} {
			# JTAG connection lost?
			jtag_close
			error "Error: Check the JTAG interface\n -> '$result'"
		}
	}
	return
}

# =================================================================
# Server socket
# =================================================================
#
# For details on socket programming, see Welch Ch. 17 [1].
#

# Start the server on the specified port
proc server_listen {port} {
	global jtag
	if {[catch {socket -server server_accept $port} result]} {

#		error "Error: Server start-up failed\n -> $result"
		puts "Error: Server start-up failed\n -> $result"

		# For some reason, this error path causes quartus_stp
		# to generate an error backtrace and then hang the
		# console (Task manager is needed to kill it).
		#
		# This happens if the 'error' function or a 'return'
		# is used here. The 'exit' command still works
		# (but you do not get a full error backtrace).
		#
		# This is not ideal, but its better than a hung console.
		exit
	}
	set jtag(port)   $port
	set jtag(socket) $result
	return
}

# Server client-accept callback
proc server_accept {client addr port} {

    # Connections not originating from local-host will be terminated.
    if {$addr != "127.0.0.1"} {
       puts "Rejecting connection from address $addr"
       close $client
       return
    }

	puts "Accept $client from $addr port $port"
	# Configure the client for line-based communication
	fconfigure $client -buffering line

	# Setup the client handler
	if  {[has_fileevent]} {
		puts "Handle the client via a fileevent callback"
		fileevent $client readable [list client_handler $client]

	} else {

		# SystemConsole (prior to Quartus 11.1sp1)
		#
		# * There is no support for fileevent, so SystemConsole
		#   has to busy loop on one client at a time.
		#
		# * If the client closes its connection cleanly via
		#   client_close, then the socket generates an EOF
		#   and the server will wait for the next client.
		#
		# * However, if the client disconnection is not cleanm,
		#   eg., the client uses exit or ctrl-C to exit, then
		#   the server does not receive an eof, and it remains
		#   blocked on the dead client connection. New clients,
		#   will not be handled!
		#
		#   In constrast, when the server is run under
		#   quartus_stp, the server log indicates that a ctrl-C
		#   from a client quartus_stp generates an
		#   'empty command' followed by 'disconnected'
		#
		puts "Handle the client via a blocked read on the socket"
		while {![eof $client]} {
			client_handler $client
		}
		puts "SERVER ($client): disconnected"
	}
	return
}

# Client handler
#
# * Note: this handler executes *any* Tcl command from the client
#   so the client can actually send arbitrary strings, eg., from
#   a client console, the following is possible:
#
#   tcl> puts $jtag(socket) "expr {5*10}"
#   tcl> gets $jtag(socket)
#   50
#
#   The client handler could be changed to restrict the client
#   command requests to a restricted list of acceptable commands.
#
proc client_handler {client} {
	if {[eof $client]} {
		puts "SERVER ($client): disconnected"
		close $client
	} elseif {[catch {gets $client cmd}]} {
		puts "SERVER ($client): error reading a line"
		close $client
	} elseif {[string length $cmd] == 0} {
		# When the client closes a connection, an empty
		# command is generated, followed by EOF
		# (which the SystemConsole loop breaks on)
		puts "SERVER ($client): empty command"
	} else {
		# Execute the command and return the response
		puts "SERVER ($client): long command"
		if {[catch {eval $cmd} rsp]} {
			puts "SERVER ($client): Invalid command from the client"
		} else {
			if {[string length $rsp] > 0} {
				puts "SERVER ($client): long response"
				puts $client $rsp
            puts $client "\n"
			}
		}
	}
	return
}

# -----------------------------------------------------------------
# jtag_server.tcl
#
# 9/14/2011 D. W. Hawkins (dwh@ovro.caltech.edu)
#
# Altera JTAG socket server.
#
# This script sets up the server environment, accesses the JTAG
# device (if not in debug mode), and then starts the server.
#
# -----------------------------------------------------------------
# Notes:
# ------
#
# 1. Command line operation
#
#    quartus_stp -t jtag_server.tcl <port> <debug>
#
#    where
#
#    <port>   Server port number (defaults to 2540)
#
#    <debug>  Debug flag (defaults to 0)
#
#             If <debug> = 1, the server runs in debug mode, where
#             reads and writes are performed on a Tcl variable,
#             rather than to the JTAG interface.
#
#  2. Console operation
#
#     The port number and debug flag can be set prior to sourcing
#     the script from a Tcl console.
#
# -----------------------------------------------------------------
# References
# ----------
#
# 1. Brent Welch, "Practical Programming in Tcl and Tk",
#    3rd Ed, 2000.
#
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# Load the server commands
# -----------------------------------------------------------------
#
#source ./jtag_server_cmds.tcl

# -----------------------------------------------------------------
# Check the Tcl console supports JTAG
# -----------------------------------------------------------------
#
if {![is_tool_ok]} {
	puts "Sorry, this script can only run using quartus_stp or SystemConsole"
	return
}

# Load the JTAG-to-Avalon bridge commands for quartus_stp
if {![is_system_console]} {
	if {[catch {package require altera_jtag_to_avalon_stp}]} {
		error [concat \
			"Error: the package 'altera_jtag_to_avalon_stp' "\
			"was not found. Please ensure the environment "\
			"variable TCLLIBPATH includes the path to the " \
			"library location." ]

	}
}

# -----------------------------------------------------------------
# Command line arguments?
# -----------------------------------------------------------------
#
# SystemConsole has an argc of 1 when you start it via the
# Transceiver Toolkit GUI, and an argc of 0 when you start
# it from SOPC Builder. Ignore command-line arguments from
# SystemConsole.
#
if {![is_system_console]} {
#	puts "Command-line argument count: $argc"
	if {$argc > 0} {
		set port [lindex $argv 0]
#		puts "Command-line port number: $port"
	}
	if {$argc > 1} {
		set debug [lindex $argv 1]
#		puts "Command-line debug flag: $debug"
	}

}
if {![info exists port]} {
	set port 2540
}
if {![info exists debug]} {
	jtag_debug_mode 0
} else {
	jtag_debug_mode $debug
	unset debug
}

# -----------------------------------------------------------------
# Start-up message
# -----------------------------------------------------------------
#
if {[is_system_console]} {
	set tool "system console"
} else {
	set tool "quartus_stp"
}
if {![is_debug_mode]} {
	puts [format "\nJTAG server running under %s\n" $tool]
} else {
	puts [format "\nJTAG server running in debug mode under %s\n" $tool]
}

if {[is_system_console]} {
	if {[has_fileevent]} {
		puts "This version of SystemConsole ([get_version]) supports fileevent."
		puts "The server can support multiple clients.\n"
	} else {
		puts "This version of SystemConsole ([get_version]) does not support fileevent."
		puts "The server can only support a single client.\n"
	}
}

# Check that the JTAG device exists
# * The Quartus tools are pretty bad about multiple accesses
#   to the JTAG hardware, so this command may hang if the
#   server is started while another is already running.
if {![is_debug_mode]} {
	puts "Open JTAG to access the JTAG-to-Avalon-MM master\n"
	jtag_open
}

# -----------------------------------------------------------------
# Start the server and wait for clients
# -----------------------------------------------------------------
#
puts "Start the server on port $port\n"
server_listen $port

puts "Wait for clients\n"
vwait forever
