        AREA    MergeSort_M0, CODE, READONLY
        THUMB
        ENTRY
        EXPORT  main
        EXPORT  my_MergeSort
        EXPORT  my_Merge

main PROC

        ; assigning array values into registers 
        MOVS R0, #38     ; 0x26 (hexadecimal) 
        MOVS R1, #27     ; 0x1B
        MOVS R2, #43     ; 0x2B
        MOVS R3, #10     ; 0x0A
        MOVS R4, #55     ; 0x37
		

		
        ; adjusting left and right index of the array 
        MOVS R5, #0  	 ; l = 0
        MOVS R6, #4   	; r = 4
        
        BL my_MergeSort 	; branch to mergesort function with link, LR is updated with this line + 1 address 
		
		
		
stop    B       stop ; put breakpoint here to work
        ENDP  ; end of main function 
			


my_MergeSort PROC
        CMP R5, R6		; compare l and r, (do l - r and save the result to the flags)  
        BGE done_sort 	; if l >= r, exit the function (base case of the recursive function) 
        ; calculating middle index 
        SUBS R7, R6, R5		; r - l 
        LSRS R7, R7, #1		; (r-l)/2
        ADDS R7, R5, R7 	; m = l + (r-l)/2  
        ; pushing the l, r, m and LR values to the stack
        PUSH {R5, R6, R7, LR}  ; in the order of LR, R7, R6, R5 
        
        ; for the left part, setting the right index as middle 
        MOVS R6, R7		 ; r = m, so new call is like (A,l,m) from pseudocode perspective		
        BL my_MergeSort	 ; recursive left call 
        
        ; for the right part: setting the left index as m + 1 
        LDR R5, [SP, #8]	; SP+0=R5, SP+4=R6, SP+8=R7(m) -> load m to R7 (l=m)
        ADDS R5, R5, #1 	; l = m + 1 
        ; also setting the right index 
        LDR R6, [SP, #4] 	; r = r (from stack) 
        BL my_MergeSort		; recursive right call (A, m+1, r) 

        ; getting index values from stack for the merge part: 
        LDR R5, [SP, #0]	;  l
        LDR R6, [SP, #4]	;  r
        LDR R7, [SP, #8]	;  m

        BL my_Merge			; (A, l, m, r) 

        ; after each merge operation, continiue with the values in the stack   
        POP {R5, R6, R7, PC} ; in the order of R5, R6, R7, PC, so the values l,r,m,LR for the upper parts conserved and get back 		
		
		
done_sort 
        BX LR 
        
        ENDP ; end of myMergeSort function 


my_Merge PROC
        PUSH    {R0-R4} ; push array values to stack 
        SUB     SP, SP, #20 ; temporary buffer 
        
        ; initialize i, j, k, m, r
        MOVS    R0, R5          ; i = l (R0 -> left counter)
        MOVS    R1, R7          
        ADDS    R1, R1, #1      ; j = m + 1 (R1 -> right counter) 
        MOVS    R2, R5          ; k = l  (R2 -> array index) 
        MOVS    R3, R7          ; R3 -> m (middle bound) 
        MOVS    R4, R6          ; R4 -> r (right bound)

merge_loop
        ; check the loop conditions 
        CMP     R0, R3		
        BGT     copy_remaining_right ; if i > m, the left part finished early, branch and copy remainings
        CMP     R1, R4
        BGT     copy_remaining_left  ; if j > r, the right part finished early, branch and copy remainings


        ; compare the left and right part  
        ; Source[i] -> R7 
        MOVS    R5, R0  		; R5 = i          
        LSLS    R5, R5, #2      ; i * 4
        MOV     R6, SP			; 
        ADDS    R6, R6, #20     ; Source Base (SP+20)
        LDR     R7, [R6, R5]    ; R7 = Source[i]

        ; Source[j] -> R6 
        MOVS    R5, R1          ; R5 = j 
        LSLS    R5, R5, #2      ; j * 4
        MOV     R6, SP          ;
        ADDS    R6, R6, #20     ; Source Base (SP+20)
        LDR     R6, [R6, R5]    ; R6 = Source[j]

        ; choose the small one 
        CMP     R7, R6
        BLE     pick_left       ; if Source[i] <= Source[j] 

pick_right
        ; Temp[k] = Source[j] (the value in R6)
        MOVS    R5, R2			; R5 -> k
        LSLS    R5, R5, #2      ; k * 4
        MOV     R7, SP          ; Temp Base (SP)
        STR     R6, [R7, R5] 	; store the value in R6 to the temp buffer (SP + k*4)   
        
        ADDS    R1, R1, #1      ; j++
        ADDS    R2, R2, #1      ; k++
        B       merge_loop

pick_left
        ; Temp[k] = Source[i] (the value in R7)
        MOVS    R5, R2			; R5 -> k
        LSLS    R5, R5, #2      ; k * 4
        MOV     R6, SP          ; Temp Base (SP)
        STR     R7, [R6, R5]	; store the value in R7 to the temp buffer (SP + k*4) 

        ADDS    R0, R0, #1      ; i++
        ADDS    R2, R2, #1      ; k++
        B       merge_loop

copy_remaining_left
        CMP     R0, R3          ; check if i > m 
        BGT     copy_back_to_source  ; this loop ends and branh to label
        
        ; Source[i] -> Temp[k] 
		; actualy this part do the same thing like pick_left, the values are recalculated and assigned to relevant registers 
        MOVS    R5, R0
        LSLS    R5, R5, #2
        MOV     R6, SP
        ADDS    R6, R6, #20
        LDR     R7, [R6, R5]
        
        MOVS    R5, R2
        LSLS    R5, R5, #2
        MOV     R6, SP
        STR     R7, [R6, R5]
        
        ADDS    R0, R0, #1
        ADDS    R2, R2, #1
        B       copy_remaining_left

copy_remaining_right
        CMP     R1, R4          ; check if j > r 
        BGT     copy_back_to_source
        
        ; Source[j] -> Temp[k]
		; actualy this part do the same thing like pick_right, the values are recalculated and assigned to relevant registers 
        MOVS    R5, R1
        LSLS    R5, R5, #2
        MOV     R6, SP
        ADDS    R6, R6, #20
        LDR     R7, [R6, R5]
        
        MOVS    R5, R2
        LSLS    R5, R5, #2
        MOV     R6, SP
        STR     R7, [R6, R5]
        
        ADDS    R1, R1, #1
        ADDS    R2, R2, #1
        B       copy_remaining_right

copy_back_to_source
        ; get the  l and r index from stack 
        ; SP + 20 (Temp) + 20 (Source) = 40. byte (stack frame of my_MergeSort)
        LDR     R0, [SP, #40]   ; original l
        LDR     R1, [SP, #44]   ; original r


copy_loop
        CMP     R0, R1          ; check if k > r 
        BGT     done_merge      ; done
        
        ; get Temp[k] 
        MOVS    R5, R0          ; k
        LSLS    R5, R5, #2		; R5 = k*4
        MOV     R6, SP			
        LDR     R7, [R6, R5]    ; load the value in the address SP + k*4 into R7 
        
        ; write Temp[k] to Source[k] 
        MOV     R6, SP
        ADDS    R6, R6, #20		; R6 = SP + 20
        STR     R7, [R6, R5]	; store R7 value into SP + 20 + offset(k*4) 
        
        ADDS    R0, R0, #1      ; k++
        B       copy_loop

done_merge
        ADD     SP, SP, #20     ; deallocate the temp buffer
        POP     {R0-R4}         ; update the registers r0-r4 with the new ordered values
        BX      LR              ; YOU CAN PUT A BREAKPOINT HERE TO OBTAIN REGISTER VALUES R0-R4 AFTER EACH MERGE OPERATION
        ENDP   ; end of myMerge function 



        END