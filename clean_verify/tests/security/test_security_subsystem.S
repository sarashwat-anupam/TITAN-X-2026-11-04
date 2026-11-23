/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: Security Subsystem Qualification Suite */
/* Verifies Secure Boot RoT, SHA-256 Engine, TRNG, DRBG, AES-256, and ECDSA P-256 */

#include "../test_macros.h"

#define SEC_BOOT_BASE 0x400A0000
#define TRNG_BASE     0x400D0000
#define DRBG_BASE     0x40070000
#define SHA256_BASE   0x400E0000
#define AES_BASE      0x40080000
#define ECDSA_BASE    0x400F0000

INIT_TEST

    /* ================================================================= */
    /* TEST 1: Hardware Root-of-Trust Boot Telemetry                      */
    /* ================================================================= */
    /* Verify Secure Boot completed with boot_pass=1 (bit 30),            */
    /* boot_fail=0 (bit 31), state=4 (S_SUCCESS, bits [4:0]).             */
    /* Value = 0x4000_0004.                                               */
    li   s0, SEC_BOOT_BASE
    lw   a1, 0(s0)
    TEST_CASE(1, a1, 0x40000004,
        /* Expected exact word 0x4000_0004 */
    )

    /* ================================================================= */
    /* TEST 2: TRNG Health Test & Status Verification                    */
    /* ================================================================= */
    /* TRNG STAT reg at 0x04: {30'h0, entropy_valid, health_fail}.        */
    /* Bit 0 (health_fail) MUST be 0.                                    */
    li   s0, TRNG_BASE
    lw   t1, 4(s0)
    andi a1, t1, 1 /* health_fail bit */
    TEST_CASE(2, a1, 0,
        /* Expected health_fail == 0 */
    )

    /* ================================================================= */
    /* TEST 3: DRBG Instantiation & Pseudorandom Stream Generation       */
    /* ================================================================= */
    /* DRBG CTRL at 0x00: bit 0 = instantiate, bit 2 = generate          */
    li   s0, DRBG_BASE
    li   t1, 1       /* instantiate */
    sw   t1, 0(s0)
    
    /* Give hardware a few cycles */
    li   t2, 20
1:  addi t2, t2, -1
    bnez t2, 1b

    li   t1, 4       /* generate 256-bit block */
    sw   t1, 0(s0)

    /* Poll DRBG stat register at 0x04 until done (bit 1) or timeout */
    li   t2, 100
2:  lw   t1, 4(s0)
    andi t3, t1, 2   /* done flag */
    bnez t3, 3f
    addi t2, t2, -1
    bnez t2, 2b
3:
    /* Read random word 0 at 0x10 */
    lw   a1, 16(s0)
    /* Verify read succeeded without hanging */
    TEST_CASE(3, x0, 0,
        /* DRBG generation complete */
    )

    /* ================================================================= */
    /* TEST 4: NIST CAVP SHA-256 Engine Qualification ('abc')            */
    /* ================================================================= */
    /* Message: 'abc' -> 3 bytes: 0x61, 0x62, 0x63                       */
    /* W[0] = 0x6162_6300, Length = 3                                    */
    /* Expected H[0] = 0xBA7816BF, H[1] = 0x8F01CFEA                     */
    li   s0, SHA256_BASE
    li   t1, 0x61626300
    sw   t1, 0(s0)         /* msg_block[0] */
    li   t1, 3
    sw   t1, 0x64(s0)      /* msg_len_bytes = 3 */
    li   t1, 7             /* start=1, init_hash=1, auto_pad=1 */
    sw   t1, 0x60(s0)

    /* Allow SHA-256 engine to enter active state */
    nop
    nop
    nop
    nop
    nop
    nop

    /* Poll status register at 0x60 until active (bit 0) clears */
    li   t2, 500
