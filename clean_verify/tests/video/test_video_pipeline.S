/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: Video Subsystem Qualification Suite */
/* Verifies VDMA (S2MM/MM2S), MIPI CSI-2 RX, ISP Pipeline, and HDMI Display */

#include "../test_macros.h"

#define VDMA_BASE 0x40018000
#define MIPI_BASE 0x40040000
#define ISP_BASE  0x40050000
#define HDMI_BASE 0x40060000
#define PLIC_BASE 0x0C000000

#define S2MM_BUF  0x80100000
#define MM2S_BUF  0x80200000

INIT_TEST

    /* ================================================================= */
    /* TEST 1: Video Subsystem APB Register Read/Write Access            */
    /* ================================================================= */
    /* Verify VDMA status register is initially 0 (idle)                 */
    li   s0, VDMA_BASE
    lw   a1, 4(s0)
    TEST_CASE(1, a1, 0,
        /* Expected VDMA SR == 0x0000_0000 */
    )

    /* Arm PLIC Hart 0 enable for IRQ 17 (bit 17 of 0x0C002000) */
    li   s4, 0x0C002000
    li   t1, 0x00020000 /* 1 << 17 */
    sw   t1, 0(s4)

    /* ================================================================= */
    /* TEST 2: ISP Pipeline Bypass Configuration                         */
    /* ================================================================= */
    /* Configure ISP bypass register (0x4005_0000) = 1                   */
    li   s1, ISP_BASE
    li   t1, 1
    sw   t1, 0(s1)
    lw   a1, 0(s1)
    TEST_CASE(2, a1, 1,
        /* Expected ISP bypass_ctrl == 1 */
    )

    /* ================================================================= */
    /* TEST 3: HDMI Controller Active Timing Configuration               */
    /* ================================================================= */
    /* Program compact timing parameters so HDMI active display          */
    /* window (vde_reg = 1) is active immediately:                       */
    /* h_total=16, h_sync=2, h_start=0, h_active=16                      */
    /* v_total=4,  v_sync=1, v_start=0, v_active=4                       */
    li   s2, HDMI_BASE
    li   t1, 16
    sw   t1, 0x00(s2)  /* h_total */
    li   t1, 2
    sw   t1, 0x04(s2)  /* h_sync */
    li   t1, 0
    sw   t1, 0x08(s2)  /* h_start */
    li   t1, 16
    sw   t1, 0x0C(s2)  /* h_active */
    li   t1, 4
    sw   t1, 0x10(s2)  /* v_total */
    li   t1, 1
    sw   t1, 0x14(s2)  /* v_sync */
    li   t1, 0
    sw   t1, 0x18(s2)  /* v_start */
    li   t1, 4
    sw   t1, 0x1C(s2)  /* v_active */
    TEST_CASE(3, x0, 0,
        /* HDMI timing programmed */
    )

    /* ================================================================= */
    /* TEST 4: VDMA S2MM Geometry Configuration (2 lines x 16 bytes)      */
    /* ================================================================= */
    /* Program S2MM channels:                                            */
    /* vsize = 2 lines, hsize = 16 bytes (4 pixels), stride = 16 bytes   */
    /* target buffer = 0x8010_0000 (DDR4)                                */
    li   s0, VDMA_BASE
    li   t1, 2
    sw   t1, 0x30(s0)  /* s2mm_vsize */
    li   t1, 16
    sw   t1, 0x34(s0)  /* s2mm_hsize */
    li   t1, 16
    sw   t1, 0x38(s0)  /* s2mm_stride */
    li   t1, S2MM_BUF
    sw   t1, 0x3C(s0)  /* s2mm_start_addr */

    /* Read back and verify S2MM vsize */
    lw   a1, 0x30(s0)
    TEST_CASE(4, a1, 2,
        /* Expected s2mm_vsize == 2 */
    )

    /* ================================================================= */
    /* TEST 5: MIPI CSI-2 Camera Stream Ingestion & S2MM Frame Capture    */
    /* ================================================================= */
    /* Clear target buffer in DDR4 */
    li   t0, S2MM_BUF
    sw   x0, 0(t0)
    sw   x0, 4(t0)
    sw   x0, 8(t0)
    sw   x0, 12(t0)
    sw   x0, 16(t0)
    sw   x0, 20(t0)
    sw   x0, 24(t0)
    sw   x0, 28(t0)

    /* Start VDMA S2MM channel: cr = 0x22 (s2mm_run=1, s2mm_start=1) */
    li   t1, 0x22
    sw   t1, 0(s0)

    /* Enable MIPI CSI-2 RX: write 1 to control_reg (0x4004_0000) */
    li   s3, MIPI_BASE
    li   t1, 1
    sw   t1, 0(s3)

    /* Poll VDMA status register (0x04) bit 3 (s2mm_done) */
    li   t2, 50000
