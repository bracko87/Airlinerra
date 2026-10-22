#!/usr/bin/env python3
"""Shared runway material eligibility, including FAA surface composition/condition codes.

FAA Chart Supplement legend: PEM=part concrete/part asphalt; -G/F/P
are runway surface condition (good/fair/poor), not grass. -GRVD is
grooved surface treatment. Do not infer that generic 'paved', 'BITUM',
'hard', or unrelated airport codes are paved. See FAA Order 5010.4.
"""
from __future__ import annotations
import re
from screen_group4 import surface_type as _original

FAA_SURFACE_CONDITION = re.compile(
    r"^(?:ASP|ASPH|CON|CONC)(?:-(?:G|F|P|GRVD))$"
    r"|^(?:ASP|ASPH|CON|CONC)-(?:ASP|ASPH|CON|CONC)-(?:G|F|P|GRVD)$"
)

def surface_type(value):
    normalized="".join((value or "").strip().strip(chr(39)+chr(34)).upper().split())
    if normalized in {"ASPHALTCONCRETE", "PEM"}:
        return "ELIGIBLE_LABEL"
    if FAA_SURFACE_CONDITION.fullmatch(normalized):
        return "ELIGIBLE_LABEL"
    return _original(value)
