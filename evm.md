EVM Execution
=============

### Overview

The EVM is a stack machine over some simple opcodes.
Most of the opcodes are "local" to the execution state of the machine, but some of them must interact with the world state.
This file only defines the local execution operations, the file `driver.md` will define the interactions with the world state.

```k
requires "data.k"
requires "network.k"

module EVM
    imports STRING
    imports EVM-DATA
    imports NETWORK
```

Configuration
-------------

The configuration has cells for the current account id, the current opcode, the program counter, the current gas, the gas price, the current program, the word stack, and the local memory.
In addition, there are cells for the callstack and execution substate.

We've broken up the configuration into two components; those parts of the state that mutate during execution of a single transaction and those that are static throughout.
In the comments next to each cell, we've marked which component of the YellowPaper state corresponds to each cell.

```k
    configuration
      <kevm>
        <k> $PGM:EthereumSimulation </k>
        <exit-code exit=""> 1 </exit-code>
        <mode> $MODE:Mode </mode>
        <schedule> $SCHEDULE:Schedule </schedule>

        <ethereum>

          // EVM Specific
          // ============

          <evm>

            // Mutable during a single transaction
            // -----------------------------------

            <output>          .ByteArray  </output>           // H_RETURN
            <statusCode>      .StatusCode </statusCode>
            <callStack>       .List       </callStack>
            <interimStates>   .List       </interimStates>
            <touchedAccounts> .Set        </touchedAccounts>

            <callState>
              <program>      .Map       </program>            // I_b
              <programBytes> .ByteArray </programBytes>

              // I_*
              <id>        0          </id>                    // I_a
              <caller>    0          </caller>                // I_s
              <callData>  .ByteArray </callData>              // I_d
              <callValue> 0          </callValue>             // I_v

              // \mu_*
              <wordStack>   .WordStack </wordStack>           // \mu_s
              <localMem>    .Map       </localMem>            // \mu_m
              <pc>          0          </pc>                  // \mu_pc
              <gas>         0          </gas>                 // \mu_g
              <memoryUsed>  0          </memoryUsed>          // \mu_i
              <callGas>     0          </callGas>

              <static>    false </static>
              <callDepth> 0     </callDepth>
            </callState>

            // A_* (execution substate)
            <substate>
              <selfDestruct> .Set  </selfDestruct>            // A_s
              <log>          .List </log>                     // A_l
              <refund>       0     </refund>                  // A_r
            </substate>

            // Immutable during a single transaction
            // -------------------------------------

            <gasPrice> 0 </gasPrice>                          // I_p
            <origin>   0 </origin>                            // I_o

            // I_H* (block information)
            <previousHash>     0          </previousHash>     // I_Hp
            <ommersHash>       0          </ommersHash>       // I_Ho
            <coinbase>         0          </coinbase>         // I_Hc
            <stateRoot>        0          </stateRoot>        // I_Hr
            <transactionsRoot> 0          </transactionsRoot> // I_Ht
            <receiptsRoot>     0          </receiptsRoot>     // I_He
            <logsBloom>        .ByteArray </logsBloom>        // I_Hb
            <difficulty>       0          </difficulty>       // I_Hd
            <number>           0          </number>           // I_Hi
            <gasLimit>         0          </gasLimit>         // I_Hl
            <gasUsed>          0          </gasUsed>          // I_Hg
            <timestamp>        0          </timestamp>        // I_Hs
            <extraData>        .ByteArray </extraData>        // I_Hx
            <mixHash>          0          </mixHash>          // I_Hm
            <blockNonce>       0          </blockNonce>       // I_Hn

            <ommerBlockHeaders> [ .JSONList ] </ommerBlockHeaders>
            <blockhash>         .List         </blockhash>

            <chainID> $CHAINID:Int </chainID>

          </evm>

          // Ethereum Network
          // ================

          <network>

            // Accounts Record
            // ---------------

            <activeAccounts> .Set </activeAccounts>
            <accounts>
              <account multiplicity="*" type="Map">
                <acctID>      0                      </acctID>
                <balance>     0                      </balance>
                <code>        .ByteArray:AccountCode </code>
                <storage>     .Map                   </storage>
                <origStorage> .Map                   </origStorage>
                <nonce>       0                      </nonce>
              </account>
            </accounts>

            // Transactions Record
            // -------------------

            <txOrder>   .List </txOrder>
            <txPending> .List </txPending>

            <messages>
              <message multiplicity="*" type="Map">
                <msgID>      0          </msgID>
                <txNonce>    0          </txNonce>            // T_n
                <txGasPrice> 0          </txGasPrice>         // T_p
                <txGasLimit> 0          </txGasLimit>         // T_g
                <to>         .Account   </to>                 // T_t
                <value>      0          </value>              // T_v
                <sigV>       0          </sigV>               // T_w
                <sigR>       .ByteArray </sigR>               // T_r
                <sigS>       .ByteArray </sigS>               // T_s
                <data>       .ByteArray </data>               // T_i/T_e
              </message>
            </messages>

          </network>

        </ethereum>
      </kevm>

    syntax EthereumSimulation
    syntax AccountCode ::= ByteArray
 // --------------------------------
```

Modal Semantics
---------------

Our semantics is modal, with the initial mode being set on the command line via `-cMODE=EXECMODE`.

-   `NORMAL` executes as a client on the network would.
-   `VMTESTS` skips `CALL*` and `CREATE` operations.

```k
    syntax Mode ::= "NORMAL"  [klabel(NORMAL), symbol]
                  | "VMTESTS" [klabel(VMTESTS), symbol]
```

-   `#setMode_` sets the mode to the supplied one.

```k
    syntax InternalOp ::= "#setMode" Mode
 // -------------------------------------
    rule <k> #setMode EXECMODE => . ... </k> <mode> _ => EXECMODE </mode>
```

State Stacks
------------

### The CallStack

The `callStack` cell stores a list of previous VM execution states.

-   `#pushCallStack` saves a copy of VM execution state on the `callStack`.
-   `#popCallStack` restores the top element of the `callStack`.
-   `#dropCallStack` removes the top element of the `callStack`.

```k
    syntax InternalOp ::= "#pushCallStack"
 // --------------------------------------
    rule <k> #pushCallStack => . ... </k>
         <callStack> (.List => ListItem(CALLSTATE)) ... </callStack>
         <callState> CALLSTATE </callState>

    syntax InternalOp ::= "#popCallStack"
 // -------------------------------------
    rule <k> #popCallStack => . ... </k>
         <callStack>  (ListItem(CALLSTATE) => .List) ... </callStack>
         <callState> _ => CALLSTATE </callState>

    syntax InternalOp ::= "#dropCallStack"
 // --------------------------------------
    rule <k> #dropCallStack => . ... </k>
         <callStack> (ListItem(_) => .List) ... </callStack>
```

### The StateStack

The `interimStates` cell stores a list of previous world states.

-   `#pushWorldState` stores a copy of the current accounts and the substate at the top of the `interimStates` cell.
-   `#popWorldState` restores the top element of the `interimStates`.
-   `#dropWorldState` removes the top element of the `interimStates`.

```k
    syntax Accounts ::= "{" AccountsCellFragment "|" Set "|" SubstateCellFragment "}"
 // ---------------------------------------------------------------------------------

    syntax InternalOp ::= "#pushWorldState"
 // ---------------------------------------
    rule <k> #pushWorldState => .K ... </k>
         <interimStates> (.List => ListItem({ ACCTDATA | ACCTS | SUBSTATE })) ... </interimStates>
         <activeAccounts> ACCTS    </activeAccounts>
         <accounts>       ACCTDATA </accounts>
         <substate>       SUBSTATE </substate>

    syntax InternalOp ::= "#popWorldState"
 // --------------------------------------
    rule <k> #popWorldState => .K ... </k>
         <interimStates> (ListItem({ ACCTDATA | ACCTS | SUBSTATE }) => .List) ... </interimStates>
         <activeAccounts> _ => ACCTS    </activeAccounts>
         <accounts>       _ => ACCTDATA </accounts>
         <substate>       _ => SUBSTATE </substate>

    syntax InternalOp ::= "#dropWorldState"
 // ---------------------------------------
    rule <k> #dropWorldState => . ... </k> <interimStates> (ListItem(_) => .List) ... </interimStates>
```

Control Flow
------------

### Exception Based

-   `#halt` indicates end of execution.
    It will consume anything related to the current computation behind it on the `<k>` cell.
-   `#end_` sets the `statusCode` then halts execution.

```k
    syntax KItem ::= "#halt" | "#end" StatusCode
 // --------------------------------------------
    rule <k> #end SC => #halt ... </k> <statusCode> _ => SC </statusCode>

    rule <k> #halt ~> (_:Int    => .) ... </k>
    rule <k> #halt ~> (_:OpCode => .) ... </k>
```

OpCode Execution
----------------

### Execution Macros

-   `#execute` loads the next opcode (or halts with `EVMC_SUCCESS` if there is no next opcode).

```k
    syntax KItem ::= "#execute"
 // ---------------------------
    rule [halt]: <k> #halt ~> (#execute => .) ... </k>
    rule [step]: <k> (. => #next [ OP ]) ~> #execute ... </k>
                 <pc> PCOUNT </pc>
                 <program> ... PCOUNT |-> OP ... </program>

    rule <k> (. => #end EVMC_SUCCESS) ~> #execute ... </k>
         <pc> PCOUNT </pc>
         <program> PGM </program>
         <output> _ => .ByteArray </output>
      requires notBool (PCOUNT in_keys(PGM))
```

### Single Step

If the program-counter points to an actual opcode, it's loaded into the `#next [_]` operator.
The `#next [_]` operator initiates execution by:

1.  checking if there will be a stack over/underflow, or a static mode violation,
2.  loading any additional state needed (when executing in full-node mode),
3.  executing the opcode (which includes any gas deduction needed), and
4.  adjusting the program counter.

```k
    syntax InternalOp ::= "#next" "[" OpCode "]"
 // --------------------------------------------
    rule <k> #next [ OP ]
          => #load [ OP ]
          ~> #exec [ OP ]
          ~> #pc   [ OP ]
         ...
         </k>
         <wordStack> WS </wordStack>
         <static> STATIC:Bool </static>
      requires notBool ( #stackUnderflow(WS, OP) orBool #stackOverflow(WS, OP) )
       andBool notBool ( STATIC andBool #changesState(OP, WS) )

    rule <k> #next [ OP ] => #end EVMC_STACK_UNDERFLOW ... </k>
         <wordStack> WS </wordStack>
      requires #stackUnderflow(WS, OP)

    rule <k> #next [ OP ] => #end EVMC_STACK_OVERFLOW ... </k>
         <wordStack> WS </wordStack>
      requires #stackOverflow(WS, OP)

    rule <k> #next [ OP ] => #end EVMC_STATIC_MODE_VIOLATION ... </k>
         <wordStack> WS </wordStack>
         <static> STATIC:Bool </static>
      requires notBool ( #stackUnderflow(WS, OP) orBool #stackOverflow(WS, OP) )
       andBool STATIC andBool #changesState(OP, WS)
```

### Exceptional Checks

-   `#stackNeeded` is how many arguments that opcode will need off the top of the stack.
-   `#stackAdded` is how many arguments that opcode will push onto the top of the stack.
-   `#stackDelta` is the delta the stack will have after the opcode executes.

```k
    syntax Bool ::= #stackUnderflow ( WordStack , OpCode ) [function]
                  | #stackOverflow  ( WordStack , OpCode ) [function]
 // -----------------------------------------------------------------
    rule #stackUnderflow(WS, OP) => #sizeWordStack(WS)                      <Int #stackNeeded(OP)
    rule #stackOverflow (WS, OP) => #sizeWordStack(WS) +Int #stackDelta(OP) >Int 1024

    syntax Int ::= #stackNeeded ( OpCode ) [function]
 // -------------------------------------------------
    rule #stackNeeded(PUSH(_, _))      => 0
    rule #stackNeeded(IOP:InvalidOp)   => 0
    rule #stackNeeded(NOP:NullStackOp) => 0
    rule #stackNeeded(UOP:UnStackOp)   => 1
    rule #stackNeeded(BOP:BinStackOp)  => 2 requires notBool isLogOp(BOP)
    rule #stackNeeded(TOP:TernStackOp) => 3
    rule #stackNeeded(QOP:QuadStackOp) => 4
    rule #stackNeeded(DUP(N))          => N
    rule #stackNeeded(SWAP(N))         => N +Int 1
    rule #stackNeeded(LOG(N))          => N +Int 2
    rule #stackNeeded(CSOP:CallSixOp)  => 6
    rule #stackNeeded(COP:CallOp)      => 7 requires notBool isCallSixOp(COP)

    syntax Int ::= #stackAdded ( OpCode ) [function]
 // ------------------------------------------------
    rule #stackAdded(CALLDATACOPY)   => 0
    rule #stackAdded(RETURNDATACOPY) => 0
    rule #stackAdded(CODECOPY)       => 0
    rule #stackAdded(EXTCODECOPY)    => 0
    rule #stackAdded(POP)            => 0
    rule #stackAdded(MSTORE)         => 0
    rule #stackAdded(MSTORE8)        => 0
    rule #stackAdded(SSTORE)         => 0
    rule #stackAdded(JUMP)           => 0
    rule #stackAdded(JUMPI)          => 0
    rule #stackAdded(JUMPDEST)       => 0
    rule #stackAdded(STOP)           => 0
    rule #stackAdded(RETURN)         => 0
    rule #stackAdded(REVERT)         => 0
    rule #stackAdded(SELFDESTRUCT)   => 0
    rule #stackAdded(PUSH(_,_))      => 1
    rule #stackAdded(LOG(_))         => 0
    rule #stackAdded(SWAP(N))        => N
    rule #stackAdded(DUP(N))         => N +Int 1
    rule #stackAdded(IOP:InvalidOp)  => 0
    rule #stackAdded(OP)             => 1 [owise]

    syntax Int ::= #stackDelta ( OpCode ) [function]
 // ------------------------------------------------
    rule #stackDelta(OP) => #stackAdded(OP) -Int #stackNeeded(OP)
```

-   `#changesState` is true if the given opcode will change `<network>` state given the arguments.

```k
    syntax Bool ::= #changesState ( OpCode , WordStack ) [function]
 // ---------------------------------------------------------------
    rule #changesState(CALL, _ : _ : VALUE : _) => VALUE =/=Int 0
    rule #changesState(OP,   _)                 => ( isLogOp(OP)
                                              orBool OP ==K SSTORE
                                              orBool OP ==K CREATE
                                              orBool OP ==K CREATE2
                                              orBool OP ==K SELFDESTRUCT
                                                   )
      requires notBool OP ==K CALL
```

### Execution Step

-   `#exec` will load the arguments of the opcode (it assumes `#stackNeeded?` is accurate and has been called) and trigger the subsequent operations.

```k
    syntax InternalOp ::= "#exec" "[" OpCode "]"
 // --------------------------------------------
    rule <k> #exec [ IOP:InvalidOp ] => IOP ... </k>

    rule <k> #exec [ OP ] => #gas [ OP , OP ] ~> OP ... </k> requires isNullStackOp(OP) orBool isPushOp(OP)
```

Here we load the correct number of arguments from the `wordStack` based on the sort of the opcode.
Some of them require an argument to be interpereted as an address (modulo 160 bits), so the `#addr?` function performs that check.

