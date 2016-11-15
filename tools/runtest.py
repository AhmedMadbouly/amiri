#!/usr/bin/env python

from __future__ import print_function

import sys
import os
import csv

import gi
gi.require_version('HarfBuzz', '0.0')
from gi.repository import HarfBuzz
from gi.repository import GLib

from fontTools.ttLib import TTFont

try:
    unicode
except NameError:
    unicode = str

try:
    bytes
except NameError:
    bytes = str

def toUnicode(s, encoding='utf-8'):
    return s if isinstance(s, unicode) else s.decode(encoding)

def toBytes(s):
    return s if isinstance(s, bytes) else s.encode()

HbFonts = {}
def getHbFont(fontname):
    if fontname not in HbFonts:
        font = open(fontname, "rb")
        data = font.read()
        font.close()
        blob = HarfBuzz.glib_blob_create(GLib.Bytes.new(data))
        face = HarfBuzz.face_create(blob, 0)
        font = HarfBuzz.font_create(face)
        upem = HarfBuzz.face_get_upem(face)
        HarfBuzz.font_set_scale(font, upem, upem)
        HarfBuzz.ot_font_set_funcs(font)

        HbFonts[fontname] = font

    return HbFonts[fontname]

TtFonts = {}
def getTtFont(fontname):
    if fontname not in TtFonts:
        font = TTFont(fontname)
        TtFonts[fontname] = font

    return TtFonts[fontname]

def runHB(direction, script, language, features, text, fontname, positions):
    font = getHbFont(fontname)
    buf = HarfBuzz.buffer_create()
    text = toUnicode(text)
    HarfBuzz.buffer_add_utf8(buf, text.encode('utf-8'), 0, -1)
    HarfBuzz.buffer_set_direction(buf, HarfBuzz.direction_from_string(toBytes(direction)))
    HarfBuzz.buffer_set_script(buf, HarfBuzz.script_from_string(toBytes(script)))
    if language:
        HarfBuzz.buffer_set_language(buf, HarfBuzz.language_from_string(toBytes(language)))

    if features:
        features = [HarfBuzz.feature_from_string(toBytes(fea))[1] for fea in features.split(',')]
    else:
        features = []
    HarfBuzz.shape(font, buf, features)

    info = HarfBuzz.buffer_get_glyph_infos(buf)
    ttfont = getTtFont(fontname)
    if positions:
        pos = HarfBuzz.buffer_get_glyph_positions(buf)
        glyphs = []
        for i, p in zip(info, pos):
            glyph = ttfont.getGlyphName(i.codepoint)
            if p.x_offset or p.y_offset:
                glyph += "@%d,%d" % (p.x_offset, p.y_offset)
            glyph += "+%d" % p.x_advance
            if p.y_advance:
                glyph += ",%d" % p.y_advance
            glyphs.append(glyph)
        out = "|".join(glyphs)
    else:
        out = "|".join([ttfont.getGlyphName(i.codepoint) for i in info])

    return "[%s]" % out

def runTest(test, font, positions):
    count = 0
    failed = {}
    passed = []
    for row in test:
        count += 1
        direction, script, language, features, text, reference = row
        text = text.encode().decode('unicode-escape') if '\\' in text else text
        result = runHB(direction, script, language, features, text, font, positions)
        if reference == result:
            passed.append(count)
        else:
            failed[count] = (direction, script, language, features, text, reference, result)

    return passed, failed

def initTest(test, font, positions):
    out = ""
    for row in test:
        direction, script, language, features, enctext, reference = row
        text = enctext.encode().decode('unicode-escape') if '\\' in enctext else enctext
        result = runHB(direction, script, language, features, text, font, positions)
        out += "%s;%s;%s\n" %(";".join(row[:4]), enctext, result)

    return out

if __name__ == '__main__':
    init = False
    positions = False
    args = sys.argv[1:]

    if len (sys.argv) > 2 and sys.argv[1] == "-i":
        init = True
        args = sys.argv[2:]

    if init is True:
        for testname in args:
            reader = csv.reader(open(testname), delimiter=';')
            test = []
            for row in reader:
                test.append(row)

            positions = os.path.splitext(testname)[1] == '.ptest'
            fontname = 'amiri-regular.ttf'
            outname = testname+".test"
            outfd = open(outname, "w")
            outfd.write(initTest(test, fontname, positions))
            outfd.close()
            sys.exit(0)

    styles = ('regular', 'bold', 'slanted', 'boldslanted')
    for style in styles:
        fontname = 'amiri-%s.ttf' % style
        print("   TEST\t%s" % fontname)
        for testname in args:
            positions = os.path.splitext(testname)[1] == '.ptest'

            if positions and style != "regular":
                continue

            reader = csv.reader(open(testname), delimiter=';')

            test = []
            for row in reader:
                test.append(row)

            passed, failed = runTest(test, fontname, positions)
            if failed:
                message = "%s: font '%s', %d passed, %d failed" %(os.path.basename(testname),
                        fontname, len(passed), len(failed))

                print(message)
                for test in failed:
                    print(test)
                    print("direction:\t", failed[test][0])
                    print("script:   \t", failed[test][1])
                    print("language: \t", failed[test][2])
                    print("features: \t", failed[test][3])
                    print("string:   \t", failed[test][4])
                    print("reference:\t", failed[test][5])
                    print("result:   \t", failed[test][6])
                sys.exit(1)
