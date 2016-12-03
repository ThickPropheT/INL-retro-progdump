#ifndef _dump_h
#define _dump_h

#include <avr/io.h>
#include "types.h"
#include "logic.h"
#include "usb.h"
#include "nes.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

uint8_t dump_page( buffer *buff ) ;

#endif