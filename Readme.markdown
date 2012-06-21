Decompilation Pipeline overview
===============================

## 1. Bytecode raising

During code generation, IR Lowering is generally a method of flattening out a multilevel IR tree into a single flat sequence, as we're usually aiming at producing flat assembly, this is generally a necessary step.

During decompilation, we don't want to do a straight translation back into the source language as there are often code "idioms" and structures that we would like to be able to "feel" out of the bytecode, which we can think of for now as our concrete canonical IR (CIR).
In order, to accomplish this, we need a crude way of associating small blocks of CIR as a nested group. Unfortunately, it's not possible to perfectly reverse lowering as the fundamental rule of lowering is the following translation from noncanonical IR (just IR or nested IR to distinguish from CIR)

    L[SEQ(s1, ..., sn)] = L(s1), ..., L(sn)
    
where each of s1 through sn may themselves be a sequence. Suppose an IR chunk is consisted of SEQ(...), then its CIR would be SEQ(L(...)).