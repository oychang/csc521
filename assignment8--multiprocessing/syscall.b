import "io"

// manifest declarations of all sys calls being set up
manifest
{ sys_datetime = 1,	sys_shutdown = 2 }


let callsysc(code, arg1) be
{ let thecode = code, ptr = @code;
  ptr ! 0 := numbargs() - 1;
  assembly
  { load r1, [<ptr>]
    syscall r1, [<thecode>] }
  resultis ptr ! 0 }

let time() = callsysc(sys_datetime)
let shutdown() = callsysc(sys_shutdown)

let sysc1 (code, reg_num, reg_val) be
{ let v1, buf = vec 2;
  datetime2(buf);
  v1 := buf ! 1;
  reg_val ! 0 := (selector 5 : 27 from v1) * 100;
  reg_val ! 0 +:= selector 6 : 21 from v1;
  out("sysc1: The compacted time is: %d\n", reg_val ! 0);
  ireturn }

let sysc2 (code, reg_num, reg_val) be
{ out("Halting the system!\n");
  assembly
  { halt } }

// sets up cgv, also installs all of the syscall functions
let setup_syscalls(cgv) be
{ cgv ! 0 := 0;
  cgv ! sys_datetime := sysc1;
  cgv ! sys_shutdown := sysc2;
  assembly
  { load	r1, [<cgv>]
    setsr	r1, $cgbr
    load	r1, 3
    setsr	r1, $cglen } } 

let start() be
{ let cgv = vec 10, x;
  setup_syscalls(cgv);
  x := time();
  out("start: The compacted time is: %d\n", x);
  shutdown() }