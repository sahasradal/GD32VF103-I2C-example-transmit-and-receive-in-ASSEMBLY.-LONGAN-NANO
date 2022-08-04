include gd32vf103.asm
RAM = 0x20000000
MEM_SIZE = 0x8000
STACK = 0x20008000
#slave_address = 0x20
#buffer = 0x20000010
#system clock is internal RC oscillator 8mhz

#==============================================
sp_init:
    li sp, STACK		# initialize stack pointer
        
#==============================================    
#I2C0_SCL = PB6			# I2C0  clock on pb6 (reccomended external pullup 4.7k)
#I2C0_SDA = PB7			# I2C0  data on pb7  (reccomended external pullup 4.7k)
#=================================================


I2C_INIT:

#Enable portA and portB clocks
        
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
	li a1,((GPIO_MODE_PP_50MHZ << 4 | GPIO_MODE_PP_50MHZ << 8)) 	# pushpull @ 50mhz speed
	sw a1,GPIO_CTL0_OFFSET(a0)
	li a1,(1 << 2 | 1 << 1)						# set PA1 & PA2 high (off as led groud driven)
	sw a1,GPIO_BOP_OFFSET(a0) 
    
# GPIOB PB7 & PB6 configuring as  AF open drain	
    	li s2, GPIO_BASE_ADDR_B
    	li a1,((1 << 7) | (1 << 6))					# set PB7 & PB6 high
    	sw a1,GPIO_BOP_OFFSET(s2)			
    	li a1, ((GPIO_MODE_AF_OD_50MHZ << 28) | (GPIO_MODE_AF_OD_50MHZ << 24)) # alternate function ,open drain @ 50mhz for I2C
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
	
	call I2C_BUSY			# check weather I2C is busy ,wait till free
	call I2C_START			# send start condition on I2C bus
jj:
        li a0, slave_address		# load register a0 with slave address (write), data to be sent is loaded in a0
	call SEND_ADDRESS		# call subroutine to send address
WL:
	li a0,0x35			# load a0 with 0x35 (sample data) to be transmitted on bus
	call I2C_WRITE			# call subroutine to transmit value loaded in a0
	call I2C_TX_COMPLETE		# call subroutine that checks the last data byte is transmitted and complete, called before stop
	call I2C_STOP			# call subroutine that stops I2C transmission
end:
	j end				# end of program

####----I2C--FUNCTIONS-----------------------------------------------------------------------------

I2C_START:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
	ori a3,a3, (1<<ACKEN) | (1<<START) 		# set start bit and ack enable bit
	sw a3, I2C_CTL0_OFFSET(a5) 			# store in I2C_CTL0 register
	ret						# return to caller

I2C_WRITE:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)			# copy I2C status0 register to a3
	andi a3,a3,(1<<TBE)				# and contents of a3 with TBE bit , if set transmission buffer empty
	beqz a3, I2C_WRITE				# wait till TBE is set (loop if a3 is 0)
	sw a0, I2C_DATA_OFFSET(a5)			# store data in a0 to I2C data register once TBE flag is set above
W1:
	lw a3, I2C_STAT0_OFFSET(a5)			# copy I2C status0 register to a3
	andi a3,a3,(1<<BTC)				# and a3 with BTC bit , if set transmission complete , if 0 transmission ogoing
	beqz a3, W1					# loop to label W1 if anding result of a3 is 0, if not 0 BTC set and transmission complete
	ret						# return to caller

SEND_ADDRESS:
	li a5, I2C0_BASE_ADDRESS			
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<SBSEND)				# check SBSEND bit is set , if start condition was sent by master SBSEND bit will be set
	beqz a3, SEND_ADDRESS				# loop till SBSEND bit is set
A1:
	sw a0, I2C_DATA_OFFSET(a5)			# store write address of slave loaded in a0 to I2C data register
A2:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<ADDSEND)				# check ADDSEND bit is set by anding contents of I2C_STAT0 register, if set address transmission complete
	beqz a3, A2					# if a3 is 0 loop till ADDSEND bit is set
#	ret
CLEAR_ADDSEND:						# this part clears the ADDSEND bit by reading first status0 register then status1 register
#	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)			# read stat0 register
	lw a3, I2C_STAT1_OFFSET(a5)			# read stat1 register
	ret						# return to caller

CLEAR_ACKEN:						# subroutine to clear ACKEN bit in I2CCTL0 register
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)			# copy to a3 contents of I2C_CTL0 rgister
	andi a3,a3,~(1<<ACKEN)				# and with 0 shifted to ACKEN bit
	sw a3, I2C_CTL0_OFFSET(a5)			# write back to register
	ret						# return to caller

I2C_TX_COMPLETE:					# subroutine checks weather I2C transmission is complete
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<TBE)				# check TBE is set 
	beqz a3, I2C_TX_COMPLETE			# if not wait by looping to label I2C_TX_COMPLETE 
	ret						# return to caller

I2C_STOP:						# subroutine to stop I2C transmission
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
	ori a3,a3,(1<<STOP)				# set STOP bit in I2C_CTL0 register
	sw a3, I2C_CTL0_OFFSET(a5)
	ret						# return to caller

