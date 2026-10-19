# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
from pathlib import Path
import sys

output = Path(sys.argv[1])
for child in ("pascal", "include", "c"):
    (output / child).mkdir(parents=True, exist_ok=True)
(output / "include/GeneratedValue.h").write_text("#define NX_GENERATED_VALUE 42\nint nx_generated_value(void);\n")
(output / "include/GeneratedConstants.inc").write_text("const cGeneratedValue = 42;\n")
(output / "pascal/GeneratedValues.pas").write_text("unit GeneratedValues;\n{$mode objfpc}{$H+}\ninterface\n{$I GeneratedConstants.inc}\nimplementation\nend.\n")
(output / "c/GeneratedValue.c").write_text('#include "GeneratedValue.h"\nint nx_generated_value(void) { return NX_GENERATED_VALUE; }\n')
with (output / "producer-runs.txt").open("a") as counter:
    counter.write("generated\n")
