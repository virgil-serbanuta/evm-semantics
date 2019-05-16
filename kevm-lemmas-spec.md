```k
requires "edsl.k"

module VERIFICATION
    imports EDSL

    rule I -Int I => 0
    // avoids the following expression:
    // andBool G >=Int ( ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
    //              -Int ((MU *Int Gmemory < SCHEDULE >) +Int ((MU *Int MU) /Int Gquadcoeff < SCHEDULE >))
    //                 )

    rule I -Int 0 => I
    // avoids the following expression:
    // G -Int 0
endmodule

module KEVM-LEMMAS-SPEC
    imports VERIFICATION
```

**TODO**: See if this speeds up ocaml backend by adding `[structural]` to these rules in the semantics.
**TODO**: See if this speeds up llvm backend by modifying https://github.com/kframework/llvm-backend/blob/master/matching/src/Pattern/Parser.hs#L163

```k
    rule <k> #next [ ADD ] => . ... </k>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <wordStack> X : Y : WS => X +Word Y : WS </wordStack>
         <gas> G => G -Int Gverylow < SCHEDULE > </gas>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool notBool ( #stackUnderflow(X : Y : WS, ADD) orBool #stackOverflow(X : Y : WS, ADD) )
        andBool G >=Int Gverylow < SCHEDULE >
      [tag(optim)]
```

```k
    rule <k> #next [ SUB ] => . ... </k>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <wordStack> X : Y : WS => X -Word Y : WS </wordStack>
         <gas> G => G -Int Gverylow < SCHEDULE > </gas>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool notBool ( #stackUnderflow(X : Y : WS, ADD) orBool #stackOverflow(X : Y : WS, ADD) )
        andBool G >=Int Gverylow < SCHEDULE >
      [tag(optim)]
```

```k
    rule <k> #next [ MUL ] => . ... </k>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <wordStack> X : Y : WS => X *Word Y : WS </wordStack>
         <gas> G => G -Int Glow < SCHEDULE > </gas>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool notBool ( #stackUnderflow(X : Y : WS, ADD) orBool #stackOverflow(X : Y : WS, ADD) )
        andBool G >=Int Glow < SCHEDULE >
      [tag(optim)]
```

```k
    rule <k> #next [ DIV ] => . ... </k>
         <mode> NORMAL </mode>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int 1 </pc>
         <wordStack> X : Y : WS => X /Word Y : WS </wordStack>
         <gas> G => G -Int Glow < SCHEDULE > </gas>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool notBool ( #stackUnderflow(X : Y : WS, ADD) orBool #stackOverflow(X : Y : WS, ADD) )
        andBool G >=Int Glow < SCHEDULE >
      [tag(optim)]
```

```k
endmodule
```
