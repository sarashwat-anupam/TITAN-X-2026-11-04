/* SPDX-License-Identifier: Apache-2.0 */
/* SMVDU TITAN-X Clean-Room Verification: Low-Speed Peripherals Qualification Suite */
/* Verifies UART0..4, CAN0/1, SPI Master, I2C Master, Watchdog, RTC, and CLINT/PLIC */

#include "../test_macros.h"

#define UART0_BASE 0x40000000
#define UART1_BASE 0x40001000
#define UART2_BASE 0x40002000
#define UART3_BASE 0x40003000
#define UART4_BASE 0x40004000
#define RTC_BASE   0x40010000
#define GPIO_BASE  0x40011000
#define WDT_BASE   0x40012000
#define SPI_BASE   0x40013000
#define I2C_BASE   0x40014000
#define CLINT_BASE 0x02000000
#define CAN0_BASE  0x400B0000
#define CAN1_BASE  0x400C0000
#define PLIC_BASE  0x0C000000

INIT_TEST

    /* ================================================================= */
    /* STAGE 1: UART0..4 Loopback & PLIC Interrupts                      */
    /* ================================================================= */
    /* Configure PLIC Target 0 Enable: Enable sources 13..28             */
    /* Sources: 14=WDT, 15=SPI, 16=I2C, 20..24=UART0..4, 25..26=CAN0..1  */
    li   s0, PLIC_BASE
    li   t0, 0x07F1E000  /* Bits 13..16, 20..26 */
    li   t2, 0x0C002000  /* Target 0 Enable */
    sw   t0, 0(t2)

    /* Set Priorities for all sources to 1 */
    li   t1, 1
    sw   t1, (13*4)(s0)
    sw   t1, (14*4)(s0)
    sw   t1, (15*4)(s0)
    sw   t1, (16*4)(s0)
    sw   t1, (20*4)(s0)
    sw   t1, (21*4)(s0)
    sw   t1, (22*4)(s0)
    sw   t1, (23*4)(s0)
    sw   t1, (24*4)(s0)
    sw   t1, (25*4)(s0)
    sw   t1, (26*4)(s0)

    /* Set Threshold to 0 */
    li   t2, 0x0C200000
    sw   x0, 0(t2)

    li   s8, 0x0C200004  /* Target 0 Claim / Complete */

    /* --- UART 0 --- */
    li   s1, UART0_BASE
    li   t0, 0x80; sw t0, 0x0C(s1)  /* LCR: DLAB=1 */
    li   t0, 0x01; sw t0, 0x00(s1)  /* DLL=1 */
    li   t0, 0x00; sw t0, 0x04(s1)  /* DLM=0 */
    li   t0, 0x03; sw t0, 0x0C(s1)  /* LCR: 8N1, DLAB=0 */
    li   t0, 0x10; sw t0, 0x10(s1)  /* MCR: Loopback enable */
    li   t0, 0x01; sw t0, 0x04(s1)  /* IER: RDA interrupt enable */
    li   t0, 0x41; sw t0, 0x00(s1)  /* Send 'A' */
1:  lwu  t0, 0x14(s1)
    andi t0, t0, 1
    beqz t0, 1b                     /* Poll LSR[0] (DR) */
    lwu  a1, 0x00(s1)               /* Read RBR */
    TEST_CASE(1, a1, 0x41, /* UART0 byte == 'A' */)
    lwu  a2, 0(s8)                  /* PLIC Claim */
    TEST_CASE(2, a2, 20, /* PLIC IRQ 20 */)
    sw   a2, 0(s8)                  /* PLIC Complete */

    /* --- UART 1 --- */
    li   s1, UART1_BASE
    li   t0, 0x80; sw t0, 0x0C(s1)
    li   t0, 0x01; sw t0, 0x00(s1)
    li   t0, 0x00; sw t0, 0x04(s1)
    li   t0, 0x03; sw t0, 0x0C(s1)
    li   t0, 0x10; sw t0, 0x10(s1)
    li   t0, 0x01; sw t0, 0x04(s1)
    li   t0, 0x42; sw t0, 0x00(s1)  /* Send 'B' */
