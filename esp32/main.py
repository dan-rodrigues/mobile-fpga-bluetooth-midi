# main.py
#
# Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
#
# SPDX-License-Identifier: MIT

import bluetooth
from machine import Pin
from ble_advertising import advertising_payload
from ble_midi_peripheral import BLEMIDIPeripheral
import time

# ESP32 GPIO

spi_csn = Pin(5, Pin.OUT)
spi_clk = Pin(16, Pin.OUT)
spi_mosi = Pin(4, Pin.OUT)
spi_miso = Pin(12, Pin.IN)
spi_write_en = Pin(2, Pin.OUT)

read_needed = Pin(13, Pin.IN)

# ESP32 -> FPGA

def fpga_write(data):
    spi_clk(0)
    spi_write_en(1)
    spi_csn(0)

    for byte in data:
        for _ in range(8):
            spi_mosi(byte & 0x01)
            spi_clk(1)
            spi_clk(0)
            byte >>= 1;

    spi_csn(1)

# ESP32 <- FPGA

def fpga_read():
   spi_clk(0)
   spi_write_en(0)
   spi_csn(0)

   midi_bytes = []

   for _ in range(3):
       byte = 0
       for _ in range(8):
           byte >>= 1
           byte |= (spi_miso.value() << 7)
           spi_clk(1)
           spi_clk(0)

       midi_bytes.append(byte)

   spi_csn(1)

   return bytes(midi_bytes)

# Main loop

def demo():
    spi_csn(1)

    ble = bluetooth.BLE()
    peripheral = BLEMIDIPeripheral(ble)

    midi_rx_queue = []

    def bt_send():
        midi_bytes = fpga_read()
        ble_midi_bytes = bytearray([0x80, 0x80])
        ble_midi_bytes.extend(midi_bytes)
        peripheral.send(ble_midi_bytes)
        print("MIDI bytes sent: {0}".format(ble_midi_bytes))

    def bt_receive(midi_bytes):
        print("MIDI bytes received: {0}".format(midi_bytes))

        # Note this doesn't support multiple messages per packet or timestamp interleaving
        # The demo app and basic clients don't depend on this
        header_length = 2
        message_length = 3
        full_length = header_length + message_length

        for x in range(0, len(midi_bytes), full_length):
            midi_rx_queue.append(midi_bytes[x + header_length:x + full_length])

    peripheral.on_write(bt_receive)

    while True:
        while midi_rx_queue:
            queued_message = midi_rx_queue[0]
            del midi_rx_queue[0]
            fpga_write(queued_message)

        if peripheral.is_connected() and read_needed.value():
            print("FPGA wants to send MIDI status..")
            bt_send()

demo()