```k
    syntax KItem  ::= OpCode
    syntax OpCode ::= NullStackOp | UnStackOp | BinStackOp | TernStackOp | QuadStackOp
                    | InvalidOp | StackOp | InternalOp | CallOp | CallSixOp | PushOp
 // --------------------------------------------------------------------------------

    syntax InternalOp ::= UnStackOp   Int
                        | BinStackOp  Int Int
                        | TernStackOp Int Int Int
                        | QuadStackOp Int Int Int Int
 // -------------------------------------------------
    rule <k> #exec [ UOP:UnStackOp   ] => #gas [ UOP , UOP W0          ] ~> UOP W0          ... </k> <wordStack> W0 : WS                => WS </wordStack>
    rule <k> #exec [ BOP:BinStackOp  ] => #gas [ BOP , BOP W0 W1       ] ~> BOP W0 W1       ... </k> <wordStack> W0 : W1 : WS           => WS </wordStack>
    rule <k> #exec [ TOP:TernStackOp ] => #gas [ TOP , TOP W0 W1 W2    ] ~> TOP W0 W1 W2    ... </k> <wordStack> W0 : W1 : W2 : WS      => WS </wordStack>
    rule <k> #exec [ QOP:QuadStackOp ] => #gas [ QOP , QOP W0 W1 W2 W3 ] ~> QOP W0 W1 W2 W3 ... </k> <wordStack> W0 : W1 : W2 : W3 : WS => WS </wordStack>
```

`StackOp` is used for opcodes which require a large portion of the stack.

```k
    syntax InternalOp ::= StackOp WordStack
 // ---------------------------------------
    rule <k> #exec [ SO:StackOp ] => #gas [ SO , SO WS ] ~> SO WS ... </k> <wordStack> WS </wordStack>
```

The `CallOp` opcodes all interperet their second argument as an address.

```k
    syntax InternalOp ::= CallSixOp Int Int     Int Int Int Int
                        | CallOp    Int Int Int Int Int Int Int
 // -----------------------------------------------------------
    rule <k> #exec [ CSO:CallSixOp ] => #gas [ CSO , CSO W0 W1    W2 W3 W4 W5 ] ~> CSO W0 W1    W2 W3 W4 W5 ... </k> <wordStack> W0 : W1 : W2 : W3 : W4 : W5 : WS      => WS </wordStack>
    rule <k> #exec [ CO:CallOp     ] => #gas [ CO  , CO  W0 W1 W2 W3 W4 W5 W6 ] ~> CO  W0 W1 W2 W3 W4 W5 W6 ... </k> <wordStack> W0 : W1 : W2 : W3 : W4 : W5 : W6 : WS => WS </wordStack>
```

### Helpers

-   `#addr` decides if the given argument should be interpreted as an address (given the opcode).

```k
    syntax InternalOp ::= "#load" "[" OpCode "]"
 // --------------------------------------------
    rule <k> #load [ OP:OpCode ] => #loadAccount #addr(W0) ... </k>
         <wordStack> (W0 => #addr(W0)) : WS </wordStack>
      requires #addr?(OP)

    rule <k> #load [ OP:OpCode ] => #loadAccount #addr(W0) ~> #lookupCode #addr(W0) ... </k>
         <wordStack> (W0 => #addr(W0)) : WS </wordStack>
      requires #code?(OP)

    rule <k> #load [ OP:OpCode ] => #loadAccount #addr(W1) ~> #lookupCode #addr(W1) ... </k>
         <wordStack> W0 : (W1 => #addr(W1)) : WS </wordStack>
      requires isCallOp(OP) orBool isCallSixOp(OP)

    rule <k> #load [ CREATE ] => #loadAccount #newAddr(ACCT, NONCE) ... </k>
         <id> ACCT </id>
         <account>
           <acctID> ACCT </acctID>
           <nonce> NONCE </nonce>
           ...
         </account>

    rule <k> #load [ OP:OpCode ] => #lookupStorage ACCT W0 ... </k>
         <id> ACCT </id>
         <wordStack> W0 : WS </wordStack>
      requires OP ==K SSTORE orBool OP ==K SLOAD

    rule <k> #load [ OP:OpCode ] => . ... </k>
      requires notBool (
        OP ==K CREATE   orBool
        OP ==K SLOAD    orBool
        OP ==K SSTORE   orBool
        isCallOp   (OP) orBool
        isCallSixOp(OP) orBool
        #addr?(OP)      orBool
        #code?(OP)
      )

    syntax Bool ::= "#addr?" "(" OpCode ")" [function]
 // --------------------------------------------------
    rule #addr?(BALANCE)      => true
    rule #addr?(SELFDESTRUCT) => true
    rule #addr?(EXTCODEHASH)  => true
    rule #addr?(OP)           => false requires (OP =/=K BALANCE) andBool (OP =/=K SELFDESTRUCT) andBool (OP =/=K EXTCODEHASH)

    syntax Bool ::= "#code?" "(" OpCode ")" [function]
 // --------------------------------------------------
    rule #code?(EXTCODESIZE)  => true
    rule #code?(EXTCODECOPY)  => true
    rule #code?(OP)           => false requires (OP =/=K EXTCODESIZE) andBool (OP =/=K EXTCODECOPY)
```

### Program Counter

All operators except for `PUSH` and `JUMP*` increment the program counter by 1.
The arguments to `PUSH` must be skipped over (as they are inline), and the opcode `JUMP` already affects the program counter in the correct way.

-   `#pc` calculates the next program counter of the given operator.

```k
    syntax InternalOp ::= "#pc" "[" OpCode "]"
 // ------------------------------------------
    rule <k> #pc [ OP ] => . ... </k>
         <pc> PCOUNT => PCOUNT +Int #widthOp(OP) </pc>

    syntax Int ::= #widthOp ( OpCode ) [function]
 // ---------------------------------------------
    rule #widthOp(PUSH(N, _)) => 1 +Int N
    rule #widthOp(OP)         => 1        requires notBool isPushOp(OP)
```

### Substate Log

During execution of a transaction some things are recorded in the substate log (Section 6.1 in YellowPaper).
This is a right cons-list of `SubstateLogEntry` (which contains the account ID along with the specified portions of the `wordStack` and `localMem`).

```k
    syntax SubstateLogEntry ::= "{" Int "|" List "|" ByteArray "}" [klabel(logEntry)]
 // ---------------------------------------------------------------------------------
```

After executing a transaction, it's necessary to have the effect of the substate log recorded.

-   `#finalizeStorage` updates the origStorage cell with the new values of storage.
-   `#finalizeTx` makes the substate log actually have an effect on the state.
-   `#deleteAccounts` deletes the accounts specified by the self destruct list.

```k
    syntax InternalOp ::= #finalizeStorage ( List )
 // -----------------------------------------------
    rule <k> #finalizeStorage((ListItem(ACCT) => .List) _) ... </k>
         <account>
           <acctID> ACCT </acctID>
           <storage> STORAGE </storage>
           <origStorage> _ => STORAGE </origStorage>
           ...
         </account>

    rule <k> #finalizeStorage(.List) => . ... </k>

    syntax InternalOp ::= #finalizeTx ( Bool )
                        | #deleteAccounts ( List )
 // ----------------------------------------------
    rule <k> #finalizeTx(true) => #finalizeStorage(Set2List(ACCTS)) ... </k>
         <selfDestruct> .Set </selfDestruct>
         <activeAccounts> ACCTS </activeAccounts>

    rule <k> (.K => #newAccount MINER) ~> #finalizeTx(_)... </k>
         <coinbase> MINER </coinbase>
         <activeAccounts> ACCTS </activeAccounts>
      requires notBool MINER in ACCTS

    rule <k> #finalizeTx(false) ... </k>
         <gas> GAVAIL => G*(GAVAIL, GLIMIT, REFUND) </gas>
         <refund> REFUND => 0 </refund>
         <txPending> ListItem(MSGID:Int) ... </txPending>
         <message>
            <msgID> MSGID </msgID>
            <txGasLimit> GLIMIT </txGasLimit>
            ...
         </message>
      requires REFUND =/=Int 0

    rule <k> #finalizeTx(false => true) ... </k>
         <origin> ORG </origin>
         <coinbase> MINER </coinbase>
         <gas> GAVAIL </gas>
         <refund> 0 </refund>
         <account>
           <acctID> ORG </acctID>
           <balance> ORGBAL => ORGBAL +Int GAVAIL *Int GPRICE </balance>
           ...
         </account>
         <account>
           <acctID> MINER </acctID>
           <balance> MINBAL => MINBAL +Int (GLIMIT -Int GAVAIL) *Int GPRICE </balance>
           ...
         </account>
         <txPending> ListItem(TXID:Int) => .List ... </txPending>
         <message>
           <msgID> TXID </msgID>
           <txGasLimit> GLIMIT </txGasLimit>
           <txGasPrice> GPRICE </txGasPrice>
           ...
         </message>
      requires ORG =/=Int MINER

    rule <k> #finalizeTx(false => true) ... </k>
         <origin> ACCT </origin>
         <coinbase> ACCT </coinbase>
         <refund> 0 </refund>
         <account>
           <acctID> ACCT </acctID>
           <balance> BAL => BAL +Int GLIMIT *Int GPRICE </balance>
           ...
         </account>
         <txPending> ListItem(MsgId:Int) => .List ... </txPending>
         <message>
           <msgID> MsgId </msgID>
           <txGasLimit> GLIMIT </txGasLimit>
           <txGasPrice> GPRICE </txGasPrice>
           ...
         </message>

    rule <k> (. => #deleteAccounts(Set2List(ACCTS))) ~> #finalizeTx(true) ... </k>
         <selfDestruct> ACCTS => .Set </selfDestruct>
      requires size(ACCTS) >Int 0

    rule <k> #deleteAccounts(ListItem(ACCT) ACCTS) => #deleteAccounts(ACCTS) ... </k>
         <activeAccounts> ... (SetItem(ACCT) => .Set) </activeAccounts>
         <accounts>
           ( <account>
               <acctID> ACCT </acctID>
               ...
             </account>
          => .Bag
           )
           ...
         </accounts>

    rule <k> #deleteAccounts(.List) => . ... </k>
```

EVM Programs
============

### Program Structure

Cons-lists of opcodes form programs (using cons operator `_;_`).
Operator `#revOps` can be used to reverse a program.

```k
    syntax OpCodes ::= ".OpCodes" | OpCode ";" OpCodes
 // --------------------------------------------------

    syntax OpCodes ::= #revOps    ( OpCodes )           [function]
                     | #revOpsAux ( OpCodes , OpCodes ) [function]
 // --------------------------------------------------------------
    rule #revOps(OPS) => #revOpsAux(OPS, .OpCodes)

    rule #revOpsAux( .OpCodes , OPS' ) => OPS'
    rule #revOpsAux( OP ; OPS , OPS' ) => #revOpsAux( OPS , OP ; OPS' )
```

### Converting to/from `Map` Representation

```k
    syntax Map ::= #asMapOpCodes    ( OpCodes )             [function]
                 | #asMapOpCodesAux ( Int , OpCodes , Map ) [function]
 // ------------------------------------------------------------------
    rule #asMapOpCodes( OPS::OpCodes ) => #asMapOpCodesAux(0, OPS, .Map)

    rule #asMapOpCodesAux( N , .OpCodes         , MAP ) => MAP
    rule #asMapOpCodesAux( N , OP:OpCode  ; OCS , MAP ) => #asMapOpCodesAux(N +Int #widthOp(OP), OCS, MAP [ N <- OP ])
```

EVM OpCodes
-----------


### Internal Operations

These are just used by the other operators for shuffling local execution state around on the EVM.

-   `#push` will push an element to the `wordStack` without any checks.
-   `#setStack_` will set the current stack to the given one.

```k
    syntax InternalOp ::= "#push" | "#setStack" WordStack
 // -----------------------------------------------------
    rule <k> W0:Int ~> #push => . ... </k> <wordStack> WS => W0 : WS </wordStack>
    rule <k> #setStack WS    => . ... </k> <wordStack> _  => WS      </wordStack>
```

-   `#newAccount_` allows declaring a new empty account with the given address (and assumes the rounding to 160 bits has already occured).
    If the account already exists with non-zero nonce or non-empty code, an exception is thrown.
    Otherwise, if the account already exists, the storage is cleared.

```k
    syntax InternalOp ::= "#newAccount" Int
 // ---------------------------------------
    rule <k> #newAccount ACCT => #end EVMC_ACCOUNT_ALREADY_EXISTS ... </k>
         <account>
           <acctID> ACCT  </acctID>
           <code>   CODE  </code>
           <nonce>  NONCE </nonce>
           ...
         </account>
      requires CODE =/=K .ByteArray orBool NONCE =/=Int 0

    rule <k> #newAccount ACCT => . ... </k>
         <account>
           <acctID>      ACCT       </acctID>
           <code>        WS         </code>
           <nonce>       0          </nonce>
           <storage>     _ => .Map  </storage>
           <origStorage> _ => .Map  </origStorage>
           ...
         </account>
      requires #sizeByteArray(WS) ==Int 0

    rule <k> #newAccount ACCT => . ... </k>
         <activeAccounts> ACCTS (.Set => SetItem(ACCT)) </activeAccounts>
         <accounts>
           ( .Bag
          => <account>
               <acctID>  ACCT       </acctID>
               ...
             </account>
           )
           ...
         </accounts>
      requires notBool ACCT in ACCTS
```

The following operations help with loading account information from an external running client.
This minimizes the amount of information which must be stored in the configuration.

-   `#loadAccount` queries for account data from the running client.
-   `#lookupCode` loads the code of an account into the `<code>` cell.
-   `#lookupStorage` loads the value of the specified storage key into the `<storage>` cell.

```k
    syntax InternalOp ::= "#loadAccount"   Int
                        | "#lookupCode"    Int
                        | "#lookupStorage" Int Int
 // ----------------------------------------------
```

In `standalone` mode, the semantics assumes that all relevant account data is already loaded into memory.

```{.k .standalone}
    rule <k> #loadAccount   _   => . ... </k>
    rule <k> #lookupCode    _   => . ... </k>
    rule <k> #lookupStorage _ _ => . ... </k>
```

In `node` mode, the semantics are given in terms of an external call to a running client.

```{.k .node}
    rule <k> #lookupStorage ACCT INDEX => . ... </k>
         <account>
           <acctID> ACCT </acctID>
           <storage> STORAGE:Map </storage>
           ...
         </account>
      requires INDEX in_keys(STORAGE)
```

-   `#transferFunds` moves money from one account into another, creating the destination account if it doesn't exist.

