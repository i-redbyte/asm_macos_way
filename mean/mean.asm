        global   _main
        extern   _atoi    ;C function
        extern   _printf  ;C function
        default  rel

        section  .text
_main:
        push     rbx

        dec      rdi
        jz       noMean
        mov      [count], rdi
accumulate:
        push     rdi
        push     rsi
        mov      rdi, [rsi+rdi*8]
        call     _atoi
        pop      rsi
        pop      rdi
        add      [sum], rax
        dec      rdi
        jnz      accumulate
average:
        cvtsi2sd xmm0, [sum]
        cvtsi2sd xmm1, [count]
        divsd    xmm0, xmm1
        lea      rdi, [format]
        mov      rax, 1
        call     _printf
        jmp      done

noMean:
        lea      rdi, [error]
        xor      rax, rax
        call     _printf

done:
        pop      rbx
        ret

        section  .data
count:  dq       0
sum:    dq       0
format: db       "%g", 10, 0
error:  db       "Error: No command line arguments!", 10, 0