#ifndef _swim_h
#define _swim_h

#include "pinport.h"
#include "shared_dictionaries.h"
#include "shared_errors.h"

extern uint8_t	swim_pin;
extern GPIO_TypeDef  *swim_base;
extern uint16_t swim_mask;

//must match swim.s .equ statements!!!
#define SWIM_RD		0x01
#define SWIM_WR		0x02
//#define SWIM_RD_HS	0x11
//#define SWIM_WR_HS	0x12
#define SWIM_LS		0x00
#define SWIM_HS		0x10

uint8_t swim_call( uint8_t opcode, uint8_t miscdata, uint16_t operand, uint8_t *rdata );
void swim_activate();
void swim_reset();
//uint8_t swim_out(uint16_t stream, uint8_t len);
uint16_t swim_rotf(uint8_t speed, uint16_t addr);
uint8_t swim_wotf(uint8_t speed, uint16_t addr, uint8_t data);
uint16_t append_pairity(uint8_t n);

//assembly functions from swim.s
extern uint32_t swim_xfr( uint16_t data_pb, uint32_t spddir_len, GPIO_TypeDef *swim_base, uint16_t swim_mask);

#endif
