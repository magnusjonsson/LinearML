(*
Copyright (c) 2011, Julien Verlaguet
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the
distribution.

3. Neither the name of Julien Verlaguet nor the names of
contributors may be used to endorse or promote products derived
from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)
open Utils
open Ist
open Est

let n = ref 0
let space() = 
  let rec aux n = if n = 0 then () else (o " " ; aux (n-1)) in
  aux !n

let nl() = o "\n" ; space()

let push() = n := !n + 2 
let pop() = n := !n - 2
  
let id x = o (Ident.debug x)
let label x = o (Ident.debug x) 
let pstring x = o x

let rec program mdl = 
  List.iter module_ mdl

and module_ md = 
  o "module " ;
  id md.md_id ;
  o " = struct" ;
  push() ;
  nl() ;
  List.iter def md.md_defs ;
  pop() ;
  o "end" ;
  nl()

and def df = 
  id df.df_id ; 
  o " " ; 
  ty_idl df.df_args ;
  o " returns " ; 
  ty_idl df.df_return ;
  o " = " ;
  push() ;
  List.iter block df.df_body ;
  pop() ;
  nl() ; nl() ;

and type_expr = function
  | Tany -> o "void*"
  | Tvar x -> id x
  | Tprim tp -> type_prim tp
  | Tid x -> id x 
  | Tapply (x, tyl) -> o "(" ; type_expr_list tyl ; o ") " ; id x
  | Tfun (k, tyl1, tyl2) -> 
      type_expr_list tyl1 ;
      o (match k with Ast.Cfun -> " #" | Ast.Lfun -> " ") ;
      o "-> " ;
      type_expr_list tyl2 

and type_expr_list l = 
  print_list o (fun _ x -> type_expr x) ", " l

and type_prim = function
  | Tunit -> o "unit"
  | Tbool -> o "bool"
  | Tchar -> o "char"
  | Tint  -> o "int"
  | Tfloat -> o "float"
  | Tstring -> o "string"
  
and pat pl = print_list o pat_el ", " pl
and pat_el _ p = pat_ (snd p)
and pat_ = function
  | Pany -> o "_"
  | Pid x -> id x 
  | Pvariant (x, p) -> id x ; o "(" ; pat p ; o ")"
  | Precord (ido, pfl) -> 
      o "{ " ; maybe id ido ; List.iter pfield pfl ; o " }"
  | Pas (x, p) -> o "(" ; id x ; o " as " ; pat_ (snd p) ; o ")"

and pfield (x, p) = 
  id x ; o " = " ; pat p ; o " ; "

and idl = List.iter (fun (_, x) -> id x ; o " ")
and ty_idl l = 
  List.iter (
  fun (ty, x) -> o "(" ; id x ; o ": " ; type_expr ty ; o ") "
 ) l

and block bl = 
  nl() ;
  id bl.bl_id ;
  o ":" ;
  nl() ;
  push() ; 
  nl() ;
  if bl.bl_phi <> [] then (o "phi: " ; nl() ; List.iter phi bl.bl_phi ; nl()) ;
  List.iter equation bl.bl_eqs ;
  (match bl.bl_ret with
  | Lreturn l -> (o "lreturn " ; List.iter (fun (_, x) -> id x ; o " ") l)  ;
  | Return (tail, l) -> 
      (o "return[" ; 
       if tail then o "true] " else o "false] " ;
       List.iter (fun (_, x) -> id x ; o " ") l)  ;
  | Jump x -> o "jump " ; id x
  | If (x, l1, l2) ->
      o "Iif " ; tid x ; o " then jump " ; label l1 ; 
      o " else jump " ; label l2 ;
  | Match (xl, al) -> 
      o "match " ; idl xl ; push() ; nl() ; List.iter maction al ; pop()

  ) ;
  pop() ;
  nl()

and phi (x, _, l) = 
  id x ; o " <- " ; 
  List.iter (fun (x, lbl) -> o "(" ; id x ; o ", " ; label lbl ; o ") ; ") l ;
  nl()

and equation (idl, e) = 
  ty_idl idl ;
  o " = " ;
  expr e ;
  nl()

and expr = function
  | Enull -> o "null"
  | Eid x -> tid x
  | Evalue v -> value v
  | Evariant (x, ty_idl) -> id x ; o "(" ; idl ty_idl ; o ")"
  | Ebinop (bop, id1, id2) -> binop bop ; o " " ; tid id1 ; o " " ; tid id2 
  | Euop (uop, x) -> unop uop ; o " " ; tid x
  | Erecord fdl -> o "{" ; List.iter field fdl ; o "}"
  | Ewith (x, fdl) -> o "{" ; tid x ; List.iter field fdl ; o "}" 
  | Efield (x, y) -> tid x ; o "." ; id y
  | Ematch (xl, al) -> 
      o "match " ; idl xl ; push() ; nl() ;List.iter action al ; pop()
  | Eapply (fk, x, l) -> 
      o "call[" ; 
      o (match fk with Ast.Cfun -> "C] " | Ast.Lfun -> "L] ") ;
      tid x ; o " " ; idl l
  | Eseq _ -> failwith "TODO seq"
  | Ecall x -> o "lcall " ; o (Ident.debug x)
  | Eif (x, l1, l2) -> 
      o "if " ; tid x ; o " then lcall " ; label l1 ; 
      o " else lcall " ; label l2 
  | Eis_null x -> o "is_null " ; id (snd x)
  | Efree x -> o "free " ; id (snd x)
  | Eget (x, y) -> o "get " ; id (snd x) ; id (snd y)
  | Eset (x, y, z) -> o "set " ; id (snd x) ; id (snd y) ; id (snd z)
  | Eswap (x, y, z) -> o "swap " ; id (snd x) ; id (snd y) ; id (snd z)
  | Epartial (f, e) -> o "partial " ; id (snd f) ; ty_idl e

and field (x, l) = id x ; o " = " ; idl l
and action (p, e) = 
  pat p ; o " -> " ; expr e ; nl()

and maction (p, lbl) = 
  pat p ; o " -> jump " ; id lbl ; nl()

and tid (_, x) = id x

and value = function
  | Ist.Eunit -> o "unit"
  | Ist.Ebool b -> o (string_of_bool b) 
  | Ist.Eint x -> o x
  | Ist.Efloat x -> o x
  | Ist.Echar x -> o x
  | Ist.Estring x -> o x

and binop = function 
  | Ast.Eeq -> o "eq"
  | Ast.Ediff -> o "diff"
  | Ast.Elt -> o "lt"
  | Ast.Elte -> o "lte"
  | Ast.Egt -> o "gt"
  | Ast.Egte -> o "gte"
  | Ast.Eplus -> o "plus"
  | Ast.Eminus -> o "minus"
  | Ast.Emod -> o "mod"
  | Ast.Estar -> o "star"
  | Ast.Ediv -> o "div"
  | Ast.Eand -> o "and"
  | Ast.Eor -> o "or"

and unop = function
  | Ast.Euminus -> o "uminus"
