include gd32vf103.asm
RAM = 0x20000000
MEM_SIZE = 0x8000
STACK = 0x20008000
#slave_address = 0x20
slave_address_read = 0x21

#buffer = 0x20000010
#==============================================
sp_init:
    li sp, STACK			# initialize stack pointer
        
#==============================================    
#I2C0_SCL = PB6				# I2C0  clock on pb6 (reccomended external pullup 4.7k)
#I2C0_SDA = PB7				# I2C0  data on pb7  (reccomended external pullup 4.7k)
#=================================================

I2C_INIT:

#Enable portA and portb clocks
        
    #RCU->APB2EN |= RCU_APB2EN_PAEN | RCU_APB2EN_PBEN;
    	li s0, RCU_BASE_ADDR
    	lw a5, RCU_APB2EN_OFFSET(s0)
    	ori a5, a5, ( (1<<RCU_APB2EN_PAEN_BIT) | (1<<RCU_APB2EN_PBEN_BIT))
    	sw a5, RCU_APB2EN_OFFSET(s0)

#Enable alternate function clock in APB2 register
    
    #RCU->APB2EN |= RCU_APB2EN_AFEN ;
    	lw a4, RCU_APB2EN_OFFSET(s0)
    	li a5, (1<<RCU_APB2EN_AFEN_BIT) 
    	or a4, a4, a5
    	sw a4, RCU_APB2EN_OFFSET(s0)

#Enable I2C0 periphral clock in APB1 register
    
    #RCU->APB1EN |=  RCU_APB1EN_I2C0EN;
    	lw a4, RCU_APB1EN_OFFSET(s0)
    	li a5, (1<<21)        #(1<<RCU_APB1EN_I2C0EN_BIT)   #(1<<21)
    	or a4, a4, a5
    	sw a4, RCU_APB1EN_OFFSET(s0) 
  
#enable PA1 & PA2 for debugging with led
	li a0,GPIO_BASE_ADDR_A						# for debugging with led
	li a1,((GPIO_MODE_PP_50MHZ << 4 | GPIO_MODE_PP_50MHZ << 8)) 	# 
	sw a1,GPIO_CTL0_OFFSET(a0)
	li a1,(1 << 2 | 1 << 1)						# 
	sw a1,GPIO_BOP_OFFSET(a0) 
    
# GPIOB PB7 & PB6 configuring as  AF open drain	
    	li s2, GPIO_BASE_ADDR_B
    	li a1,((1 << 7) | (1 << 6))
    	sw a1,GPIO_BOP_OFFSET(s2)			
    	li a1, ((GPIO_MODE_AF_OD_50MHZ << 28) | (GPIO_MODE_AF_OD_50MHZ << 24))
    	sw a1, GPIO_CTL0_OFFSET(s2)
    

#I2C0 configuration  
    	li a5, I2C0_BASE_ADDRESS
    	lw a3, I2C_CTL0_OFFSET(a5)
    	li a2,(1<<SRESET)		# reset I2C
    	or a3,a3, a2
    	sw a3, I2C_CTL0_OFFSET(a5)
    	not a2,a2
    	and a3,a3,a2			# set I2C to normal
    	sw a3, I2C_CTL0_OFFSET(a5)  
    	li a5, I2C0_BASE_ADDRESS
    	lw a3, I2C_CTL1_OFFSET(a5)
    	ori a3,a3,(8<<0)		# input clock PCLK1 = 8mhz
    	sw a3, I2C_CTL1_OFFSET(a5)
    	lw a3, I2C_CKCFG_OFFSET(a5)
    	ori a3,a3,(40<<0)		#CCLK = 4000ns + 1000ns/ (1/8000000) =40  CCLK = Trise(SCL) + Twidth(SCL)/ Tpclk1
    	sw a3, I2C_CKCFG_OFFSET(a5) 
    	lw a3, I2C_RT_OFFSET(a5)
    	ori a3,a3,(9<<0)		#TRISE = ((1000ns/125ns)+1) = 9  TRISE = ((Tr(SCL)/Tpclk1) + 1)
    	sw a3, I2C_RT_OFFSET(a5)
    	lw a3, I2C_CTL0_OFFSET(a5)
    	ori a3,a3,(1<<I2CEN)		#enable I2C
    	sw a3, I2C_CTL0_OFFSET(a5)
    	lw a3, I2C_CTL0_OFFSET(a5)
    	ori a3,a3, (1<<ACKEN)	
    	sw a3, I2C_CTL0_OFFSET(a5)

	
	
main_loop:
	li t0,init_ar1000	# address of array
	li t1,18		# number of bytes/words
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
jj:
        li a0, slave_address	# load register a0 with slave address (write), data to be sent is loaded in a0
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x01		# load AR1000 register where the data to be written , slave will auto increment its pointer internally
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
initloop:
	lb t4,0(t0)		# lsb loaded in t4
	addi t0,t0,1		# increase pointer 1 byte
	lb t5,0(t0)		# msb loaded in t5
	addi t0,t0,1		# increase pointer 1 byte
	mv a0,t5		# move value in t5 to a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	mv a0,t4		# move value in t4 to a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	addi t1,t1,-1		# decrease message/array counter
	bnez t1,initloop	# loop till t1 is 0 , all bytes will be transmitted when 0
	call I2C_TX_COMPLETE	# call subroutine that all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	call delay		# approx 1 second delay
	
read_registers:			# procedure to read AR1000 slave registers (number of bytes to be read is modified inside the subroutine I2C_READ_MULTI
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0, slave_address	# load register a0 with slave address (write), data to be sent is loaded in a0
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x12		# load AR1000 register from where the data to be read , slave will auto increment its pointer internally	
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call I2C_START		# send start condition on I2C bus , same as repeat start for read operation 
	li a0, slave_address_read # load AR1000 address for read operation
	call I2C_READ_MULTI	# call sub routine to read multiple bytes, values are stored in buffer (memory located)



