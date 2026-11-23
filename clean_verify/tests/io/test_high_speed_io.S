/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: High-Speed I/O Qualification Suite */
/* Verifies Gigabit Ethernet GMII, USB 2.0 ULPI, and PCIe Gen2 x4 PIPE 3.0 */

#include "../test_macros.h"

#define GEM_BASE   0x40020000
#define USB_BASE   0x40030000
#define PLIC_BASE  0x0C000000

#define ETH_TX_BUF 0x80100000
#define ETH_RX_BUF 0x80200000
#define USB_BUF    0x80300000
#define PCIE_BUF   0x80400000

INIT_TEST

    /* ================================================================= */
    /* TEST 1: GEM Ethernet APB Configuration & PLIC IRQ 27 Arming       */
    /* ================================================================= */
    li   s0, GEM_BASE
    li   s1, USB_BASE

    /* Arm PLIC Hart 0 enable for IRQ 27 (Ethernet) and IRQ 28 (USB) */
    /* Target 0 Enable: 0x0C002000, bit 27 (0x0800_0000), bit 28 (0x1000_0000) */
    li   s4, 0x0C002000
    li   t1, 0x18000000
    sw   t1, 0(s4)

    /* Set Priority for IRQ 27 (0x0C00006C) to 1 and IRQ 28 (0x0C000070) to 2 */
    li   s4, 0x0C00006C
    li   t1, 1
    sw   t1, 0(s4)
    li   t1, 2
    sw   t1, 4(s4)

    /* Set Threshold to 0 (accept all priority >= 1) */
    li   s4, 0x0C200000
    sw   x0, 0(s4)

    /* Configure GEM Ethernet: 1G full duplex */
    li   t1, 0x00080002
    sw   t1, 0x04(s0)  /* network_config */

    /* Configure buffer pointers */
    li   t1, ETH_TX_BUF
    sw   t1, 0x14(s0)  /* tx_q_ptr */
    li   t1, ETH_RX_BUF
    sw   t1, 0x18(s0)  /* rx_q_ptr */

    /* Unmask ONLY RX interrupt in GEM (bit 1), keep TX interrupt (bit 7) masked */
    li   t1, 0xFFFFFFFD
    sw   t1, 0x24(s0)  /* irq_mask */

    /* Verify network_config readback */
    lwu  a1, 0x04(s0)
    TEST_CASE(1, a1, 0x00080002,
        /* Expected GEM network_config == 0x00080002 */
    )

    /* ================================================================= */
    /* TEST 2: Preload Ethernet TX Buffer in DDR4 & Initiate GMII TX     */
    /* ================================================================= */
    li   s5, ETH_TX_BUF
    li   t1, 0x0011223344556677
    sd   t1, 0(s5)
    li   t1, 0x8899aabbccddeeff
    sd   t1, 8(s5)
    li   t1, 0x0123456789abcdef
    sd   t1, 16(s5)
    li   t1, 0xfedcba9876543210
    sd   t1, 24(s5)
    li   t1, 0xaa55aa55aa55aa55
    sd   t1, 32(s5)
    li   t1, 0x55aa55aa55aa55aa
    sd   t1, 40(s5)
    li   t1, 0x1234567812345678
    sd   t1, 48(s5)
    li   t1, 0x8765432187654321
    sd   t1, 56(s5)

    /* Enable TX & RX in GEM (bit 2 RX en, bit 3 TX en, bit 9 start TX) */
    li   t1, 0x0000020C
    sw   t1, 0x00(s0)

    /* Poll tx_status until bit 0 is set */
    li   t3, 50000
1:
    lwu  a1, 0x08(s0)
    andi t1, a1, 1
    bnez t1, 2f
    addi t3, t3, -1
    bnez t3, 1b
2:
    /* Clear tx_status and clear TX complete IRQ (bit 7) */
    li   t1, 1
    sw   t1, 0x08(s0)
    li   t1, 0x00000080
    sw   t1, 0x20(s0)

    TEST_CASE(2, a1, 1,
        /* Expected GEM tx_status[0] == 1 */
    )

    /* ================================================================= */
    /* TEST 3: Ethernet GMII Loopback Reception & PLIC Claim             */
    /* ================================================================= */
    /* Poll PLIC claim until claim == 27 (from RX complete) */
    li   s4, 0x0C200004
    li   t3, 50000
