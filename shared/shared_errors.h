#ifndef _shared_errors_h
#define _shared_errors_h

#define SUCCESS 			0
#define GEN_FAIL 			0xFF

//#define FALSE				0
//#define NILL				0

//greater than 128 are possible avr return codes
#define ERR_UNKN_DICTIONARY 		128
#define ERR_BAD_PP_OP_MINMAX 		129
#define ERR_BAD_IO_OP_MINMAX 		130
#define ERR_BAD_NES_OP_MINMAX 		131
#define ERR_BAD_SNES_OP_MINMAX 		132
#define ERR_BAD_BUFF_OP_MINMAX 		133
#define ERR_BUFN_DOES_NOT_EXIST 	134
#define ERR_BAD_OPER_OP_MINMAX 		135


//#define ERR_UNKN_PP_OPCODE_ONLY 	140
//#define ERR_UNKN_PP_OPCODE_8BOP 	141
//#define ERR_UNKN_PP_OPCODE_16BOP 	142
//#define ERR_UNKN_PP_OPCODE_24BOP 	143
//#define ERR_UNKN_PP_OPCODE_8BRV 	144
//
//#define ERR_UNKN_IO_OPCODE_ONLY 	150
//#define ERR_UNKN_IO_OPCODE_RTN		151
//
//#define ERR_UNKN_NES_OPCODE_24BOP 	160
//#define ERR_UNKN_NES_OPCODE_16BOP_8BRV 	161
//
////reserved libusb erro			165
//
//#define ERR_UNKN_SNES_OPCODE_24BOP 	170
//#define ERR_UNKN_SNES_OPCODE_24BOP_8BRV	171
//
//#define ERR_UNKN_BUFF_OPCODE_NRV	180
//#define ERR_UNKN_BUFF_OPCODE_RV		181
//#define ERR_UNKN_BUFF_OPCODE_BUFN_NRV	182
//
//#define ERR_BUFF_ALLOC_RANGE		190
//#define ERR_BUFF_STATUS_ALREADY_ALLOC	191
//#define ERR_BUFF_ID_ALREADY_ALLOC	192
//#define ERR_BUFF_RAW_ALREADY_ALLOC	193
//#define ERR_BUFF_ALLOC_SIZE_ZERO	194
//#define ERR_BUFF_UNSUP_MEM_TYPE		195
//
//#define ERR_OUT_CURLDBUF_STATUS		200
//#define ERR_OUT_CURLDBUF_TO_SMALL	201
//
//#define ERR_UNKN_OPER_OPCODE_NRV	210
//#define ERR_UNKN_OPER_OPCODE_RV		211
//
////max error number			255


#endif
