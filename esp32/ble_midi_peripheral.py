# This file is based on the Micropython examples
# UUIDs and the tuple names have been changed and tweaks made to suit BLE MIDI

import bluetooth
import random
import struct
import time
from ble_advertising import advertising_payload

_IRQ_CENTRAL_CONNECT = const(1)
_IRQ_CENTRAL_DISCONNECT = const(2)
_IRQ_GATTS_WRITE = const(3)

_MIDI_IO = (
    bluetooth.UUID("7772E5DB-3868-4112-A1A9-F2669D106BF3"),
    bluetooth.FLAG_READ | bluetooth.FLAG_NOTIFY | bluetooth.FLAG_WRITE | bluetooth.FLAG_WRITE_NO_RESPONSE,
)

_MIDI_UUID = bluetooth.UUID("03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
_MIDI_SERVICE = (
    _MIDI_UUID,
    (_MIDI_IO,),
)

class BLEMIDIPeripheral:
    def __init__(self, ble, name="ESP32"):
        self._ble = ble
        self._ble.active(True)
        self._ble.irq(self._irq)

        ((
            self._handle_io,
        ),) = self._ble.gatts_register_services((_MIDI_SERVICE,))

        # Default setting is to clobber the characteristic value with the latest
        # This enables buffering of MIDI messages sent in rapid succession
        self._ble.gatts_set_buffer(self._handle_io, 32, True)

        self._connections = set()
        self._write_callback = None
        self._payload = advertising_payload(name=name, services=[_MIDI_UUID])
        self._advertise()

    def _irq(self, event, data):
        # Track connections so we can send notifications.
        if event == _IRQ_CENTRAL_CONNECT:
            conn_handle, _, _ = data
            print("New connection", conn_handle)
            self._connections.add(conn_handle)
        elif event == _IRQ_CENTRAL_DISCONNECT:
            conn_handle, _, _ = data
            print("Disconnected", conn_handle)
            self._connections.remove(conn_handle)
            # Start advertising again to allow a new connection.
            self._advertise()
        elif event == _IRQ_GATTS_WRITE:
            conn_handle, value_handle = data
            value = self._ble.gatts_read(value_handle)

            if self._write_callback:
                self._write_callback(value)

    def send(self, data):
        for conn_handle in self._connections:
            self._ble.gatts_notify(conn_handle, self._handle_io, data)

    def is_connected(self):
        return len(self._connections) > 0

    def _advertise(self, interval_us=500000):
        print("Starting advertising")
        self._ble.gap_advertise(interval_us, adv_data=self._payload)

    def on_write(self, callback):
        self._write_callback = callback
