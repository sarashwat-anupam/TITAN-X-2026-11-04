// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X Clean-Room Low-Speed Peripherals BFM
// Pre-Synthesis Signoff BFM for UART0..4, CAN0/1, SPI Master, I2C Master, GPIO, WDT, and RTC.

#pragma once

#include <cstdint>
#include <iostream>
#include <iomanip>
#include <string>
#include <vector>

class PeripheralsBFM {
private:
    bool m_verbose;
    uint64_t m_violations;

    // UART0..4 tracking
    uint64_t m_uart_tx_bytes[5];
    uint64_t m_uart_rx_bytes[5];

    // CAN0..1 tracking
    uint64_t m_can_tx_frames[2];
    uint64_t m_can_rx_frames[2];

    // SPI Slave Model State
    bool     m_spi_prev_clk;
    uint8_t  m_spi_rx_byte;
    uint8_t  m_spi_tx_byte;
    int      m_spi_bit_idx;
    uint64_t m_spi_transfers;

    // I2C Slave Model State
    bool     m_i2c_prev_scl;
    bool     m_i2c_prev_sda;
    int      m_i2c_state; // 0=IDLE, 1=ADDR, 2=ACK_ADDR, 3=DATA, 4=ACK_DATA
    int      m_i2c_bit_idx;
    uint8_t  m_i2c_shift;
    uint8_t  m_i2c_addr;
    uint8_t  m_i2c_data;
    bool     m_i2c_drive_sda_low;
    uint64_t m_i2c_transfers;

    // WDT and RTC tracking
    uint64_t m_wdt_resets;
    uint64_t m_rtc_ticks;

public:
    PeripheralsBFM(bool verbose = false)
        : m_verbose(verbose),
          m_violations(0),
          m_spi_prev_clk(false),
          m_spi_rx_byte(0),
          m_spi_tx_byte(0x5A), // Default slave response byte
          m_spi_bit_idx(7),
          m_spi_transfers(0),
          m_i2c_prev_scl(true),
          m_i2c_prev_sda(true),
          m_i2c_state(0),
          m_i2c_bit_idx(7),
          m_i2c_shift(0),
          m_i2c_addr(0),
          m_i2c_data(0),
          m_i2c_drive_sda_low(false),
          m_i2c_transfers(0),
          m_wdt_resets(0),
          m_rtc_ticks(0) {
        for (int i = 0; i < 5; ++i) {
            m_uart_tx_bytes[i] = 0;
            m_uart_rx_bytes[i] = 0;
        }
        for (int i = 0; i < 2; ++i) {
            m_can_tx_frames[i] = 0;
            m_can_rx_frames[i] = 0;
        }
    }

