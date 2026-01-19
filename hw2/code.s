; BLG212E Assignment 2

; ----------------------------------------------------------------------------
; DATA SECTIONS
; ----------------------------------------------------------------------------
        AREA    myData, DATA, READONLY

;arr     DCD     0xA8, 0x14, 0x24, 0x32, 0x02, 0xFF ; Example Array
                                                   ; A8 -> Color 0x88
                                                   ; 14 -> Right, 4 steps
                                                   ; 24 -> Down, 4 steps
                                                   ; 32 -> Left, 2 steps ...

arr     DCD 0xA1, 0x15, 0x32, 0x27, 0x32, 0x14, 0xA0, 0x13, 0xA2, 0x11, 0x07, 0x32, 0x14, 0xA0, 0x11, 0xA3, 0x11, 0x27, 0x14, 0x07, 0xA0, 0x11, 0xA4, 0x14, 0x33, 0x27, 0x13, 0xA0, 0x11, 0xA5, 0x14, 0x03, 0x33, 0x04 , 0x13, 0xFF
                                        ; The input array containing commands
                                        ; 0xA_ -> Color change
                                        ; 0x1_ -> Move Right, etc.
                                        ; 0xFF -> End of data

        AREA    myDataRW, DATA, READWRITE
varx    DCD     0       ; Cursor X
vary    DCD     0       ; Cursor Y
varc    DCB     0       ; Color
vari    DCD     0       ; Array Index
varb    DCD     0       ; Data Ready Flag
curr_cmd DCD    0       ; Current Command


; ----------------------------------------------------------------------------
; CODE SECTION
; ----------------------------------------------------------------------------
        AREA    main, CODE, READONLY
        EXPORT  __main
        EXPORT  SysTick_Handler

__main
        ; Configure the SysTick Timer
        LDR     R0, =0xE000E014     ; Load address of SysTick Reload Value Register
        LDR     R1, =9999999        ; Load value for 1 second delay (10MHz clock)
        STR     R1, [R0]            ; Set the reload value
        
        LDR     R0, =0xE000E010     ; Load address of SysTick Control Register
        MOVS    R1, #7              ; Enable Timer, Interrupt, and System Clock
        STR     R1, [R0]            ; Start the timer
        
        CPSIE   I                   ; Enable global interrupts

Loop
        ; Main loop to wait for data from interrupt
        LDR     R0, =varb           ; Load address of the flag
        LDR     R1, [R0]            ; Read the flag value
        CMP     R1, #1              ; Check if flag is 1 (new data arrived)
        BNE     Loop                ; If not 1, keep waiting in the loop
        
        ; Read the new command
        LDR     R0, =curr_cmd       ; Load address of current command variable
        LDR     R1, [R0]            ; Load the command value into R1
        
        ; Check if it is a Color command or Move command
        CMP     R1, #0xA0           ; Compare with 0xA0
        BGE     CaseColor           ; If greater or equal, jump to color logic
        
        ; It is a move command
        BL      DoMove              ; Call the function to handle movement
        B       CmdDone             ; Jump to cleanup

CaseColor
        ; Handle color change (Format: 0xA8 -> Color 0x88)
        MOVS    R0, #0x0F           ; Prepare mask for lower nibble
        ANDS    R1, R1, R0          ; Mask R1 to get the color value (e.g., 8)
        
        LSLS    R0, R1, #4          ; Shift left by 4 to get upper part (e.g., 0x80)
        ADDS    R1, R1, R0          ; Add them together to get 0x88 format
        
        LDR     R0, =varc           ; Load address of color variable
        STRB    R1, [R0]            ; Store the new color byte
        
        B       CmdDone             ; Finished color change

CmdDone
        ; Reset the data ready flag
        LDR     R0, =varb           ; Load address of flag
        MOVS    R1, #0              ; Prepare 0 value
        STR     R1, [R0]            ; Set flag to 0
        B       Loop                ; Go back to main loop

; ----------------------------------------------------------------------------
; Function: DoMove
; Description: Loops for the length of the stroke. Uses Stack to save R0/R1.
; ----------------------------------------------------------------------------
DoMove  FUNCTION
        PUSH    {R0, R1, LR}        ; Save registers and LR to stack
        
        ; Extract length from the command
        LDR     R0, =curr_cmd       ; Get command address
        LDR     R0, [R0]            ; Load command
        MOVS    R1, #0x0F           ; Mask for lower nibble
        ANDS    R0, R0, R1          ; R0 now holds the length (loop counter)
        
        PUSH    {R0}                ; Save the counter to the stack
        
MoveLoop
        ; Check the loop counter
        LDR     R0, [SP]            ; Read counter from stack
        CMP     R0, #0              ; Check if counter is zero
        BEQ     MoveExitPop         ; If zero, exit the loop
        
        ; Get the direction from command
        LDR     R0, =curr_cmd       ; Get command address
        LDR     R0, [R0]            ; Load command
        LSRS    R1, R0, #4          ; Shift right to get direction (upper nibble)
        
        ; Call the appropriate move function
        CMP     R1, #0              ; Check if Up
        BEQ     CallUp              ; Jump to CallUp
        CMP     R1, #1              ; Check if Right
        BEQ     CallRight           ; Jump to CallRight
        CMP     R1, #2              ; Check if Down
        BEQ     CallDown            ; Jump to CallDown
        CMP     R1, #3              ; Check if Left
        BEQ     CallLeft            ; Jump to CallLeft
        B       DecrCounter         ; Safety jump

CallUp    BL GoUp                   ; Move cursor up
          B DoPaint                 ; Go to paint
CallRight BL GoRight                ; Move cursor right
          B DoPaint                 ; Go to paint
CallDown  BL GoDown                 ; Move cursor down
          B DoPaint                 ; Go to paint