```k
    syntax InternalOp ::= "#transferFunds" Int Int Int
 // --------------------------------------------------
    rule <k> #transferFunds ACCT ACCT VALUE => . ... </k>
         <account>
           <acctID> ACCT </acctID>
           <balance> ORIGFROM </balance>
           ...
         </account>
      requires VALUE <=Int ORIGFROM

    rule <k> #transferFunds ACCTFROM ACCTTO VALUE => . ... </k>
         <account>
           <acctID> ACCTFROM </acctID>
           <balance> ORIGFROM => ORIGFROM -Word VALUE </balance>
           ...
         </account>
         <account>
           <acctID> ACCTTO </acctID>
           <balance> ORIGTO => ORIGTO +Word VALUE </balance>
           ...
         </account>
      requires ACCTFROM =/=K ACCTTO andBool VALUE <=Int ORIGFROM

    rule <k> #transferFunds ACCTFROM ACCTTO VALUE => #end EVMC_BALANCE_UNDERFLOW ... </k>
         <account>
           <acctID> ACCTFROM </acctID>
           <balance> ORIGFROM </balance>
           ...
         </account>
      requires VALUE >Int ORIGFROM

    rule <k> (. => #newAccount ACCTTO) ~> #transferFunds ACCTFROM ACCTTO VALUE ... </k>
         <activeAccounts> ACCTS </activeAccounts>
         <schedule> SCHED </schedule>
      requires ACCTFROM =/=K ACCTTO
       andBool notBool ACCTTO in ACCTS
       andBool (VALUE >Int 0 orBool notBool Gemptyisnonexistent << SCHED >>)

    rule <k> #transferFunds ACCTFROM ACCTTO 0 => . ... </k>
         <activeAccounts> ACCTS </activeAccounts>
         <schedule> SCHED </schedule>
      requires ACCTFROM =/=K ACCTTO
       andBool notBool ACCTTO in ACCTS
       andBool Gemptyisnonexistent << SCHED >>
```

### Invalid Operator

We use `INVALID` both for marking the designated invalid operator, and `UNDEFINED(_)` for garbage bytes in the input program.

```k
    syntax InvalidOp ::= "INVALID" | "UNDEFINED" "(" Int ")"
 // --------------------------------------------------------
    rule <k> INVALID      => #end EVMC_INVALID_INSTRUCTION   ... </k>
    rule <k> UNDEFINED(_) => #end EVMC_UNDEFINED_INSTRUCTION ... </k>
```

### Stack Manipulations

Some operators don't calculate anything, they just push the stack around a bit.

```k
    syntax UnStackOp ::= "POP"
 // --------------------------
    rule <k> POP W => . ... </k>

    syntax StackOp ::= DUP ( Int ) | SWAP ( Int )
 // ---------------------------------------------
    rule <k> DUP(N)  WS:WordStack => #setStack ((WS [ N -Int 1 ]) : WS)                      ... </k>
    rule <k> SWAP(N) (W0 : WS)    => #setStack ((WS [ N -Int 1 ]) : (WS [ N -Int 1 := W0 ])) ... </k>

    syntax PushOp ::= PUSH ( Int , Int )
 // ------------------------------------
    rule <k> PUSH(_, W) => W ~> #push ... </k>
```

### Local Memory

These operations are getters/setters of the local execution memory.

```k
    syntax UnStackOp ::= "MLOAD"
 // ----------------------------
    rule <k> MLOAD INDEX => #asWord(#range(LM, INDEX, 32)) ~> #push ... </k>
         <localMem> LM </localMem>

    syntax BinStackOp ::= "MSTORE" | "MSTORE8"
 // ------------------------------------------
    rule <k> MSTORE INDEX VALUE => . ... </k>
         <localMem> LM => LM [ INDEX := #padToWidth(32, #asByteStack(VALUE)) ] </localMem>

    rule <k> MSTORE8 INDEX VALUE => . ... </k>
         <localMem> LM => LM [ INDEX <- (VALUE modInt 256) ] </localMem>
```

### Expressions

Expression calculations are simple and don't require anything but the arguments from the `wordStack` to operate.

NOTE: We have to call the opcode `OR` by `EVMOR` instead, because K has trouble parsing it/compiling the definition otherwise.

```k
    syntax UnStackOp ::= "ISZERO" | "NOT"
 // -------------------------------------
    rule <k> ISZERO W => W ==Word 0 ~> #push ... </k>
    rule <k> NOT    W => ~Word W    ~> #push ... </k>

    syntax BinStackOp ::= "ADD" | "MUL" | "SUB" | "DIV" | "EXP" | "MOD"
 // -------------------------------------------------------------------
    rule <k> ADD W0 W1 => W0 +Word W1 ~> #push ... </k>
    rule <k> MUL W0 W1 => W0 *Word W1 ~> #push ... </k>
    rule <k> SUB W0 W1 => W0 -Word W1 ~> #push ... </k>
    rule <k> DIV W0 W1 => W0 /Word W1 ~> #push ... </k>
    rule <k> EXP W0 W1 => W0 ^Word W1 ~> #push ... </k>
    rule <k> MOD W0 W1 => W0 %Word W1 ~> #push ... </k>

    syntax BinStackOp ::= "SDIV" | "SMOD"
 // -------------------------------------
    rule <k> SDIV W0 W1 => W0 /sWord W1 ~> #push ... </k>
    rule <k> SMOD W0 W1 => W0 %sWord W1 ~> #push ... </k>

    syntax TernStackOp ::= "ADDMOD" | "MULMOD"
 // ------------------------------------------
    rule <k> ADDMOD W0 W1 W2 => (W0 +Int W1) %Word W2 ~> #push ... </k>
    rule <k> MULMOD W0 W1 W2 => (W0 *Int W1) %Word W2 ~> #push ... </k>

    syntax BinStackOp ::= "BYTE" | "SIGNEXTEND"
 // -------------------------------------------
    rule <k> BYTE INDEX W     => byte(INDEX, W)     ~> #push ... </k>
    rule <k> SIGNEXTEND W0 W1 => signextend(W0, W1) ~> #push ... </k>

    syntax BinStackOp ::= "SHL" | "SHR" | "SAR"
 // -------------------------------------------
    rule <k> SHL W0 W1 => W1 <<Word  W0 ~> #push ... </k>
    rule <k> SHR W0 W1 => W1 >>Word  W0 ~> #push ... </k>
    rule <k> SAR W0 W1 => W1 >>sWord W0 ~> #push ... </k>

    syntax BinStackOp ::= "AND" | "EVMOR" | "XOR"
 // ---------------------------------------------
    rule <k> AND   W0 W1 => W0 &Word W1   ~> #push ... </k>
    rule <k> EVMOR W0 W1 => W0 |Word W1   ~> #push ... </k>
    rule <k> XOR   W0 W1 => W0 xorWord W1 ~> #push ... </k>

    syntax BinStackOp ::= "LT" | "GT" | "EQ"
 // ----------------------------------------
    rule <k> LT W0 W1 => W0 <Word  W1 ~> #push ... </k>
    rule <k> GT W0 W1 => W0 >Word  W1 ~> #push ... </k>
    rule <k> EQ W0 W1 => W0 ==Word W1 ~> #push ... </k>

    syntax BinStackOp ::= "SLT" | "SGT"
 // -----------------------------------
    rule <k> SLT W0 W1 => W0 s<Word W1 ~> #push ... </k>
    rule <k> SGT W0 W1 => W1 s<Word W0 ~> #push ... </k>

    syntax BinStackOp ::= "SHA3"
 // ----------------------------
    rule <k> SHA3 MEMSTART MEMWIDTH => keccak(#range(LM, MEMSTART, MEMWIDTH)) ~> #push ... </k>
         <localMem> LM </localMem>
```

### Local State

These operators make queries about the current execution state.

```k
    syntax NullStackOp ::= "PC" | "GAS" | "GASPRICE" | "GASLIMIT"
 // -------------------------------------------------------------
    rule <k> PC       => PCOUNT ~> #push ... </k> <pc> PCOUNT </pc>
    rule <k> GAS      => GAVAIL ~> #push ... </k> <gas> GAVAIL </gas>
    rule <k> GASPRICE => GPRICE ~> #push ... </k> <gasPrice> GPRICE </gasPrice>
    rule <k> GASLIMIT => GLIMIT ~> #push ... </k> <gasLimit> GLIMIT </gasLimit>

    syntax NullStackOp ::= "COINBASE" | "TIMESTAMP" | "NUMBER" | "DIFFICULTY"
 // -------------------------------------------------------------------------
    rule <k> COINBASE   => CB   ~> #push ... </k> <coinbase> CB </coinbase>
    rule <k> TIMESTAMP  => TS   ~> #push ... </k> <timestamp> TS </timestamp>
    rule <k> NUMBER     => NUMB ~> #push ... </k> <number> NUMB </number>
    rule <k> DIFFICULTY => DIFF ~> #push ... </k> <difficulty> DIFF </difficulty>

    syntax NullStackOp ::= "ADDRESS" | "ORIGIN" | "CALLER" | "CALLVALUE"
 // --------------------------------------------------------------------
    rule <k> ADDRESS   => ACCT ~> #push ... </k> <id> ACCT </id>
    rule <k> ORIGIN    => ORG  ~> #push ... </k> <origin> ORG </origin>
    rule <k> CALLER    => CL   ~> #push ... </k> <caller> CL </caller>
    rule <k> CALLVALUE => CV   ~> #push ... </k> <callValue> CV </callValue>

    syntax NullStackOp ::= "MSIZE" | "CODESIZE"
 // -------------------------------------------
    rule <k> MSIZE    => 32 *Word MU         ~> #push ... </k> <memoryUsed> MU </memoryUsed>
    rule <k> CODESIZE => #sizeByteArray(PGM) ~> #push ... </k> <programBytes> PGM </programBytes>

    syntax TernStackOp ::= "CODECOPY"
 // ---------------------------------
    rule <k> CODECOPY MEMSTART PGMSTART WIDTH => . ... </k>
         <programBytes> PGM </programBytes>
         <localMem> LM => LM [ MEMSTART := PGM [ PGMSTART .. WIDTH ] ] </localMem>

    syntax UnStackOp ::= "BLOCKHASH"
 // --------------------------------
```

When running as a `node`, the blockhash will be retrieved from the running client.
Otherwise, it is calculated here using the "shortcut" formula used for running tests.

```{.k .standalone}
    rule <k> BLOCKHASH N => #blockhash(HASHES, N, HI -Int 1, 0) ~> #push ... </k>
         <number>    HI     </number>
         <blockhash> HASHES </blockhash>

    syntax Int ::= #blockhash ( List , Int , Int , Int ) [function]
 // ---------------------------------------------------------------
    rule #blockhash(_, N, HI, _) => 0 requires N >Int HI
    rule #blockhash(_, _, _, 256) => 0
    rule #blockhash(ListItem(0) _, _, _, _) => 0
    rule #blockhash(ListItem(H) _, N, N, _) => H
    rule #blockhash(ListItem(_) L, N, HI, A) => #blockhash(L, N, HI -Int 1, A +Int 1) [owise]
```

EVM OpCodes
-----------

### EVM Control Flow

The `JUMP*` family of operations affect the current program counter.

```k
    syntax NullStackOp ::= "JUMPDEST"
 // ---------------------------------
    rule <k> JUMPDEST => . ... </k>

    syntax UnStackOp ::= "JUMP"
 // ---------------------------
    rule <k> JUMP DEST => #if OP ==K JUMPDEST #then #endBasicBlock #else #end EVMC_BAD_JUMP_DESTINATION #fi ... </k>
         <pc> _ => DEST </pc>
         <program> ... DEST |-> OP ... </program>

    rule <k> JUMP DEST => #end EVMC_BAD_JUMP_DESTINATION ... </k>
         <program> PGM </program>
      requires notBool (DEST in_keys(PGM))

    syntax BinStackOp ::= "JUMPI"
 // -----------------------------
    rule <k> JUMPI DEST I => . ... </k>
      requires I ==Int 0

    rule <k> JUMPI DEST I => JUMP DEST ... </k>
      requires I =/=Int 0

    syntax InternalOp ::= "#endBasicBlock"
 // --------------------------------------
    rule <k> #endBasicBlock ~> (_:OpCode => .) ... </k>
    rule <k> (#endBasicBlock => .) ~> #execute ... </k>
```

### `STOP`, `REVERT`, and `RETURN`

```k
    syntax NullStackOp ::= "STOP"
 // -----------------------------
    rule <k> STOP => #end EVMC_SUCCESS ... </k>
         <output> _ => .ByteArray </output>

    syntax BinStackOp ::= "RETURN"
 // ------------------------------
    rule <k> RETURN RETSTART RETWIDTH => #end EVMC_SUCCESS ... </k>
         <output> _ => #range(LM, RETSTART, RETWIDTH) </output>
         <localMem> LM </localMem>

    syntax BinStackOp ::= "REVERT"
 // ------------------------------
    rule <k> REVERT RETSTART RETWIDTH => #end EVMC_REVERT ... </k>
         <output> _ => #range(LM, RETSTART, RETWIDTH) </output>
         <localMem> LM </localMem>
```

### Call Data

These operators query about the current `CALL*` state.

```k
    syntax NullStackOp ::= "CALLDATASIZE"
 // -------------------------------------
    rule <k> CALLDATASIZE => #sizeByteArray(CD) ~> #push ... </k>
         <callData> CD </callData>

    syntax UnStackOp ::= "CALLDATALOAD"
 // -----------------------------------
    rule <k> CALLDATALOAD DATASTART => #asWord(CD [ DATASTART .. 32 ]) ~> #push ... </k>
         <callData> CD </callData>

    syntax TernStackOp ::= "CALLDATACOPY"
 // -------------------------------------
    rule <k> CALLDATACOPY MEMSTART DATASTART DATAWIDTH => . ... </k>
         <localMem> LM => LM [ MEMSTART := CD [ DATASTART .. DATAWIDTH ] ] </localMem>
         <callData> CD </callData>
```

### Return Data

These operators query about the current return data buffer.

```k
    syntax NullStackOp ::= "RETURNDATASIZE"
 // ---------------------------------------
    rule <k> RETURNDATASIZE => #sizeByteArray(RD) ~> #push ... </k>
         <output> RD </output>

    syntax TernStackOp ::= "RETURNDATACOPY"
 // ----------------------------------------
    rule <k> RETURNDATACOPY MEMSTART DATASTART DATAWIDTH => . ... </k>
         <localMem> LM => LM [ MEMSTART := RD [ DATASTART .. DATAWIDTH ] ] </localMem>
         <output> RD </output>
      requires DATASTART +Int DATAWIDTH <=Int #sizeByteArray(RD)

    rule <k> RETURNDATACOPY MEMSTART DATASTART DATAWIDTH => #end EVMC_INVALID_MEMORY_ACCESS ... </k>
         <output> RD </output>
      requires DATASTART +Int DATAWIDTH >Int #sizeByteArray(RD)
```

### Log Operations

```k
    syntax BinStackOp ::= LogOp
    syntax LogOp ::= LOG ( Int )
 // ----------------------------
    rule <k> LOG(N) MEMSTART MEMWIDTH => . ... </k>
         <id> ACCT </id>
         <wordStack> WS => #drop(N, WS) </wordStack>
         <localMem> LM </localMem>
         <log> ... (.List => ListItem({ ACCT | WordStack2List(#take(N, WS)) | #range(LM, MEMSTART, MEMWIDTH) })) </log>
      requires #sizeWordStack(WS) >=Int N
```

Ethereum Network OpCodes
------------------------

Operators that require access to the rest of the Ethereum network world-state can be taken as a first draft of a "blockchain generic" language.

### Account Queries

TODO: It's unclear what to do in the case of an account not existing for these operators.
`BALANCE` is specified to push 0 in this case, but the others are not specified.
For now, I assume that they instantiate an empty account and use the empty data.

