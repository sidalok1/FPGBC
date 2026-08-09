import numpy as np
from scipy import signal
import matplotlib.pyplot as plt

filt = signal.iirdesign(
    wp = [100, 16e3], 
    ws = [1, 20e3], 
    gpass = 6, 
    gstop = 20, 
    analog = False, 
    output = 'sos', 
    fs = 4.1943e6
)

w, h = signal.freqz_sos(filt, fs = 4.1943e6, worN = 2**12)

plt.subplot(2, 1, 1)
db = 20*np.log10(np.maximum(np.abs(h), 1e-5))
plt.plot(w, db)
plt.ylim(-60, 6)
plt.xlim(0, 44.1e3)
plt.grid(True)
plt.ylabel('Gain [dB]')
plt.title('Frequency Respone')
plt.subplot(2, 1, 2)
plt.plot(w, np.angle(h))
plt.xlim(0, 44.1e3)
plt.ylabel('Phase [rad]')
plt.savefig('freq_resp.png')

print(filt)