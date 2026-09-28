// The same cases as ios/VlogifyDesign/Tests/VlogifyEngineTests (InviteCodeTests,
// RoomRulesTests) and VlogifyContractTests/MarkTests, plus vectors printed by the Swift
// package itself. If a value here and a value there disagree, one side has drifted.

import { describe, expect, it } from "vitest";
import {
  ALPHABET, canJoin, capturesPerSlot, checkCharacter, clipLimit, generateInviteCode, isClipTooLong, isDayInWindow,
  isValidCapacity, isValidHour, isValidMark, normalizeCode, normalizedName, parseDayKey, parseInviteCode,
  randomInviteCode, type RoomType,
} from "../src/rules";
import { base64url } from "../src/util";

/// InviteCodeTests.Fixed: a 64-bit LCG, wrapping like Swift's &* and &+.
function fixed(): () => bigint {
  let state = 1n;
  return () => {
    state = (state * 6_364_136_223_846_793_005n + 1n) & 0xffff_ffff_ffff_ffffn;
    return state;
  };
}

describe("invite codes (InviteCodeTests)", () => {
  it("generates exactly what Swift generates from the same generator", () => {
    // `InviteCode.generate(using: &Fixed())` eight times, printed by the Swift package.
    const swift = ["EQCXTP", "KRS6FH", "4NJBG0", "HY7WDK", "A389PT", "ZM52V5", "01EQC4", "XTKRS7"];
    const next = fixed();
    expect(swift.map(() => generateInviteCode(next))).toEqual(swift);
  });

  it("a generated code round-trips through parsing, formatted and lowercased too", () => {
    const code = generateInviteCode(fixed());
    expect(code).toHaveLength(6);
    expect(parseInviteCode(code)).toBe(code);
    expect(parseInviteCode(`${code.slice(0, 3)}-${code.slice(3)}`)).toBe(code);
    expect(parseInviteCode(code.toLowerCase())).toBe(code);
  });

  it("a single-character typo is rejected", () => {
    const code = generateInviteCode(fixed());
    const typo = code.slice(0, 2) + (code[2] === "7" ? "8" : "7") + code.slice(3);
    expect(parseInviteCode(typo)).toBeNull();
  });

  it("confusable letters map back: I and L to 1, O to 0", () => {
    expect(normalizeCode("o1i-lab")).toBe("0111AB");
    expect(normalizeCode("ab cd ef")).toBe("ABCDEF");
    // Swift uppercases ß to SS, and so does JavaScript.
    expect(normalizeCode("ßx")).toBe("SSX");
  });

  it("too short, too long, and junk are all null", () => {
    expect(parseInviteCode("ABC")).toBeNull();
    expect(parseInviteCode("ABCDEFG")).toBeNull();
    expect(parseInviteCode("!!!!!!")).toBeNull();
  });

  it("codes never contain the dropped letters", () => {
    const next = fixed();
    for (let i = 0; i < 200; i++) expect(generateInviteCode(next)).not.toMatch(/[ILOU]/);
    for (let i = 0; i < 50; i++) expect(randomInviteCode()).toMatch(/^[0-9ABCDEFGHJKMNPQRSTVWXYZ]{6}$/);
  });

  it("check characters match Swift's for known bodies", () => {
    // Printed by the Swift package: the one valid check character for each body.
    const vectors: Record<string, string> = { REV1E: "F", V10G5: "P", "00000": "0", ZZZZZ: "H", AB3K7: "R" };
    for (const [bodyText, check] of Object.entries(vectors)) expect(checkCharacter(bodyText)).toBe(check);
    expect(ALPHABET).toHaveLength(32);
  });
});

describe("room rules (RoomRulesTests)", () => {
  it("capacity validation per type", () => {
    const cases: [RoomType, number, boolean][] = [
      ["log", 1, false], ["log", 2, true], ["log", 20, true], ["log", 21, false],
      ["stack", 40, true], ["stack", 41, false], ["vlog", 1, true], ["vlog", 2, false], ["zip", 2, true],
    ];
    for (const [type, capacity, valid] of cases) expect(isValidCapacity(capacity, type), `${type} ${capacity}`).toBe(valid);
  });

  it("logs are two seconds and one take; vlogs are unlimited", () => {
    expect(clipLimit("log")).toBe(2.0);
    expect(clipLimit("vlog")).toBeNull();
    expect(capturesPerSlot("log")).toBe(1);
    expect(capturesPerSlot("vlog")).toBeNull();
    // MockBackend: `Double(clip.durationMs) > limit * 1_000 + 250`.
    expect(isClipTooLong("log", 2250)).toBe(false);
    expect(isClipTooLong("log", 2251)).toBe(true);
    expect(isClipTooLong("vlog", 600_000)).toBe(false);
  });

  it("names are trimmed, capped, and optional", () => {
    expect(normalizedName("   ")).toBeNull();
    expect(normalizedName("  lololol testing ")).toBe("lololol testing");
    expect(normalizedName("a".repeat(40))).toHaveLength(24);
  });

  it("a room is joinable until it is at capacity", () => {
    expect(canJoin(2, 3)).toBe(true);
    expect(canJoin(3, 3)).toBe(false);
  });
});