```k
    syntax UnStackOp ::= "BALANCE"
 // ------------------------------
    rule <k> BALANCE ACCT => BAL ~> #push ... </k>
         <account>
           <acctID> ACCT </acctID>
           <balance> BAL </balance>
           ...
         </account>

    rule <k> BALANCE ACCT => 0 ~> #push ... </k>
         <activeAccounts> ACCTS </activeAccounts>
      requires notBool ACCT in ACCTS

    syntax UnStackOp ::= "EXTCODESIZE"
 // ----------------------------------
    rule <k> EXTCODESIZE ACCT => #sizeByteArray(CODE) ~> #push ... </k>
         <account>
           <acctID> ACCT </acctID>
           <code> CODE </code>
           ...
         </account>

    rule <k> EXTCODESIZE ACCT => 0 ~> #push ... </k>
         <activeAccounts> ACCTS </activeAccounts>
      requires notBool ACCT in ACCTS

    syntax UnStackOp ::= "EXTCODEHASH"
 // ----------------------------------
```

```k
    rule <k> EXTCODEHASH ACCT => keccak(CODE) ~> #push ... </k>
         <account>
           <acctID> ACCT </acctID>
           <code> CODE:ByteArray </code>
           <nonce> NONCE </nonce>
           <balance> BAL </balance>
           ...
         </account>
      requires notBool #accountEmpty(CODE, NONCE, BAL)

     rule <k> EXTCODEHASH ACCT => 0 ~> #push ... </k>
         <account>
           <acctID> ACCT </acctID>
           <code> CODE </code>
           <nonce> NONCE </nonce>
           <balance> BAL </balance>
           ...
         </account>
       requires #accountEmpty(CODE, NONCE, BAL)

    rule <k> EXTCODEHASH ACCT => 0 ~> #push ... </k>
         <activeAccounts> ACCTS </activeAccounts>
      requires notBool ACCT in ACCTS
```

TODO: What should happen in the case that the account doesn't exist with `EXTCODECOPY`?
Should we pad zeros (for the copied "program")?

```k
    syntax QuadStackOp ::= "EXTCODECOPY"
 // ------------------------------------
    rule <k> EXTCODECOPY ACCT MEMSTART PGMSTART WIDTH => . ... </k>
         <localMem> LM => LM [ MEMSTART := PGM [ PGMSTART .. WIDTH ] ] </localMem>
         <account>
           <acctID> ACCT </acctID>
           <code> PGM </code>
           ...
         </account>

    rule <k> EXTCODECOPY ACCT MEMSTART PGMSTART WIDTH => . ... </k>
         <activeAccounts> ACCTS </activeAccounts>
      requires notBool ACCT in ACCTS
```

### Account Storage Operations

These rules reach into the network state and load/store from account storage:

```k
    syntax UnStackOp ::= "SLOAD"
 // ----------------------------
    rule <k> SLOAD INDEX => #lookup(STORAGE, INDEX) ~> #push ... </k>
         <id> ACCT </id>
         <account>
           <acctID> ACCT </acctID>
           <storage> STORAGE </storage>
           ...
         </account>

    syntax BinStackOp ::= "SSTORE"
 // ------------------------------
    rule <k> SSTORE INDEX NEW => . ... </k>
         <id> ACCT </id>
         <account>
           <acctID> ACCT </acctID>
           <storage> STORAGE => STORAGE [ INDEX <- NEW ] </storage>
           ...
         </account>
```

### Call Operations

The various `CALL*` (and other inter-contract control flow) operations will be desugared into these `InternalOp`s.

-   The `callLog` is used to store the `CALL*`/`CREATE` operations so that we can compare them against the test-set.

```k
    syntax Call ::= "{" Int "|" Int "|" Int "|" WordStack "}"
 // ---------------------------------------------------------
```

-   `#call_____` takes the calling account, the account to execute as, the account whose code should execute, the gas limit, the amount to transfer, and the arguments.
-   `#callWithCode______` takes the calling account, the accout to execute as, the code to execute (as a map), the gas limit, the amount to transfer, and the arguments.
-   `#return__` is a placeholder for the calling program, specifying where to place the returned data in memory.

```k
    syntax InternalOp ::= "#checkCall" Int Int
                        | "#call"         Int Int Int Int Int ByteArray Bool
                        | "#callWithCode" Int Int Map ByteArray Int Int ByteArray Bool
                        | "#mkCall"       Int Int Map ByteArray     Int ByteArray Bool
 // ----------------------------------------------------------------------------------
    rule <k> #checkCall ACCT VALUE
          => #refund GCALL ~> #pushCallStack ~> #pushWorldState
          ~> #end #if VALUE >Int BAL #then EVMC_BALANCE_UNDERFLOW #else EVMC_CALL_DEPTH_EXCEEDED #fi
         ...
         </k>
         <callDepth> CD </callDepth>
         <output> _ => .ByteArray </output>
         <account>
           <acctID> ACCT </acctID>
           <balance> BAL </balance>
           ...
         </account>
         <callGas> GCALL </callGas>
      requires VALUE >Int BAL orBool CD >=Int 1024

     rule <k> #checkCall ACCT VALUE => . ... </k>
         <callDepth> CD </callDepth>
         <account>
           <acctID> ACCT </acctID>
           <balance> BAL </balance>
           ...
         </account>
      requires notBool (VALUE >Int BAL orBool CD >=Int 1024)

    rule <k> #call ACCTFROM ACCTTO ACCTCODE VALUE APPVALUE ARGS STATIC
          => #callWithCode ACCTFROM ACCTTO (0 |-> #precompiled(ACCTCODE)) .ByteArray VALUE APPVALUE ARGS STATIC
         ...
         </k>
         <schedule> SCHED </schedule>
      requires ACCTCODE in #precompiledAccounts(SCHED)

    rule <k> #call ACCTFROM ACCTTO ACCTCODE VALUE APPVALUE ARGS STATIC
          => #callWithCode ACCTFROM ACCTTO #asMapOpCodes(#dasmOpCodes(CODE, SCHED)) CODE VALUE APPVALUE ARGS STATIC
         ...
         </k>
         <schedule> SCHED </schedule>
         <account>
           <acctID> ACCTCODE </acctID>
           <code> CODE </code>
           ...
         </account>
      requires notBool ACCTCODE in #precompiledAccounts(SCHED)

    rule <k> #call ACCTFROM ACCTTO ACCTCODE VALUE APPVALUE ARGS STATIC
          => #callWithCode ACCTFROM ACCTTO .Map .ByteArray VALUE APPVALUE ARGS STATIC
         ...
         </k>
         <activeAccounts> ACCTS </activeAccounts>
         <schedule> SCHED </schedule>
      requires notBool ACCTCODE in #precompiledAccounts(SCHED) andBool notBool ACCTCODE in ACCTS

    rule <k> #callWithCode ACCTFROM ACCTTO CODE BYTES VALUE APPVALUE ARGS STATIC
          => #pushCallStack ~> #pushWorldState
          ~> #transferFunds ACCTFROM ACCTTO VALUE
          ~> #mkCall ACCTFROM ACCTTO CODE BYTES APPVALUE ARGS STATIC
         ...
         </k>

    rule <k> #mkCall ACCTFROM ACCTTO CODE BYTES APPVALUE ARGS STATIC:Bool
          => #initVM ~> #execute
         ...
         </k>
         <callDepth> CD => CD +Int 1 </callDepth>
         <callData> _ => ARGS </callData>
         <callValue> _ => APPVALUE </callValue>
         <id> _ => ACCTTO </id>
         <gas> _ => GCALL </gas>
         <callGas> GCALL => 0 </callGas>
         <caller> _ => ACCTFROM </caller>
         <program> _ => CODE </program>
         <programBytes> _ => BYTES </programBytes>
         <static> OLDSTATIC:Bool => OLDSTATIC orBool STATIC </static>
         <touchedAccounts> ... .Set => SetItem(ACCTFROM) SetItem(ACCTTO) ... </touchedAccounts>

    syntax KItem ::= "#initVM"
 // --------------------------
    rule <k> #initVM    => . ...      </k>
         <pc>         _ => 0          </pc>
         <memoryUsed> _ => 0          </memoryUsed>
         <output>     _ => .ByteArray </output>
         <wordStack>  _ => .WordStack </wordStack>
         <localMem>   _ => .Map       </localMem>

    syntax KItem ::= "#return" Int Int
 // ----------------------------------
    rule <statusCode> _:ExceptionalStatusCode </statusCode>
         <k> #halt ~> #return _ _
          => #popCallStack ~> #popWorldState ~> 0 ~> #push
         ...
         </k>
         <output> _ => .ByteArray </output>

    rule <statusCode> EVMC_REVERT </statusCode>
         <k> #halt ~> #return RETSTART RETWIDTH
          => #popCallStack ~> #popWorldState
          ~> 0 ~> #push ~> #refund GAVAIL ~> #setLocalMem RETSTART RETWIDTH OUT
         ...
         </k>
         <output> OUT </output>
         <gas> GAVAIL </gas>

    rule <statusCode> EVMC_SUCCESS </statusCode>
         <k> #halt ~> #return RETSTART RETWIDTH
          => #popCallStack ~> #dropWorldState
          ~> 1 ~> #push ~> #refund GAVAIL ~> #setLocalMem RETSTART RETWIDTH OUT
         ...
         </k>
         <output> OUT </output>
         <gas> GAVAIL </gas>

    syntax InternalOp ::= "#refund" Exp [strict]
                        | "#setLocalMem" Int Int ByteArray
 // ------------------------------------------------------
    rule [refund]: <k> #refund G:Int => . ... </k> <gas> GAVAIL => GAVAIL +Int G </gas>

    rule <k> #setLocalMem START WIDTH WS => . ... </k>
         <localMem> LM => LM [ START := WS [ 0 .. minInt(WIDTH, #sizeByteArray(WS)) ] ] </localMem>
```

Ethereum Network OpCodes
------------------------

### Call Operations

For each `CALL*` operation, we make a corresponding call to `#call` and a state-change to setup the custom parts of the calling environment.

```k
    syntax CallOp ::= "CALL"
 // ------------------------
    rule <k> CALL GCAP ACCTTO VALUE ARGSTART ARGWIDTH RETSTART RETWIDTH
          => #checkCall ACCTFROM VALUE
          ~> #call ACCTFROM ACCTTO ACCTTO VALUE VALUE #range(LM, ARGSTART, ARGWIDTH) false
          ~> #return RETSTART RETWIDTH
         ...
         </k>
         <schedule> SCHED </schedule>
         <id> ACCTFROM </id>
         <localMem> LM </localMem>

    syntax CallOp ::= "CALLCODE"
 // ----------------------------
    rule <k> CALLCODE GCAP ACCTTO VALUE ARGSTART ARGWIDTH RETSTART RETWIDTH
          => #checkCall ACCTFROM VALUE
          ~> #call ACCTFROM ACCTFROM ACCTTO VALUE VALUE #range(LM, ARGSTART, ARGWIDTH) false
          ~> #return RETSTART RETWIDTH
         ...
         </k>
         <schedule> SCHED </schedule>
         <id> ACCTFROM </id>
         <localMem> LM </localMem>

    syntax CallSixOp ::= "DELEGATECALL"
 // -----------------------------------
    rule <k> DELEGATECALL GCAP ACCTTO ARGSTART ARGWIDTH RETSTART RETWIDTH
          => #checkCall ACCTFROM 0
          ~> #call ACCTAPPFROM ACCTFROM ACCTTO 0 VALUE #range(LM, ARGSTART, ARGWIDTH) false
          ~> #return RETSTART RETWIDTH
         ...
         </k>
         <schedule> SCHED </schedule>
         <id> ACCTFROM </id>
         <caller> ACCTAPPFROM </caller>
         <callValue> VALUE </callValue>
         <localMem> LM </localMem>

    syntax CallSixOp ::= "STATICCALL"
 // ---------------------------------
    rule <k> STATICCALL GCAP ACCTTO ARGSTART ARGWIDTH RETSTART RETWIDTH
          => #checkCall ACCTFROM 0
          ~> #call ACCTFROM ACCTTO ACCTTO 0 0 #range(LM, ARGSTART, ARGWIDTH) true
          ~> #return RETSTART RETWIDTH
         ...
         </k>
         <schedule> SCHED </schedule>
         <id> ACCTFROM </id>
         <localMem> LM </localMem>
```

### Account Creation/Deletion

-   `#create____` transfers the endowment to the new account and triggers the execution of the initialization code.
-   `#codeDeposit_` checks the result of initialization code and whether the code deposit can be paid, indicating an error if not.

```k
    syntax InternalOp ::= "#create"   Int Int Int ByteArray
                        | "#mkCreate" Int Int Int ByteArray
                        | "#incrementNonce" Int
 // -------------------------------------------
    rule <k> #create ACCTFROM ACCTTO VALUE INITCODE
          => #incrementNonce ACCTFROM
          ~> #pushCallStack ~> #pushWorldState
          ~> #newAccount ACCTTO
          ~> #transferFunds ACCTFROM ACCTTO VALUE
          ~> #mkCreate ACCTFROM ACCTTO VALUE INITCODE
         ...
         </k>

    rule <k> #mkCreate ACCTFROM ACCTTO VALUE INITCODE
          => #initVM ~> #execute
         ...
         </k>
         <schedule> SCHED </schedule>
         <id> ACCT => ACCTTO </id>
         <gas> _ => GCALL </gas>
         <callGas> GCALL => 0 </callGas>
         <program> _ => #asMapOpCodes(#dasmOpCodes(INITCODE, SCHED)) </program>
         <programBytes> _ => INITCODE </programBytes>
         <caller> _ => ACCTFROM </caller>
         <callDepth> CD => CD +Int 1 </callDepth>
         <callData> _ => .ByteArray </callData>
         <callValue> _ => VALUE </callValue>
         <account>
           <acctID> ACCTTO </acctID>
           <nonce> NONCE => #if Gemptyisnonexistent << SCHED >> #then NONCE +Int 1 #else NONCE #fi </nonce>
           ...
         </account>
         <touchedAccounts> ... .Set => SetItem(ACCTFROM) SetItem(ACCTTO) ... </touchedAccounts>

    rule <k> #incrementNonce ACCT => . ... </k>
         <account>
           <acctID> ACCT </acctID>
           <nonce> NONCE => NONCE +Int 1 </nonce>
           ...
         </account>

    syntax KItem ::= "#codeDeposit" Int
                   | "#mkCodeDeposit" Int
                   | "#finishCodeDeposit" Int ByteArray
 // ---------------------------------------------------
    rule <statusCode> _:ExceptionalStatusCode </statusCode>
         <k> #halt ~> #codeDeposit _ => #popCallStack ~> #popWorldState ~> 0 ~> #push ... </k> <output> _ => .ByteArray </output>
    rule <statusCode> EVMC_REVERT </statusCode>
         <k> #halt ~> #codeDeposit _ => #popCallStack ~> #popWorldState ~> #refund GAVAIL ~> 0 ~> #push ... </k>
         <gas> GAVAIL </gas>

    rule <statusCode> EVMC_SUCCESS </statusCode>
         <k> #halt ~> #codeDeposit ACCT => #mkCodeDeposit ACCT ... </k>

    rule <k> #mkCodeDeposit ACCT
          => Gcodedeposit < SCHED > *Int #sizeByteArray(OUT) ~> #deductGas
          ~> #finishCodeDeposit ACCT OUT
         ...
         </k>
         <schedule> SCHED </schedule>
         <output> OUT => .ByteArray </output>
      requires #sizeByteArray(OUT) <=Int maxCodeSize < SCHED >

    rule <k> #mkCodeDeposit ACCT => #popCallStack ~> #popWorldState ~> 0 ~> #push ... </k>
         <schedule> SCHED </schedule>
         <output> OUT => .ByteArray </output>
      requires #sizeByteArray(OUT) >Int maxCodeSize < SCHED >

    rule <k> #finishCodeDeposit ACCT OUT
          => #popCallStack ~> #dropWorldState
          ~> #refund GAVAIL ~> ACCT ~> #push
         ...
         </k>
         <gas> GAVAIL </gas>
         <account>
           <acctID> ACCT </acctID>
           <code> _ => OUT </code>
           ...
         </account>

    rule <statusCode> _:ExceptionalStatusCode </statusCode>
         <k> #halt ~> #finishCodeDeposit ACCT _
          => #popCallStack ~> #dropWorldState
          ~> #refund GAVAIL ~> ACCT ~> #push
         ...
         </k>
         <gas> GAVAIL </gas>
         <schedule> FRONTIER </schedule>

    rule <statusCode> _:ExceptionalStatusCode </statusCode>
         <k> #halt ~> #finishCodeDeposit _ _ => #popCallStack ~> #popWorldState ~> 0 ~> #push ... </k>
         <schedule> SCHED </schedule>
      requires SCHED =/=K FRONTIER
```