I2C_READ:  						# (subroutine for single byte reception)
	li t1,buffer					# load address of memory location with label buffer
	call SEND_ADDRESS     				# (slave address + read)
	call CLEAR_ACKEN				# call subroutine to clear ACKEN bit
	call CLEAR_ADDSEND				# call subroutine to clear ADDSEND bit
	call I2C_STOP					# call subroutine to set STOP bit
R1:
	lw a3, I2C_STAT0_OFFSET(a5)			# copy contents of I2C_STAT0 register to a3
	andi a3,a3,(1<<RBNE)				# and a3 with RBNE bit mask (receive buffer not empty)
	beqz a3,R1					# if a3 is 0 wait by looping to R1 label until RBNE is set
	lw a0, I2C_DATA_OFFSET(a5) 			# read data byte from I2C data register
	sw a0, 0(t1)					# store byte in a0 to memory location buffer pointed by t0 register offset 0
	ret						# return to caller


I2C_READ_MULTI:						# subroutine to receive 2 or more bytes
	li t1,buffer					# load address of memory location with label buffer
	li t3,2						# load t3 with compare value 2 (last 2 bytes count of message to be received)
	li t0,10                        		# number of bytes to be received
	call SEND_ADDRESS     		                # (slave address + read)
	call CLEAR_ADDSEND				# call subroutine to clear ADDSEND bit 
R2:
	lw a3, I2C_STAT0_OFFSET(a5)			# copy to a3 contents of I2C_STAT0
	andi a3,a3,(1<<RBNE)				# and a3 with RBNE bit mask
	beqz a3,R2					# if RBNE not set loop to R3 till it sets
	lw a0, I2C_DATA_OFFSET(a5) 			# read data byte from I2C data register
	sw a0, 0(t1)					# store byte in a0 to memory location buffer
	addi t1,t1,1					# increase buffer address + 1
	addi t0,t0,-1			      		# decrease counter of received bytes
	bleu t0,t3,BYTES2				# branch to label BYTES2 if t0 is equal or lower than t2 (t2 = 2) , if condition meets we have reached last 2 bytes 
	j R2						# if not reached last 2 bytes jump back to R2 to receive bytes
BYTES2:							# reach here if the read has reached last 2 bytes of the message
	lw a3, I2C_STAT0_OFFSET(a5)			# copy to a3 I2C_STAT0 register
	andi a3,a3,(1<<RBNE)				# check RBNE bit is set by anding a3
	beqz a3,BYTES2					# wait till RBNE is set by looping
	lw a0, I2C_DATA_OFFSET(a5) 			# read data byte from I2C data register
	sw a0, 0(t1)					# store byte in a0 to memory location buffer
	addi t1,t1,1			  		# increase buffer address + 1
	call CLEAR_ACKEN				# clear ACKEN bit so that master will send NAK to stop slave from sending data after next byte
	call I2C_STOP					# set STOP bit to terminate I2C operation after next byte (last one)
BYTES1:
	lw a3, I2C_STAT0_OFFSET(a5)			# copy I2C_STAT0 to a3
	andi a3,a3,(1<<RBNE)				# check RBNE bit is set by anding a3
	beqz a3,BYTES1					# sit in tight loop till RBNE sets
	lw a0, I2C_DATA_OFFSET(a5) 			# read data byte from I2C data register
	sw a0, 0(t1)			     		# store byte in a0 to memory location buffer
	ret						# return to caller

I2C_BUSY:						# subroutine checks weather I2C is busy
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT1_OFFSET(a5)			# copy to a3 I2C_STAT1 register contents
	andi a3,a3, (1<<1) 				# and a3 with 1<<I2CBUSY
	bnez a3,I2C_BUSY 				# if not 0 loop till I2CBUSY bit becomes 0
	ret						# return to caller

#=================================================


#==========================================
delay:								# delay routine
	li t1,2000000						# load an arbitarary value 20000000 to t1 register		
loop:
	addi t1,t1,-1						# subtract 1 from t1
	bne t1,zero,loop					# if t1 not equal to 0 branch to label loop
	ret	

LED1ON:
	li a0,GPIO_BASE_ADDR_A					# GPIO A base address
	li a1, 1 << 1						# value of 1 lhs 2 OR 1 lhs 2 loaded in a1
	sw a1,GPIO_BC_OFFSET(a0)
	ret
LED1OFF:
	li a0,GPIO_BASE_ADDR_A					# GPIO A base address
	li a1, 1 << 1						# value of 1 lhs 2 OR 1 lhs 2 loaded in a1
	sw a1,GPIO_BOP_OFFSET(a0) 
	ret
LED2ON:
	li a0,GPIO_BASE_ADDR_A					# GPIO A base address
	li a1, 1 << 2 						# value of 1 lhs 2 OR 1 lhs 2 loaded in a1
	sw a1,GPIO_BC_OFFSET(a0) 
	ret
LED2OFF:
	li a0,GPIO_BASE_ADDR_A					# GPIO A base address
	li a1,(1 << 2)						# value of 1 lhs 2 OR 1 lhs 2 loaded in a1
	sw a1,GPIO_BOP_OFFSET(a0)
	ret


