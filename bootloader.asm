                                                ;************************************************************************************;
                                                ;      Copyright (c) 2012-2016                           Mohamed El Sayed          *\;
                                                ;                -- All rights reserved -- Use at your own risk --                 *\;
                                                ;***********************************************************************************\;
                                                ;       File             : bootloader.asm                                          *\;
                                                ;       Built with       : NASM ver. 2.12.01                                       *\;
                                                ;       Building command : nasm -f bin bootloader.asm -o boot.bin                  *\;
                                                ;************************************************************************************;
      
JMP MAIN

WAIT_FOR_KEY:
MOV AH, 00H
INT 16H
RET

CLEAR:
MOV AH, 0H                       ;CHANGING THE VIDEO MODE TO CLEAR THE SCREEN 
MOV AL, 03H                      
INT 10H
RET

LOG_TO_HTS:
PUSH BX
PUSH AX
MOV BX, AX
MOV DX, 0
DIV WORD[ALL_SECTORS]
ADD DL, 01H
MOV CL, DL
MOV AX, BX
MOV DX, 0
DIV WORD [ALL_SECTORS]
MOV DX, 0 
DIV WORD[FACES]
MOV DH, DL
MOV CH, AL
POP AX
POP BX
MOV DL, BYTE [BOOT_DEVICE]
RET

ECHO:                   ;-=-=-=PRINTING FUNCTION =-=-=-;
LODSB                   ;MOV ONE CHAR FROM SI TO AL AND DELETE IT FROM SI
CMP AL, 0               ;CHECK IF THE VALUE IN AL=0, IF ITS ZERO THEN WE
JE DONE                 ;WE ARE DONE PRINTING, AND JUMP BACK TO THE MAIN FUNCTION
CMP AL, 59
JE NEWLINE
MOV AH, 0EH             ;THE FUNCTION CODE FOR PRINTING (TELETYPE PRINTING)
INT 10H                 ;BIOS CALL
JMP ECHO                ;IF WE ARRIVED TO THIS LINE THATS MEAN WE ARE NOT DONE WITH
                        ;PRINTING THE WHOLE STREING SO JUMP BACK AND COMPLETE THE PROCESS

DONE:                   ;LABEL CONTAINS ONE INSTRUCTION TO JUMP BACK TO THE LINE 
RET                     ;WHERE WE CALLED THE ECHO FUNCTION

NEWLINE:
PUSHA
MOV AH, 0EH
MOV AL, 13
INT 10H
MOV AL, 10
INT 10H 
POPA
RET

RESET_DRIVE:				                ;RESET FLOPPY DRIVE FUNCTION
MOV AX, 0       					;THE FUNCTION CODE TO RESET DRIVE
MOV DL, BYTE [BOOT_DEVICE]	                        ;DRIVE ID TO RESET
INT 13H
RET


MAIN:                            ;THE MAIN FUNCTION LABEL


;TO BEGIN LOADING EXTERNAL FILE LIKE KERNEL SOME THINGS MUST BE DONE LIKE :
;1- SETTING UP THE STACK
;2- SETTING UP THE SEGMENTS
;3- SPECIFY THE BOOT DRIVE

;SETTING UP THE STACK
CLI                             ;CLEAR INTERRUPTS TO SET THE SEGMENT
                  
XOR AX, AX                       ;SET THE BOTTOM OF THE STACK
MOV SS, AX
MOV SP, 0XFFFF                  ;SET THE TOP OF THE STACK
STI                             ;RESTORE THE INTERRUPTS

;SETTING UP THE SEGMENTS
MOV AX, 07C0H
MOV DS, AX
MOV ES, AX
;AFTER SETTING UP SEGMENTS AND STACK, YOU ARE FREE TO CODE WHAT EVER YOU WANT
;THE CPU WILL RECOGNISE YOUR CODE AS A BOOTLOADER

CALL CLEAR
MOV SI, WELCOME_MSG
CALL ECHO


MOV [BOOT_DEVICE], DL          ;SAVE THE DRIVE ID TO USE IT LATER


