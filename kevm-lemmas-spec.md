```k
requires "edsl.k"

module VERIFICATION
    imports EDSL

    rule I -Int I => 0

    // avoids the following expression:
    // andBool G >=Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
    //              -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
    //                 )
endmodule

module KEVM-LEMMAS-SPEC
    imports VERIFICATION
```

**TODO**: See if this speeds up ocaml backend by adding `[structural]` to these rules in the semantics.
**TODO**: See if this speeds up llvm backend by modifying https://github.com/kframework/llvm-backend/blob/master/matching/src/Pattern/Parser.hs#L163

```k
    rule <k> #execute ... </k>
         <static> false </static>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <callGas> _ => _ </callGas>
         <program> #asMapOpCodes( PUSH(32, X) ; PUSH(32, Y) ; ADD ; .OpCodes ) </program>
         <pc> 0  => _ </pc>
         <wordStack> .WordStack => chop ( X +Int Y ) : .WordStack </wordStack>
         <gas> G  => G -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > </gas>
         <memoryUsed> MU </memoryUsed>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool G >=Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE >
        andBool G >=Int 0
      [structural]
```

```
    rule <k> #execute ... </k>
         <static> false </static>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <callGas> _ => _ </callGas>
         <program> #asMapOpCodes( PUSH(32, X) ; PUSH(32, Y) ; SUB ; .OpCodes ) </program>
         <pc> 0  => _ </pc>
         <wordStack> .WordStack => W0 -Word W1 : .WordStack </wordStack>
         <gas> G  => G -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > </gas>
         <memoryUsed> MU </memoryUsed>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool G >=Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE >
        andBool G >=Int 0
      [structural]

    rule <k> #execute ... </k>
         <static> false </static>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <callGas> _ => _ </callGas>
         <program> #asMapOpCodes( PUSH(32, X) ; PUSH(32, Y) ; MUL ; .OpCodes ) </program>
         <pc> 0  => _ </pc>
         <wordStack> .WordStack => chop ( X *Int Y ) : .WordStack </wordStack>
         <gas> G  => G -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > </gas>
         <memoryUsed> MU </memoryUsed>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool G >=Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE >
        andBool G >=Int 0
      [structural]

    rule <k> #execute ... </k>
         <static> false </static>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <callGas> _ => _ </callGas>
         <program> #asMapOpCodes( PUSH(32, X) ; PUSH(32, Y) ; DIV ; .OpCodes ) </program>
         <pc> 0  => _ </pc>
         <wordStack> .WordStack => chop ( X /Int Y ) : .WordStack </wordStack>
         <gas> G  => G -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > </gas>
         <memoryUsed> MU </memoryUsed>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool G >=Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE >
        andBool G >=Int 0
      [structural]
```

```k
endmodule
```
