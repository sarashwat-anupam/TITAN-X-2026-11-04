#ifndef TITAN_X_MEMORY_MODEL_HPP
#define TITAN_X_MEMORY_MODEL_HPP

#include <cstdint>
#include <vector>
#include <unordered_map>
#include <string>
#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <cstring>

class TitanXMemoryModel {
public:
    static constexpr uint64_t PAGE_SIZE = 4096;
    static constexpr uint64_t PAGE_MASK = PAGE_SIZE - 1;

    TitanXMemoryModel() = default;
    ~TitanXMemoryModel() {
        for (auto& pair : pages_) {
            delete[] pair.second;
        }
        pages_.clear();
    }

    uint8_t* get_page(uint64_t page_addr) {
        auto it = pages_.find(page_addr);
        if (it != pages_.end()) {
            return it->second;
        }
        uint8_t* page = new uint8_t[PAGE_SIZE]();
        pages_[page_addr] = page;
        return page;
    }

    uint8_t read8(uint64_t addr) {
        uint64_t page_addr = addr & ~PAGE_MASK;
        uint64_t offset = addr & PAGE_MASK;
        auto it = pages_.find(page_addr);
        if (it == pages_.end()) return 0;
        return it->second[offset];
    }

    uint16_t read16(uint64_t addr) {
        uint16_t val = read8(addr);
        val |= (static_cast<uint16_t>(read8(addr + 1)) << 8);
        return val;
    }

    uint32_t read32(uint64_t addr) {
        uint32_t val = read16(addr);
        val |= (static_cast<uint32_t>(read16(addr + 2)) << 16);
        return val;
    }

    uint64_t read64(uint64_t addr) {
        uint64_t val = read32(addr);
        val |= (static_cast<uint64_t>(read32(addr + 4)) << 32);
        return val;
    }

    void write8(uint64_t addr, uint8_t val) {
        uint64_t page_addr = addr & ~PAGE_MASK;
        uint64_t offset = addr & PAGE_MASK;
        uint8_t* page = get_page(page_addr);
        page[offset] = val;
    }

    void write16(uint64_t addr, uint16_t val) {
        write8(addr, val & 0xFF);
        write8(addr + 1, (val >> 8) & 0xFF);
    }

    void write32(uint64_t addr, uint32_t val) {
        write16(addr, val & 0xFFFF);
        write16(addr + 2, (val >> 16) & 0xFFFF);
    }

    void write64(uint64_t addr, uint64_t val, uint8_t strb = 0xFF) {
        for (int i = 0; i < 8; ++i) {
            if ((strb >> i) & 1) {
                write8(addr + i, (val >> (i * 8)) & 0xFF);
            }
        }
    }

    bool load_hex(const std::string& filepath, uint64_t base_addr = 0) {
        std::ifstream file(filepath);
        if (!file.is_open()) {
            std::cerr << "[MemoryModel] Error: Cannot open hex file " << filepath << std::endl;
            return false;
        }

        std::string line;
        uint64_t current_addr = base_addr;
        while (std::getline(file, line)) {
            // Trim whitespace
            size_t start = line.find_first_not_of(" \t\r\n");
            if (start == std::string::npos) continue;
            line = line.substr(start);
            if (line.empty() || line[0] == '#' || line[0] == '/') continue;

            if (line[0] == '@') {
                // Address directive: @80000000
                current_addr = std::stoull(line.substr(1), nullptr, 16);
            } else {
                // Tokens of 8-bit, 16-bit, 32-bit or 64-bit hex words
                std::istringstream iss(line);
                std::string token;
                while (iss >> token) {
                    if (token.length() <= 2) {
                        uint8_t b = std::stoul(token, nullptr, 16);
                        write8(current_addr, b);
                        current_addr += 1;
                    } else if (token.length() <= 8) {
                        uint32_t w = std::stoul(token, nullptr, 16);
                        write32(current_addr, w);
                        current_addr += 4;
                    } else {
                        uint64_t dw = std::stoull(token, nullptr, 16);
                        write64(current_addr, dw, 0xFF);
                        current_addr += 8;
                    }
                }
            }
        }
        std::cout << "[MemoryModel] Loaded hex file: " << filepath << " up to addr 0x" 
                  << std::hex << current_addr << std::dec << std::endl;
        return true;
    }

    bool load_binary(const std::string& filepath, uint64_t base_addr) {
        std::ifstream file(filepath, std::ios::binary);
        if (!file.is_open()) {
            std::cerr << "[MemoryModel] Error: Cannot open binary file " << filepath << std::endl;
            return false;
        }
        char buffer[4096];
        uint64_t current_addr = base_addr;
        while (file.read(buffer, sizeof(buffer)) || file.gcount() > 0) {
            std::streamsize bytes = file.gcount();
            for (std::streamsize i = 0; i < bytes; ++i) {
                write8(current_addr + i, static_cast<uint8_t>(buffer[i]));
            }
            current_addr += bytes;
        }
        std::cout << "[MemoryModel] Loaded binary file: " << filepath << " (" 
                  << (current_addr - base_addr) << " bytes) at 0x" 
                  << std::hex << base_addr << std::dec << std::endl;
        return true;
    }

private:
    std::unordered_map<uint64_t, uint8_t*> pages_;
};

#endif // TITAN_X_MEMORY_MODEL_HPP
