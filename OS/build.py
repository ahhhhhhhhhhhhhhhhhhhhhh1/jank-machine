import subprocess
import os

# File names
boot_src = "boot.asm"
stage2_src = "boot2.asm"
boot_bin = "boot.bin"
stage2_bin = "boot2.bin"
final_bin = "full.bin"

# NASM executable (make sure nasm.exe is in PATH)
nasm_exe = "nasm"

# Assemble bootloader
print("Assembling bootloader...")
subprocess.run([nasm_exe, "-f", "bin", boot_src, "-o", boot_bin], check=True)

# Assemble stage2
print("Assembling stage2...")
subprocess.run([nasm_exe, "-f", "bin", stage2_src, "-o", stage2_bin], check=True)

# Make sure bootloader is 512 bytes (pad if needed)
boot_size = os.path.getsize(boot_bin)
if boot_size < 512:
    print(f"Padding bootloader ({boot_size} bytes) to 512 bytes...")
    with open(boot_bin, "ab") as f:
        f.write(b'\x00' * (512 - boot_size))
elif boot_size > 512:
    raise ValueError("Bootloader exceeds 512 bytes!")

# Combine into single binary
print("Combining bootloader + stage2 into full.bin...")
with open(final_bin, "wb") as f:
    with open(boot_bin, "rb") as b:
        f.write(b.read())
    with open(stage2_bin, "rb") as s:
        f.write(s.read())

print("Done! Generated:", final_bin)
