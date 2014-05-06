import "io"

let twotimes(x) be
{ let sptr, prev;
  if x = 0 then resultis 0;
  prev := twotimes(x-1);
  resultis prev+2 }

let start() be {
    outs("Hello, World!\n");
    out("%d\n", twotimes(50));
    return }