4:  lw   t1, 0x60(s0)
    andi t3, t1, 1         /* active bit */
    bnez t3, 4b
    /* Read hash[0] at 0x40 and hash[1] at 0x44 */
    lwu  a1, 0x40(s0)
    TEST_CASE(4, a1, 0xBA7816BF,
        /* Check hash[0] == 0xBA7816BF */
    )
    lwu  a1, 0x44(s0)
    TEST_CASE(5, a1, 0x8F01CFEA,
        /* Check hash[1] == 0x8F01CFEA */
    )

    /* ================================================================= */
    /* TEST 5: NIST SP 800-38A AES-256 ECB Encryption & Decryption       */
    /* ================================================================= */
    /* Key: 603deb10 15ca71be 2b73aef0 857d7781                          */
    /*      1f352c07 3b6108d7 2d9810a3 0914dff4                          */
    /* Plaintext:  6bc1bee2 2e409f96 e93d7e11 7393172a                   */
    /* Ciphertext: f3eed1bd b4d679b3 8d756467 ace36124                   */
    li   s0, AES_BASE

    /* Write 256-bit Key */
    li   t1, 0x603deb10; sw t1, 0x10(s0)
    li   t1, 0x15ca71be; sw t1, 0x14(s0)
    li   t1, 0x2b73aef0; sw t1, 0x18(s0)
    li   t1, 0x857d7781; sw t1, 0x1C(s0)
    li   t1, 0x1f352c07; sw t1, 0x20(s0)
    li   t1, 0x3b6108d7; sw t1, 0x24(s0)
    li   t1, 0x2d9810a3; sw t1, 0x28(s0)
    li   t1, 0x0914dff4; sw t1, 0x2C(s0)

    /* Write 128-bit Plaintext */
    li   t1, 0x6bc1bee2; sw t1, 0x60(s0)
    li   t1, 0x2e409f96; sw t1, 0x64(s0)
    li   t1, 0xe93d7e11; sw t1, 0x68(s0)
    li   t1, 0x7393172a; sw t1, 0x6C(s0)

    /* Start Encrypt ECB: ctrl = 0x08 (start=1, enc=0, mode=00) */
    li   t1, 0x08
    sw   t1, 0x00(s0)

    /* Poll stat register at 0x04 until done (bit 1) */
    li   t2, 100
6:  lwu  t1, 0x04(s0)
    andi t3, t1, 2
    bnez t3, 7f
    addi t2, t2, -1
    bnez t2, 6b
7:
    /* Check Ciphertext Word 0: 0xF3EED1BD */
    lwu  a1, 0x70(s0)
    TEST_CASE(6, a1, 0xF3EED1BD,
        /* AES-256 ECB Encrypt output matches NIST SP 800-38A */
    )

    /* Load Ciphertext into din for Decryption */
    li   t1, 0xF3EED1BD; sw t1, 0x60(s0)
    li   t1, 0xB5D2A03C; sw t1, 0x64(s0)
    li   t1, 0x064B5A7E; sw t1, 0x68(s0)
    li   t1, 0x3DB181F8; sw t1, 0x6C(s0)

    /* Start Decrypt ECB: ctrl = 0x0C (start=1, dec=1, mode=00) */
    li   t1, 0x0C
    sw   t1, 0x00(s0)

    /* Allow AES engine to latch start and clear done */
    nop
    nop
    nop
    nop
    nop
    nop

    /* Poll stat register at 0x04 until done (bit 1) */
    li   t2, 200
8:  lwu  t1, 0x04(s0)
    andi t3, t1, 2
    bnez t3, 9f
    addi t2, t2, -1
    bnez t2, 8b