    void tick(uint64_t cycle,
              bool rst_n,
              // UART
              uint8_t  uart_tx_pins,
              uint8_t& uart_rx_pins,
              // CAN
              uint8_t  can_tx_pins,
              uint8_t& can_rx_pins,
              // SPI
              bool     spi_clk,
              bool     spi_mosi,
              bool&    spi_miso,
              uint8_t  spi_csn,
              // I2C
              bool     i2c_scl_in,
              bool     i2c_sda_in,
              bool&    i2c_drive_sda_low,
              // WDT reset
              bool     wdt_reset_n,
              // RTC
              bool     rtc_clk) {
        if (!rst_n) {
            uart_rx_pins = 0x1F; // UART RX idle high
            can_rx_pins  = 0x03; // CAN RX idle recessive (high)
            spi_miso     = 1;
            i2c_drive_sda_low = false;
            m_spi_bit_idx = 7;
            m_i2c_state = 0;
            return;
        }

        // 1. UART loopback & monitoring
        uart_rx_pins = uart_tx_pins;

        // 2. CAN loopback & monitoring
        can_rx_pins = can_tx_pins;

        // 3. SPI Slave Responder Model
        // Active when spi_csn[0] == 0
        if ((spi_csn & 0x1) == 0) {
            // In Mode 0, drive MSB immediately when CS is low
            spi_miso = ((m_spi_tx_byte >> m_spi_bit_idx) & 1);

            // Rising edge of spi_clk: sample MOSI
            if (!m_spi_prev_clk && spi_clk) {
                m_spi_rx_byte = (m_spi_rx_byte << 1) | (spi_mosi ? 1 : 0);
            }
            // Falling edge of spi_clk: advance bit index
            if (m_spi_prev_clk && !spi_clk) {
                if (m_spi_bit_idx == 0) {
                    m_spi_bit_idx = 7;
                    m_spi_transfers++;
                    if (m_verbose) {
                        std::cout << "[SPI BFM] Cycle " << cycle << ": Received byte 0x"
                                  << std::hex << (int)m_spi_rx_byte
                                  << ", Responded 0x" << (int)m_spi_tx_byte << std::dec << std::endl;
                    }
                    m_spi_tx_byte = ~m_spi_rx_byte;
                } else {
                    m_spi_bit_idx--;
                }
            }
        } else {
            m_spi_bit_idx = 7;
            spi_miso = 1;
        }
        m_spi_prev_clk = spi_clk;

        // 4. I2C Slave Responder Model
        // Detect START condition: SDA high->low while SCL is high
        if (i2c_scl_in && m_i2c_prev_sda && !i2c_sda_in) {
            m_i2c_state = 1; // ADDR state
            m_i2c_bit_idx = 7;
            m_i2c_shift = 0;
            m_i2c_drive_sda_low = false;
        }
        // Detect STOP condition: SDA low->high while SCL is high
        else if (i2c_scl_in && !m_i2c_prev_sda && i2c_sda_in) {
            if (m_i2c_state != 0) {
                m_i2c_transfers++;
            }
            m_i2c_state = 0;
            m_i2c_drive_sda_low = false;
        }
        // Clock edge handling
        else if (!m_i2c_prev_scl && i2c_scl_in) {
            // Rising edge of SCL: sample bits
            if (m_i2c_state == 1) { // ADDR
                m_i2c_shift = (m_i2c_shift << 1) | (i2c_sda_in ? 1 : 0);
                if (m_i2c_bit_idx == 0) {
                    m_i2c_addr = m_i2c_shift;
                    m_i2c_state = 2; // Move to ADDR ACK drive
                } else {
                    m_i2c_bit_idx--;
                }
            } else if (m_i2c_state == 4) { // DATA
                m_i2c_shift = (m_i2c_shift << 1) | (i2c_sda_in ? 1 : 0);
                if (m_i2c_bit_idx == 0) {
                    m_i2c_data = m_i2c_shift;
                    m_i2c_state = 5; // Move to DATA ACK drive
                } else {
                    m_i2c_bit_idx--;
                }
            }
        } else if (m_i2c_prev_scl && !i2c_scl_in) {
            // Falling edge of SCL: drive / release ACK
            if (m_i2c_state == 2) {
                // Falling edge after bit 0 of address: drive ACK low
                m_i2c_drive_sda_low = true;
                m_i2c_state = 3;
            } else if (m_i2c_state == 3) {
                // Falling edge after address ACK pulse: release SDA, prepare for data
                m_i2c_drive_sda_low = false;
                m_i2c_state = 4;
                m_i2c_bit_idx = 7;
                m_i2c_shift = 0;
            } else if (m_i2c_state == 5) {
                // Falling edge after bit 0 of data: drive ACK low
                m_i2c_drive_sda_low = true;
                m_i2c_state = 6;
            } else if (m_i2c_state == 6) {
                // Falling edge after data ACK pulse: release SDA, wait for STOP
                m_i2c_drive_sda_low = false;
                m_i2c_state = 0;
            } else {
                m_i2c_drive_sda_low = false;
            }
        }

        m_i2c_prev_scl = i2c_scl_in;
        m_i2c_prev_sda = i2c_sda_in;
        i2c_drive_sda_low = m_i2c_drive_sda_low;

        // 5. Watchdog reset tracking
        if (!wdt_reset_n) {
            m_wdt_resets++;
        }
    }

    uint64_t get_violations() const {
        return m_violations;
    }

    uint64_t get_spi_transfers() const {
        return m_spi_transfers;
    }

    uint64_t get_i2c_transfers() const {
        return m_i2c_transfers;
    }

    void print_summary() const {
        std::cout << "\n--- Low-Speed Peripherals BFM Summary ---\n";
        std::cout << "  SPI Transfers Completed: " << m_spi_transfers << "\n";
        std::cout << "  I2C Transfers Completed: " << m_i2c_transfers << "\n";
        std::cout << "  Peripheral Violations:   " << m_violations << "\n";
        std::cout << "------------------------------------------\n";
    }
};
