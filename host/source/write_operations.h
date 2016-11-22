#ifndef _write_operations_h
#define _write_operations_h

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>
#include <libusb.h>

#include "usb_operations.h"
#include "shared_usb_commands.h"

//uncomment to DEBUG this file alone
#define DEBUG
//"make debug" to get DEBUG msgs on entire program
#include "dbg.h"


int write_file( libusb_device_handle *usbhandle, char *filename, char *ines_mapper, char *board_config );

#endif