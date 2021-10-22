* Boot a custom ROMs using (Super)GoldCard
* This code should be followed by the 48K image of the ROM to be used
* e.g. base=ALCHP(50000)
*      LBYTES customboot_bin,a
*      LBYTES custom_rom_code,a+FLEN(customboot_bin)
*      CALL a
* It works by first copying the whole code to a safe RAM area at $80000,
* then swapping in the GC boot ROM at $C000 (and $4C000), and then copying
* the ROM image to the ROM area, which on the (S)GC is in fact RAM, except
* for the first two longwords (the SSP and PC boot vectors).
* Credits to Marcel Kilgus for exploring the mysteries of the (S)GC.
* This has been tested on a GoldCard with version 2.49 ROM. Other versions
* may not work because the address to be jumped to ($C064) may be different
* (it should be just after the GC's ROM to shadow RAM copy loop).

* Revision history:
*
* 20211022  JB  Reworked relocation code, no relocation if code is already in
*               safe RAM. Fixed potential bugs in 68020 handling code.
* 20210429  JB  First release

glk_bas0 equ      $1c000            ; base of (S)GC I/O area
glo_rdis equ      $64               ; RAM disable (offset)
sgo_scr2 equ      $68               ; SGC second screen disable (write)
glo_ptch equ      $200              ; patch area offset

safe_ram equ      $50000            ; safe RAM location not affected by ROM swap-in

*----------------------------------------------------------------
* You may have to modify this depending on the (S)GC ROM version!
* The value used here is valid for v2.49
* See the README.md file for details

glr_entr equ      $c064

*----------------------------------------------------------------

;         org      $80000            ; obsolete
         section  code              ; use relocatable code now

base     trap     #0                ; supervisor mode
         move.w   #$3700,SR         ; disable interrupts
         lea      start,a0          ; start of boot code
         lea      safe_ram,a1       ; temporary location in RAM
         move.l   a0,a2             ; preset boot address
         cmpa.l   a0,a1             ; is start above safe_ram?
         bls.s    do_reset          ; yes, it's in safe memory
         move.l   a1,a2             ; boot from copied code
         move.l   #custrom-start+$c000,d0 ; bytes to move
         adda.l   d0,a0             ; copy from end
         adda.l   d0,a1
cpy_up   move.l   -(a0),-(a1)       ; copy to safe_ram
         subq.w   #4,d0
         bhi      cpy_up
do_reset move.w   sr,d1
         btst     #12,d1            ; test for 68020
         beq.s    no_cache          ; skip if lower
         moveq    #9,d0
         dc.l     $4e7b0002         ; clear and enable cache
no_cache jmp      (a2)              ; now jump to start (either next
                                    ; instruction or in safe_ram)

start    lea      glk_bas0,a6       ; base of GC I/O
         sf       glo_rdis(a6)      ; ensure ROM paged in
         moveq    #0,d6
         moveq    #2,d7             ; for GC
;         move.w   sr,d1            ; obsolete now
         bclr     #12,d1            ; test for 68020
         beq.s    do_copy           ; no 68020
         move.w   d1,sr             ; reset MSP bit
;         moveq    #9,d0             ; already done!
;         dc.l     $4e7b0002         ; clear and enable cache
         sf       sgo_scr2(a6)      ; disable second screen
         movem.l  glo_ptch(a6),d0-d7 ; wait?
         move.l   #$28480,sp        ; set SSP
         moveq    #$20,d6           ; set for 68020
         moveq    #0,d7
do_copy  lea      custrom,a4        ; base of custom ROM
         move.l   a4,a0
         suba.l   a1,a1
         move.w   #$c000/4-1,d0
rom2ram  move.l   (a0)+,(a1)+       ; copy to ROM area
         dbra     d0,rom2ram

; NB: A4 keeps pointing to our custom ROM image in RAM, so the patch code in
; the (S)GC ROM will use the boot vector of this image rather than the original
; ROM's boot vector which is write-protected. However, this will ONLY work on
; later SGC ROMs which are compatible with both SGC and GC!

         lea      $c000,a1          ; set A1 for GC boot code
         jmp      glr_entr          ; let GC ROM patch ROM code and boot it!

custrom  equ      *                 ; should start hereafter

         end