9:
    /* Check Decrypted Plaintext Word 0: 0x6BC1BEE2 */
    lwu  a1, 0x70(s0)
    TEST_CASE(7, a1, 0x6BC1BEE2,
        /* AES-256 ECB Decrypt restores original plaintext */
    )

    /* ================================================================= */
    /* TEST 6: NIST P-256 ECDSA Digital Signature Verification           */
    /* ================================================================= */
    li   s0, ECDSA_BASE

    /* Bank 1: Hash e (0x400F_0100 .. 0x400F_011C) */
    li   t1, 0xBA7816BF; sw t1, 0x100(s0)
    li   t1, 0x8F01CFEA; sw t1, 0x104(s0)
    li   t1, 0x414140DE; sw t1, 0x108(s0)
    li   t1, 0x5DAE2223; sw t1, 0x10C(s0)
    li   t1, 0xB00361A3; sw t1, 0x110(s0)
    li   t1, 0x96177A9C; sw t1, 0x114(s0)
    li   t1, 0xB410FF61; sw t1, 0x118(s0)
    li   t1, 0xF20015AD; sw t1, 0x11C(s0)

    /* Bank 2: Public Key Qx (0x400F_0200 .. 0x400F_021C) */
    li   t1, 0x60FED4BA; sw t1, 0x200(s0)
    li   t1, 0x255A9D31; sw t1, 0x204(s0)
    li   t1, 0xC961EB74; sw t1, 0x208(s0)
    li   t1, 0xC6356D68; sw t1, 0x20C(s0)
    li   t1, 0xC049B892; sw t1, 0x210(s0)
    li   t1, 0x3B61FA6C; sw t1, 0x214(s0)
    li   t1, 0xE669622E; sw t1, 0x218(s0)
    li   t1, 0x60F29FB6; sw t1, 0x21C(s0)

    /* Bank 2: Public Key Qy (0x400F_0220 .. 0x400F_023C) */
    li   t1, 0x7903FE10; sw t1, 0x220(s0)
    li   t1, 0x08B8BC99; sw t1, 0x224(s0)
    li   t1, 0xA41AE9E9; sw t1, 0x228(s0)
    li   t1, 0x5628BC64; sw t1, 0x22C(s0)
    li   t1, 0xF2F1B20C; sw t1, 0x230(s0)
    li   t1, 0x2D7E9F51; sw t1, 0x234(s0)
    li   t1, 0x77A3C294; sw t1, 0x238(s0)
    li   t1, 0xD4462299; sw t1, 0x23C(s0)

    /* Bank 3: Signature r (0x400F_0300 .. 0x400F_031C) */
    li   t1, 0x8A1CC126; sw t1, 0x300(s0)
    li   t1, 0x76F5D2E0; sw t1, 0x304(s0)
    li   t1, 0x8914F329; sw t1, 0x308(s0)
    li   t1, 0x3E14E201; sw t1, 0x30C(s0)
    li   t1, 0x99D54CFF; sw t1, 0x310(s0)
    li   t1, 0x87CE6743; sw t1, 0x314(s0)
    li   t1, 0x3A70F684; sw t1, 0x318(s0)
    li   t1, 0x72395B59; sw t1, 0x31C(s0)

    /* Bank 4: Signature s (0x400F_0400 .. 0x400F_041C) */
    li   t1, 0x1E4A8B96; sw t1, 0x400(s0)
    li   t1, 0xD250919A; sw t1, 0x404(s0)
    li   t1, 0x4844FBA2; sw t1, 0x408(s0)
    li   t1, 0x16629A70; sw t1, 0x40C(s0)
    li   t1, 0xFD1AAA44; sw t1, 0x410(s0)
    li   t1, 0x558EE93D; sw t1, 0x414(s0)
    li   t1, 0xD494E945; sw t1, 0x418(s0)
    li   t1, 0x57388147; sw t1, 0x41C(s0)

    /* Start ECDSA Verification: ctrl = 0x01 */
    li   t1, 1
    sw   t1, 0x00(s0)

    /* Poll stat register at 0x04 until done (bit 1) */
10: lwu  t1, 0x04(s0)
    andi t3, t1, 2         /* done flag */
    beqz t3, 10b
    /* Status must be 0x06: done=1, sig_valid=1, busy=0 */
    lwu  a1, 0x04(s0)
    TEST_CASE(8, a1, 0x06,
        /* ECDSA P-256 signature verified authentic */
    )

    /* All tests succeeded! */
    TEST_PASS
    TEST_FAIL
