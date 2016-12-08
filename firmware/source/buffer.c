#include "buffer.h"

//used to communicate to usbFunctionWrite which buffer object
//it should be filling
buffer *cur_usb_load_buff;
//used to determine number of bytes left to finish current
//OUT transfer utilized by usbFunctionWrite
//uint16_t incoming_bytes_remain;
uint8_t incoming_bytes_remain;

//min define of two buffers
static buffer buff0;
static buffer buff1;
#if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
static buffer buff2;
static buffer buff3;
#endif
#ifdef NUM_BUFFERS_8
static buffer buff4;
static buffer buff5;
static buffer buff6;
static buffer buff7;
#endif

//max raw buffer size is only limited based on buffer struct
//raw buffer memory to which smaller buffers will be created from
//set pointers and lengths to prevent buffer conflicts
static uint8_t raw_buffer[NUM_RAW_BANKS * RAW_BANK_SIZE];	//8 banks of 32bytes each 256Bytes total

//buffer status stores allocation status of each raw buffer 32Byte bank
static uint8_t raw_bank_status[NUM_RAW_BANKS]; 



/* Desc:Bridge between usb.c and buffer.c functions
 * 	usb.c calls this function providing setup packet info
 * 	usb.c also provides pointer to small 'rv' return value buffer of 8bytes
 * 	and pointer to rlen so buffer.c can decide wether to utilize the 
 * 	small 8byte generic return buffer or point usbMsgPtr to some larger buffer of sram.
 * 	this function interprets opcode type to call proper opcode switch function
 * Pre: opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * 	rlen updated to lenght of return data
 * 	rv[0] contains SUCCESS/ERROR code
 * 	rv buffer filled with return data for small data requests
 * Rtn: pointer to ram buffer to be returned over USB
 */
//uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint16_t *rlen)
uint8_t	* buffer_usb_call( setup_packet *spacket, uint8_t *rv, uint8_t *rlen)
{
	buffer *called_buff = &buff0; //used to point to buffer that was called based on opcode
	uint8_t *rptr = rv; //used for return pointer set to small rv buffer by default

	//some opcodes place buffer number in misc/data
	if ( (spacket->opcode > BUFFN_INMISC_MIN) && (spacket->opcode < BUFFN_INMISC_MAX) ) {
		switch ( spacket->miscdata ) {
			//2 buffers minimum support
			case 0:	called_buff = &buff0;	break;
			case 1:	called_buff = &buff1;	break;
#			if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
			//4-8 buffers
			case 2:	called_buff = &buff2;	break;
			case 3:	called_buff = &buff3;	break;
#			endif
#			ifdef NUM_BUFFERS_8
			//8 buffers
			case 4:	called_buff = &buff4;	break;
			case 5:	called_buff = &buff5;	break;
			case 6:	called_buff = &buff6;	break;
			case 7:	called_buff = &buff7;	break;
#			endif
			default:	//opcode sent for non-existent buffer 
				rv[RV_ERR_IDX] = ERR_BUFN_DOES_NOT_EXIST;
				//don't decode opcode, just return error to host
				*rlen = 1;
				return rptr;
		}
	}

	switch (spacket->opcode) {

		//now that buffer obtained, decode opcode and make call with called_buff if needed.
		case BUFF_OPCODE_NRV_MIN ... BUFF_OPCODE_NRV_MAX:
			rv[RV_ERR_IDX] = buffer_opcode_no_return( spacket->opcode, called_buff,
			spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
			*rlen = 1;
		break;

		case BUFF_PAYLOADN_MIN ... BUFF_PAYLOADN_MAX:
		//designate what buffer to fill with miscdata byte
			rptr = buffer_payload( spacket, called_buff, ~FALSE, rlen);
		//TODO
		break;

		case BUFF_OPCODE_RV_MIN ... BUFF_OPCODE_RV_MAX:
			rv[RV_ERR_IDX] = buffer_opcode_return( spacket->opcode, called_buff,
			spacket->operandMSB, spacket->operandLSB, spacket->miscdata, 
								&rv[RV_DATA0_IDX], rlen );	
			// set *rlen in function depending on opcode
		break;

		case BUFF_PAYLOAD_MIN ... BUFF_PAYLOAD_MAX:
		//let buffer.c decide what buffer to fill
			rptr = buffer_payload( spacket, called_buff, FALSE, rlen);
		//TODO
		break;

		//opcodes which include designation of which buffer is being called in lower bits of opcode
		case BUFF_OPCODE_BUFN_MIN ... BUFF_OPCODE_BUFN_MAX:
			//mask out last three bits to detect buffer being called based on opcode number
			switch ( (spacket->opcode) & 0x07) {
				//2 buffers minimum support
				case 0:	called_buff = &buff0;	break;
				case 1:	called_buff = &buff1;	break;
#				if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
				//4-8 buffers
				case 2:	called_buff = &buff2;	break;
				case 3:	called_buff = &buff3;	break;
#				endif
#				ifdef NUM_BUFFERS_8
				//8 buffers
				case 4:	called_buff = &buff4;	break;
				case 5:	called_buff = &buff5;	break;
				case 6:	called_buff = &buff6;	break;
				case 7:	called_buff = &buff7;	break;
#				endif
				default:	//opcode sent for non-existent buffer 
					rv[RV_ERR_IDX] = ERR_BUFN_DOES_NOT_EXIST;
					//don't decode opcode, just return error to host
					*rlen = 1;
					return rptr;
			}
			//now that we have pointer to buffer object call associated function
			switch ( spacket->opcode ) {
				case BUFF_OPCODE_BUFN_NRV_MIN ... BUFF_OPCODE_BUFN_NRV_MAX:
					rv[RV_ERR_IDX] = buffer_opcode_buffnum_no_return( 
					spacket->opcode, called_buff,
					spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
				break;
				case BUFF_OPCODE_BUFN_RV_MIN ... BUFF_OPCODE_BUFN_RV_MAX:
					//returnlength  = somereturn value( spacket->opcode, &called_buff,
					//spacket->operandMSB, spacket->operandLSB, spacket->miscdata );	
					//return pointer to buffer's data
					rptr = called_buff->data;
					*rlen = (spacket->wLength);
				break;
				case BUFF_PAYLOAD0 ... BUFF_PAYLOAD7:
					rptr = buffer_payload( spacket, called_buff, ~FALSE, rlen);
				break;
				default: 
					rv[RV_ERR_IDX] = ERR_BAD_BUFF_OP_MINMAX;
			}
		break;

		default:	//nes opcode min/max definition error 
			rv[RV_ERR_IDX] = ERR_BAD_BUFF_OP_MINMAX;
	}

	return rptr;
}



/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_buffer.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_BUFF_OPCODE_NRV if opcode not present.
 */
uint8_t buffer_opcode_no_return( uint8_t opcode, buffer *buff, 
				uint8_t operMSB, uint8_t operLSB, uint8_t miscdata )
{
	switch (opcode) { 
		case RAW_BUFFER_RESET:	
			raw_buffer_reset();	
			break;
		case SET_MEM_N_PART:	
			buff->mem_type = operMSB;
			buff->part_num = operLSB;
			break;
		case SET_MULT_N_ADDMULT:	
			buff->multiple = operMSB;
			buff->add_mult = operLSB;
			break;
		case SET_MAP_N_MAPVAR:	
			buff->mapper = operMSB;
			buff->mapvar = operLSB;
			break;
		case SET_FUNCTION:	
			buff->function = operLSB;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BUFF_OPCODE_NRV;
	}
	
	return SUCCESS;

}

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_buffer.h is used in both host and fw to ensure opcodes/names align
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_BUFF_OPCODE_NRV if opcode not present.
 */
uint8_t buffer_opcode_return( uint8_t opcode, buffer *buff, 
				uint8_t operMSB, uint8_t operLSB, uint8_t miscdata, 
				//uint8_t *rvalue, uint16_t *rlength )
				uint8_t *rvalue, uint8_t *rlength )
{
	switch (opcode) { 
		case RAW_BANK_STATUS:	
				*rvalue = raw_bank_status[operLSB];	
				*rlength += 1;
			break;
		case GET_PRI_ELEMENTS:	
				rvalue[0] = buff->last_idx;
				rvalue[1] = buff->status;
				rvalue[2] = buff->cur_byte;
				rvalue[3] = buff->reload;
				rvalue[4] = buff->id;
				rvalue[5] = buff->page_num;	//pretty sure this assigns next line too
				rvalue[6] = (buff->page_num>>8);//little endian
				*rlength += 7;
			break;
		case GET_SEC_ELEMENTS:	
				rvalue[0] = buff->mem_type;
				rvalue[1] = buff->part_num;
				rvalue[2] = buff->multiple;
				rvalue[3] = buff->add_mult;
				rvalue[4] = buff->mapper;
				rvalue[5] = buff->mapvar;
				rvalue[6] = buff->function;
				*rlength += 7;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BUFF_OPCODE_NRV;
	}
	
	return SUCCESS;

}

/* Desc:Function takes an opcode which was transmitted via USB
 * 	then decodes it to call designated function.
 * 	shared_dict_buffer.h is used in both host and fw to ensure opcodes/names align
 * 	This function is for opcodes which use their opcode lower bits to
 * 	denote which buffer to be operated on.
 * Pre: Macros must be defined in firmware pinport.h
 * 	opcode must be defined in shared_dict_buffer.h
 * Post:function call complete.
 * Rtn: SUCCESS if opcode found, ERR_UNKN_BUFF_OPCODE_BUFN_NRV if opcode not present.
 */
uint8_t buffer_opcode_buffnum_no_return( uint8_t opcode, buffer *buff, 
					uint8_t operMSB, uint8_t operLSB, uint8_t miscdata )
{
	switch (opcode) { 
		case ALLOCATE_BUFFER0 ... ALLOCATE_BUFFER7:	
			return allocate_buffer( buff, operMSB, operLSB, miscdata );
			//uint8_t allocate_buffer( *buff, new_id, base_bank, num_banks )
			break;
		case SET_RELOAD_PAGENUM0 ... SET_RELOAD_PAGENUM7:	
			buff->reload = miscdata; 
			buff->page_num = (operMSB<<8);
			buff->page_num |= operLSB;
			break;
		default:
			 //opcode doesn't exist
			 return ERR_UNKN_BUFF_OPCODE_BUFN_NRV;
	}
	
	return SUCCESS;

}

/* Desc:
 * Pre: 
 * Post:
 * Rtn: 
 */
uint8_t * buffer_payload( setup_packet *spacket, buffer *buff, uint8_t hostsetbuff, uint8_t *rlength )
{

	uint8_t *rtnpointer = buff0.data;	//default to remove warnings..
	uint8_t endpoint = (spacket->bmRequestType & ENDPOINT_BIT);

	//return length and incoming_bytes_remain only depends on endpoint direction
	if ( endpoint == ENDPOINT_IN) {
		//read/dump from device to host
		*rlength = (spacket->wLength); 
	} else { //write to device from host
		//return USB_NO_MSG to get usbFunctionWrite
		//called on incoming packets
		*rlength = USB_NO_MSG;
		incoming_bytes_remain = (spacket->wLength); 
	}

	//buffer in use depends on opcode which was decoded prior to calling into hostsetbuff
	//if buffer number not designated by host buffer.c gets to decide
	if ( hostsetbuff != ~FALSE ) {
		//buffer.c gets to decide buffer in use
		//TODO implement some fancy double buffering code
		//for now just designate buffer 0
		if ( endpoint == ENDPOINT_IN) {
			//reads
			rtnpointer = buff0.data;
			buff0.status = USB_UNLOADING;
		} else {//writes
			cur_usb_load_buff = &buff0;
			buff0.status = USB_LOADING;
		}
		buff0.cur_byte = 0;

	} else { //host determined the buffer to use
		if ( endpoint == ENDPOINT_IN) {
			//reads
			rtnpointer = buff->data;
			buff->status = USB_UNLOADING;
		} else {//writes
			cur_usb_load_buff = buff;
			buff->status = USB_LOADING;
		}
		buff->cur_byte = 0;
	}

	//now only thing left to do is stuff 2 bytes from setup packet into the buffer if designated by the opcode
	if ( (spacket->opcode == BUFF_OUT_PAYLOAD_2B_INSP)
	   ||(spacket->opcode == BUFF_OUT_PAYLOADN_2B_INSP) ) {
	//operandMSB:LSB actually contains first 2 bytes
	//these two bytes don't count as part of transfer OUT byte count
	//but they do count as part of buffer's byte count.
		cur_usb_load_buff->data[0] = spacket->operandMSB;
		cur_usb_load_buff->data[1] = spacket->operandLSB;
		cur_usb_load_buff->cur_byte += 2;
	}

	return rtnpointer;

}

/* Desc:Blindly resets all buffer allocation and values
 * 	Host instructs this to be called.
 * Pre: static instantitions of raw_buffer, raw_bank_status, and buff0-7
 * Post:all raw buffer ram unallocated
 * 	buffer status updated to UNALLOC
 * Rtn:	None
 */
void raw_buffer_reset( )
{
	uint8_t i;

	//unallocate raw buffer space
	for( i=0; i<NUM_RAW_BANKS; i++) {
		raw_bank_status[i] = UNALLOC;
	}

	//unallocate all buffer objects
	//set buffer id to UNALLOC
//min 2 buffers
	buff0.status = UNALLOC;
	buff1.status = UNALLOC;
	buff0.id = UNALLOC;
	buff1.id = UNALLOC;
// 4-8 buffers
#if ( defined(NUM_BUFFERS_4) || (defined(NUM_BUFFERS_8)) )
	buff2.status = UNALLOC;
	buff3.status = UNALLOC;
	buff2.id = UNALLOC;
	buff3.id = UNALLOC;
#endif	//8 buffers
#ifdef NUM_BUFFERS_8
	buff4.status = UNALLOC;
	buff5.status = UNALLOC;
	buff6.status = UNALLOC;
	buff7.status = UNALLOC;
	buff4.id = UNALLOC;
	buff5.id = UNALLOC;
	buff6.id = UNALLOC;
	buff7.id = UNALLOC;
#endif

}

/* Desc:Embeded subtitute for malloc of a buffer object
 * 	Host instructs this to be called so the host
 * 	is in charge of what buffers are for what
 * 	and how things are used.  This function does
 * 	keep track of each bank of the raw buffer.
 * 	It will not allocate buffer space and return error
 * 	if host is trying to allocate buffer on top of 
 * 	another buffer or bank already allocated.
 * 	pass in pointer to buffer object to be allocated
 * 	pass base bank number and number of banks in buffer
 * 	This function works with various sizes of raw buffer
 * 	as it works based on NUM_RAW_BANKS and RAW_BANK_SIZE
 * Pre: static instantitions of raw_buffer raw_bank_status,
 * 	and buff0-7 above.
 * 	Buffer must be unallocated.
 * 	new id cannot be 0xFF/255 "UNALLOC"
 * 	bank allocation request can't go beyond raw ram space
 * Post:section of raw buffer allocated for host use
 * 	status of raw buffer updated to prevent future collisions
 * 	bank status byte contains buffer's id
 * 	buffer status updated from UNALLOC to EMPTY
 *	buffer size set according to allocation
 * 	all other buffer values cleared to zero
 * Rtn:	SUCCESS or ERROR code if unable to allocate
 */
uint8_t allocate_buffer( buffer *buff, uint8_t new_id, uint8_t base_bank, uint8_t num_banks )
{
	uint8_t i;

	//check incoming args
	if ( (base_bank+num_banks) > NUM_RAW_BANKS ) {
		//trying to allocate SRAM past end of raw_buffer
		return ERR_BUFF_ALLOC_RANGE;
	}
	if ( (num_banks) == 0  ) {
		//trying to allocate buffer with zero banks
		return ERR_BUFF_ALLOC_SIZE_ZERO;
	}

	//check that buffer isn't already allocated
	if ( buff->status != UNALLOC) {
		return ERR_BUFF_STATUS_ALREADY_ALLOC;
	}
	if ( buff->id != UNALLOC) {
		return ERR_BUFF_ID_ALREADY_ALLOC;
	}

	//check that raw banks aren't allocated
	for ( i=0; i<num_banks; i++) {
		if ( raw_bank_status[base_bank+i] != UNALLOC ) {
			return ERR_BUFF_RAW_ALREADY_ALLOC;
		}
	}

	//seems that buffer and raw are free allocate them as requested
	buff->id = new_id;
	buff->status = EMPTY;
	//buff->size = num_banks * RAW_BANK_SIZE;	//16bit value (256 = 9bits)
	buff->last_idx = (num_banks * RAW_BANK_SIZE) - 1;	//give the last index of the array

	//zero out other elements
	buff->cur_byte = 0;
	buff->reload = 0;
	buff->page_num = 0;
	buff->mem_type = 0;
	buff->part_num = 0;
	buff->multiple = 0;
	buff->add_mult = 0;
	buff->mapper = 0;
	buff->function = 0;

	//set buffer data pointer to base ram address
	buff->data = &raw_buffer[base_bank*RAW_BANK_SIZE];

	//set bank status to bank's id
	for ( i=0; i<num_banks; i++) {
		raw_bank_status[base_bank+i] = new_id;
	}

	return SUCCESS;	

}

//check buffer status' and instruct them to 
//flash/dump as needed to keep data moving
void update_buffers() 
{
	uint8_t result = 0;
	buffer *buff = &buff0;

	//when dumping we don't actually know when the buffer has been fully
	//read back through USB IN transfer.  But we know when the next buffer
	//is requested to read back, so we'll dump the second page into the second buffer
	//after the first page has been requested for IN transfer
	//need to get data dumped before in transfer..
	
	//to start let's sense dumping operation by buffer status
	//host updates status of buffer, then we go off and dump as appropriate
	//might be best to add some opcode to kick things off.
	if ( buff->function == DUMPING ) {

		buff->cur_byte = 0;
		//to start lets just dump the first page of PRG-ROM
		result = dump_page( buff );

		if (result == SUCCESS) {
			buff->status = DUMPED;
		}
	
		//now it can be read back in next IN transfer
	}

	//for now lets use one buffer to flash a cartridge
	//later try a second one to double buffer, might not actually matter much..
//	buffer *buff = &buff0;
	
	//check if buffer is full and update status accordingly
	if (cur_usb_load_buff->last_idx == cur_usb_load_buff->cur_byte) {
		cur_usb_load_buff->status = USB_FULL;

	//update other buffer so it can be filled by incoming USB data now
	//if buffer size is smaller than data transfer lengths this must be done quickly
	//enough for usbFunction write to not notice
	} else {
		//if there are no full buffers yet simply exit
		//return;
	}
	
	//found a buffer that's full and ready to flash onto cart
	
	//set it's page number to the proper value
	//perhaps this should be done after it's flashed as we want to start at zero.
	
	//update any other necessary elements
	
	//send it off to it's flashing routine
	if ( buff->function == FLASHING ) {


		buff->cur_byte = 0;
		//to start lets just dump the first page of PRG-ROM
		result = flash_page( buff );

		if (result == SUCCESS) {
			buff->status = DUMPED;
		}
	
		//now it can be read back in next IN transfer
	}
	
	//now that it's flashed perform verifications if needed
	
	//adjust multiple/page num to program to another location if
	//buffer is supposed to be flashed to multiple locations
	
	//send it off to flash again as many times as needed

	//complete any remaining checks desired

	//set it's page number to the proper value
	//perhaps this should be done after it's flashed as we want to start at zero.
	
	//update it's status so buffer is ready for reuse.

}


