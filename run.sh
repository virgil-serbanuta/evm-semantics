# make repo-deps
# rm -rf .build/java
# make defn
# make -C ~/verified-smart-contracts clean all
# cp ~/verified-smart-contracts/specs/lemmas.k .build/java

  export PATH=~/work/k5/k-distribution/target/release/k/bin:$PATH
  export PATH=$PATH:~/work/z3/z3-4.6.0-x64-osx-10.11.6/bin
# export LD_LIBRARY_PATH=~/work/z3/z3-4.6.0-x64-osx-10.11.6/bin

  export K_OPTS='-Xmx4g'
# export K_OPTS='-Xmx8g -agentlib:jdwp=transport=dt_socket,server=n,address=localhost:5005,suspend=y'

# rm -rf .build/java/driver-kompiled
# time kompile -v --debug --backend java -I .build/java -d .build/java --main-module ETHEREUM-SIMULATION --syntax-module ETHEREUM-SIMULATION .build/java/driver.k
##MODE=VMTESTS SCHEDULE=DEFAULT ./kevm run-java tests/ethereum-tests/VMTests/vmIOandFlowOperations/mstore_mload0.json
# time krun -v -d .build/java -cSCHEDULE="\`DEFAULT_EVM\`(.KList)" -pSCHEDULE='printf %s' -cMODE="\`VMTESTS\`(.KList)" -pMODE='printf %s' tests/ethereum-tests/VMTests/vmIOandFlowOperations/mstore_mload0.json

# time kprove ~/verified-smart-contracts/specs/zeppelin-erc20/balanceOf-spec.k -v -d .build/java -m VERIFICATION --z3-executable --smt_prelude evm.smt2
# time kprove ~/verified-smart-contracts/specs/vyper-erc20/balanceOf-spec.k -v -d .build/java -m VERIFICATION --z3-executable --smt_prelude evm.smt2

# time kprove orig-balanceOf-spec.k -v -d .build/java --z3-executable --smt_prelude evm.smt2
# time kprove orig-transfer-success-1-spec.k -v -d .build/java --z3-executable --smt_prelude evm.smt2
# time kprove orig-transferFrom-success-1-spec.k -v -d .build/java --z3-executable --smt_prelude evm.smt2

# time kompile -v --debug --backend java -d common common.k

# time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 balanceOf-spec.k -s2 balanceOf-spec.k -sm1 BALANCEOF-SPEC -sm2 BALANCEOF-SPEC --smt_prelude evm.smt2 --z3-executable
# time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 balanceOf1-spec.k -s2 balanceOf2-spec.k -sm1 BALANCEOF1-SPEC -sm2 BALANCEOF2-SPEC --smt_prelude evm.smt2 --z3-executable
# time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 balanceOf1-spec.k -s2 balanceOf3-spec.k -sm1 BALANCEOF1-SPEC -sm2 BALANCEOF3-SPEC --smt_prelude evm.smt2 --z3-executable

# time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 transfer-spec.k  -s2 transfer-spec.k  -sm1 TRANSFER-SPEC  -sm2 TRANSFER-SPEC  --smt_prelude evm.smt2 --z3-executable
# time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 transfer1-spec.k -s2 transfer2-spec.k -sm1 TRANSFER1-SPEC -sm2 TRANSFER2-SPEC --smt_prelude evm.smt2 --z3-executable

# time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 transferFrom-spec.k  -s2 transferFrom-spec.k  -sm1 TRANSFERFROM-SPEC  -sm2 TRANSFERFROM-SPEC  --smt_prelude evm.smt2 --z3-executable
  time keq -v -d common -d1 .build/java -d2 .build/java -m1 ETHEREUM-SIMULATION -m2 ETHEREUM-SIMULATION -s1 transferFrom1-spec.k -s2 transferFrom2-spec.k -sm1 TRANSFERFROM1-SPEC -sm2 TRANSFERFROM2-SPEC --smt_prelude evm.smt2 --z3-executable
