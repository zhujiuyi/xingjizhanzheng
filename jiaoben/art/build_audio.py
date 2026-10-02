"""原创合成音效；只输出媒体，响度混音和触发由catalog及游戏事件决定。"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "code/assets/audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100

def synth(name, duration, function, loop=False):
    samples = []
    rng = random.Random(name)
    for index in range(round(duration * RATE)):
        t = index / RATE
        envelope = 1.0 if loop else min(1.0, t / .012) * min(1.0, (duration - t) / .04)
        samples.append(function(t, duration, rng) * envelope)
    peak = max(abs(value) for value in samples) or 1
    pcm = b"".join(struct.pack("<h", round(value / peak * 24000)) for value in samples)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)

def tone(t, frequency):
    return math.sin(math.tau * frequency * t)

def blast(t, duration, rng):
    return (rng.uniform(-1, 1) * math.exp(-t * 6) +
            .7 * tone(t, 40 * math.exp(-t * 1.7) + 18) * math.exp(-t * 3))

synth("ui_confirm", .18, lambda t, d, r: (tone(t, 740) + .5 * tone(t, 1110)) * math.exp(-t * 20))
synth("ui_error", .28, lambda t, d, r: (tone(t, 190) + tone(t, 225)) * math.exp(-t * 9))
synth("engine_loop", 2, lambda t, d, r: .6 * tone(t, 56) + .22 * tone(t, 112) + .12 * tone(t, 224) * (.7 + .3 * tone(t, 4)), True)
synth("mining_loop", 2, lambda t, d, r: .4 * tone(t, 180) + .3 * tone(t, 360) * (.8 + .2 * tone(t, 6)) + .2 * tone(t, 724), True)
synth("repair_loop", 2, lambda t, d, r: .4 * tone(t, 240) + .25 * tone(t, 480) * (.7 + .3 * tone(t, 3)), True)
synth("station_ambience", 4, lambda t, d, r: .5 * tone(t, 32) + .25 * tone(t, 64) + .1 * tone(t, 130) * (.8 + .2 * tone(t, .5)), True)
synth("weapon_kinetic", .38, lambda t, d, r: (r.uniform(-1, 1) * .8 + tone(t, 95 * math.exp(-t * 4))) * math.exp(-t * 18))
synth("weapon_thermal", .48, lambda t, d, r: (tone(t, 760 - t * 900) + .3 * r.uniform(-1, 1)) * math.exp(-t * 8))
synth("weapon_pulse", .5, lambda t, d, r: (tone(t, 210 + t * 420) + .4 * tone(t, 840)) * math.exp(-t * 8))
synth("scan_pulse", 1.2, lambda t, d, r: (tone(t, 440 + t * 210) + .4 * tone(t, 880 + t * 160)) * math.exp(-t * 2.5))
synth("jump_charge", 2.4, lambda t, d, r: (tone(t, 90 + t * t * 90) + .3 * tone(t, 220 + t * 140)) * (.12 + .6 * t / d))
synth("jump_arrival", 1.4, lambda t, d, r: (r.uniform(-1, 1) * .4 + tone(t, 280 * math.exp(-t * 2) + 35)) * math.exp(-t * 3))
synth("shield_hit", .42, lambda t, d, r: (tone(t, 680 * math.exp(-t * 3)) + .3 * tone(t, 1230)) * math.exp(-t * 12))
synth("armor_hit", .42, lambda t, d, r: (r.uniform(-1, 1) + .5 * tone(t, 160)) * math.exp(-t * 15))
synth("explosion", 1.4, blast)
print("ART_AUDIO_COMPLETE", len(list(OUT.glob("*.wav"))), "original WAV files")