;WE WILL USE IN 13H TO LOAD ROOT DIR. THAT WE NEED TO LOAD THE FIRST SECTOR OF THE KERNEL
;THEN WE WILL LOAD FAT TO LOAD THE WHOLE KERNEL SINCE THE FILE LOAD PROCESS CONSISTS OF 3 STEPS
;1- LOAD THE FISRT SECTOR OF THE FILE
;2- LOAD THE WHOLE FILE AND COPY IT INTO RAM
;3- EXCUTE THE FILE
;THE ROOT DIR. AND FAT ARE LOCATED IN SOMEWHERE ON THE FLOPPY DRIVE AS FOLLOWS

;1- SETTING UP AND LOADING THE ROOT DIR.
MOV AH, 02H						;THE FUNCTION CODE FOR LOADING ROOT DIR.
MOV AL, 14						;THE SIZE OF THE ROOT DIR. THE ROOT DIR. = 14 AND WE WANT TO LOAD IT ALL SO AL=14
MOV BX, TEMP					        ;THE TEMP STORAGE FOR THE DATA WILL BE READED OR LOADED
MOV CH, 0 						;TRACK WE WANT TO LOAD, ITS TRACK 0 BEACUSE THE ROOT DIR. LOCATED THERE (CYLINDER)
MOV CL, 2						;SECTOR WE WANT TO LOAD, ITS SECTOR 2 BEACUSE THE ROOT DIR. LOCATED THERE
MOV DH, 1						;HEAD WE WANT TO LOAD, ITS HEAD 1 BEACUSE THE ROOT DIR. LOCATED THERE
PUSHA							;TO BE ABLE TO RETRY TO LOAD ROOT DIR. IF INT 13H FAILED
LOAD_RD:
INT 13H
JNC LOAD_RD_DONE			        	;IF WE ARRIVE HERE, THATS MEAN THAT THE ROOT DIR. LOADED SUCCESSFULLY
CALL RESET_DRIVE				        ;RESET FLOPPY FUNCTION CALL
JMP LOAD_RD						;RETRY IF INT 13H FAILED


LOAD_RD_DONE:
POPA
;NOW WE WILL SEARCH IN THE ROOT DIR. TABLE IF IT CONTAINS THE DESIRED FILE NAME WHICH IS KERNEL.BIN
;WE WILL USE CMPSB INSTRUCTION THAT COMPARES THE VALUE OF DS:SI AND ES:DI
;ES AND DS ARE ALREADY SET
;THE SEARCH WILL BE LIMITED TO SEARCH AMONG 11 BYTES BECAUSE THE FILE NAME IS 11 BYTES

MOV DI, TEMP					        ;THE RESULT WE GOT (THE ENTRY)
MOV CX, 224						;THE MAX. POSSIBLE FILE NUMBER THAT WE COULD HAVE IS 224 SO WE LIMIT THE SEARCH TO IT (THE VALUE THAT WILL BE DECREASED WHILE LOOPING)

FIND_KERNEL:
PUSH CX							;PUSH CX AND DI BECAUSE THEY HELD IMPORTANT DATA THAT WE DONT WANT TO LOSE
POP DX						
MOV SI, FILE_NAME				        ;THE VALUE THAT WE WILL COMPARE THE RESULT OF ROOT DIR. TO FIND
MOV CX, 11						;TO REPEATE THE SEARCH PROCESS 11 TIMES(THE FILE NAME LENGTH)
REP CMPSB						;COPMARES SI WITH DI

JE FOUND_KERNEL					        ;IF WO GO TO THE NEXT LINE, THAT MEANS THAT THE KERNEL IS NOT FOUNDED YET
;AND SINCE DI IS POINTS TO THE FIRST ENTRY, WE NEED TO MOVE TO THE NEXT ONE BY ADDING 32

ADD AX, 32
MOV DI, TEMP
ADD DI, AX
PUSH DX
POP CX

LOOP FIND_KERNEL
;IF WE ARE HERE, THEN THE KERNEL IS NOT EXISTS
MOV SI, FAILED_TO_LOAD_KERNEL
CALL ECHO
CLI
INT 18H							;CRASH AND HALT THE PROCESSOR


FOUND_KERNEL:                                           ;IF WE FOUND THE KERNEL WE WILL BE HERE
;NOW WE HAVE THE ENTRY POINT FOR THE KERNEL SAVED IN DL REGISTER
;WE GOT THE KERNEL FROM THE FIRST 11 BYTES SO WE NEED TO ADD 15 TO GET TO THE 26 BYTES
;THE FIRST SECTOR IS LOCATED AT 26 AND 27 SO WE MUST ADD 15 TO LOAD THE KERNEL IN THE FIRST SECTOR
MOV AX, WORD [DI+15]			                ;WORD ADDED TO COPY BOTH 26 AND 27 BYTES TO AX, THE WORD IS 2 BYTES
MOV [ENTERY_POINT], AX



