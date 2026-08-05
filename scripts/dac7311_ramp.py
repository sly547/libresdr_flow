#!/usr/bin/env python
# coding: utf-8

import iio

# Contexts can be found like this:
#     iio_info -S usb
#     iio_info -S ip
# Specifying the complete USB identifier causes a "Device or resource busy" error.
ctx = iio.Context("ip:")

print("Found IIO devices:")
for d in ctx.devices:
        print("  " + d.name)


import pyvisa
rm = pyvisa.ResourceManager("@py")
instrument = rm.open_resource("TCPIP0::lab-pc::gpib0,23::INSTR")


dac = ctx.find_device("dac7311")
for c in dac.channels:
    print(f"Found DAC7311 as an IIO device with channel {c.id = }") # there should be only one: "voltage"
ch = dac.channels[0]
raw = ch.attrs["raw"]
print(f"{raw.value = }")
raw.value = "0"
print(f"{raw.value = }")


import time

# the HP 3478A is in talk only mode by default - getting some readings is simple
print(instrument.read())
time.sleep(0.1)
print(instrument.read())


import numpy as np

# parsing the string with NumPy is easy
foo = np.empty((1))
foo[0] = instrument.read()
print(foo)


N_bits = 12
N_steps = 2**N_bits
N_avg = 2
v = np.empty((N_steps, N_avg))

raw.value = "0"
time.sleep(1) # give it some time to settle

for i in range(N_steps):
    for k in range(N_avg):
        v[i,k] = instrument.read()
    raw.value = str(i)

now = time.strftime("%Y%m%d-%H%M", time.localtime())
np.save(f"dac_step_{now}.npy", v)

import matplotlib.pyplot as plt

plt.plot(np.mean(v[1000:1010], 1), '.')