CallLeft  BL GoLeft                 ; Move cursor left
          B DoPaint                 ; Go to paint

DoPaint
        BL      PaintPixel          ; Paint the current pixel
        
DecrCounter
        ; Decrement the loop counter on the stack
        LDR     R0, [SP]            ; Load counter from stack
        SUBS    R0, R0, #1          ; Decrement by 1
        STR     R0, [SP]            ; Store updated counter back to stack
        B       MoveLoop            ; Repeat the loop

MoveExitPop
        POP     {R0}                ; Remove counter from stack
        POP     {R0, R1, PC}        ; Restore registers and return
        ENDFUNC

; ----------------------------------------------------------------------------
; Direction Functions: Update X or Y with boundary checks
; ----------------------------------------------------------------------------
GoRight FUNCTION
        PUSH    {R0, R1, LR}        ; Save context
        LDR     R0, =varx           ; Load X address
        LDR     R1, [R0]            ; Load X value
        CMP     R1, #31             ; Check right boundary (width is 32)
        BGE     ExitRight           ; If out of bounds, do not update
        ADDS    R1, R1, #1          ; Increment X
        STR     R1, [R0]            ; Store new X
ExitRight POP   {R0, R1, PC}        ; Restore context and return
        ENDFUNC

GoLeft  FUNCTION
        PUSH    {R0, R1, LR}        ; Save context
        LDR     R0, =varx           ; Load X address
        LDR     R1, [R0]            ; Load X value
        CMP     R1, #0              ; Check left boundary
        BLE     ExitLeft            ; If out of bounds, do not update
        SUBS    R1, R1, #1          ; Decrement X
        STR     R1, [R0]            ; Store new X
ExitLeft POP    {R0, R1, PC}        ; Restore context and return
        ENDFUNC

GoDown  FUNCTION
        PUSH    {R0, R1, LR}        ; Save context
        LDR     R0, =vary           ; Load Y address
        LDR     R1, [R0]            ; Load Y value
        CMP     R1, #7              ; Check bottom boundary (height is 8)
        BGE     ExitDown            ; If out of bounds, do not update
        ADDS    R1, R1, #1          ; Increment Y
        STR     R1, [R0]            ; Store new Y
ExitDown POP    {R0, R1, PC}        ; Restore context and return
        ENDFUNC

GoUp    FUNCTION
        PUSH    {R0, R1, LR}        ; Save context
        LDR     R0, =vary           ; Load Y address
        LDR     R1, [R0]            ; Load Y value
        CMP     R1, #0              ; Check top boundary
        BLE     ExitUp              ; If out of bounds, do not update
        SUBS    R1, R1, #1          ; Decrement Y
        STR     R1, [R0]            ; Store new Y
ExitUp  POP     {R0, R1, PC}        ; Restore context and return
        ENDFUNC

; ----------------------------------------------------------------------------
; Function: PaintPixel
; Description: Calculates memory address and writes the color
; ----------------------------------------------------------------------------
PaintPixel FUNCTION
        PUSH    {R0, R1, LR}        ; Save registers
        
        ; Calculate Offset: (Y * 32)
        LDR     R0, =vary           ; Load Y address
        LDR     R1, [R0]            ; Load Y value
        LSLS    R1, R1, #5          ; Shift left by 5 (Multiply by 32)
        
        ; Add X to the offset
        LDR     R0, =varx           ; Load X address
        PUSH    {R1}                ; Save Y offset to stack temporarily
        LDR     R1, [R0]            ; Load X value into R1
        MOV     R0, R1              ; Move X to R0
        POP     {R1}                ; Restore Y offset
        
        ADDS    R1, R1, R0          ; R1 = (Y * 32) + X
        
        ; Add Base Address
        LDR     R0, =0x20001000     ; Load base address of the screen
        ADDS    R0, R0, R1          ; R0 is now the final address
        
        ; Get current color
        PUSH    {R0}                ; Save the pixel address
        LDR     R0, =varc           ; Load color variable address
        LDRB    R1, [R0]            ; Load the color byte
        POP     {R0}                ; Restore the pixel address
        
        STRB    R1, [R0]            ; Write color to memory (Paint)
        
        POP     {R0, R1, PC}        ; Restore registers and return
        ENDFUNC

; ----------------------------------------------------------------------------
; Interrupt Handler: Runs every 1 second
; ----------------------------------------------------------------------------
SysTick_Handler FUNCTION
        EXPORT  SysTick_Handler
        PUSH    {R0, R1, LR}        ; Save context
        
        LDR     R0, =vari           ; Load index variable address
        LDR     R1, [R0]            ; Load current index
        
        LDR     R0, =arr            ; Load array base address
        LDR     R1, [R0, R1]        ; Load data from array[index]
        
        CMP     R1, #0xFF           ; Check for end of data
        BEQ     StopTimer           ; If end, stop the timer
        
        LDR     R0, =curr_cmd       ; Load address to store command
        STR     R1, [R0]            ; Save the new command
        
        LDR     R0, =varb           ; Load flag address
        MOVS    R1, #1              ; Set flag to 1
        STR     R1, [R0]            ; Update flag
        
        LDR     R0, =vari           ; Load index address
        LDR     R1, [R0]            ; Load index value
        ADDS    R1, R1, #4          ; Increment index by 4 bytes
        STR     R1, [R0]            ; Update index variable
        B       ExitISR             ; Exit interrupt

StopTimer
        LDR     R0, =0xE000E010     ; Load SysTick Control address
        MOVS    R1, #0              ; Prepare 0 to disable
        STR     R1, [R0]            ; Stop the timer

ExitISR
        POP     {R0, R1, PC}        ; Restore context and return
        ENDFUNC

        END