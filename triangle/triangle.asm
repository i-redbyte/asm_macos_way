        global      _main
        section     .text
_main:    
        push    rbx                     
        mov     rdx, output             
        mov     r8, 18                
        mov     r9, 0                   
line:
        mov     byte [rdx], '//'         
        inc     rdx                     
        inc     r9                      
        cmp     r9, r8                  
        jne     line                    
lineDone:
        mov     byte [rdx], 10          
        inc     rdx                     
        dec     r8                      
        mov     r9, 0                   
        cmp     r8, 0            
        jg      line                    
done:
        mov     rax, 0x02000004        
        mov     rdi, 1                 
        mov     rsi, output            
        mov     rdx, dataSize          
        syscall                        
        mov     rax, 0x02000001        
        xor     rdi, rdi               
        syscall                        

        section   .bss
maxlines    equ       18
dataSize    equ       189 
output:     resb    dataSize