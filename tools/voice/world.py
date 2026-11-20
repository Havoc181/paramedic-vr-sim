"""Minimal ctypes binding to the WORLD vocoder (modified-BSD licence; build
tool only). Splits speech into pitch (F0), spectral envelope (vocal tract)
and aperiodicity (breathiness), so each can be changed separately and the
voice resynthesised cleanly."""
import ctypes as C, os
import numpy as np

_lib = C.CDLL(os.path.join(os.environ.get("VOICE_TOOLS", os.path.expanduser("~/tts")), "world", "libworld.so"))

class HarvestOption(C.Structure):
    _fields_ = [("f0_floor", C.c_double), ("f0_ceil", C.c_double), ("frame_period", C.c_double)]
class CheapTrickOption(C.Structure):
    _fields_ = [("q1", C.c_double), ("f0_floor", C.c_double), ("fft_size", C.c_int)]
class D4COption(C.Structure):
    _fields_ = [("threshold", C.c_double)]

DP = C.POINTER(C.c_double)
_lib.GetFFTSizeForCheapTrick.restype = C.c_int
_lib.GetSamplesForHarvest.restype = C.c_int


def _rows(a):
    arr = (DP * a.shape[0])()
    for i in range(a.shape[0]):
        arr[i] = a[i].ctypes.data_as(DP)
    return arr


def analyse(x, fs, frame_period=5.0, f0_floor=60.0, f0_ceil=500.0):
    x = np.ascontiguousarray(x, dtype=np.float64)
    ho = HarvestOption(); _lib.InitializeHarvestOption(C.byref(ho))
    ho.frame_period = frame_period; ho.f0_floor = f0_floor; ho.f0_ceil = f0_ceil
    n = _lib.GetSamplesForHarvest(fs, len(x), C.c_double(frame_period))
    t = np.zeros(n); f0 = np.zeros(n)
    _lib.Harvest(x.ctypes.data_as(DP), len(x), fs, C.byref(ho), t.ctypes.data_as(DP), f0.ctypes.data_as(DP))
    co = CheapTrickOption(); _lib.InitializeCheapTrickOption(fs, C.byref(co)); co.f0_floor = f0_floor
    co.fft_size = _lib.GetFFTSizeForCheapTrick(fs, C.byref(co))
    nb = co.fft_size // 2 + 1
    sp = np.zeros((n, nb)); ap = np.zeros((n, nb))
    _lib.CheapTrick(x.ctypes.data_as(DP), len(x), fs, t.ctypes.data_as(DP), f0.ctypes.data_as(DP), n, C.byref(co), _rows(sp))
    do = D4COption(); _lib.InitializeD4COption(C.byref(do))
    _lib.D4C(x.ctypes.data_as(DP), len(x), fs, t.ctypes.data_as(DP), f0.ctypes.data_as(DP), n, co.fft_size, C.byref(do), _rows(ap))
    return f0, sp, ap, co.fft_size


def synthesise(f0, sp, ap, fft_size, fs, frame_period=5.0):
    f0 = np.ascontiguousarray(f0, dtype=np.float64)
    sp = np.ascontiguousarray(sp, dtype=np.float64); ap = np.ascontiguousarray(np.clip(ap, 0, 1), dtype=np.float64)
    ylen = int((len(f0) - 1) * frame_period / 1000.0 * fs) + 1
    y = np.zeros(ylen)
    _lib.Synthesis(f0.ctypes.data_as(DP), len(f0), _rows(sp), _rows(ap), fft_size, C.c_double(frame_period), fs, ylen, y.ctypes.data_as(DP))
    return y
