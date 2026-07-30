"""
Day 260B -- inspect real get_input_details() for the IMU-family models Day
259 flagged as either "exactly constant" or "wrong-direction":
  m2_motion_b, m2_motion_adversarial, o_running_fleeing (+f32),
  s_crowd_panic_a (+f32), s_best

Does NOT assume PREPROCESSING_SPEC.md's shape table is correct (it was
already shown wrong for k_confinement on Day 260). Reports the real
signature straight from the interpreter for each staged file.
"""
import pathlib
import tensorflow as tf

STAGE = pathlib.Path(
    r"C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\kaggle_notebooks\day108_int4_m9_push"
    r"\day108_kaggle_output\saved\int4_m9\day108-int4-m9-kaggle-20260703-v5-production\tflite_staging"
)

FILES = [
    "m2_motion_b.tflite",
    "m2_motion_adversarial.tflite",
    "o_running_fleeing.tflite",
    "o_running_fleeing_f32.tflite",
    "s_crowd_panic_a.tflite",
    "s_crowd_panic_a_f32.tflite",
    "s_best.tflite",
]

for fn in FILES:
    p = STAGE / fn
    print("\n" + "=" * 70)
    print(fn, "  size=", p.stat().st_size if p.exists() else "MISSING")
    if not p.exists():
        continue
    interp = tf.lite.Interpreter(model_path=str(p))
    interp.allocate_tensors()
    print("INPUTS:")
    for d in interp.get_input_details():
        print(f"  name={d['name']!r} shape={d['shape'].tolist()} dtype={d['dtype']} quant={d['quantization']}")
    print("OUTPUTS:")
    for d in interp.get_output_details():
        print(f"  name={d['name']!r} shape={d['shape'].tolist()} dtype={d['dtype']} quant={d['quantization']}")
