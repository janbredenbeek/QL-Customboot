A Boot Loader for custom QL ROMs with the (Super-)Gold Card
===========================================================

Ever wanted to use Minerva on your JM or JS QL but have no EPROM programmer or just don't want to put your precious QL at risk for a hardware mod? Well, if you have a Miracle Systems (Super) Gold Card or a clone such as Tetroid, there is now a software solution for that. This 128-byte program lets you boot any compatible 48K ROM image on your (S)GC-equipped QL by just LRESPRing it. It doesn't make any permanent changes so when you press the RESET-button you're back again with your original ROM. Simple as that!

How it works
------------
Before I delve into details, let me give credits to Marcel Kilgus who spent many hours puzzling out the mysteries of the (S)GC boot sequence, including the paging in and out of ROM and RAM, patching the QL ROM and booting this patched version from the same place where it was before the (S)GC took over. In his [article](https://www.kilgus.net/2018/11/14/supergoldcard-boot-sequence/), he claims that the patched ROM area from $0000 to $BFFF is write-protected, which would prevent it from being replaced by a custom ROM. Fortunately, this is only partially true. In fact, only *the first 8 bytes* (containing the 68000's SSP and PC vectors at boot time) are write-protected. The remaining 49144 bytes are in fact RAM, even if they are shadowed by the QL or SGC ROM when the machine cold starts. Writing to this area will at any time modify the contents of the RAM, whether the ROM is paged in or not. Only the initial SSP and PC vectors are immutable, which is probably just as well as they are needed when the QL starts and it doesn't have a clue whether there is ROM or RAM at the bottom 48K!

Thus, it seems very easy to just load your own favourite ROM image using LBYTES myrom_bin,0 and boot it. Well, actually it's not that simple. First of all, you cannot just overwrite a running system without crashing it. Second, the machine needs to go through the *entire* boot sequence which involves patching the ROM contents to make it work with the additional hardware, and linking in the (S)GC extensions like the flp driver etc. This requires parts of the (S)GC ROM which are only available at boot time, so these have to be paged in first. They reside at $C000-$FFFF (GC), $0000-$FFFF (SGC) and $40000-$4FFFF (both GC and SGC). On a live system, these areas may be in use by system extensions or applications so we have to make sure that our code is in a safe place before we page in the ROMs (of course, after going into supervisor mode and disabling interrupts!). After some experimenting, I chose $50000 which is well into the (S)GC's fast RAM area (for some reason, $30000 didn't work, probably because it is shared with video RAM). Any location between $50000 and $1F0000 will probably do.

So we load our boot loader and ROM first using RESPR or ALCHP, then relocate it to the safe RAM at $50000, then copy our custom ROM to it's final place at the start and jump into the (S)GC's boot code just at the point where it normally has copied the ROM's contents to RAM and starts to patch it. Unfortunately this point isn't vectored and may be different for different versions of the (S)GC ROM. My Gold Card has version 2.49, which I believe is the latest version and is compatible with both Super- and non-Super versions. There are older versions around which only work in non-Super GC, and these will **not** work with this custom ROM boot code. Why not? Because the boot process changed with the introduction of the SGC. With a GC, the QL first boots its own ROM normally, then when it starts to scan for extension roms at $C000 the GC ROM takes over by copying the QL ROM to RAM, patching it and booting it a second time. With the Super-GC, the QL starts up with the SGC ROM in place of the QL ROM, which immediately starts copying and patching the QL ROM (which is now located at $400000) and boots it, so you only see the boot pattern once.

Now remember that the first 8 bytes in the 680x0's address space, which contain the boot SSP and PC vectors, are read-only. On the GC they will hold the boot vector belonging to the original QL ROM, and even after patching this remains the same. So after the patching, the GC ROM can just take the location of the boot vector at $0004 and jump to it. Not so on the SGC; it would enter the patched system ROM at the start location of the SGC ROM which will obviously be different and result in a crash. So, the boot code was changed to take the vectors at the start of the mirrored original QL ROM at $400000 when running on a SGC. In the code, this is pointed to by register A4 which at the start of the (S)GC boot code is set to either zero (GC) or $400000 (SGC). Now the trick is to let A4 point to our custom ROM code whilst still in RAM at $50000 and let the (S)GC ROM do the patching, after which it happily boots it from its boot vector. Unfortunately, older GC-only ROMs always take the boot vector from location $0004, which is read-only, so it's very likely that our custom ROM is entered at the wrong location and won't boot. Fixing this is possible, but needs a lot more code and even then the code would be dependent on the particular (S)GC ROM version. 

Usage
-----
Images for both QL ROMs and the (Super)GoldCard ROM v2.49 can be downloaded [here](https://dilwyn.qlforum.co.uk/qlrom/index.html). Bear in mind that the SGC ROM only supports a limited number of ROM versions, notably Sinclair's AH, JM, JS and MG (with international variants), and Minerva. The ROM image must be EXACTLY 48K since the space immediately after it is occupied by the SGC ROM's boot code at startup. If you get a message 'QL ROM version is not recognised! Please contact Miracle Systems', your particular ROM version is not supported (obviously, it will be of no use to contact Miracle Systems since they went out of business in 2004). Please note the copyright notice at the top of the download page mentioned, the original Sinclair ROMs may be used freely in Europe whilst Minerva has been released under the GPL.

As mentioned, the boot loader binary is just 128 bytes long. It expects the 48K ROM image to immediately follow its code, so you can boot your ROM with the following commands:

```
a=RESPR(50000)
LBYTES customboot_bin,a
LBYTES your_favourite_rom,a+128
CALL a
```
If you want to save the boot loader along with your ROM, you can do so by entering SBYTES your_rom_bin,a,49280. You can then simply boot the ROM using LRESPR your_rom_bin.

Caveats
-------
As mentioned, the current version has only been tested with a Gold Card with firmware version 2.49. A Super Gold Card from Tetroid with this version has been reported to work too with v2 (20211022).

Other (S)GC firmware versions may or may not work depending on where the code which patches the QL ROM starts. In v2.49, this is at $C064, just after the DBRA D0,rom_to_ram loop which copies the QL ROM to RAM (see the boot.asm file in the article from Marcel Kilgus mentioned above). Versions which only support the non-super Gold Card will probably not work for reasons mentioned earlier.

If you have a non-super Gold Card, DO NOT try to use memory cut facilities which issue a soft reboot of the QL, such as RES_128 or Minerva's CALL 390. These commands reboot the QL by reading the boot vector at the write-protected location $0004, which still points to the start location of the original QL ROM rather than the ROM we have loaded, so it's very likely to crash the machine. On the Super Gold Card, these commands will probably cause a reset to occur, returning you to the original QL ROM.

Building
--------
If you need to build your own version of the boot loader, use the GST or Quanta assembler with -NOLINK option. Versions 20211022 and later are position-independent and do no longer need to be linked separately.

The assembler can be downloaded from [this](https://dilwyn.qlforum.co.uk/asm/index.html) page.
