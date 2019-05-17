KEVM Lemmas
===========

```k
requires "evm.k"

module KEVM-LEMMAS-SPEC
    imports EVM
```

```k
    rule <k> #next [ PUSH(N, M) ] => . ... </k>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int #widthOp(PUSH(N, M)) </pc>
         <wordStack> WS => M : WS </wordStack>
         <gas> G => G -Int Gverylow < SCHEDULE > </gas>
       requires #range(0 <= M < pow256)
        andBool notBool ( #stackUnderflow(WS, PUSH(N, M)) orBool #stackOverflow(WS, PUSH(N, M)) )
        andBool G >=Int Gverylow < SCHEDULE >
      [tag(optim)]
```

```k
    rule <k> #next [ POP ] => . ... </k>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int #widthOp(POP) </pc>
         <wordStack> W : WS => WS </wordStack>
         <gas> G => G -Int Gbase < SCHEDULE > </gas>
       requires #range(0 <= W < pow256)
        andBool notBool ( #stackUnderflow(W : WS, POP) orBool #stackOverflow(W : WS, POP) )
        andBool G >=Int Gbase < SCHEDULE >
      [tag(optim)]
```

```k
    rule <k> #next [ ADD ] => . ... </k>
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
    rule <k> PUSH(N, X) ; PUSH(M, Y) ; ADD ; .OpCodes => . ... </k>
         <schedule> SCHEDULE </schedule>
         <pc> PCOUNT => PCOUNT +Int #widthOps(PUSH(N, X) ; PUSH(M, Y) ; ADD ; .OpCodes) </pc>
         <wordStack> WS => X +Word Y : WS </wordStack>
         <gas> G => G -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > -Int Gverylow < SCHEDULE > </gas>
       requires #range(0 <= X < pow256)
        andBool #range(0 <= Y < pow256)
        andBool notBool ( #stackUnderflow(       WS, PUSH(N, X)) orBool #stackOverflow(        WS, PUSH(N, X))
                   orBool #stackUnderflow(   X : WS, PUSH(N, Y)) orBool #stackOverflow(    Y : WS, PUSH(N, Y))
                   orBool #stackUnderflow(Y: X : WS, ADD)        orBool #stackOverflow(X : Y : WS, ADD)
                        )
        // andBool notBool ( #stackUnderflow(       WS, PUSH(N, X)) orBool #stackOverflow(        WS, PUSH(N, X)) )
        // andBool notBool ( #stackUnderflow(   X : WS, PUSH(N, Y)) orBool #stackOverflow(    Y : WS, PUSH(N, Y)) )
        // andBool notBool ( #stackUnderflow(Y: X : WS, ADD)        orBool #stackOverflow(X : Y : WS, ADD)        )
        // andBool notBool (sizeWordStackAux(WS, 0) <Int 0 orBool sizeWordStackAux(WS, 0) +Int  1 >Int 1024)
        // andBool notBool (sizeWordStackAux(WS, 1) <Int 0 orBool sizeWordStackAux(WS, 1) +Int  1 >Int 1024)
        // andBool notBool (sizeWordStackAux(WS, 2) <Int 2 orBool sizeWordStackAux(WS, 2) +Int -1 >Int 1024)
        andBool G >=Int Gverylow < SCHEDULE >
        andBool G >=Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE >
        andBool G >=Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE > +Int Gverylow < SCHEDULE >
```

```k
endmodule
```