2:  lwu  t0, 0x14(s1)
    andi t0, t0, 1
    beqz t0, 2b
    lwu  a1, 0x00(s1)
    TEST_CASE(3, a1, 0x42, /* UART1 byte == 'B' */)
    lwu  a2, 0(s8)
    TEST_CASE(4, a2, 21, /* PLIC IRQ 21 */)
    sw   a2, 0(s8)

    /* --- UART 2 --- */
    li   s1, UART2_BASE
    li   t0, 0x80; sw t0, 0x0C(s1)
    li   t0, 0x01; sw t0, 0x00(s1)
    li   t0, 0x00; sw t0, 0x04(s1)
    li   t0, 0x03; sw t0, 0x0C(s1)
    li   t0, 0x10; sw t0, 0x10(s1)
    li   t0, 0x01; sw t0, 0x04(s1)
    li   t0, 0x43; sw t0, 0x00(s1)  /* Send 'C' */
3:  lwu  t0, 0x14(s1)
    andi t0, t0, 1
    beqz t0, 3b
    lwu  a1, 0x00(s1)
    TEST_CASE(5, a1, 0x43, /* UART2 byte == 'C' */)
    lwu  a2, 0(s8)
    TEST_CASE(6, a2, 22, /* PLIC IRQ 22 */)
    sw   a2, 0(s8)

    /* --- UART 3 --- */
    li   s1, UART3_BASE
    li   t0, 0x80; sw t0, 0x0C(s1)
    li   t0, 0x01; sw t0, 0x00(s1)
    li   t0, 0x00; sw t0, 0x04(s1)
    li   t0, 0x03; sw t0, 0x0C(s1)
    li   t0, 0x10; sw t0, 0x10(s1)
    li   t0, 0x01; sw t0, 0x04(s1)
    li   t0, 0x44; sw t0, 0x00(s1)  /* Send 'D' */
4:  lwu  t0, 0x14(s1)
    andi t0, t0, 1
    beqz t0, 4b
    lwu  a1, 0x00(s1)
    TEST_CASE(7, a1, 0x44, /* UART3 byte == 'D' */)
    lwu  a2, 0(s8)
    TEST_CASE(8, a2, 23, /* PLIC IRQ 23 */)
    sw   a2, 0(s8)

    /* --- UART 4 --- */
    li   s1, UART4_BASE
    li   t0, 0x80; sw t0, 0x0C(s1)
    li   t0, 0x01; sw t0, 0x00(s1)
    li   t0, 0x00; sw t0, 0x04(s1)
    li   t0, 0x03; sw t0, 0x0C(s1)
    li   t0, 0x10; sw t0, 0x10(s1)
    li   t0, 0x01; sw t0, 0x04(s1)
    li   t0, 0x45; sw t0, 0x00(s1)  /* Send 'E' */
5:  lwu  t0, 0x14(s1)
    andi t0, t0, 1
    beqz t0, 5b
    lwu  a1, 0x00(s1)
    TEST_CASE(9, a1, 0x45, /* UART4 byte == 'E' */)
    lwu  a2, 0(s8)
    TEST_CASE(10, a2, 24, /* PLIC IRQ 24 */)
    sw   a2, 0(s8)

    /* ================================================================= */
    /* STAGE 2: CAN0 & CAN1 Frame Transmission, Reception & IRQs         */
    /* ================================================================= */
    /* --- CAN0: Standard 11-bit Frame --- */
    li   s2, CAN0_BASE
    li   t0, 0x04; sw t0, 0x00(s2)  /* Mode: Normal + Self-test */
    li   t0, 0x03; sw t0, 0x10(s2)  /* Enable RI and TI interrupts */
    li   t0, 0x55A; sw t0, 0x20(s2) /* TX ID = 0x55A */
    li   t0, 4; sw t0, 0x24(s2)     /* TX DLC = 4 */
    li   t0, 0xDEADBEEF; sw t0, 0x28(s2) /* TX Data 0 */
    li   t0, 0x01; sw t0, 0x04(s2)  /* CMD: TR (Transmit Request) */