`CREATE` will attempt to `#create` the account using the initialization code and cleans up the result with `#codeDeposit`.

```k
    syntax TernStackOp ::= "CREATE"
 // -------------------------------
    rule <k> CREATE VALUE MEMSTART MEMWIDTH
          => #checkCall ACCT VALUE
          ~> #create ACCT #newAddr(ACCT, NONCE) VALUE #range(LM, MEMSTART, MEMWIDTH)
          ~> #codeDeposit #newAddr(ACCT, NONCE)
         ...
         </k>
         <schedule> SCHED </schedule>
         <id> ACCT </id>
         <localMem> LM </localMem>
         <account>
           <acctID> ACCT </acctID>
           <nonce> NONCE </nonce>
           ...
         </account>
```

`CREATE2` will attempt to `#create` the account, but with the new scheme for choosing the account address.
Note that we cannot execute #loadAccount during the #load phase earlier because gas will not yet
have been paid, and it may be to expensive to compute the hash of the init code.

```k
    syntax QuadStackOp ::= "CREATE2"
 // --------------------------------
    rule <k> CREATE2 VALUE MEMSTART MEMWIDTH SALT
          => #loadAccount #newAddr(ACCT, SALT, #range(LM, MEMSTART, MEMWIDTH))
          ~> #checkCall ACCT VALUE
          ~> #create ACCT #newAddr(ACCT, SALT, #range(LM, MEMSTART, MEMWIDTH)) VALUE #range(LM, MEMSTART, MEMWIDTH)
          ~> #codeDeposit #newAddr(ACCT, SALT, #range(LM, MEMSTART, MEMWIDTH))
         ...
         </k>
         <id> ACCT </id>
         <callGas> GCALL </callGas>
         <localMem> LM </localMem>
```

`SELFDESTRUCT` marks the current account for deletion and transfers funds out of the current account.
Self destructing to yourself, unlike a regular transfer, destroys the balance in the account, irreparably losing it.

```k
    syntax UnStackOp ::= "SELFDESTRUCT"
 // -----------------------------------
    rule <k> SELFDESTRUCT ACCTTO => #transferFunds ACCT ACCTTO BALFROM ~> #end EVMC_SUCCESS ... </k>
         <schedule> SCHED </schedule>
         <id> ACCT </id>
         <selfDestruct> ... (.Set => SetItem(ACCT)) ... </selfDestruct>
         <account>
           <acctID> ACCT </acctID>
           <balance> BALFROM </balance>
           ...
         </account>
         <output> _ => .ByteArray </output>
         <touchedAccounts> ... .Set => SetItem(ACCT) SetItem(ACCTTO) ... </touchedAccounts>
      requires ACCT =/=Int ACCTTO

    rule <k> SELFDESTRUCT ACCT => #end EVMC_SUCCESS ... </k>
         <schedule> SCHED </schedule>
         <id> ACCT </id>
         <selfDestruct> ... (.Set => SetItem(ACCT)) ... </selfDestruct>
         <account>
           <acctID> ACCT </acctID>
           <balance> BALFROM => 0 </balance>
           <nonce> NONCE </nonce>
           <code> CODE </code>
           ...
         </account>
         <output> _ => .ByteArray </output>
         <touchedAccounts> ... .Set => SetItem(ACCT) ... </touchedAccounts>
```

Precompiled Contracts
---------------------

-   `#precompiled` is a placeholder for the 8 pre-compiled contracts at addresses 1 through 8.

```k
    syntax NullStackOp   ::= PrecompiledOp
    syntax PrecompiledOp ::= #precompiled ( Int ) [function]
 // --------------------------------------------------------
    rule #precompiled(1) => ECREC
    rule #precompiled(2) => SHA256
    rule #precompiled(3) => RIP160
    rule #precompiled(4) => ID
    rule #precompiled(5) => MODEXP
    rule #precompiled(6) => ECADD
    rule #precompiled(7) => ECMUL
    rule #precompiled(8) => ECPAIRING

    syntax Set ::= #precompiledAccounts ( Schedule ) [function]
 // -----------------------------------------------------------
    rule #precompiledAccounts(DEFAULT)           => SetItem(1) SetItem(2) SetItem(3) SetItem(4)
    rule #precompiledAccounts(FRONTIER)          => #precompiledAccounts(DEFAULT)
    rule #precompiledAccounts(HOMESTEAD)         => #precompiledAccounts(FRONTIER)
    rule #precompiledAccounts(TANGERINE_WHISTLE) => #precompiledAccounts(HOMESTEAD)
    rule #precompiledAccounts(SPURIOUS_DRAGON)   => #precompiledAccounts(TANGERINE_WHISTLE)
    rule #precompiledAccounts(BYZANTIUM)         => #precompiledAccounts(SPURIOUS_DRAGON) SetItem(5) SetItem(6) SetItem(7) SetItem(8)
    rule #precompiledAccounts(CONSTANTINOPLE)    => #precompiledAccounts(BYZANTIUM)
    rule #precompiledAccounts(PETERSBURG)        => #precompiledAccounts(CONSTANTINOPLE)
```

-   `ECREC` performs ECDSA public key recovery.
-   `SHA256` performs the SHA2-257 hash function.
-   `RIP160` performs the RIPEMD-160 hash function.
-   `ID` is the identity function (copies input to output).

```k
    syntax PrecompiledOp ::= "ECREC"
 // --------------------------------
    rule <k> ECREC => #end EVMC_SUCCESS ... </k>
         <callData> DATA </callData>
         <output> _ => #ecrec(#sender(#unparseByteStack(DATA [ 0 .. 32 ]), #asWord(DATA [ 32 .. 32 ]), #unparseByteStack(DATA [ 64 .. 32 ]), #unparseByteStack(DATA [ 96 .. 32 ]))) </output>

    syntax ByteArray ::= #ecrec ( Account ) [function]
 // --------------------------------------------------
    rule #ecrec(.Account) => .ByteArray
    rule #ecrec(N:Int)    => #padToWidth(32, #asByteStack(N))

    syntax PrecompiledOp ::= "SHA256"
 // ---------------------------------
    rule <k> SHA256 => #end EVMC_SUCCESS ... </k>
         <callData> DATA </callData>
         <output> _ => #parseHexBytes(Sha256(#unparseByteStack(DATA))) </output>

    syntax PrecompiledOp ::= "RIP160"
 // ---------------------------------
    rule <k> RIP160 => #end EVMC_SUCCESS ... </k>
         <callData> DATA </callData>
         <output> _ => #padToWidth(32, #parseHexBytes(RipEmd160(#unparseByteStack(DATA)))) </output>

    syntax PrecompiledOp ::= "ID"
 // -----------------------------
    rule <k> ID => #end EVMC_SUCCESS ... </k>
         <callData> DATA </callData>
         <output> _ => DATA </output>

    syntax PrecompiledOp ::= "MODEXP"
 // ---------------------------------
    rule <k> MODEXP => #end EVMC_SUCCESS ... </k>
         <callData> DATA </callData>
         <output> _ => #modexp1(#asWord(DATA [ 0 .. 32 ]), #asWord(DATA [ 32 .. 32 ]), #asWord(DATA [ 64 .. 32 ]), DATA [ 96 .. maxInt(0, #sizeByteArray(DATA) -Int 96) ]) </output>

    syntax ByteArray ::= #modexp1 ( Int , Int , Int , ByteArray ) [function]
                       | #modexp2 ( Int , Int , Int , ByteArray ) [function]
                       | #modexp3 ( Int , Int , Int , ByteArray ) [function]
                       | #modexp4 ( Int , Int , Int )             [function]
 // ------------------------------------------------------------------------
    rule #modexp1(BASELEN, EXPLEN,   MODLEN, DATA) => #modexp2(#asInteger(DATA [ 0 .. BASELEN ]), EXPLEN, MODLEN, DATA [ BASELEN .. maxInt(0, #sizeByteArray(DATA) -Int BASELEN) ]) requires MODLEN =/=Int 0
    rule #modexp1(_,       _,        0,      _)    => .ByteArray
    rule #modexp2(BASE,    EXPLEN,   MODLEN, DATA) => #modexp3(BASE, #asInteger(DATA [ 0 .. EXPLEN ]), MODLEN, DATA [ EXPLEN .. maxInt(0, #sizeByteArray(DATA) -Int EXPLEN) ])
    rule #modexp3(BASE,    EXPONENT, MODLEN, DATA) => #padToWidth(MODLEN, #modexp4(BASE, EXPONENT, #asInteger(DATA [ 0 .. MODLEN ])))
    rule #modexp4(BASE,    EXPONENT, MODULUS)      => #asByteStack(powmod(BASE, EXPONENT, MODULUS))

    syntax PrecompiledOp ::= "ECADD"
 // --------------------------------
    rule <k> ECADD => #ecadd((#asWord(DATA [ 0 .. 32 ]), #asWord(DATA [ 32 .. 32 ])), (#asWord(DATA [ 64 .. 32 ]), #asWord(DATA [ 96 .. 32 ]))) ... </k>
         <callData> DATA </callData>

    syntax InternalOp ::= #ecadd(G1Point, G1Point)
 // ----------------------------------------------
    rule <k> #ecadd(P1, P2) => #end EVMC_PRECOMPILE_FAILURE ... </k>
      requires notBool isValidPoint(P1) orBool notBool isValidPoint(P2)
    rule <k> #ecadd(P1, P2) => #end EVMC_SUCCESS ... </k> <output> _ => #point(BN128Add(P1, P2)) </output>
      requires isValidPoint(P1) andBool isValidPoint(P2)

    syntax PrecompiledOp ::= "ECMUL"
 // --------------------------------
    rule <k> ECMUL => #ecmul((#asWord(DATA [ 0 .. 32 ]), #asWord(DATA [ 32 .. 32 ])), #asWord(DATA [ 64 .. 32 ])) ... </k>
         <callData> DATA </callData>

    syntax InternalOp ::= #ecmul(G1Point, Int)
 // ------------------------------------------
    rule <k> #ecmul(P, S) => #end EVMC_PRECOMPILE_FAILURE ... </k>
      requires notBool isValidPoint(P)
    rule <k> #ecmul(P, S) => #end EVMC_SUCCESS ... </k> <output> _ => #point(BN128Mul(P, S)) </output>
      requires isValidPoint(P)

    syntax ByteArray ::= #point ( G1Point ) [function]
 // --------------------------------------------------
    rule #point((X, Y)) => #padToWidth(32, #asByteStack(X)) ++ #padToWidth(32, #asByteStack(Y))

    syntax PrecompiledOp ::= "ECPAIRING"
 // ------------------------------------
    rule <k> ECPAIRING => #ecpairing(.List, .List, 0, DATA, #sizeByteArray(DATA)) ... </k>
         <callData> DATA </callData>
      requires #sizeByteArray(DATA) modInt 192 ==Int 0
    rule <k> ECPAIRING => #end EVMC_PRECOMPILE_FAILURE ... </k>
         <callData> DATA </callData>
      requires #sizeByteArray(DATA) modInt 192 =/=Int 0

    syntax InternalOp ::= #ecpairing(List, List, Int, ByteArray, Int)
 // -----------------------------------------------------------------
    rule <k> (.K => #checkPoint) ~> #ecpairing((.List => ListItem((#asWord(DATA [ I .. 32 ]), #asWord(DATA [ I +Int 32 .. 32 ])))) _, (.List => ListItem((#asWord(DATA [ I +Int 96 .. 32 ]) x #asWord(DATA [ I +Int 64 .. 32 ]) , #asWord(DATA [ I +Int 160 .. 32 ]) x #asWord(DATA [ I +Int 128 .. 32 ])))) _, I => I +Int 192, DATA, LEN) ... </k>
      requires I =/=Int LEN
    rule <k> #ecpairing(A, B, LEN, _, LEN) => #end EVMC_SUCCESS ... </k>
         <output> _ => #padToWidth(32, #asByteStack(bool2Word(BN128AtePairing(A, B)))) </output>

    syntax InternalOp ::= "#checkPoint"
 // -----------------------------------
    rule <k> (#checkPoint => .) ~> #ecpairing(ListItem(AK::G1Point) _, ListItem(BK::G2Point) _, _, _, _) ... </k>
      requires isValidPoint(AK) andBool isValidPoint(BK)
    rule <k> #checkPoint ~> #ecpairing(ListItem(AK::G1Point) _, ListItem(BK::G2Point) _, _, _, _) => #end EVMC_PRECOMPILE_FAILURE ... </k>
      requires notBool isValidPoint(AK) orBool notBool isValidPoint(BK)
```


Ethereum Gas Calculation
========================

Overall Gas
-----------

-   `#gas` calculates how much gas this operation costs, and takes into account the memory consumed.
-   `#deductGas` is used to check that there won't be a gas underflow (throwing `EVMC_OUT_OF_GAS` if so), and deducts the gas if not.
-   `#deductMemory` checks that access to memory stay within sensible bounds (and deducts the correct amount of gas for it), throwing `EVMC_INVALID_MEMORY_ACCESS` if bad access happens.

```k
    syntax InternalOp ::= "#gas" "[" OpCode "," OpCode "]"
 // ---------------------------------------------------------------------------
    rule <k> #gas [ OP , AOP ]
          => #if #usesMemory(OP) #then #memory [ AOP ] #else .K #fi
          ~> #gas [ AOP ]
         ...
        </k>

    rule <k> #gas [ OP ] => #gasExec(SCHED, OP) ~> #deductGas ... </k>
         <schedule> SCHED </schedule>

    rule <k> #memory [ OP ] => #memory(OP, MU) ~> #deductMemory ... </k>
         <memoryUsed> MU </memoryUsed>

    syntax InternalOp ::= "#gas"    "[" OpCode "]" | "#deductGas"
                        | "#memory" "[" OpCode "]" | "#deductMemory"
 // ----------------------------------------------------------------
    rule <k> MU':Int ~> #deductMemory => (Cmem(SCHED, MU') -Int Cmem(SCHED, MU)) ~> #deductGas ... </k>
         <memoryUsed> MU => MU' </memoryUsed> <schedule> SCHED </schedule>

    rule <k> G:Int ~> #deductGas => #end EVMC_OUT_OF_GAS ... </k> <gas> GAVAIL                  </gas> requires GAVAIL <Int G
    rule <k> G:Int ~> #deductGas => .                    ... </k> <gas> GAVAIL => GAVAIL -Int G </gas> requires GAVAIL >=Int G
```

