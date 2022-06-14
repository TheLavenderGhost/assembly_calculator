;; crated by Katarzyna Sajchta
;; Kalkulator dla liczb calkowitych 4-bajtowych (32-bitowych) ze znakiem
;; +/- 2 147 483 647
;; dzialania: +, -, *, /, %, ^
;;
;; nasm -f elf64 calc.asm
;; ld calc.o -o calc
;; ./calc

segment .data
    a dd 0
    b dd 0
    operator db 0
    calcRes dd 0
    number dd 0
    tmp dd 0 
    opt dw 0

    newLine db 0Ah
    equality db "= "

    msg db 0,0,0,0,0,0,0,0,0,0,0,0Ah
    msgLen equ $-msg
    
    errMsgOperator db "Error: Nie rozpoznano znaku operacji.", 0Ah
    errMsgOperatorLen equ $-errMsgOperator
    errMsgZeroDiv db "Error: Dzielenie przez 0.", 0Ah
    errMsgZeroDivLen equ $-errMsgZeroDiv
    errMsgBadChar db "Error: Wprowadzono błędny znak.", 0Ah
    errMsgBadCharLen equ $-errMsgBadChar
    errMsgBigInNr db "Error: Wprowadzona liczba jest spoza zakresu.", 0Ah
    errMsgBigInNrLen equ $-errMsgBigInNr
    errMsgBigOut db "Error: Wynik jest liczba spoza zakresu.", 0Ah
    errMsgBigOutLen equ $-errMsgBigOut
    errMsgNegPower db "Error: Potega mniejsza od 0.", 0Ah
    errMsgNegPowerLen equ $-errMsgNegPower
    
segment .text
    global _start