6:  lwu  t0, 0x08(s2)               /* Poll stat_reg for RBS (bit 0) */
    andi t0, t0, 1
    beqz t0, 6b

    lwu  a1, 0x30(s2)               /* RX ID */
    TEST_CASE(11, a1, 0x55A, /* CAN0 RX ID == 0x55A */)
    lwu  a2, 0x38(s2)               /* RX Data 0 */
    TEST_CASE(12, a2, 0xDEADBEEF, /* CAN0 RX Data == 0xDEADBEEF */)

    li   t0, 0x04; sw t0, 0x04(s2)  /* Release Receive Buffer (RRB) & clear CAN IRQ */
    lwu  a3, 0(s8)                  /* PLIC Claim */
    TEST_CASE(13, a3, 25, /* PLIC IRQ 25 (CAN0) */)
    sw   a3, 0(s8)                  /* PLIC Complete */

    /* --- CAN1: Extended 29-bit Frame --- */
    li   s2, CAN1_BASE
    li   t0, 0x04; sw t0, 0x00(s2)
    li   t0, 0x03; sw t0, 0x10(s2)
    li   t0, 0x1ABCDEF0; sw t0, 0x20(s2) /* 29-bit Extended ID */
    li   t0, 8; sw t0, 0x24(s2)          /* DLC = 8 */
    li   t0, 0x11223344; sw t0, 0x28(s2) /* TX Data 0 */
    li   t0, 0x55667788; sw t0, 0x2C(s2) /* TX Data 1 */
    li   t0, 0x01; sw t0, 0x04(s2)       /* CMD: TR */

7:  lwu  t0, 0x08(s2)
    andi t0, t0, 1
    beqz t0, 7b

    lwu  a1, 0x30(s2)
    TEST_CASE(14, a1, 0x1ABCDEF0, /* CAN1 RX ID == 0x1ABCDEF0 */)
    lwu  a2, 0x38(s2)
    TEST_CASE(15, a2, 0x11223344, /* CAN1 RX Data 0 */)
    lwu  a3, 0x3C(s2)
    TEST_CASE(16, a3, 0x55667788, /* CAN1 RX Data 1 */)

    li   t0, 0x04; sw t0, 0x04(s2)  /* RRB & clear CAN IRQ */
    lwu  a4, 0(s8)                  /* PLIC Claim */
    TEST_CASE(17, a4, 26, /* PLIC IRQ 26 (CAN1) */)
    sw   a4, 0(s8)                  /* PLIC Complete */

    /* ================================================================= */
    /* STAGE 3: SPI Master Transfer & Slave BFM Response                */
    /* ================================================================= */
    li   s3, SPI_BASE
    li   t0, 1; sw t0, 0x04(s3)     /* clk_div = 1 */
    li   t0, 0; sw t0, 0x08(s3)     /* CS0 select */
    li   t0, 0xA5; sw t0, 0x00(s3)  /* Transmit 0xA5, starts transfer */

8:  lwu  t0, 0x04(s3)               /* Poll busy bit (bit 16) */
    srli t0, t0, 16
    bnez t0, 8b

    lwu  a1, 0x00(s3)               /* Read RX data */
    TEST_CASE(18, a1, 0x5A, /* SPI Slave BFM response == 0x5A */)

    lwu  a2, 0(s8)                  /* PLIC Claim */
    TEST_CASE(19, a2, 15, /* PLIC IRQ 15 (SPI) */)
    sw   a2, 0(s8)                  /* PLIC Complete */

    /* ================================================================= */
    /* STAGE 4: I2C Master Transfer & Slave BFM ACK                      */
    /* ================================================================= */
    li   s4, I2C_BASE
    li   t0, 2; sw t0, 0x00(s4)     /* prescale = 2 */
    li   t0, 0x42; sw t0, 0x04(s4)  /* Slave Address 0x21 (Write) */
    li   t0, 0x05; sw t0, 0x08(s4)  /* CMD: START + WRITE */