Memory Consumption
------------------

Memory consumed is tracked to determine the appropriate amount of gas to charge for each operation.
In the YellowPaper, each opcode is defined to consume zero gas unless specified otherwise next to the semantics of the opcode (appendix H).

-   `#memory` computes the new memory size given the old size and next operator (with its arguments).
-   `#memoryUsageUpdate` is the function `M` in appendix H of the YellowPaper which helps track the memory used.

```k
    syntax Int ::= #memory ( OpCode , Int ) [function]
 // --------------------------------------------------
    rule #memory ( MLOAD INDEX     , MU ) => #memoryUsageUpdate(MU, INDEX, 32)
    rule #memory ( MSTORE INDEX _  , MU ) => #memoryUsageUpdate(MU, INDEX, 32)
    rule #memory ( MSTORE8 INDEX _ , MU ) => #memoryUsageUpdate(MU, INDEX, 1)

    rule #memory ( SHA3 START WIDTH   , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( LOG(_) START WIDTH , MU ) => #memoryUsageUpdate(MU, START, WIDTH)

    rule #memory ( CODECOPY START _ WIDTH       , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( EXTCODECOPY _ START _ WIDTH  , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( CALLDATACOPY START _ WIDTH   , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( RETURNDATACOPY START _ WIDTH , MU ) => #memoryUsageUpdate(MU, START, WIDTH)

    rule #memory ( CREATE  _ START WIDTH   , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( CREATE2 _ START WIDTH _ , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( RETURN START WIDTH      , MU ) => #memoryUsageUpdate(MU, START, WIDTH)
    rule #memory ( REVERT START WIDTH      , MU ) => #memoryUsageUpdate(MU, START, WIDTH)

    rule #memory ( COP:CallOp     _ _ _ ARGSTART ARGWIDTH RETSTART RETWIDTH , MU ) => #memoryUsageUpdate(#memoryUsageUpdate(MU, ARGSTART, ARGWIDTH), RETSTART, RETWIDTH)
    rule #memory ( CSOP:CallSixOp _ _   ARGSTART ARGWIDTH RETSTART RETWIDTH , MU ) => #memoryUsageUpdate(#memoryUsageUpdate(MU, ARGSTART, ARGWIDTH), RETSTART, RETWIDTH)

    rule #memory ( _ , MU ) => MU [owise]

    syntax Bool ::= #usesMemory ( OpCode ) [function]
 // -------------------------------------------------
    rule #usesMemory(OP) => isLogOp(OP)
                     orBool isCallOp(OP)
                     orBool isCallSixOp(OP)
                     orBool OP ==K MLOAD
                     orBool OP ==K MSTORE
                     orBool OP ==K MSTORE8
                     orBool OP ==K SHA3
                     orBool OP ==K CODECOPY
                     orBool OP ==K EXTCODECOPY
                     orBool OP ==K CALLDATACOPY
                     orBool OP ==K RETURNDATACOPY
                     orBool OP ==K CREATE
                     orBool OP ==K CREATE2
                     orBool OP ==K RETURN
                     orBool OP ==K REVERT

    syntax Int ::= #memoryUsageUpdate ( Int , Int , Int ) [function]
 // ----------------------------------------------------------------
    rule #memoryUsageUpdate(MU, START, WIDTH) => MU                                       requires WIDTH ==Int 0
    rule #memoryUsageUpdate(MU, START, WIDTH) => maxInt(MU, (START +Int WIDTH) up/Int 32) requires WIDTH  >Int 0 [concrete]
```

Execution Gas
-------------

The intrinsic gas calculation mirrors the style of the YellowPaper (appendix H).

-   `#gasExec` loads all the relevant surronding state and uses that to compute the intrinsic execution gas of each opcode.

```k
    syntax InternalOp ::= #gasExec ( Schedule , OpCode )
 // ----------------------------------------------------
    rule <k> #gasExec(SCHED, SSTORE INDEX NEW) => Csstore(SCHED, NEW, #lookup(STORAGE, INDEX), #lookup(ORIGSTORAGE, INDEX)) ... </k>
         <id> ACCT </id>
         <account>
           <acctID> ACCT </acctID>
           <storage> STORAGE </storage>
           <origStorage> ORIGSTORAGE </origStorage>
           ...
         </account>
         <refund> R => R +Int Rsstore(SCHED, NEW, #lookup(STORAGE, INDEX), #lookup(ORIGSTORAGE, INDEX)) </refund>
         <schedule> SCHED </schedule>

    rule <k> #gasExec(SCHED, EXP W0 0)  => Gexp < SCHED > ... </k>
    rule <k> #gasExec(SCHED, EXP W0 W1) => Gexp < SCHED > +Int (Gexpbyte < SCHED > *Int (1 +Int (log256Int(W1)))) ... </k> requires W1 =/=Int 0

    rule <k> #gasExec(SCHED, CALLDATACOPY    _ _ WIDTH) => Gverylow     < SCHED > +Int (Gcopy < SCHED > *Int (WIDTH up/Int 32)) ... </k>
    rule <k> #gasExec(SCHED, RETURNDATACOPY  _ _ WIDTH) => Gverylow     < SCHED > +Int (Gcopy < SCHED > *Int (WIDTH up/Int 32)) ... </k>
    rule <k> #gasExec(SCHED, CODECOPY        _ _ WIDTH) => Gverylow     < SCHED > +Int (Gcopy < SCHED > *Int (WIDTH up/Int 32)) ... </k>
    rule <k> #gasExec(SCHED, EXTCODECOPY   _ _ _ WIDTH) => Gextcodecopy < SCHED > +Int (Gcopy < SCHED > *Int (WIDTH up/Int 32)) ... </k>

    rule <k> #gasExec(SCHED, LOG(N) _ WIDTH) => (Glog < SCHED > +Int (Glogdata < SCHED > *Int WIDTH) +Int (N *Int Glogtopic < SCHED >)) ... </k>

    rule <k> #gasExec(SCHED, CALL GCAP ACCTTO VALUE _ _ _ _)
          => Ccallgas(SCHED, #accountNonexistent(ACCTTO), GCAP, GAVAIL, VALUE) ~> #allocateCallGas
          ~> Ccall(SCHED, #accountNonexistent(ACCTTO), GCAP, GAVAIL, VALUE)
         ...
         </k>
         <gas> GAVAIL </gas>

    rule <k> #gasExec(SCHED, CALLCODE GCAP _ VALUE _ _ _ _)
          => Ccallgas(SCHED, #accountNonexistent(ACCTFROM), GCAP, GAVAIL, VALUE) ~> #allocateCallGas
          ~> Ccall(SCHED, #accountNonexistent(ACCTFROM), GCAP, GAVAIL, VALUE)
         ...
         </k>
         <id> ACCTFROM </id>
         <gas> GAVAIL </gas>

    rule <k> #gasExec(SCHED, DELEGATECALL GCAP _ _ _ _ _)
          => Ccallgas(SCHED, #accountNonexistent(ACCTFROM), GCAP, GAVAIL, 0) ~> #allocateCallGas
          ~> Ccall(SCHED, #accountNonexistent(ACCTFROM), GCAP, GAVAIL, 0)
         ...
         </k>
         <id> ACCTFROM </id>
         <gas> GAVAIL </gas>

    rule <k> #gasExec(SCHED, STATICCALL GCAP ACCTTO _ _ _ _)
          => Ccallgas(SCHED, #accountNonexistent(ACCTTO), GCAP, GAVAIL, 0) ~> #allocateCallGas
          ~> Ccall(SCHED, #accountNonexistent(ACCTTO), GCAP, GAVAIL, 0)
         ...
         </k>
         <gas> GAVAIL </gas>

    rule <k> #gasExec(SCHED, SELFDESTRUCT ACCTTO) => Cselfdestruct(SCHED, #accountNonexistent(ACCTTO), BAL) ... </k>
         <id> ACCTFROM </id>
         <selfDestruct> SDS </selfDestruct>
         <refund> RF => #if ACCTFROM in SDS #then RF #else RF +Word Rselfdestruct < SCHED > #fi </refund>
         <account>
           <acctID> ACCTFROM </acctID>
           <balance> BAL </balance>
           ...
         </account>

    rule <k> #gasExec(SCHED, CREATE _ _ _)
          => Gcreate < SCHED > ~> #deductGas
          ~> #allocateCreateGas ~> 0
         ...
         </k>

    rule <k> #gasExec(SCHED, CREATE2 _ _ WIDTH _)
          => Gcreate < SCHED > +Int Gsha3word < SCHED > *Int (WIDTH up/Int 32) ~> #deductGas
          ~> #allocateCreateGas ~> 0
         ...
         </k>

    rule <k> #gasExec(SCHED, SHA3 _ WIDTH) => Gsha3 < SCHED > +Int (Gsha3word < SCHED > *Int (WIDTH up/Int 32)) ... </k>

    rule <k> #gasExec(SCHED, JUMPDEST) => Gjumpdest < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SLOAD _)  => Gsload    < SCHED > ... </k>

    // Wzero
    rule <k> #gasExec(SCHED, STOP)       => Gzero < SCHED > ... </k>
    rule <k> #gasExec(SCHED, RETURN _ _) => Gzero < SCHED > ... </k>
    rule <k> #gasExec(SCHED, REVERT _ _) => Gzero < SCHED > ... </k>

    // Wbase
    rule <k> #gasExec(SCHED, ADDRESS)        => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, ORIGIN)         => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, CALLER)         => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, CALLVALUE)      => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, CALLDATASIZE)   => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, RETURNDATASIZE) => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, CODESIZE)       => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, GASPRICE)       => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, COINBASE)       => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, TIMESTAMP)      => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, NUMBER)         => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, DIFFICULTY)     => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, GASLIMIT)       => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, POP _)          => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, PC)             => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, MSIZE)          => Gbase < SCHED > ... </k>
    rule <k> #gasExec(SCHED, GAS)            => Gbase < SCHED > ... </k>

    // Wverylow
    rule <k> #gasExec(SCHED, ADD _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SUB _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, NOT _)          => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, LT _ _)         => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, GT _ _)         => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SLT _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SGT _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, EQ _ _)         => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, ISZERO _)       => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, AND _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, EVMOR _ _)      => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, XOR _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, BYTE _ _)       => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SHL _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SHR _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SAR _ _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, CALLDATALOAD _) => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, MLOAD _)        => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, MSTORE _ _)     => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, MSTORE8 _ _)    => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, PUSH(_, _))     => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, DUP(_) _)       => Gverylow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SWAP(_) _)      => Gverylow < SCHED > ... </k>

    // Wlow
    rule <k> #gasExec(SCHED, MUL _ _)        => Glow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, DIV _ _)        => Glow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SDIV _ _)       => Glow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, MOD _ _)        => Glow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SMOD _ _)       => Glow < SCHED > ... </k>
    rule <k> #gasExec(SCHED, SIGNEXTEND _ _) => Glow < SCHED > ... </k>

    // Wmid
    rule <k> #gasExec(SCHED, ADDMOD _ _ _) => Gmid < SCHED > ... </k>
    rule <k> #gasExec(SCHED, MULMOD _ _ _) => Gmid < SCHED > ... </k>
    rule <k> #gasExec(SCHED, JUMP _) => Gmid < SCHED > ... </k>

    // Whigh
    rule <k> #gasExec(SCHED, JUMPI _ _) => Ghigh < SCHED > ... </k>

    rule <k> #gasExec(SCHED, EXTCODESIZE _) => Gextcodesize < SCHED > ... </k>
    rule <k> #gasExec(SCHED, BALANCE _)     => Gbalance     < SCHED > ... </k>
    rule <k> #gasExec(SCHED, EXTCODEHASH _) => Gbalance     < SCHED > ... </k>
    rule <k> #gasExec(SCHED, BLOCKHASH _)   => Gblockhash   < SCHED > ... </k>

    // Precompiled
    rule <k> #gasExec(_, ECREC)  => 3000 ... </k>
    rule <k> #gasExec(_, SHA256) =>  60 +Int  12 *Int (#sizeByteArray(DATA) up/Int 32) ... </k> <callData> DATA </callData>
    rule <k> #gasExec(_, RIP160) => 600 +Int 120 *Int (#sizeByteArray(DATA) up/Int 32) ... </k> <callData> DATA </callData>
    rule <k> #gasExec(_, ID)     =>  15 +Int   3 *Int (#sizeByteArray(DATA) up/Int 32) ... </k> <callData> DATA </callData>
    rule <k> #gasExec(_, MODEXP)
          => #multComplexity(maxInt(#asWord(DATA [ 0 .. 32 ]), #asWord(DATA [ 64 .. 32 ]))) *Int maxInt(#adjustedExpLength(#asWord(DATA [ 0 .. 32 ]), #asWord(DATA [ 32 .. 32 ]), DATA), 1) /Int Gquaddivisor < SCHED >
         ...
         </k>
         <schedule> SCHED </schedule>
         <callData> DATA </callData>

    rule <k> #gasExec(_, ECADD)     => 500   ... </k>
    rule <k> #gasExec(_, ECMUL)     => 40000 ... </k>
    rule <k> #gasExec(_, ECPAIRING) => 100000 +Int (#sizeByteArray(DATA) /Int 192) *Int 80000 ... </k> <callData> DATA </callData>

    syntax InternalOp ::= "#allocateCallGas"
 // ----------------------------------------
    rule <k> GCALL:Int ~> #allocateCallGas => . ... </k>
         <callGas> _ => GCALL </callGas>

    syntax InternalOp ::= "#allocateCreateGas"
 // ------------------------------------------
    rule <schedule> SCHED </schedule>
         <k> #allocateCreateGas => . ... </k>
         <gas>     GAVAIL => #if Gstaticcalldepth << SCHED >> #then 0      #else GAVAIL /Int 64      #fi </gas>
         <callGas> _      => #if Gstaticcalldepth << SCHED >> #then GAVAIL #else #allBut64th(GAVAIL) #fi </callGas>
```

There are several helpers for calculating gas (most of them also specified in the YellowPaper).

