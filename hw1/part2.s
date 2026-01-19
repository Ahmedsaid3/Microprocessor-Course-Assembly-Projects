        AREA    MergeSort_M0, CODE, READONLY
        THUMB
        ENTRY
        EXPORT  main
        EXPORT  my_MergeSort
        EXPORT  my_Merge

main    PROC

        ; take the base address of the array into R7
        LDR     R7, =MyArray     

        ; fill the array with test data
        ; Data: 13, 27, 10, 7, 22, 56, 28, 2
        
        MOVS    R0, #13
        STR     R0, [R7, #0]     ; Array[0] = 13
        
        MOVS    R0, #27
        STR     R0, [R7, #4]     ; Array[1] = 27 (Each int is 4 bytes, so offset increases by 4)
        
        MOVS    R0, #10
        STR     R0, [R7, #8]     ; Array[2] = 10
        
        MOVS    R0, #7
        STR     R0, [R7, #12]    ; Array[3] = 7
        
        MOVS    R0, #22
        STR     R0, [R7, #16]    ; Array[4] = 22
        
        MOVS    R0, #56
        STR     R0, [R7, #20]    ; Array[5] = 56
        
        MOVS    R0, #28
        STR     R0, [R7, #24]    ; Array[6] = 28
        
        MOVS    R0, #2
        STR     R0, [R7, #28]    ; Array[7] = 2
        

        ; set left and right indices
        MOVS    R5, #0           ; l = 0
        MOVS    R6, #7           ; r = 7
        
        BL      my_MergeSort  ; call my_MergeSort with l and r


        ; Load sorted array elements back into registers for verification
        LDR     R0, [R7, #0] ; 
        LDR     R1, [R7, #4]
        LDR     R2, [R7, #8]
        LDR     R3, [R7, #12]
        LDR     R4, [R7, #16]
        LDR     R5, [R7, #20]
        LDR     R6, [R7, #24]
        ; We load R7 last because it holds the address
        LDR     R7, [R7, #28]    ; Now R7 holds data, we lost the address (No problem, program ended)


stop    B       stop             ; put breakpoint here to work 
        ENDP    ; end of main function


my_MergeSort PROC
        ; Base case check if l >= r
        CMP     R5, R6
        BGE     done_sort

        ; Calculate middle index m using R3 register
        ; R7 cannot be used here as it holds the base address
        SUBS    R3, R6, R5      ; R3 = r - l
        LSRS    R3, R3, #1      ; R3 = (r - l) / 2
        ADD     R3, R5, R3      ; R3(m) = l + (r - l) / 2

        ; PUSH: Registers are stored in sorted order: R3, R5, R6, LR
        ; Stack Layout:
        ; [SP + 0] = R3 (m)
        ; [SP + 4] = R5 (l)
        ; [SP + 8] = R6 (r)
        ; [SP + 12] = LR
        ; Save current state (l,r,m, LR) to stack before recursive calls
        PUSH    {R5, R6, R3, LR}

        ; Recursive call for the left half
        ; Set new right boundary to m
        MOVS    R6, R3  ; r = m
        BL      my_MergeSort

        ; Recursive call for the right half
        ; Restore m and r from stack to calculate new boundaries
        LDR     R3, [SP, #0]    ; Load m 
        LDR     R6, [SP, #8]    ; Load r 
        
        ; Set new left boundary to m + 1
        MOVS    R5, R3
        ADDS    R5, R5, #1      ; l = m + 1
        BL      my_MergeSort

        ; Merge the sorted halves
        ; Restore original l, r, and m values from stack
        LDR     R3, [SP, #0]    ; m
        LDR     R5, [SP, #4]    ; l
        LDR     R6, [SP, #8]    ; r
        
        BL      my_Merge

        ; Restore registers and return to caller
        POP     {R5, R6, R3, PC}

done_sort
        BX      LR
        ENDP    ; end of my_MergeSort function



my_Merge PROC
        ; Save registers that will be used as scratch or counters
        PUSH    {R4-R6, LR}

        ; Allocate temporary buffer on stack for 8 elements
        SUB     SP, SP, #32

        ; Initialize indices
        ; R0 is i (left index), R1 is j (right index), R2 is k (buffer index)
        MOVS    R0, R5  ; i = l
        MOVS    R1, R3
        ADDS    R1, R1, #1  ; j = m + 1
        MOVS    R2, R5  ; k = l

merge_loop
        ; Check if left or right segments are finished
        CMP     R0, R3  ; check if i > m
        BGT     copy_remaining_right
        CMP     R1, R6  ; check if j > r
        BGT     copy_remaining_left

        ; Load value from left segment (Arr[i]) into R5
        MOVS    R4, R0
        LSLS    R4, R4, #2      ; i * 4
        LDR     R5, [R7, R4]    ; Load Arr[i]

        ; Load value from right segment (Arr[j]) into R4
        PUSH    {R5}            ; Temporarily save left value
        MOVS    R5, R1
        LSLS    R5, R5, #2      ; j * 4
        LDR     R4, [R7, R5]    ; Load Arr[j]
        MOV     R5, R4          ; Move right value to R5 for comparison
        POP     {R4}            ; Restore left value to R4
        
        ; Comparison: Left Value (R4) vs Right Value (R5)
        CMP     R4, R5
        BLE     pick_left

pick_right
        ; Store Right Value (R5) to Temp Buffer
        ; Calculate address in stack buffer
        MOVS    R4, R2
        LSLS    R4, R4, #2      ; k * 4
        ADD     R4, R4, SP      ; SP + k*4
        STR     R5, [R4]

        ADDS    R1, R1, #1      ; j++
        ADDS    R2, R2, #1      ; k++
        B       merge_loop

pick_left
        ; Store Left Value (R4) to Temp Buffer
        MOVS    R5, R2
        LSLS    R5, R5, #2      ; k * 4
        ADD     R5, R5, SP      ; SP + k*4
        STR     R4, [R5]        

        ADDS    R0, R0, #1      ; i++
        ADDS    R2, R2, #1      ; k++
        B       merge_loop

copy_remaining_left
        CMP     R0, R3  ; check if i > m
        BGT     copy_back_to_memory
        
        ; Load Arr[i] from RAM
        MOVS    R4, R0
        LSLS    R4, R4, #2      ; i * 4
        LDR     R5, [R7, R4]    ; Load Arr[i]
        
        ; Store to Temp Buffer
        MOVS    R4, R2
        LSLS    R4, R4, #2      ; k * 4
        ADD     R4, R4, SP      ; SP + k*4
        STR     R5, [R4]
        
        ADDS    R0, R0, #1      ; i++
        ADDS    R2, R2, #1      ; k++
        B       copy_remaining_left

copy_remaining_right
        CMP     R1, R6  ; check if j > r
        BGT     copy_back_to_memory   
        
        ; Load Arr[j] from RAM
        MOVS    R4, R1
        LSLS    R4, R4, #2      ; j * 4
        LDR     R5, [R7, R4]    ; Load Arr[j]
        
        ; Store to Temp Buffer
        MOVS    R4, R2
        LSLS    R4, R4, #2      ; k * 4
        ADD     R4, R4, SP      ; SP + k*4
        STR     R5, [R4]
        
        ADDS    R1, R1, #1      ; j++
        ADDS    R2, R2, #1      ; k++
        B       copy_remaining_right

copy_back_to_memory
        ; Restore original l and r values to define write range
        ; These values are retrieved from the stack frame of the caller
        ; Offset calculation: 32 (buffer) + 4 (l) + 4 (r) -> 40
        LDR     R0, [SP, #36]   ; Load original l
        LDR     R1, [SP, #40]   ; Load original r

write_loop
        CMP     R0, R1  ; check if k > r
        BGT     finish_merge

        ; Load value from Temp Buffer
        MOVS    R2, R0
        LSLS    R2, R2, #2      ; k * 4
        ADD     R2, R2, SP      ; SP + k*4
        LDR     R5, [R2]

        ; Move value to R4 for observation/debugging purposes
        MOV     R4, R5

        ; Store value from R4 to RAM
        MOVS    R2, R0
        LSLS    R2, R2, #2      ; k * 4

        STR     R4, [R7, R2]    ; Store back to Arr[k], YOU CAN PUT A BREAKPOINT ON THIS LINE TO OBTAIN R4 VALUES

        ADDS    R0, R0, #1      ; k++
        B       write_loop

finish_merge
        ; Deallocate temp buffer and restore registers
        ADD     SP, SP, #32
        POP     {R4-R6, PC}
        ENDP    ; end of my_Merge function



        AREA    MyData, DATA, READWRITE
        ALIGN
MyArray SPACE   32                  ; 8 eleman * 4 byte = 32 byte yer ayir


        END
