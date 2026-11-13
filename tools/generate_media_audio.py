"""Ver.0.2用のオリジナル試験曲2曲を生成する。Python標準ライブラリのみ。"""
from array import array
from math import exp, pi, sin
from pathlib import Path
import sys
import wave

RATE = 16000
SECONDS = 8
MELODIES = {
    "mountain": [64, 67, 69, 67, 62, 64, 67, 64, 60, 64, 67, 69, 67, 64, 62, 60],
    "discovery": [72, 71, 67, 64, 69, 67, 64, 62, 65, 69, 72, 69, 67, 64, 62, 60],
}


def frequency(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def render(name, melody):
    samples = array("h")
    for index in range(RATE * SECONDS):
        time = index / RATE
        note_time = time % 0.5
        note = melody[int(time / 0.5)]
        envelope = min(note_time / 0.015, 1) * exp(-6 * note_time)
        phase = 2 * pi * frequency(note) * note_time
        lead = (sin(phase) + 0.18 * sin(2 * phase)) * envelope
        bass_note = [48, 43, 45, 41][int(time / 2)]
        bass = 0.18 * sin(2 * pi * frequency(bass_note) * time) * sin(pi * (time % 2) / 2)
        fade = min(time / 0.05, (SECONDS - time) / 0.08, 1)
        value = (lead * 0.32 + bass) * max(0, fade)
        samples.append(round(max(-1, min(1, value)) * 32767))
    if sys.byteorder != "little":
        samples.byteswap()
    destination = Path(__file__).resolve().parents[1] / "assets" / "media" / (name + ".wav")
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(samples.tobytes())
    print(destination.name, destination.stat().st_size, "bytes")


if __name__ == "__main__":
    for title, notes in MELODIES.items():
        render(title, notes)