```k
    syntax Exp     ::= Int
    syntax KResult ::= Int
    syntax Exp ::= Ccall         ( Schedule , BExp , Int , Int , Int ) [strict(2)]
                 | Ccallgas      ( Schedule , BExp , Int , Int , Int ) [strict(2)]
                 | Cselfdestruct ( Schedule , BExp , Int )             [strict(2)]
 // ------------------------------------------------------------------------------
    rule <k> Ccall(SCHED, ISEMPTY:Bool, GCAP, GAVAIL, VALUE)
          => Cextra(SCHED, ISEMPTY, VALUE) +Int Cgascap(SCHED, GCAP, GAVAIL, Cextra(SCHED, ISEMPTY, VALUE)) ... </k>

    rule <k> Ccallgas(SCHED, ISEMPTY:Bool, GCAP, GAVAIL, VALUE)
          => Cgascap(SCHED, GCAP, GAVAIL, Cextra(SCHED, ISEMPTY, VALUE)) +Int #if VALUE ==Int 0 #then 0 #else Gcallstipend < SCHED > #fi ... </k>

    rule <k> Cselfdestruct(SCHED, ISEMPTY:Bool, BAL)
          => Gselfdestruct < SCHED > +Int Cnew(SCHED, ISEMPTY andBool Gselfdestructnewaccount << SCHED >>, BAL) ... </k>

    syntax Int ::= Cgascap ( Schedule , Int , Int , Int ) [function]
                 | Csstore ( Schedule , Int , Int , Int ) [function]
                 | Rsstore ( Schedule , Int , Int , Int ) [function]
                 | Cextra  ( Schedule , Bool , Int )      [function]
                 | Cnew    ( Schedule , Bool , Int )      [function]
                 | Cxfer   ( Schedule , Int )             [function]
                 | Cmem    ( Schedule , Int )             [function, memo]
 // ----------------------------------------------------------------------
    rule Cgascap(SCHED, GCAP, GAVAIL, GEXTRA)
      => #if GAVAIL <Int GEXTRA orBool Gstaticcalldepth << SCHED >> #then GCAP #else minInt(#allBut64th(GAVAIL -Int GEXTRA), GCAP) #fi  [concrete]

    rule Csstore(SCHED, NEW, CURR, ORIG)
      => #if CURR ==Int NEW orBool ORIG =/=Int CURR #then Gsload < SCHED > #else #if ORIG ==Int 0 #then Gsstoreset < SCHED > #else Gsstorereset < SCHED > #fi #fi
      requires Ghasdirtysstore << SCHED >>  [concrete]
    rule Csstore(SCHED, NEW, CURR, ORIG)
      => #if CURR ==Int 0 andBool NEW =/=Int 0 #then Gsstoreset < SCHED > #else Gsstorereset < SCHED > #fi
      requires notBool Ghasdirtysstore << SCHED >>  [concrete]

    rule Rsstore(SCHED, NEW, CURR, ORIG)
      => #if CURR =/=Int NEW andBool ORIG ==Int CURR andBool NEW ==Int 0 #then
             Rsstoreclear < SCHED >
         #else
             #if CURR =/=Int NEW andBool ORIG =/=Int CURR andBool ORIG =/=Int 0 #then
                 #if CURR ==Int 0 #then 0 -Int Rsstoreclear < SCHED > #else #if NEW ==Int 0 #then Rsstoreclear < SCHED > #else 0 #fi #fi
             #else
                 0
             #fi +Int
             #if CURR =/=Int NEW andBool ORIG ==Int NEW #then
                 #if ORIG ==Int 0 #then Gsstoreset < SCHED > #else Gsstorereset < SCHED > #fi -Int Gsload < SCHED >
             #else
                 0
             #fi
         #fi
      requires Ghasdirtysstore << SCHED >>
      [concrete]

    rule Rsstore(SCHED, NEW, CURR, ORIG)
      => #if CURR =/=Int 0 andBool NEW ==Int 0 #then Rsstoreclear < SCHED > #else 0 #fi
      requires notBool Ghasdirtysstore << SCHED >>
      [concrete]

    rule Cextra(SCHED, ISEMPTY, VALUE)
      => Gcall < SCHED > +Int Cnew(SCHED, ISEMPTY, VALUE) +Int Cxfer(SCHED, VALUE)  [concrete]

    rule Cnew(SCHED, ISEMPTY:Bool, VALUE)
      => #if ISEMPTY andBool (VALUE =/=Int 0 orBool Gzerovaluenewaccountgas << SCHED >>) #then Gnewaccount < SCHED > #else 0 #fi

    rule Cxfer(SCHED, 0) => 0
    rule Cxfer(SCHED, N) => Gcallvalue < SCHED > requires N =/=Int 0

    rule Cmem(SCHED, N) => (N *Int Gmemory < SCHED >) +Int ((N *Int N) /Int Gquadcoeff < SCHED >)  [concrete]

    syntax BExp    ::= Bool
    syntax KResult ::= Bool
    syntax BExp ::= #accountNonexistent ( Int )
 // -------------------------------------------
    rule <k> #accountNonexistent(ACCT) => true ... </k>
         <activeAccounts> ACCTS </activeAccounts>
      requires notBool ACCT in ACCTS

    rule <k> #accountNonexistent(ACCT) => #accountEmpty(CODE, NONCE, BAL) andBool Gemptyisnonexistent << SCHED >> ... </k>
         <schedule> SCHED </schedule>
         <account>
           <acctID>  ACCT  </acctID>
           <balance> BAL   </balance>
           <nonce>   NONCE </nonce>
           <code>    CODE  </code>
           ...
         </account>

    syntax Bool ::= #accountEmpty ( AccountCode , Int , Int ) [function, klabel(accountEmpty), symbol]
 // --------------------------------------------------------------------------------------------------
    rule #accountEmpty(CODE, NONCE, BAL) => CODE ==K .ByteArray andBool NONCE ==Int 0 andBool BAL ==Int 0

    syntax Int ::= #allBut64th ( Int ) [function]
 // ---------------------------------------------
    rule #allBut64th(N) => N -Int (N /Int 64)
```

```{.k .symbolic}
    syntax Int ::= G0 ( Schedule , ByteArray , Bool ) [function]
 // ------------------------------------------------------------
    rule G0(SCHED, .WordStack, true)  => Gtxcreate    < SCHED >
    rule G0(SCHED, .WordStack, false) => Gtransaction < SCHED >

    rule G0(SCHED, N : REST, ISCREATE) => Gtxdatazero    < SCHED > +Int G0(SCHED, REST, ISCREATE) requires N ==Int 0
    rule G0(SCHED, N : REST, ISCREATE) => Gtxdatanonzero < SCHED > +Int G0(SCHED, REST, ISCREATE) requires N =/=Int 0
```

```{.k .concrete}
    syntax Int ::= G0 ( Schedule , ByteArray , Bool )      [function]
                 | G0 ( Schedule , ByteArray , Int , Int ) [function, klabel(G0data)]
                 | G0 ( Schedule , Bool )                  [function, klabel(G0base)]
 // ---------------------------------------------------------------------------------
    rule G0(SCHED, WS, B) => G0(SCHED, WS, 0, #sizeByteArray(WS)) +Int G0(SCHED, B)

    rule G0(SCHED, true)  => Gtxcreate    < SCHED >
    rule G0(SCHED, false) => Gtransaction < SCHED >

    rule G0(SCHED, WS, I, I) => 0
    rule G0(SCHED, WS, I, J) => #if WS[I] ==Int 0 #then Gtxdatazero < SCHED > #else Gtxdatanonzero < SCHED > #fi +Int G0(SCHED, WS, I +Int 1, J) [owise]
```

```k
    syntax Int ::= "G*" "(" Int "," Int "," Int ")" [function]
 // ----------------------------------------------------------
    rule G*(GAVAIL, GLIMIT, REFUND) => GAVAIL +Int minInt((GLIMIT -Int GAVAIL)/Int 2, REFUND)

    syntax Int ::= #multComplexity(Int) [function]
 // ----------------------------------------------
    rule #multComplexity(X) => X *Int X                                     requires X <=Int 64
    rule #multComplexity(X) => X *Int X /Int 4 +Int 96 *Int X -Int 3072     requires X >Int 64 andBool X <=Int 1024
    rule #multComplexity(X) => X *Int X /Int 16 +Int 480 *Int X -Int 199680 requires X >Int 1024

    syntax Int ::= #adjustedExpLength(Int, Int, ByteArray) [function]
                 | #adjustedExpLength(Int)                 [function, klabel(#adjustedExpLengthAux)]
 // ------------------------------------------------------------------------------------------------
    rule #adjustedExpLength(BASELEN, EXPLEN, DATA) => #if EXPLEN <=Int 32 #then 0 #else 8 *Int (EXPLEN -Int 32) #fi +Int #adjustedExpLength(#asInteger(DATA [ 96 +Int BASELEN .. minInt(EXPLEN, 32) ]))

    rule #adjustedExpLength(0) => 0
    rule #adjustedExpLength(1) => 0
    rule #adjustedExpLength(N) => 1 +Int #adjustedExpLength(N /Int 2) requires N >Int 1
```

Fee Schedule from C++ Implementation
------------------------------------


### From the C++ Implementation

