import "io"
import "fsutils"
import "tape"

manifest
{ iv_none = 0,        iv_memory = 1,      iv_pagefault = 2,   iv_unimpop = 3,
  iv_halt = 4,        iv_divzero = 5,     iv_unwrop = 6,      iv_timer = 7,
  iv_privop = 8,      iv_keybd = 9,       iv_badcall = 10,    iv_pagepriv = 11,
  iv_debug = 12,      iv_intrfault = 13 }

let ivec = table 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

let set_handler(int, fn) be
  if int >= 0 /\ int <= 13 then
    ivec ! int := fn

let int_enable() be
  assembly
  { LOAD  R1, [<ivec>]
    SETSR R1, $INTVEC
    LOAD  R1, 0
    SETFL R1, $IP }

let int_disable() be
  assembly
  { LOAD  R1, 1
    SETFL R1, $IP }

let otherhandler(intcode, address, info) be
{ out("interrupt %d (%x, %d)\n", intcode, address, info);
  ireturn }

let halthandler(intcode, address, info) be
{ out("(exit)\n");    // this is where the process would be deleted
  assembly
  { halt } }

let getpage(x) be
{ static { nextfreepage = 0, lastfreepage = 0 }
  test numbargs() > 0 then
  { let firstfreeword = ! 0x101;
    let lastexistingword = (! 0x100) - 1;
    nextfreepage := (firstfreeword + 2047) >> 11;
    lastfreepage := lastexistingword >> 11;
    out("first free page = %d = 0x%x\n", nextfreepage, nextfreepage);
    out("last free page = %d = 0x%x\n", lastfreepage, lastfreepage); }
  else
  { let p = nextfreepage;
    if p > lastfreepage then
      resultis -1;
    nextfreepage +:= 1;
    resultis p << 11 } }

let pfhandler(intcode, address, info, pc) be   // A TRICK
{ let ptn, pn, pdiraddr, pdentry, ptaddr, ptentry, newentry;
  out("page fault for VA 0x%x\n", address);
  ptn := address >> 22;
  pn := (address >> 11) bitand 0x7FF;          // eleven ones
  assembly
  { getsr  r1, $pdbr
    store  r1, [<pdiraddr>]
    add    r1, [<ptn>]
    phload r2, r1
    store  r2, [<pdentry>] }
  out("  page table 0x%x = %d\n", ptn, ptn);
  out("  page 0x%x = %d\n", pn, pn);
  out("  pdbr = 0x%x (page %d + %d)\n", pdiraddr, pdiraddr >> 11, pdiraddr bitand 0x7FF);
  out("  pd entry = 0x%x\n", pdentry);
  if pdentry = 0 then
  { outs("invalid page directory entry\n");
    assembly { halt } }
  ptaddr := pdentry bitand bitnot 0x7FF;
  assembly
  { load   r1, [<ptaddr>]
    add    r1, [<pn>]
    phload r2, r1
    store  r2, [<ptentry>] }
  out("  pt entry = 0x%x\n", ptentry);
  if ptentry <> 0 then
  { outs("unexpected reason\n");
    assembly { halt } }
  newentry := getpage();
  out("  using page %d\n", newentry >> 11);
  newentry bitor:= 1;
  assembly
  { load    r1, [<ptaddr>]
    add     r1, [<pn>]
    load    r2, [<newentry>]
    phstore r2, r1 }
  pc -:= 1;
  ireturn }

let printmemmap(pdpn) be
{ let pdaddr = pdpn << 11;
  out("pp %d:\n", pdpn);    // pp = physical page
  for ptn = 0 to 1023 do
    if pdaddr ! ptn <> 0 then
    { let ptppn = (pdaddr ! ptn) >> 11;
      let ptaddr = ptppn << 11;
      out("  %d: pp %d for VAs 0x%x to 0x%x:\n", ptn, ptppn, ptn << 22, ((ptn+1) << 22)-1);
      for pn = 0 to 2047 do
        if ptaddr ! pn bitand 1 then
        { let pppn = (ptaddr ! pn) >> 11;
          let baseva = (ptn << 22) + (pn << 11);
          out("    %d: pp %d for VAs 0x%x to 0x%x:\n", pn, pppn, baseva, baseva+2047); } } }

let start2() be
{ let pdir, ptabusr, ptabusrstk, ptabsysstk;
  let sysstkpage;
  let lastusedpage = ((! 0x101) - 1) >> 11;
  let func, page;
  getpage("setup!");
  pdir := getpage();
  ptabusr := getpage();
  ptabusrstk := getpage();
  ptabsysstk := getpage();
  sysstkpage := getpage();

  set_handler(iv_pagefault, pfhandler);
  set_handler(iv_halt, halthandler);
  int_enable();

  for i = 0 to 2047 do
  { pdir       ! i := 0;
    ptabusr    ! i := 0;
    ptabsysstk ! i := 0;
    ptabusrstk ! i := 0;
    ptabsysstk ! i := 0 }

  pdir ! 0   := ptabusr bitor 1;
  pdir ! 511 := ptabusrstk bitor 1;
  pdir ! 767 := ptabsysstk bitor 1;

  for pn = 0 to lastusedpage do
    ptabusr ! pn := (pn << 11) bitor 1;

  ptabusrstk ! 2047 := 0x7FFFF801;
  ptabsysstk ! 2047 := sysstkpage bitor 1;

  page := (pdir ! 0) + 0x400;
  load_program("test.exe", page);

  printmemmap(pdir >> 11);

  outs("Dangerous place\n");
  assembly
  { store  sp, r2
    store  fp, r3
    load   sp, 0xFFFF
    loadh  sp, 0xBFFF
    load   r1, [<pdir>]
    setsr  r1, $pdbr
    getsr  r1, $flags
    sbit   r1, $vm
    cbit   r1, $sys
    flagsj r1, pc
    load   sp, r2
    load   fp, r3 }

  func := getfn(0x400);
  func();
}

let dop(exes) be {
  let addr = dop + 2000;
  if load_program(exes, addr) = false then return;
  addr := getfn(addr);
  addr();
}

let start() be {
  manifest { maxs = 128 }
  let buf = vec maxs;

  {
    out("$ ");
    ins(buf, maxs);

    test strcmp(buf, "") then {
      finish;
    } else {
      dop(buf);
    }

  } repeat;
}