#!/usr/bin/env python3
"""Shared runway material eligibility, including explicitly named asphalt concrete."""
from screen_group4 import surface_type as _original

def surface_type(value):
    normalized="".join((value or "").strip().strip(chr(39)+chr(34)).upper().split())
    if normalized=="ASPHALTCONCRETE":
        return "ELIGIBLE_LABEL"
    return _original(value)