describe("days and hours (DayClock)", () => {
  it("parses only zero-padded real dates", () => {
    expect(parseDayKey("2026-09-11")).toEqual({ year: 2026, month: 9, day: 11 });
    expect(parseDayKey("2026-9-11")).toBeNull();
    expect(parseDayKey("2026-02-31")).toBeNull();
    expect(parseDayKey("2026-13-01")).toBeNull();
  });

  it("slot hours run 4...27", () => {
    expect(isValidHour(4)).toBe(true);
    expect(isValidHour(27)).toBe(true);
    expect(isValidHour(3)).toBe(false);
    expect(isValidHour(28)).toBe(false);
    expect(isValidHour(4.5)).toBe(false);
  });

  it("the posting window reaches back as far as clip copies live, and a day ahead", () => {
    const at = new Date("2026-09-28T12:00:00Z");
    expect(isDayInWindow("2026-09-28", at, 7)).toBe(true);
    expect(isDayInWindow("2026-09-29", at, 7)).toBe(true);
    expect(isDayInWindow("2026-09-30", at, 7)).toBe(false);
    expect(isDayInWindow("2026-09-20", at, 7)).toBe(true);
    expect(isDayInWindow("2026-09-19", at, 7)).toBe(false);
  });
});

describe("marks (MarkTests)", () => {
  it("accepts every sample mark exactly as Swift encodes it", () => {
    // `Mark.sample(0...3).encoded`, printed by the Swift package.
    const samples = [
      "AR3bgNmU0qfHubnHp9KU2YDba9lY0kbHOLktpyaUJIAmay1YOEZGOFgtayZ_JJQmpy25OMdG0ljZa9t_AWFrAZ5rDaaRo5meoJilkKqIrICtd6xvqmelYaBcmVmR",
      "AQaAH7vXHmXhZUTXfx8",
      "AT2AgIGAgoGDg4OFgoiAinyLeYt1inGIbYRrgGp6a3RtbXJoeGSAYYhgkGKZZqBtpXWof6mKppagoJepjK-As3KyZK9Yp02cRo9CgENvSF9RUV1FbTx_OJI5pT-2ScNYzWvRf9CVyaq9vazMl9eA22faUNI7xCqxH5kZgA",
      "AQMzgIAuzIAER3BH1rjWuHAEcNZwo4-jj9Y",
    ];
    for (const sample of samples) expect(isValidMark(sample)).toBe(true);
  });

  it("refuses malformed wire strings", () => {
    const b = (bytes: number[]) => base64url(new Uint8Array(bytes));
    expect(isValidMark("")).toBe(false);
    expect(isValidMark("!!!!")).toBe(false);
    expect(isValidMark(b([2, 1, 10, 10]))).toBe(false); // version 2
    expect(isValidMark(b([1, 5, 10, 10]))).toBe(false); // claims more points than it holds
    expect(isValidMark(b([1, 0]))).toBe(false); // zero-length stroke
    expect(isValidMark(b([1]))).toBe(false); // no strokes
    expect(isValidMark("A".repeat(1801))).toBe(false);
    expect(isValidMark(b([1, 1, 10, 10]))).toBe(true); // one dot
  });

  it("holds the stroke and point caps", () => {
    const strokes = (count: number, points: number) => {
      const bytes = [1];
      for (let s = 0; s < count; s++) {
        bytes.push(points);
        for (let p = 0; p < points; p++) bytes.push(p % 256, s % 256);
      }
      return base64url(new Uint8Array(bytes));
    };
    expect(isValidMark(strokes(64, 1))).toBe(true);
    expect(isValidMark(strokes(65, 1))).toBe(false);
    expect(isValidMark(strokes(4, 160))).toBe(true); // 640 points
    expect(isValidMark(strokes(5, 129))).toBe(false); // 645 points
  });
});
