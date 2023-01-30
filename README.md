# Masked-SNTRUP

**WARNING This is experimental code, do NOT use in production systems**

This is a gate-level masked implementation of Streamlined NTRU Prime, and is the code from the paper "Gate-Level Masking of Streamlined NTRU Prime Decapsulation in Hardware", which is available here https://eprint.iacr.org/2023/105.  

The top module is ntru_prime_top.vhd, the corresponding testbench is tb_ntru_top_msk.vhd.

The constant "shares" in the file constants.pkg.vhd allows the configuration of the number of masking shares (at least 2).

Only decapsulation for the parameter set sntrup761 is currently supported.

**Acknowledgments**

The HPC gadgets in the folder "gadgets/lib_v" are from https://github.com/cassiersg/fullverif.

The Masked Sklansky Adder in the folder gadets/hpc2-sklansky-adder-main is based on the work from Florian Bache and Tim Güneysu, and their paper "Boolean Masking for Arithmetic Additions at Arbitrary Order in Hardware"

This implementation is based on the Streamlined NTRU Prime implementation from the paper "Streamlined NTRU Prime on FPGA" by Bo-Yuan Peng, Adrian Marotzke, Ming-Han Tsai, Bo-Yin Yang and Ho-Lin Chen, which is available at https://eprint.iacr.org/2021/1444 and  https://github.com/AdrianMarotzke/SNTRUP_on_FPGA

The implementation of the SHA-512 hash function is based on the implementation from https://github.com/dsaves/SHA-512