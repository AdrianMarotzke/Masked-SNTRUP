# Masked-SNTRUP

**WARNING This is experimental code, do NOT use in production systems**

This is a gate-level masked implementation of Streamlined NTRU Prime, and is the code from the paper "Gadget-Based Masking of Streamlined NTRU Prime Decapsulation in Hardware", which is also available here https://eprint.iacr.org/2023/105. 

The top module is ntru_prime_top.vhd. While the port interface and top level module contain signals and wires for other operations, only decapsulation for the parameter set sntrup761 is currently supported.

The masking degree of the design can be configured using the constant "shares" in the file constants.pkg.vhd (line 13).
All other constants should not be modified.

To build: 
- Install Vivado v2021.2 (64-bit). Other versions of Vivado should also work, but may have slightly different results.
- In Vivado, create a new project, with the "xc7a200tsbv484-3" FPGA as the target platform.
- Add ntru_prime_top.vhd, constants.pkg.vhd, data_type.pkg.vhd as well as all files in the folders sha_512, multiplication, misc, gadgets, encoding, decapsualtion as design files to the project.
- Add the constraints.xdc as a constraints file to the project.
- Set ntru_prime_top.vhd as the top level module.
- In implementation run properties, enable opt_design and phys_opt_design.
- The design can now be syntheized, with the number of shares set by the constant "shares" in the file constants.pkg.vhd (line 13)

Please refer to Section 5.2 "Side-Channel Evaluation" in the paper on how to create a testbench setup for SCA measurement, and on how to apply the Verica formal verification tool.

In order to simulate the design, use the testbench ./tb/tb_ntru_top_msk.vhd.
The simulation can takes quite a long time, the design should run for 10ms, which can take several hours 
Depending on the system, you may need to replace the relative file paths of the stimulus files in line 143, line 169 and line 229 to absolute file paths.
The stimulus data is gathered from the Known-Awnser-Tests from the reference C implementation of NTRU Prime.
The testbench checks the decapsualtion output for correctness, and throws an VHDL assertion failure on a mismatch. 

**Acknowledgments**

The HPC gadgets in the folder "gadgets/lib_v" are from https://github.com/cassiersg/fullverif.

The Masked Sklansky Adder in the folder gadets/hpc2-sklansky-adder-main is based on the work from Florian Bache and Tim Güneysu, and their paper "Boolean Masking for Arithmetic Additions at Arbitrary Order in Hardware"

This implementation is based on the Streamlined NTRU Prime implementation from the paper "Streamlined NTRU Prime on FPGA" by Bo-Yuan Peng, Adrian Marotzke, Ming-Han Tsai, Bo-Yin Yang and Ho-Lin Chen, which is available at https://eprint.iacr.org/2021/1444 and  https://github.com/AdrianMarotzke/SNTRUP_on_FPGA

The implementation of the SHA-512 hash function is originally based on the unmasked implementation from https://github.com/dsaves/SHA-512