end:
	j end

####----I2C--FUNCTIONS-----------------------------------------------------------------------------

I2C_START:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
    	ori a3,a3, (1<<ACKEN) | (1<<START)	
    	sw a3, I2C_CTL0_OFFSET(a5)
	ret

I2C_WRITE:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<TBE)
	beqz a3, I2C_WRITE
	sw a0, I2C_DATA_OFFSET(a5)
W1:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<BTC)
	beqz a3, W1
	ret

SEND_ADDRESS:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<SBSEND)
	beqz a3, SEND_ADDRESS
	
A1:
	sw a0, I2C_DATA_OFFSET(a5)
A2:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<ADDSEND)
	beqz a3, A2
#	ret
CLEAR_ADDSEND:
#	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	lw a3, I2C_STAT1_OFFSET(a5)
	ret

CLEAR_ACKEN:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
	andi a3,a3,~(1<<ACKEN)
	sw a3, I2C_CTL0_OFFSET(a5)
	ret

I2C_TX_COMPLETE:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<TBE)
	beqz a3, I2C_TX_COMPLETE
	ret

I2C_STOP:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
	ori a3,a3,(1<<STOP)
	sw a3, I2C_CTL0_OFFSET(a5)
	ret

I2C_READ:  				#(single byte)
	li t1,buffer
	call SEND_ADDRESS     		#(slave address + read)
	call CLEAR_ACKEN
	call CLEAR_ADDSEND
	call I2C_STOP
R1:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,R1
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sw a0, 0(t1)		 	# store byte in a0 to memory location buffer
	ret	


I2C_READ_MULTI:
	li t1,buffer			# address of location buffer in SRAM
	li t3,2				# last 2 bytes compare value
	li t0,11                        # number of bytes to be received from AR1000
	call SEND_ADDRESS     		# (slave address + read)
	call CLEAR_ADDSEND
R2:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,R2
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sw a0, 0(t1)			# store byte in a0 to memory location buffer
	addi t1,t1,1			# increase buffer address + 1
	addi t0,t0,-1			# decrease counter of received bytes
	bleu t0,t3,BYTES2
	j R2
BYTES2:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,BYTES2
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sw a0, 0(t1)			# store byte in a0 to memory location buffer
	addi t1,t1,1			# increase buffer address + 1
	call CLEAR_ACKEN
	call I2C_STOP
BYTES1:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,BYTES1
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sw a0, 0(t1)			# store byte in a0 to memory location buffer
	ret

I2C_BUSY:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT1_OFFSET(a5)
	andi a3,a3, (1<<1) 		# 1<<I2CBUSY
	bnez a3,I2C_BUSY
	ret

#=================================================


#==========================================
delay:					# delay routine
	li t1,2000000			# load an arbitarary value 20000000 to t1 register		
loop:
	addi t1,t1,-1			# subtract 1 from t1
	bne t1,zero,loop		# if t1 not equal to 0 branch to label loop
ret	



init_ar1000:		# bronzebeard assembler method for arrays, GCC/GNU arrays differ
 
shorts	0x5B15     	# R1:  0101 1011 0001 0101 - Mono (D3), Softmute (D2), Hardmute (D1)  !! SOFT-MUTED BY DEFAULT !!
shorts	0xD0B9     	# R2:  1101 0000 1011 1001 - Tune/Channel
shorts	0xA010     	# R3:  1010 0000 0001 0000 - Seekup (D15), Seek bit (D14), Space 100kHz (D13), Seek threshold: 16 (D6-D0)
shorts	0x0780     	# R4:  0000 0111 1000 0000
shorts	0x28AB     	# R5:  0010 1000 1010 1011
shorts	0x6400     	# R6:  0110 0100 0000 0000
shorts	0x1EE7		# R7:  0001 1110 1110 0111
shorts	0x7141		# R8:  0111 0001 0100 0001 
shorts	0x007D		# R9:  0000 0000 0111 1101
shorts	0x82C6		# R10: 1000 0010 1100 0110 - Seek wrap (D3)
shorts	0x4E55		# R11: 0100 1110 0101 0101
shorts	0x970C		# R12: 1001 0111 0000 1100
shorts	0xB845		# R13: 1011 1000 0100 0101
shorts	0xFC2D		# R14: 1111 1100 0010 1101 - Volume control 2 (D12-D15)
shorts	0x8097		# R15: 1000 0000 1001 0111
shorts	0x04A1		# R16: 0000 0100 1010 0001
shorts	0xDF61		# R17: 1101 1111 0110 0001
shorts	0xFFFB    	# R0:  1111 1111 1111 1011

# Define register/bit arrays for particular functions
# hardmute_bit  = (1<<1) 	# Register 1 -  xxxx xxxx xxxx xxDx
# softmute_bit  = (1<<2)	# Register 1 -  xxxx xxxx xxxx xDxx
# seek_bit      = (1<<14)	# Register 3 -  xDxx xxxx xxxx xxxx
# seekup_bit    = (1<<15)	# Register 3 -  Dxxx xxxx xxxx xxxx
# tune_bit      = (1<<9) 	# Register 2 -  xxxx xxDx xxxx xxxx
# hiloctrl1_bit = (1<<2)	# Register 11 - xxxx xxxx xxxx xDxx
# hiloctrl2_bit = (1<<0)	# Register 11 - xxxx xxxx xxxx xxxD
# hiloside_bit  = (1<<15)	# Register 11 - Dxxx xxxx xxxx xxxx