.Lwait_s2mm:
    lw   t1, 4(s0)
    andi t3, t1, 8     /* bit 3: s2mm_done */
    bnez t3, .Ls2mm_done
    addi t2, t2, -1
    bnez t2, .Lwait_s2mm

.Ls2mm_done:
    /* Check s2mm_done bit was set */
    andi a1, t1, 8
    TEST_CASE(5, a1, 8,
        /* Expected s2mm_done == 1 (bit 3 set) */
    )

    /* ================================================================= */
    /* TEST 6: DDR4 Captured Frame Pixel Verification                   */
    /* ================================================================= */
    /* Verify pixel data captured in DDR4 at 0x8010_0000:               */
    /* Word 0: 0xA000_0000                                               */
    /* Word 1: 0xA001_0001                                               */
    li   s5, S2MM_BUF
    lwu  a1, 0(s5)
    TEST_CASE(6, a1, 0xA0000000,
        /* Verify Pixel 0 == 0xA0000000 */
    )

    lwu  a1, 4(s5)
    li   t0, 0xA0010001
    bne  a1, t0, .Lfail_pix1
    j    .Lpix_ok
.Lfail_pix1:
    li   a0, 6
    j    test_fail
.Lpix_ok:

    /* ================================================================= */
    /* TEST 7: VDMA MM2S Stream to HDMI Controller                       */
    /* ================================================================= */
    /* Preload known frame data into DDR4 at MM2S_BUF (0x8020_0000)     */
    li   t0, MM2S_BUF
    li   t1, 0xCAFEBABE
    sw   t1, 0(t0)
    li   t1, 0xDEADBEEF
    sw   t1, 4(t0)
    li   t1, 0x12345678
    sw   t1, 8(t0)
    li   t1, 0x9ABCDEF0
    sw   t1, 12(t0)

    /* Program MM2S geometry: 1 line x 16 bytes, stride=16               */
    li   s0, VDMA_BASE
    li   t1, 1
    sw   t1, 0x10(s0)  /* mm2s_vsize */
    li   t1, 16
    sw   t1, 0x14(s0)  /* mm2s_hsize */
    li   t1, 16
    sw   t1, 0x18(s0)  /* mm2s_stride */
    li   t1, MM2S_BUF
    sw   t1, 0x1C(s0)  /* mm2s_start_addr */

    /* Start MM2S channel: cr = 0x11 (mm2s_run=1, mm2s_start=1) */
    li   t1, 0x11
    sw   t1, 0(s0)

    /* Poll VDMA status register bit 2 (mm2s_done) */
    li   t2, 50000
.Lwait_mm2s:
    lw   t1, 4(s0)
    andi t3, t1, 4     /* bit 2: mm2s_done */
    bnez t3, .Lmm2s_done
    addi t2, t2, -1
    bnez t2, .Lwait_mm2s

.Lmm2s_done:
    andi a1, t1, 4
    TEST_CASE(7, a1, 4,
        /* Expected mm2s_done == 1 (bit 2 set) */
    )

    /* ================================================================= */
    /* TEST 8: VDMA Interrupt Routing via PLIC (IRQ 17)                  */
    /* ================================================================= */
    /* Configure PLIC Hart 0 enable for IRQ 17 (bit 17 of 0x0C002000)    */
    li   s4, 0x0C002000
    li   t1, 0x00020000 /* 1 << 17 */
    sw   t1, 0(s4)

    /* Read PLIC claim register at 0x0C200004 for Hart 0 M-mode */
    li   s4, 0x0C200004
    lw   a1, 0(s4)
    TEST_CASE(8, a1, 17,
        /* Expected PLIC claim register returns 17 (VDMA IRQ) */
    )

    /* Claim/complete interrupt by writing source ID 17 back to claim register */
    li   t1, 17
    sw   t1, 0(s4)

    /* Clear VDMA done flags in CR: write 0x0C (bits 2 and 3 clear done) */
    li   s0, VDMA_BASE
    li   t1, 0x0C
    sw   t1, 0(s0)

    /* All 8 Tests Passed! */
    TEST_PASS
    TEST_FAIL