9:  lwu  t0, 0x00(s4)               /* Poll busy bit (bit 16) */
    srli t0, t0, 16
    bnez t0, 9b

    lwu  a1, 0x08(s4)               /* Read ACK status */
    andi a1, a1, 1
    TEST_CASE(20, a1, 1, /* I2C Address ACK == 1 */)

    /* Send Data byte */
    li   t0, 0xCE; sw t0, 0x04(s4)  /* Data byte 0xCE */
    li   t0, 0x09; sw t0, 0x08(s4)  /* CMD: STOP + WRITE */

10: lwu  t0, 0x00(s4)
    srli t0, t0, 16
    bnez t0, 10b

    lwu  a2, 0x08(s4)               /* Read ACK status */
    andi a2, a2, 1
    TEST_CASE(21, a2, 1, /* I2C Data ACK == 1 */)

    lwu  a3, 0(s8)                  /* PLIC Claim */
    TEST_CASE(22, a3, 16, /* PLIC IRQ 16 (I2C) */)
    sw   a3, 0(s8)                  /* PLIC Complete */

    /* ================================================================= */
    /* STAGE 5: Watchdog Timer Count & Kick                              */
    /* ================================================================= */
    li   s5, WDT_BASE
    li   t0, 0x1ACCE551; sw t0, 0x00(s5) /* Unlock */
    li   t0, 200; sw t0, 0x04(s5)        /* load_val = 200 */
    li   t0, 0x03; sw t0, 0x0C(s5)       /* Enable WDT and Interrupt */

11: lwu  t0, 0x0C(s5)                    /* Poll int_stat (bit 1) */
    andi t0, t0, 2
    beqz t0, 11b

    lwu  a1, 0(s8)                       /* PLIC Claim */
    TEST_CASE(23, a1, 14, /* PLIC IRQ 14 (WDT) */)
    sw   a1, 0(s8)                       /* PLIC Complete */

    /* Kick Watchdog: write 0xE5 */
    li   t0, 0x000000E5; sw t0, 0x08(s5)
    lwu  a2, 0x0C(s5)                    /* Verify int_stat cleared */
    andi a2, a2, 2
    TEST_CASE(24, a2, 0, /* WDT int_stat cleared */)

    /* Disable WDT */
    li   t0, 0x1ACCE551; sw t0, 0x00(s5)
    sw   x0, 0x0C(s5)

    /* ================================================================= */
    /* STAGE 6: RTC Timebase & Hart 0 Timer Interrupt                    */
    /* ================================================================= */
    li   s6, RTC_BASE
    lwu  s7, 0x00(s6)               /* Read mtime low */
    li   t0, 500
12: addi t0, t0, -1
    bnez t0, 12b
    lwu  a1, 0x00(s6)               /* Read mtime low again */
    sub  a2, a1, s7
    sltu a3, x0, a2                 /* a3 = (a1 > s7) ? 1 : 0 */
    TEST_CASE(25, a3, 1, /* RTC mtime incrementing */)

    /* ================================================================= */
    /* STAGE 7: CLINT MSIP Software Interrupt & mtimecmp Readback        */
    /* ================================================================= */
    li   s7, CLINT_BASE
    li   t0, 1; sw t0, 0x0000(s7)   /* msip[0] = 1 */
    csrr a1, mip
    andi a2, a1, 0x08               /* MSIP bit 3 */
    snez a2, a2
    TEST_CASE(26, a2, 1, /* Hart 0 MIP.MSIP == 1 */)

    sw   x0, 0x0000(s7)             /* msip[0] = 0 */
    csrr a1, mip
    andi a2, a1, 0x08
    TEST_CASE(27, a2, 0, /* Hart 0 MIP.MSIP cleared */)

    /* Test mtimecmp write and readback */
    li   t2, 0x02004000             /* CLINT mtimecmp[0] */
    li   t0, 0xCAFEBABE; sw t0, 0(t2)
    lwu  a1, 0(t2)
    TEST_CASE(28, a1, 0xCAFEBABE, /* CLINT mtimecmp[0] readback */)

    /* Restore mtimecmp to max */
    li   t0, 0xFFFFFFFF; sw t0, 0(t2)
    sw   t0, 4(t2)

    TEST_PASS
    TEST_FAIL
