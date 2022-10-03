open Batteries
open Uref

module Var = struct
  let count = ref (-1)
  let fresh () = incr count; !count

  type 'a t = 
    | Int
    | Char
    | Var of int
    | Fun of 'a * 'a
  
  let rec unify f r = 
    unite ~sel:begin fun t0 u0 -> match t0, u0 with
      | Fun (i0, o0) as g, Fun (i1, o1) -> 
        f i0 i1; 
        f o0 o1; 
        g
      | x, Var _ | Var _, x -> x
      | x, y when x = y -> x
      | _, _ -> 
        Printf.sprintf "type error" |> failwith
    end r
end

module MakeStack () = struct
  let count = ref (-1)
  let fresh () = incr count; !count

  type 'a t = 'a _t uref
  and 'a _t = 
    | Seq of 'a uref * 'a t
    | Bot of int
  
  let rec unify f r = 
    unite ~sel:begin fun a0 b0 -> match a0, b0 with
      | Bot _ as s, Bot _ -> s
      | Seq _ as s, Bot _ | Bot _, (Seq _ as s) -> s
      | Seq (t, a) as s, Seq (u, b) -> 
        f t u; 
        unify f a b; 
        s
    end r
end

module Stack = MakeStack ()
module Costack = MakeStack ()

type t = T of t Var.t Stack.t Costack.t

(* let _unify f = Costack.unify (Stack.unify (Var.unify f)) *)

(* let _unify f (T u) = Costack.unify (Stack.unify (Var.unify f)) u *)

type u = U of u Var.t Stack.t
let _unify f (U u) (U v) = Stack.unify (Var.unify f) u v
let rec unify u v = _unify unify u v



(* let rec unify u v =
  Costack.unify (Stack.unify (Var.unify unify)) u v *)