_start:  
    redirect:               ; switch który przekierowuje do kolejnego zadania
        mov al, [opt]
        add al, 1 
        mov [opt], al 
        
        mov al, [opt]
        cmp al, 1           ; pierwsza zmienna
        je read
        cmp al, 2           
        je stringToInt
        cmp al, 3           
        je assignA
        
        cmp al, 4           ; operator
        je read
        cmp al, 5           
        je assignOperator
        
        cmp al, 6           ; druga zmienna
        je read
        cmp al, 7           
        je stringToInt
        cmp al, 8           
        je assignB
        
        cmp al, 9
        je calculate
        
        jmp exit            ; jeśli spoza zakresu to wyjdz  - moze dac blad
    
    resetMsg:
        mov dl, 0
        mov ecx, msgLen-1 
        mov ebx, msg
        zerosMsg:
            mov [ebx], dl
            add ebx, 1
            loop zerosMsg 
            mov dl, 0Ah
            mov [ebx], dl   
            jmp redirect
    
    read:
        mov eax, 3          ; sys_read()
        mov ebx, 0          ; std_in
        mov ecx, msg        ; adres
        mov edx, msgLen     ; dlugosc
        int 80h             ; wywolaj
        jmp redirect
    
    stringToInt:  
        mov ebx, msg
        mov eax, 0               ; zeruj zmienna
        mov [number], eax        
        mov cl, [ebx]
        cmp cl, "-"
        je setNegative
        mov edx, 1
        mov [tmp], edx
        cmp cl, "+"
        je nextIntChar
        jmp digitMsg
        setNegative:
            mov edx, -1
            mov [tmp], edx
        nextIntChar:
            add ebx, 1 
            xor ecx, ecx
            mov cl, [ebx]
            cmp cl, 0Ah
            je errorBadChar
            jmp convertToInt
        digitMsg:
            xor ecx, ecx
            mov cl, [ebx]
            cmp cl, 0Ah
            je redirect     ; jesli znak to enter to koniec konwersji
            
            mov eax, [number]
            mov edx, 10
            mul edx
            jc errorToBigNumber
            mov [number], eax
        convertToInt:
            sub cl, "0"

            cmp cl, 0           ; sprawdza wprowadzony znak
            jl errorBadChar
            cmp cl, 9
            jg errorBadChar

            mov eax, [number]
            add eax, ecx
            jc errorToBigNumber     ; if carry flag
            mov [number], eax
            add ebx, 1      ; wez kolejny znak
            jmp digitMsg
    
    assignA:
        mov eax, [number]
        mov edx, [tmp]
        mul edx
        mov [a], eax
        jmp resetMsg
        
    assignB:
        mov eax, [number]
        mov edx, [tmp]
        mul edx
        mov [b], eax
        jmp resetMsg
        
    assignOperator:
        mov al, [msg+1]
        cmp al, 0Ah
        jne errorBadChar
        mov al, [msg]
        mov [operator], al
        jmp resetMsg
    
    calculate:              ; przekieruj do odpowiedniego dzialania na podstawie znaku operacji
        mov al, [operator]
        
        cmp al, "+"           ; dodawanie
        je addition
        
        cmp al, "-"           ; odejmowanie
        je subtraction
        
        cmp al, "*"           ; mnożenie
        je multiplication
        
        cmp al, "/"           ; dzielenie
        je division
        
        cmp al, "%"           ; modulo
        je modulo
        
        cmp al, "^"           ; potegowanie
        je power
        
        jmp errorOperator
    
    addition:
        mov eax, [a]
        add eax, [b]
        jo errorResultOutOfRange    ;; if OverflowFlag
        mov [calcRes], eax
        jmp resultToString
    
    subtraction:
        mov eax, [a]
        sub eax, [b]
        jo errorResultOutOfRange
        mov [calcRes], eax
        jmp resultToString
    
    multiplication:
        mov eax, [a]
        mov edx, [b]
        imul edx
        jo errorResultOutOfRange
        mov [calcRes], eax
        jmp resultToString
    
    division:
        mov ecx, [b]
        cmp ecx, 0
        je errorZeroDiv

        xor edx, edx
        mov eax, [a]
        cdq
        idiv ecx
        mov [calcRes], eax
        jmp resultToString
        
    modulo:
        mov ecx, [b]
        cmp ecx, 0
        je errorZeroDiv

        xor edx, edx
        mov eax, [a]
        cdq
        idiv ecx
        mov [calcRes], edx
        jmp resultToString
    
    power:
        mov ecx, [b]
        cmp ecx, 0
        jl errorNegativePower
        je setOne
        mov eax, 1
        getPower:
            mov edx, [a]
            imul edx
            jo errorResultOutOfRange
            mov [calcRes], eax
            loop getPower
            jmp resultToString
        setOne:
            mov eax, 1
            mov [calcRes], eax
            jmp resultToString

    resultToString:
        xor eax, eax
        mov eax, [calcRes]
        mov [tmp], eax
        cmp eax, 0
        jge initToString
        mov ebx, msg
        mov dl, "-"
        mov [ebx], dl
        sub ebx, 1
        neg eax
        
        initToString:
            mov ebx, msg+10
            mov ecx, 10
        convertDigit:
            xor edx, edx
            div ecx
            add edx, "0"
            mov [ebx], dl
            sub ebx, 1
            cmp eax, 0
            jg convertDigit
        
    print:
        mov eax, 4     
        mov ebx, 1     
        mov ecx, equality
        mov edx, 2    
        int 80h 
        
        mov eax, 4          ; sys_write()
        mov ebx, 1          ; std_out
        mov ecx, msg        ; adres
        mov edx, msgLen     ; dlugosc
        int 80h             ; wywolaj
       
        mov eax, 4      
        mov ebx, 1   
        mov ecx, newLine       
        mov edx, 1     
        int 80h 
    
    exit:
        mov eax, 1
        xor ebx, ebx
        int 80h
        
    errorOperator:
        mov eax, 4          
        mov ebx, 1         
        mov ecx, errMsgOperator       
        mov edx, errMsgOperatorLen
        int 80h     
        jmp exit
        
    errorZeroDiv:
        mov eax, 4          
        mov ebx, 1         
        mov ecx, errMsgZeroDiv       
        mov edx, errMsgZeroDivLen
        int 80h     
        jmp exit
    
    errorBadChar:
        mov eax, 4
        mov ebx, 1
        mov ecx, errMsgBadChar
        mov edx, errMsgBadCharLen
        int 80h
        jmp exit
    
    errorToBigNumber:
        mov eax, 4
        mov ebx, 1
        mov ecx, errMsgBigInNr
        mov edx, errMsgBigInNrLen
        int 80h
        jmp exit
    
    errorResultOutOfRange:
        mov eax, 4
        mov ebx, 1
        mov ecx, errMsgBigOut
        mov edx, errMsgBigOutLen
        int 80h
        jmp exit
    
    errorNegativePower:
        mov eax, 4
        mov ebx, 1
        mov ecx, errMsgNegPower
        mov edx, errMsgNegPowerLen
        int 80h
        jmp exit