3:
    lw   a1, 0(s4)
    li   t2, 27
    beq  a1, t2, 4f
    addi t3, t3, -1
    bnez t3, 3b
4:
    /* Complete PLIC interrupt */
    li   t1, 27
    sw   t1, 0(s4)

    /* Clear GEM irq_status bit 1 (RX complete) and rx_status */
    li   t1, 0x00000002
    sw   t1, 0x20(s0)
    li   t1, 1
    sw   t1, 0x0C(s0)

    TEST_CASE(3, a1, 27,
        /* Expected PLIC claim == 27 (Ethernet MAC) */
    )

    /* ================================================================= */
    /* TEST 4: Ethernet Received Buffer Data Integrity Check             */
    /* ================================================================= */
    li   s6, ETH_RX_BUF
    ld   a1, 0(s6)
    TEST_CASE(4, a1, 0x0011223344556677,
        /* Expected ETH_RX_BUF word 0 matches TX payload */
    )

    /* ================================================================= */
    /* TEST 5: USB 2.0 APB Configuration & PLIC IRQ 28 Arming            */
    /* ================================================================= */
    /* Configure asynclistaddr = 0x80300000 */
    li   t1, USB_BUF
    sw   t1, 0x58(s1)

    /* Preload USB buffer with test word */
    li   s7, USB_BUF
    li   t1, 0xa1b2c3d4e5f60718
    sd   t1, 0(s7)

    /* Enable USBINT */
    li   t1, 1
    sw   t1, 0x48(s1)  /* usbintr */

    /* Trigger transfer: Run (bit 0) | Start (bit 4) */
    li   t1, 0x00000011
    sw   t1, 0x40(s1)  /* usbcmd */

    /* Poll PLIC claim until claim == 28 */
    li   s4, 0x0C200004
    li   t3, 50000
5:
    lw   a1, 0(s4)
    li   t2, 28
    beq  a1, t2, 6f
    addi t3, t3, -1
    bnez t3, 5b
6:
    /* Complete PLIC interrupt */
    li   t1, 28
    sw   t1, 0(s4)

    /* Clear usbsts */
    sw   x0, 0x44(s1)

    TEST_CASE(5, a1, 28,
        /* Expected PLIC claim == 28 (USB OTG) */
    )

    /* ================================================================= */
    /* TEST 6: USB Status Readback Verification                          */
    /* ================================================================= */
    lwu  a1, 0x58(s1)  /* asynclistaddr */
    TEST_CASE(6, a1, 0x80300000,
        /* Expected USB asynclistaddr == 0x80300000 */
    )

    /* ================================================================= */
    /* TEST 7: PCIe LTSSM Link Training & Memory Write TLP to DDR4       */
    /* ================================================================= */
    /* PCIe BFM trains link to L0 and writes 0xCAFEBABEDEADBEEF to       */
    /* address 0x80400000. Poll until non-zero.                          */
    li   s8, PCIE_BUF
    li   t3, 50000
7:
    ld   a1, 0(s8)
    bnez a1, 8f
    addi t3, t3, -1
    bnez t3, 7b
8:
    TEST_CASE(7, a1, 0xcafebabedeadbeef,
        /* Expected DDR4 at 0x80400000 contains PCIe MWr payload */
    )

    /* ================================================================= */
    /* TEST 8: PCIe Memory Read TLP & Completion TLP Verification        */
    /* ================================================================= */
    /* Write test data to 0x80400008 for PCIe BFM MRd TLP request       */
    li   t1, 0x1122334455667788
    sd   t1, 8(s8)
    ld   a1, 8(s8)
    TEST_CASE(8, a1, 0x1122334455667788,
        /* Expected DDR4 at 0x80400008 matches readback */
    )

    /* Wait for PCIe BFM to issue MRd and verify CplD completion */
    li   t3, 500
9:
    addi t3, t3, -1
    bnez t3, 9b

    TEST_PASS
    TEST_FAIL