;2- SETTING UP AND LOADING THE FAT
MOV AX, 1
MOV BX, TEMP					        ;THE TEMP STORAGE FOR THE DATA WILL BE READED OR LOADED
CALL LOG_TO_HTS
MOV AH, 2						;THE FUNCTION CODE FOR LOADING ROOT DIR.
MOV AL, 9						;THE SIZE OF THE ROOT DIR. THE ROOT DIR. = 14 AND WE WANT TO LOAD IT ALL SO AL=14
PUSHA							;TO BE ABLE TO RETRY TO LOAD ROOT DIR. IF INT 13H FAILED
LOAD_FAT:
INT 13H
JNC LOAD_FAT_DONE				        ;IF WE ARRIVE HERE, THATS MEAN THAT THE FAT LOADED SUCCESSFULLY
CALL RESET_DRIVE				        ;RESET FLOPPY FUNCTION CALL
JMP LOAD_FAT					        ;RETRY IF INT 13H FAILED


LOAD_FAT_DONE:					        ;IF LOADING FAT DONE SUCCESSFULLY, WE WILL BE HERE
MOV AH, 2
MOV AL, 1 
PUSH AX

LOAD_SECTOR:					        ;ROOT DIR. GIVES US A DATA SECTOR AND WE WANT A LOGICAL SECTOR, WE WILL DO IT HERE
MOV AX, WORD [ENTERY_POINT]
ADD AX, 31						;31 ADDED TO DONE THE CONVERTION

CALL LOG_TO_HTS					        ;COVERTS THE LOGICAL SECTORS INTO HEAD TRACK SECTORS
MOV AX, 2000H
MOV ES, AX
MOV BX, WORD[OFFSET_]
POP AX
PUSH AX

INT 13H
JNC GET_NEXT
CALL RESET_DRIVE
JMP LOAD_SECTOR

GET_NEXT:
MOV AX, [ENTERY_POINT]
MOV DX, 0
MOV BX, 6
MUL BX
MOV BX, 4
DIV BX
MOV SI, TEMP
ADD SI, AX
MOV AX, WORD[SI]

OR DX, DX
JZ EVEN

ODD:
SHR AX, 4
JMP SHORT COMP_SECTOR

EVEN:
AND AX, 0FFFH

COMP_SECTOR:
MOV WORD [ENTERY_POINT], AX
CMP AX, 0FF8H
JAE END
ADD WORD[OFFSET_], 512
JMP LOAD_SECTOR

END:
MOV SI, KERNEL_LOADED_MSG
CALL ECHO

CALL WAIT_FOR_KEY

POP AX
MOV DL, BYTE[BOOT_DEVICE]
JMP 2000H:0000H

OFFSET_					DW		0
ALL_SECTORS				DW 		18
FACES					DW		2
ENTERY_POINT			        DW		0
FAILED_TO_LOAD_KERNEL	                DB		"Error, Cannot Load The Kernel. Booting Process Aborted;",0
BOOT_DEVICE                             DB              0
FILE_NAME				DB		"KERNEL  BIN"           ;WE ARE USING FAT12 SO ANY FILE NAME MUST BE 11 BYTE
WELCOME_MSG                             DB              "Litesoft bootloader  Copyright (C) 2012-2016 By Mohamed El Sayed;",0
KERNEL_LOADED_MSG                       DB              "Kernel Loaded, Press Any Key To Continue...",0
TIMES	510 - ($-$$)	DB		0               ;LOOK FOR EVERY SINGLE EMPTY BIT AND FILL IT WITH ZERO
                                                        ;TILL THE BOOTLOADER SIZE BE 512 BYTE
DW	0xAA55                                          ;THE BOOT SIGNETUARE, ALWAYS THE SAME

TEMP: 							;HERE IN BYTE 513 WE HAVE SOME MEMORY THAT WILL NOT BE EXECUTED
;AND WE CAN USE IT AS A TEMP MEMORY
