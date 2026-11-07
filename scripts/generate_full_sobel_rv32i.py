"""Generate an exact RV32I program for full 256x256 Cameraman Sobel."""

from pathlib import Path

# Kept local so the generator is standalone when copied to another project.
def r(f7, rs2, rs1, f3, rd): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33
def i(imm, rs1, f3, rd, opcode): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode
def s(imm, rs2, rs1, f3): return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | 0x23
def b(imm, rs2, rs1, f3): return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63
def u(imm, rd): return (imm & 0xFFFFF000) | (rd << 7) | 0x37
def j(imm, rd): return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F

code, labels = [], {}
def emit(name, *args): code.append((name, args))
def label(name): labels[name] = len(code) * 4

# x10: input-row start (0x00000); x11: output pointer (0x40000)
# x12/x14: remaining rows/columns; x13: current window top-left.
emit("addi", 10, 0, 0)
emit("lui", 11, 0x40000)
emit("addi", 12, 0, 254)
label("outer_loop")
emit("add", 13, 10, 0)
emit("addi", 14, 0, 254)
label("inner_loop")
# x24/x25 point to the middle/bottom rows. This avoids illegal >2047 LW offsets.
emit("addi", 24, 13, 1024)
emit("addi", 25, 24, 1024)
for rd, base, offset in ((1,13,0), (2,13,4), (3,13,8), (4,24,0), (6,24,8), (7,25,0), (8,25,4), (9,25,8)):
    emit("lw", rd, base, offset)
for rd, rs1, rs2 in ((17,3,1), (18,6,4), (18,18,18), (19,9,7), (17,17,18), (20,17,19),
                     (17,7,1), (18,8,2), (18,18,18), (19,9,3), (17,17,18), (21,17,19)):
    emit("sub" if (rd,rs1,rs2) in ((17,3,1),(18,6,4),(19,9,7),(17,7,1),(18,8,2),(19,9,3)) else "add", rd, rs1, rs2)
emit("blt", 20, 0, "neg_gx"); emit("add", 15, 20, 0); emit("jal", 0, "gx_done")
label("neg_gx"); emit("sub", 15, 0, 20)
label("gx_done"); emit("blt", 21, 0, "neg_gy"); emit("add", 16, 21, 0); emit("jal", 0, "gy_done")
label("neg_gy"); emit("sub", 16, 0, 21)
label("gy_done")
emit("add", 22, 15, 16); emit("sw", 22, 11, 0)
emit("addi", 13, 13, 4); emit("addi", 11, 11, 4); emit("addi", 14, 14, -1); emit("bne", 14, 0, "inner_loop")
emit("addi", 10, 10, 1024); emit("addi", 12, 12, -1); emit("bne", 12, 0, "outer_loop")
label("done"); emit("jal", 0, "done")

def encode(pc, name, a):
    if name == "add": return r(0, a[2], a[1], 0, a[0])
    if name == "sub": return r(0x20, a[2], a[1], 0, a[0])
    if name == "addi": return i(a[2], a[1], 0, a[0], 0x13)
    if name == "lw": return i(a[2], a[1], 2, a[0], 0x03)
    if name == "sw": return s(a[2], a[0], a[1], 2)
    if name == "blt": return b(labels[a[2]] - pc, a[1], a[0], 4)
    if name == "bne": return b(labels[a[2]] - pc, a[1], a[0], 1)
    if name == "jal": return j(labels[a[1]] - pc, a[0])
    if name == "lui": return u(a[1], a[0])
    raise ValueError(name)

out = Path(__file__).resolve().parents[1] / "RTL" / "sobel_full"
out.mkdir(exist_ok=True)
words = [encode(index * 4, name, args) for index, (name, args) in enumerate(code)]
(out / "program.mem").write_text("\n".join(f"{word:08x}" for word in words) + "\n", encoding="ascii")
(out / "program_listing.txt").write_text("\n".join(f"{index*4:03x}: {word:08x}    {name} {', '.join(map(str, args))}" for index, ((name,args),word) in enumerate(zip(code,words))) + "\n", encoding="ascii")
print(f"Wrote {len(words)} instructions")
