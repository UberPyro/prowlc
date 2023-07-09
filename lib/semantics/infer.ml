open! Batteries
open Uref

open Syntax
open System
module Tast = Ast.Make(struct type t = fn[@@deriving show] end)
open Tast

open Util
open Ull

let inspect i o i_final o_final = 
  let arg, argcos = usplit i in
  let res, rescos = usplit o in
  match argcos, rescos with
  | None, _ | _, None -> failwith "Void sequence passed to dataflow"
  | Some ka, Some kr when ka = kr -> 
    ujoin i_final arg, ujoin o_final res
  | _ -> failwith "Insufficiently specific data passed to dataflow"

let inspect_biased disj conj disj_final = 
  let disj_list, disj_key = usplit disj in
  let _, conj_key = usplit conj in
  match disj_key, conj_key with
  | None, _ | _, None -> failwith "Void seq passed to dataflow [biased]"
  | Some kd, Some kc when kd = kc -> ujoin disj_final disj_list
  | _ -> failwith "Insufficiently specific data passed to dataflow [biased]"

let inspect_nested i o i_final o_final = 
  let arg, argcos = usplit i in
  let res, rescos = usplit o in
  match argcos, rescos with
  | None, _ | _, None -> failwith "Void sequence passed to dataflow"
  | Some ka, Some kr when ka = kr -> 
    map_hd (fun x -> ujoin x arg) i_final, 
    map_hd (fun x -> ujoin x res) o_final
  | _ -> failwith "Insufficiently specific data passed to dataflow"

let inspect_nested_biased disj conj disj_final = 
  let disj_list, disj_key = usplit disj in
  let _, conj_key = usplit conj in
  match disj_key, conj_key with
  | None, _ | _, None -> failwith "Void seq passed to dataflow [biased]"
  | Some kd, Some kc when kd = kc -> 
    map_hd (fun x -> ujoin x disj_list) disj_final
  | _ -> failwith "Insufficiently specific data passed to dataflow [biased]"

let rec infer ctx uctx (ast, _sp, (i0, o0)) = match ast with
  | Bop ((_, _, (i1, o1) as left), Aop _, (_, _, (i2, o2) as right)) -> 
    infer ctx uctx left;
    infer ctx uctx right;
    let u = mk_unital_costack () in
    u =?= i1;
    u =?= i2;
    let z = uref @@ System.Lit Int >: u in
    z =?= o1;
    z =?= o2;
    let p = mk_poly_costack () in
    p =?= i0;
    uref @@ System.Lit Int >: p =?= o0
  
  | Bop ((_, _, (i1, o1) as left), Cop _, (_, _, (i2, o2) as right)) -> 
    infer ctx uctx left;
    infer ctx uctx right;
    let u = mk_unital_costack () in
    u =?= i1;
    u =?= i2;
    let z = uref @@ System.Lit Int >: u in
    z =?= o1;
    z =?= o2;
    let s = ufresh () in
    let p = s >>: ufresh () in
    p =?= i1;
    s >>: p =?= o1
  
  | SectLeft (Aop _, (_, _, (i1, o1) as just)) -> 
    infer ctx uctx just;
    let u = mk_unital_costack () in
    u =?= i1;
    uref @@ System.Lit Int >: u =?= o1;
    let p = uref @@ System.Lit Int >: mk_poly_costack () in
    p =?= i0;
    p =?= o0
  
  | SectLeft (Cop _, (_, _, (i1, o1) as just)) -> 
    infer ctx uctx just;
    let u = mk_unital_costack () in
    u =?= i1;
    uref @@ System.Lit Int >: u =?= o1;
    let s = ufresh () in
    let p = s >>: ufresh () in
    uref @@ System.Lit Int >: p =?= i1;
    s >>: p =?= o1
  
  | SectRight ((_, _, (i1, o1) as just), Aop _) -> 
    infer ctx uctx just;
    let u = mk_unital_costack () in
    u =?= i1;
    uref @@ System.Lit Int >: u =?= o1;
    let p = uref @@ System.Lit Int >: mk_poly_costack () in
    p =?= i0;
    p =?= o0
  
  | SectRight ((_, _, (i1, o1) as just), Cop _) -> 
    infer ctx uctx just;
    let u = mk_unital_costack () in
    u =?= i1;
    uref @@ System.Lit Int >: u =?= o1;
    let s = ufresh () in
    let p = s >>: ufresh () in
    uref @@ System.Lit Int >: p =?= i1;
    s >>: p =?= o1
  
  | Sect Aop _ -> 
    let p = uref @@ System.Lit Int >: mk_poly_costack () in
    p =?= i0;
    uref @@ System.Lit Int >: p =?= o0
  
  | Sect Cop _ -> 
    let s = ufresh () in
    let p = s >>: ufresh () in
    uref @@ System.Lit Int >: (uref @@ System.Lit Int >: p) =?= i0;
    s >>: p =?= o0
  
  | Uop ((_, _, (i1, o1) as just), Dag) -> 
    infer ctx uctx just;
    i1 =?= o0;
    i0 =?= o1
  
  | Uop ((_, _, (i1, o1) as just), (Mark | Star | Plus)) -> 
    infer ctx uctx just;
    i1 =?= o1;
    i1 =?= i0;
    o1 =?= o0
  
  | Dop ((_, _, (i1, o1) as left), Ponder, (_, _, (i2, o2) as right)) -> 
    infer ctx uctx left;
    infer ctx uctx right;
    let i, o = inspect i2 o2 i1 o1 in
    i =?= i0;
    o =?= o0
  
  | Dop ((_, _, (i1, o1) as left), Pick, (_, _, (i2, o2) as right)) -> 
    infer ctx uctx left;
    infer ctx uctx right;
    let i = inspect_biased i2 o2 i1 in
    i =?= i0;
    o1 =?= o0;
    o2 =?= o0
  
  | Dop ((_, _, (i1, o1) as left), Tensor, (_, _, (i2, o2) as right)) -> 
    infer ctx uctx left;
    infer ctx uctx right;
    let i2s, o2s = Tuple2.mapn ((|>) ()) (ufresh, ufresh) in
    i2s >>: unil () =?= i2;
    o2s >>: unil () =?= o2;
    let i, o = inspect_nested i2s o2s i1 o1 in
    i =?= i0;
    o =?= o0
  
  | Dop ((_, _, (i1, o1) as left), Fork, (_, _, (i2, o2) as right)) -> 
    infer ctx uctx left;
    infer ctx uctx right;
    let i2s, o2s = Tuple2.mapn ((|>) ()) (ufresh, ufresh) in
    i2s >>: unil () =?= i2;
    o2s >>: unil () =?= o2;
    let o = inspect_nested_biased i2s o2s o1 in
    i1 =?= i0;
    i2 =?= i0;
    o =?= o0
  
  | _ -> failwith "todo"