The [C++ Implementation of EVM](https://github.com/ethereum/cpp-ethereum) specifies several different "profiles" for how the VM works.
Here we provide each protocol from the C++ implementation, as the YellowPaper does not contain all the different profiles.
Specify which profile by passing in the argument `-cSCHEDULE=<FEE_SCHEDULE>` when calling `krun` (the available `<FEE_SCHEDULE>` are supplied here).

A `ScheduleFlag` is a boolean determined by the fee schedule; applying a `ScheduleFlag` to a `Schedule` yields whether the flag is set or not.

```k
    syntax Bool ::= ScheduleFlag "<<" Schedule ">>" [function, functional]
 // ----------------------------------------------------------------------

    syntax ScheduleFlag ::= "Gselfdestructnewaccount" | "Gstaticcalldepth" | "Gemptyisnonexistent" | "Gzerovaluenewaccountgas"
                          | "Ghasrevert"              | "Ghasreturndata"   | "Ghasstaticcall"      | "Ghasshift"
                          | "Ghasdirtysstore"         | "Ghascreate2"      | "Ghasextcodehash"
 // ------------------------------------------------------------------------------------------
```

### Schedule Constants

A `ScheduleConst` is a constant determined by the fee schedule.

```k
    syntax Int ::= ScheduleConst "<" Schedule ">" [function, functional]
 // --------------------------------------------------------------------

    syntax ScheduleConst ::= "Gzero"        | "Gbase"          | "Gverylow"      | "Glow"          | "Gmid"        | "Ghigh"
                           | "Gextcodesize" | "Gextcodecopy"   | "Gbalance"      | "Gsload"        | "Gjumpdest"   | "Gsstoreset"
                           | "Gsstorereset" | "Rsstoreclear"   | "Rselfdestruct" | "Gselfdestruct" | "Gcreate"     | "Gcodedeposit"  | "Gcall"
                           | "Gcallvalue"   | "Gcallstipend"   | "Gnewaccount"   | "Gexp"          | "Gexpbyte"    | "Gmemory"       | "Gtxcreate"
                           | "Gtxdatazero"  | "Gtxdatanonzero" | "Gtransaction"  | "Glog"          | "Glogdata"    | "Glogtopic"     | "Gsha3"
                           | "Gsha3word"    | "Gcopy"          | "Gblockhash"    | "Gquadcoeff"    | "maxCodeSize" | "Rb"            | "Gquaddivisor"
 // -------------------------------------------------------------------------------------------------------------------------------------------------
```

### Default Schedule

```k
    syntax Schedule ::= "DEFAULT" [klabel(DEFAULT_EVM), symbol]
 // -----------------------------------------------------------
    rule Gzero    < DEFAULT > => 0
    rule Gbase    < DEFAULT > => 2
    rule Gverylow < DEFAULT > => 3
    rule Glow     < DEFAULT > => 5
    rule Gmid     < DEFAULT > => 8
    rule Ghigh    < DEFAULT > => 10

    rule Gexp      < DEFAULT > => 10
    rule Gexpbyte  < DEFAULT > => 10
    rule Gsha3     < DEFAULT > => 30
    rule Gsha3word < DEFAULT > => 6

    rule Gsload       < DEFAULT > => 50
    rule Gsstoreset   < DEFAULT > => 20000
    rule Gsstorereset < DEFAULT > => 5000
    rule Rsstoreclear < DEFAULT > => 15000

    rule Glog      < DEFAULT > => 375
    rule Glogdata  < DEFAULT > => 8
    rule Glogtopic < DEFAULT > => 375

    rule Gcall        < DEFAULT > => 40
    rule Gcallstipend < DEFAULT > => 2300
    rule Gcallvalue   < DEFAULT > => 9000
    rule Gnewaccount  < DEFAULT > => 25000

    rule Gcreate       < DEFAULT > => 32000
    rule Gcodedeposit  < DEFAULT > => 200
    rule Gselfdestruct < DEFAULT > => 0
    rule Rselfdestruct < DEFAULT > => 24000

    rule Gmemory      < DEFAULT > => 3
    rule Gquadcoeff   < DEFAULT > => 512
    rule Gcopy        < DEFAULT > => 3
    rule Gquaddivisor < DEFAULT > => 20

    rule Gtransaction   < DEFAULT > => 21000
    rule Gtxcreate      < DEFAULT > => 53000
    rule Gtxdatazero    < DEFAULT > => 4
    rule Gtxdatanonzero < DEFAULT > => 68

    rule Gjumpdest    < DEFAULT > => 1
    rule Gbalance     < DEFAULT > => 20
    rule Gblockhash   < DEFAULT > => 20
    rule Gextcodesize < DEFAULT > => 20
    rule Gextcodecopy < DEFAULT > => 20

    rule maxCodeSize < DEFAULT > => 2 ^Int 32 -Int 1
    rule Rb          < DEFAULT > => 5 *Int (10 ^Int 18)

    rule Gselfdestructnewaccount << DEFAULT >> => false
    rule Gstaticcalldepth        << DEFAULT >> => true
    rule Gemptyisnonexistent     << DEFAULT >> => false
    rule Gzerovaluenewaccountgas << DEFAULT >> => true
    rule Ghasrevert              << DEFAULT >> => false
    rule Ghasreturndata          << DEFAULT >> => false
    rule Ghasstaticcall          << DEFAULT >> => false
    rule Ghasshift               << DEFAULT >> => false
    rule Ghasdirtysstore         << DEFAULT >> => false
    rule Ghascreate2             << DEFAULT >> => false
    rule Ghasextcodehash         << DEFAULT >> => false
```

### Frontier Schedule

```k
    syntax Schedule ::= "FRONTIER" [klabel(FRONTIER_EVM), symbol]
 // -------------------------------------------------------------
    rule Gtxcreate  < FRONTIER > => 21000
    rule SCHEDCONST < FRONTIER > => SCHEDCONST < DEFAULT > requires SCHEDCONST =/=K Gtxcreate

    rule SCHEDFLAG << FRONTIER >> => SCHEDFLAG << DEFAULT >>
```

### Homestead Schedule

```k
    syntax Schedule ::= "HOMESTEAD" [klabel(HOMESTEAD_EVM), symbol]
 // ---------------------------------------------------------------
    rule SCHEDCONST < HOMESTEAD > => SCHEDCONST < DEFAULT >

    rule SCHEDFLAG << HOMESTEAD >> => SCHEDFLAG << DEFAULT >>
```

### Tangerine Whistle Schedule

```k
    syntax Schedule ::= "TANGERINE_WHISTLE" [klabel(TANGERINE_WHISTLE_EVM), symbol]
 // -------------------------------------------------------------------------------
    rule Gbalance      < TANGERINE_WHISTLE > => 400
    rule Gsload        < TANGERINE_WHISTLE > => 200
    rule Gcall         < TANGERINE_WHISTLE > => 700
    rule Gselfdestruct < TANGERINE_WHISTLE > => 5000
    rule Gextcodesize  < TANGERINE_WHISTLE > => 700
    rule Gextcodecopy  < TANGERINE_WHISTLE > => 700

    rule SCHEDCONST    < TANGERINE_WHISTLE > => SCHEDCONST < HOMESTEAD >
      requires notBool      ( SCHEDCONST ==K Gbalance      orBool SCHEDCONST ==K Gsload       orBool SCHEDCONST ==K Gcall
                       orBool SCHEDCONST ==K Gselfdestruct orBool SCHEDCONST ==K Gextcodesize orBool SCHEDCONST ==K Gextcodecopy
                            )

    rule Gselfdestructnewaccount << TANGERINE_WHISTLE >> => true
    rule Gstaticcalldepth        << TANGERINE_WHISTLE >> => false
    rule SCHEDCONST              << TANGERINE_WHISTLE >> => SCHEDCONST << HOMESTEAD >>
      requires notBool      ( SCHEDCONST ==K Gselfdestructnewaccount orBool SCHEDCONST ==K Gstaticcalldepth )
```

### Spurious Dragon Schedule

```k
    syntax Schedule ::= "SPURIOUS_DRAGON" [klabel(SPURIOUS_DRAGON_EVM), symbol]
 // ---------------------------------------------------------------------------
    rule Gexpbyte    < SPURIOUS_DRAGON > => 50
    rule maxCodeSize < SPURIOUS_DRAGON > => 24576

    rule SCHEDCONST  < SPURIOUS_DRAGON > => SCHEDCONST < TANGERINE_WHISTLE > requires SCHEDCONST =/=K Gexpbyte andBool SCHEDCONST =/=K maxCodeSize

    rule Gemptyisnonexistent     << SPURIOUS_DRAGON >> => true
    rule Gzerovaluenewaccountgas << SPURIOUS_DRAGON >> => false
    rule SCHEDCONST              << SPURIOUS_DRAGON >> => SCHEDCONST << TANGERINE_WHISTLE >>
      requires notBool      ( SCHEDCONST ==K Gemptyisnonexistent orBool SCHEDCONST ==K Gzerovaluenewaccountgas )
```

### Byzantium Schedule

```k
    syntax Schedule ::= "BYZANTIUM" [klabel(BYZANTIUM_EVM), symbol]
 // ---------------------------------------------------------------
    rule Rb         < BYZANTIUM > => 3 *Int eth
    rule SCHEDCONST < BYZANTIUM > => SCHEDCONST < SPURIOUS_DRAGON >
      requires notBool ( SCHEDCONST ==K Rb )

    rule Ghasrevert     << BYZANTIUM >> => true
    rule Ghasreturndata << BYZANTIUM >> => true
    rule Ghasstaticcall << BYZANTIUM >> => true
    rule SCHEDFLAG      << BYZANTIUM >> => SCHEDFLAG << SPURIOUS_DRAGON >>
      requires notBool ( SCHEDFLAG ==K Ghasrevert orBool SCHEDFLAG ==K Ghasreturndata orBool SCHEDFLAG ==K Ghasstaticcall )
```

### Constantinople Schedule

```k
    syntax Schedule ::= "CONSTANTINOPLE" [klabel(CONSTANTINOPLE_EVM), symbol]
 // -------------------------------------------------------------------------
    rule Rb         < CONSTANTINOPLE > => 2 *Int eth
    rule SCHEDCONST < CONSTANTINOPLE > => SCHEDCONST < BYZANTIUM >
      requires notBool ( SCHEDCONST ==K Rb )

    rule Ghasshift       << CONSTANTINOPLE >> => true
    rule Ghasdirtysstore << CONSTANTINOPLE >> => true
    rule Ghascreate2     << CONSTANTINOPLE >> => true
    rule Ghasextcodehash << CONSTANTINOPLE >> => true
    rule SCHEDFLAG       << CONSTANTINOPLE >> => SCHEDFLAG << BYZANTIUM >>
      requires notBool ( SCHEDFLAG ==K Ghasshift orBool SCHEDFLAG ==K Ghasdirtysstore orBool SCHEDFLAG ==K Ghascreate2 orBool SCHEDFLAG ==K Ghasextcodehash )
```

### Petersburg Schedule

```k
    syntax Schedule ::= "PETERSBURG" [klabel(PETERSBURG_EVM), symbol]
 // -----------------------------------------------------------------
    rule SCHEDCONST < PETERSBURG > => SCHEDCONST < CONSTANTINOPLE >

    rule Ghasdirtysstore << PETERSBURG >> => false
    rule SCHEDFLAG       << PETERSBURG >> => SCHEDFLAG << CONSTANTINOPLE >>
      requires notBool ( SCHEDFLAG ==K Ghasdirtysstore )
```

EVM Program Representations
===========================

EVM programs are represented algebraically in K, but programs can load and manipulate program data directly.
The opcodes `CODECOPY` and `EXTCODECOPY` rely on the assembled form of the programs being present.
The opcode `CREATE` relies on being able to interperet EVM data as a program.

This is a program representation dependence, which we might want to avoid.
Perhaps the only program representation dependence we should have is the hash of the program; doing so achieves:

-   Program representation independence (different analysis tools on the language don't have to ensure they have a common representation of programs, just a common interperetation of the data-files holding programs).
-   Programming language independence (we wouldn't even have to commit to a particular language or interperetation of the data-file).
-   Only depending on the hash allows us to know that we have *exactly* the correct data-file (program), and nothing more.

Disassembler
------------

After interpreting the strings representing programs as a `WordStack`, it should be changed into an `OpCodes` for use by the EVM semantics.

-   `#dasmOpCodes` interperets `WordStack` as an `OpCodes`.
-   `#dasmPUSH` handles the case of a `PushOp`.
-   `#dasmOpCode` interperets a `Int` as an `OpCode`.

```k
    syntax OpCodes ::= #dasmOpCodes ( ByteArray , Schedule )           [function]
 // -----------------------------------------------------------------------------
```

```{.k .symbolic}
    syntax OpCodes ::= #dasmOpCodes ( OpCodes , ByteArray , Schedule ) [function, klabel(#dasmOpCodesAux)]
 // ------------------------------------------------------------------------------------------------------
    rule #dasmOpCodes( WS, SCHED ) => #revOps(#dasmOpCodes(.OpCodes, WS, SCHED))

    rule #dasmOpCodes( OPS, .WordStack, _ ) => OPS
    rule #dasmOpCodes( OPS, W : WS, SCHED ) => #dasmOpCodes(#dasmOpCode(W, SCHED) ; OPS, WS, SCHED) requires W >=Int 0   andBool W <=Int 95
    rule #dasmOpCodes( OPS, W : WS, SCHED ) => #dasmOpCodes(#dasmOpCode(W, SCHED) ; OPS, WS, SCHED) requires W >=Int 165 andBool W <=Int 255
    rule #dasmOpCodes( OPS, W : WS, SCHED ) => #dasmOpCodes(DUP(W -Int 127)       ; OPS, WS, SCHED) requires W >=Int 128 andBool W <=Int 143
    rule #dasmOpCodes( OPS, W : WS, SCHED ) => #dasmOpCodes(SWAP(W -Int 143)      ; OPS, WS, SCHED) requires W >=Int 144 andBool W <=Int 159
    rule #dasmOpCodes( OPS, W : WS, SCHED ) => #dasmOpCodes(LOG(W -Int 160)       ; OPS, WS, SCHED) requires W >=Int 160 andBool W <=Int 164

    rule #dasmOpCodes( OPS, W : WS, SCHED ) => #dasmOpCodes(PUSH(W -Int 95, #asWord(#take(W -Int 95, WS))) ; OPS, #drop(W -Int 95, WS), SCHED) requires W >=Int 96  andBool W <=Int 127
```

```{.k .concrete}
    syntax OpCodes ::= #dasmOpCodes ( OpCodes , ByteArray , Schedule , Int , Int ) [function, klabel(#dasmOpCodesAux)]
 // ------------------------------------------------------------------------------------------------------------------
    rule #dasmOpCodes( WS, SCHED ) => #revOps(#dasmOpCodes(.OpCodes, WS, SCHED, 0, #sizeByteArray(WS)))

    rule #dasmOpCodes( OPS, _ ,     _ , I , J ) => OPS requires I >=Int J
    rule #dasmOpCodes( OPS, WS, SCHED , I , J ) => #dasmOpCodes(#dasmOpCode(WS[I], SCHED) ; OPS, WS, SCHED, I +Int 1, J) requires WS[I] >=Int 0   andBool WS[I] <=Int 95 [owise]
    rule #dasmOpCodes( OPS, WS, SCHED , I , J ) => #dasmOpCodes(#dasmOpCode(WS[I], SCHED) ; OPS, WS, SCHED, I +Int 1, J) requires WS[I] >=Int 165 andBool WS[I] <=Int 255 [owise]
    rule #dasmOpCodes( OPS, WS, SCHED , I , J ) => #dasmOpCodes(DUP(WS[I] -Int 127)       ; OPS, WS, SCHED, I +Int 1, J) requires WS[I] >=Int 128 andBool WS[I] <=Int 143 [owise]
    rule #dasmOpCodes( OPS, WS, SCHED , I , J ) => #dasmOpCodes(SWAP(WS[I] -Int 143)      ; OPS, WS, SCHED, I +Int 1, J) requires WS[I] >=Int 144 andBool WS[I] <=Int 159 [owise]
    rule #dasmOpCodes( OPS, WS, SCHED , I , J ) => #dasmOpCodes(LOG(WS[I] -Int 160)       ; OPS, WS, SCHED, I +Int 1, J) requires WS[I] >=Int 160 andBool WS[I] <=Int 164 [owise]

    rule #dasmOpCodes( OPS, WS, SCHED , I , J ) => #dasmOpCodes(PUSH(WS[I] -Int 95, #asWord(WS [ I +Int 1 .. WS[I] -Int 95 ])) ; OPS, WS, SCHED, I +Int WS[I] -Int 94, J) requires WS[I] >=Int 96  andBool WS[I] <=Int 127 [owise]
```

```k
    syntax OpCode ::= #dasmOpCode ( Int , Schedule ) [function]
 // -----------------------------------------------------------
    rule #dasmOpCode(   0,     _ ) => STOP
    rule #dasmOpCode(   1,     _ ) => ADD
    rule #dasmOpCode(   2,     _ ) => MUL
    rule #dasmOpCode(   3,     _ ) => SUB
    rule #dasmOpCode(   4,     _ ) => DIV
    rule #dasmOpCode(   5,     _ ) => SDIV
    rule #dasmOpCode(   6,     _ ) => MOD
    rule #dasmOpCode(   7,     _ ) => SMOD
    rule #dasmOpCode(   8,     _ ) => ADDMOD
    rule #dasmOpCode(   9,     _ ) => MULMOD
    rule #dasmOpCode(  10,     _ ) => EXP
    rule #dasmOpCode(  11,     _ ) => SIGNEXTEND
    rule #dasmOpCode(  16,     _ ) => LT
    rule #dasmOpCode(  17,     _ ) => GT
    rule #dasmOpCode(  18,     _ ) => SLT
    rule #dasmOpCode(  19,     _ ) => SGT
    rule #dasmOpCode(  20,     _ ) => EQ
    rule #dasmOpCode(  21,     _ ) => ISZERO
    rule #dasmOpCode(  22,     _ ) => AND
    rule #dasmOpCode(  23,     _ ) => EVMOR
    rule #dasmOpCode(  24,     _ ) => XOR
    rule #dasmOpCode(  25,     _ ) => NOT
    rule #dasmOpCode(  26,     _ ) => BYTE
    rule #dasmOpCode(  27, SCHED ) => SHL requires Ghasshift << SCHED >>
    rule #dasmOpCode(  28, SCHED ) => SHR requires Ghasshift << SCHED >>
    rule #dasmOpCode(  29, SCHED ) => SAR requires Ghasshift << SCHED >>
    rule #dasmOpCode(  32,     _ ) => SHA3
    rule #dasmOpCode(  48,     _ ) => ADDRESS
    rule #dasmOpCode(  49,     _ ) => BALANCE
    rule #dasmOpCode(  50,     _ ) => ORIGIN
    rule #dasmOpCode(  51,     _ ) => CALLER
    rule #dasmOpCode(  52,     _ ) => CALLVALUE
    rule #dasmOpCode(  53,     _ ) => CALLDATALOAD
    rule #dasmOpCode(  54,     _ ) => CALLDATASIZE
    rule #dasmOpCode(  55,     _ ) => CALLDATACOPY
    rule #dasmOpCode(  56,     _ ) => CODESIZE
    rule #dasmOpCode(  57,     _ ) => CODECOPY
    rule #dasmOpCode(  58,     _ ) => GASPRICE
    rule #dasmOpCode(  59,     _ ) => EXTCODESIZE
    rule #dasmOpCode(  60,     _ ) => EXTCODECOPY
    rule #dasmOpCode(  61, SCHED ) => RETURNDATASIZE requires Ghasreturndata << SCHED >>
    rule #dasmOpCode(  62, SCHED ) => RETURNDATACOPY requires Ghasreturndata << SCHED >>
    rule #dasmOpCode(  63, SCHED ) => EXTCODEHASH requires Ghasextcodehash << SCHED >>
    rule #dasmOpCode(  64,     _ ) => BLOCKHASH
    rule #dasmOpCode(  65,     _ ) => COINBASE
    rule #dasmOpCode(  66,     _ ) => TIMESTAMP
    rule #dasmOpCode(  67,     _ ) => NUMBER
    rule #dasmOpCode(  68,     _ ) => DIFFICULTY
    rule #dasmOpCode(  69,     _ ) => GASLIMIT
    rule #dasmOpCode(  80,     _ ) => POP
    rule #dasmOpCode(  81,     _ ) => MLOAD
    rule #dasmOpCode(  82,     _ ) => MSTORE
    rule #dasmOpCode(  83,     _ ) => MSTORE8
    rule #dasmOpCode(  84,     _ ) => SLOAD
    rule #dasmOpCode(  85,     _ ) => SSTORE
    rule #dasmOpCode(  86,     _ ) => JUMP
    rule #dasmOpCode(  87,     _ ) => JUMPI
    rule #dasmOpCode(  88,     _ ) => PC
    rule #dasmOpCode(  89,     _ ) => MSIZE
    rule #dasmOpCode(  90,     _ ) => GAS
    rule #dasmOpCode(  91,     _ ) => JUMPDEST
    rule #dasmOpCode( 240,     _ ) => CREATE
    rule #dasmOpCode( 241,     _ ) => CALL
    rule #dasmOpCode( 242,     _ ) => CALLCODE
    rule #dasmOpCode( 243,     _ ) => RETURN
    rule #dasmOpCode( 244, SCHED ) => DELEGATECALL requires SCHED =/=K FRONTIER
    rule #dasmOpCode( 245, SCHED ) => CREATE2      requires Ghascreate2    << SCHED >>
    rule #dasmOpCode( 250, SCHED ) => STATICCALL   requires Ghasstaticcall << SCHED >>
    rule #dasmOpCode( 253, SCHED ) => REVERT       requires Ghasrevert     << SCHED >>
    rule #dasmOpCode( 254,     _ ) => INVALID
    rule #dasmOpCode( 255,     _ ) => SELFDESTRUCT
    rule #dasmOpCode(   W,     _ ) => UNDEFINED(W) [owise]
endmodule
```
