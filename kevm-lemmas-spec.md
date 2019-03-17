```k
requires "evm.k"

module KEVM-LEMMAS-SPEC
    imports EVM
```

**TODO**: See if this speeds up ocaml backend by adding `[structural]` to these rules in the semantics.
**TODO**: See if this speeds up llvm backend by modifying https://github.com/kframework/llvm-backend/blob/master/matching/src/Pattern/Parser.hs#L163

```
    rule <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <k> #execute ... </k>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <program> ... PCOUNT |-> ADD ... </program>
         <wordStack> W0 : W1 : WS => chop ( W0 +Int W1 ) : WS </wordStack>
         <gas> G => G -Int Gverylow < SCHEDULE > </gas>
         <static> STATIC </static>
         <memoryUsed> MU </memoryUsed>
      requires G >=Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                    -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                       )
       andBool ( G -Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                     -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                        )
           >=Int Gverylow < SCHEDULE >
               )
       andBool notBool ( #stackUnderflow(W0 : W1 : WS, ADD) orBool #stackOverflow(W0 : W1 : WS, ADD) )
      [structural]

    rule <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <k> #execute ... </k>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <program> ... PCOUNT |-> SUB ... </program>
         <wordStack> W0 : W1 : WS => W0 -Word W1 : WS </wordStack>
         <gas> G => G -Int Gverylow < SCHEDULE > </gas>
         <static> STATIC </static>
         <memoryUsed> MU </memoryUsed>
      requires G >=Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                    -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                       )
       andBool ( G -Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                     -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                        )
           >=Int Gverylow < SCHEDULE >
               )
       andBool notBool ( #stackUnderflow(W0 : W1 : WS, SUB) orBool #stackOverflow(W0 : W1 : WS, SUB) )
      [structural]

    rule <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <k> #execute ... </k>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <program> ... PCOUNT |-> MUL ... </program>
         <wordStack> W0 : W1 : WS => chop ( W0 *Int W1 ) : WS </wordStack>
         <gas> G => G -Int Glow < SCHEDULE > </gas>
         <static> STATIC </static>
         <memoryUsed> MU </memoryUsed>
      requires G >=Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                    -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                       )
       andBool ( G -Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                     -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                        )
           >=Int Glow < SCHEDULE >
               )
       andBool notBool ( #stackUnderflow(W0 : W1 : WS, MUL) orBool #stackOverflow(W0 : W1 : WS, MUL) )
      [structural]

    rule <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <k> #execute ... </k>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <program> ... PCOUNT |-> DIV ... </program>
         <wordStack> W0 : W1 : WS => W0 /Word W1 : WS </wordStack>
         <gas> G => G -Int Glow < SCHEDULE > </gas>
         <static> STATIC </static>
         <memoryUsed> MU </memoryUsed>
      requires G >=Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                    -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                       )
       andBool ( G -Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                     -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
                        )
           >=Int Glow < SCHEDULE >
               )
       andBool notBool ( #stackUnderflow(W0 : W1 : WS, DIV) orBool #stackOverflow(W0 : W1 : WS, DIV) )
      [structural]
```

```k
endmodule
```
