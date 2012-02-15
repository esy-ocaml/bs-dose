(**************************************************************************************)
(*  Copyright (C) 2009 Pietro Abate <pietro.abate@pps.jussieu.fr>                     *)
(*  Copyright (C) 2009 Mancoosi Project                                               *)
(*                                                                                    *)
(*  This library is free software: you can redistribute it and/or modify              *)
(*  it under the terms of the GNU Lesser General Public License as                    *)
(*  published by the Free Software Foundation, either version 3 of the                *)
(*  License, or (at your option) any later version.  A special linking                *)
(*  exception to the GNU Lesser General Public License applies to this                *)
(*  library, see the COPYING file for more information.                               *)
(**************************************************************************************)

module OcamlHash = Hashtbl
open ExtLib
open Common

let debug fmt = Util.make_debug __FILE__ fmt
let info fmt = Util.make_info __FILE__ fmt
let warning fmt = Util.make_warning __FILE__ fmt
let fatal fmt = Util.make_fatal __FILE__ fmt

type reason =
  |Dependency of (Cudf.package * Cudf_types.vpkg list * Cudf.package list)
  |Missing of (Cudf.package * Cudf_types.vpkg list)
  |Conflict of (Cudf.package * Cudf.package * Cudf_types.vpkg)

type request =
  |Package of Cudf.package
  |PackageList of Cudf.package list

type result =
  |Success of (?all:bool -> unit -> Cudf.package list)
  |Failure of (unit -> reason list)

type diagnosis = { result : result ; request : request }

module ResultHash = OcamlHash.Make (
  struct
    type t = reason

    let equal v w = match (v,w) with
    |Missing (_,v1),Missing (_,v2) -> v1 = v2
    |Conflict(i1,j1,_),Conflict (i2,j2,_) -> i1 = i2 && j1 = j2
    |_ -> false

    let hash = function
      |Missing (_,vpkgs) -> OcamlHash.hash vpkgs
      |Conflict (i,j,_) -> OcamlHash.hash (i,j)
      |_ -> assert false
  end
)

type summary = {
  mutable missing : int;
  mutable conflict : int;
  mutable unique_missing : int;
  mutable unique_conflict : int;
  summary : (Cudf.package list ref) ResultHash.t 
}

let default_result n = {
  missing = 0;
  conflict = 0;
  unique_missing = 0;
  unique_conflict = 0;
  summary = ResultHash.create n;
}

(** given a list of dependencies, return a list of list containg all
 *  paths in the dependency tree starting from [root] *)
let build_paths deps root =
  let bind m f = List.flatten (List.map f m) in
  let rec aux acc deps root =
    match List.partition (fun (i,_,_) -> CudfAdd.equal i root) deps with
    |([],_) when (List.length acc) = 1 -> [] 
    |(rootlist,_) ->
        bind rootlist (function
          |(i,v,[]) -> [List.rev acc]
          |(i,v,l) -> bind l (fun r -> aux ((i,v)::acc) deps r)
        )
  in
  aux [] deps root
;;

let pp_package ?(source=false) pp fmt pkg =
  let (p,v,fields) = pp pkg in
  Format.fprintf fmt "package: %s@," (CudfAdd.decode p);
  Format.fprintf fmt "version: %s" v;
  List.iter (function
    |(("source"|"sourcenumber"),_) -> ()
    |(k,v) -> Format.fprintf fmt "@,%s: %s" k (CudfAdd.decode v)
  ) fields;
  if source then
    begin try
      let source = List.assoc "source" fields in
      let sourceversion = 
        try "(= "^(List.assoc "sourcenumber" fields)^")" 
        with Not_found -> ""
      in
      Format.fprintf fmt "@,source: %s %s" source sourceversion
    with Not_found -> () end
;;

let pp_vpkglist pp fmt = 
  (* from libcudf ... again *)
  let pp_list fmt ~pp_item ~sep l =
    let rec aux fmt = function
      | [] -> assert false
      | [last] -> (* last item, no trailing sep *)
          Format.fprintf fmt "@,%a" pp_item last
      | vpkg :: tl -> (* at least one package in tl *)
          Format.fprintf fmt "@,%a%s" pp_item vpkg sep ;
          aux fmt tl
    in
    match l with
    | [] -> ()
    | [sole] -> pp_item fmt sole
    | _ -> Format.fprintf fmt "@[<h>%a@]" aux l
  in
  let string_of_relop = function
      `Eq -> "="
    | `Neq -> "!="
    | `Geq -> ">="
    | `Gt -> ">"
    | `Leq -> "<="
    | `Lt -> "<"
  in
  let pp_item fmt = function
    |(p,None) -> Format.fprintf fmt "%s" (CudfAdd.decode p)
    |(p,Some(c,v)) ->
        let (p,v,_) = pp {Cudf.default_package with Cudf.package = p ; version = v} in
        Format.fprintf fmt "%s (%s %s)" (CudfAdd.decode p) (string_of_relop c) v
  in
  pp_list fmt ~pp_item ~sep:" | "

let pp_dependency pp ?(label="depends") fmt (i,vpkgs) =
  Format.fprintf fmt "%a" (pp_package pp) i;
  if vpkgs <> [] then
    Format.fprintf fmt "@,%s: %a" label (pp_vpkglist pp) vpkgs;
;;

let rec pp_list pp fmt = function
  |[h] -> Format.fprintf fmt "@[<v 1>-@,%a@]" pp h
  |h::t ->
      (Format.fprintf fmt "@[<v 1>-@,%a@]@," pp h ;
      pp_list pp fmt t)
  |[] -> ()
;;

let create_pathlist root deps =
  let dl = List.map (function Dependency x -> x |_ -> assert false) deps in
  build_paths (List.unique dl) root

let pp_dependencies pp fmt pathlist =
  let rec aux fmt = function
    |[path] -> Format.fprintf fmt "@[<v 1>-@,@[<v 1>depchain:@,%a@]@]" (pp_list (pp_dependency pp)) path
    |path::pathlist ->
        (Format.fprintf fmt "@[<v 1>-@,@[<v 1>depchain:@,%a@]@]@," (pp_list (pp_dependency pp)) path;
        aux fmt pathlist)
    |[] -> ()
  in
  aux fmt pathlist
;;

let print_error pp root fmt l =
  let (deps,res) = List.partition (function Dependency _ -> true |_ -> false) l in
  let pp_reason fmt = function
    |Conflict (i,j,vpkg) ->
        Format.fprintf fmt "@[<v 1>conflict:@,";
        Format.fprintf fmt "@[<v 1>pkg1:@,%a@," (pp_package ~source:true pp) i;
        Format.fprintf fmt "unsat-conflitc: %a@]@," (pp_vpkglist pp) [vpkg];
        Format.fprintf fmt "@[<v 1>pkg2:@,%a@]" (pp_package ~source:true pp) j;
        if deps <> [] then begin
          let pl1 = create_pathlist root (Dependency(i,[],[])::deps) in
          let pl2 = create_pathlist root (Dependency(j,[],[])::deps) in
          if pl1 <> [[]] then
            Format.fprintf fmt "@,@[<v 1>depchain1:@,%a@]" (pp_dependencies pp) pl1;
          if pl2 <> [[]] then
            Format.fprintf fmt "@,@[<v 1>depchain2:@,%a@]" (pp_dependencies pp) pl2;
          Format.fprintf fmt "@]"
        end else
          Format.fprintf fmt "@,@]"
    |Missing (i,vpkgs) ->
        Format.fprintf fmt "@[<v 1>missing:@,";
        Format.fprintf fmt "@[<v 1>pkg:@,%a@]" 
          (pp_dependency ~label:"unsat-dependency" pp) (i,vpkgs);
        let pl = create_pathlist root (Dependency(i,vpkgs,[])::deps) in
        if pl <> [[]] then begin
          Format.fprintf fmt "@,@[<v 1>depchains:@,%a@]" (pp_dependencies pp) pl;
          Format.fprintf fmt "@]"
        end else
          Format.fprintf fmt "@,@]"
    (* only two failures reasons. Dependency describe the 
     * dependency chain to a failure witness *)
    |_ -> assert false 
  in
  pp_list pp_reason fmt res;
;;

let default_pp pkg = (pkg.Cudf.package,CudfAdd.string_of_version pkg,[])

let fprintf ?(pp=default_pp) ?(failure=false) ?(success=false) ?(explain=false) fmt = function
  |{result = Success (f); request = req } when success ->
       Format.fprintf fmt "@[<v 1>-@,";
       begin match req with
       |Package r -> Format.fprintf fmt "@[<v>%a@]@," (pp_package ~source:true pp) r
       |PackageList rl -> ()
       end;
       Format.fprintf fmt "status: ok@,";
       if explain then begin
         let is = f ~all:true () in
         if is <> [] then begin
           Format.fprintf fmt "@[<v 1>installationset:@," ;
           Format.fprintf fmt "@[<v>%a@]" (pp_list (pp_package pp)) is;
           Format.fprintf fmt "@]"
         end
       end;
       Format.fprintf fmt "@]@,"
  |{result = Failure (f) ; request = Package r } when failure -> 
       Format.fprintf fmt "@[<v 1>-@,";
       Format.fprintf fmt "@[<v>%a@]@," (pp_package ~source:true pp) r;
       Format.fprintf fmt "status: broken@,";
       if explain then begin
         Format.fprintf fmt "@[<v 1>reasons:@,";
         Format.fprintf fmt "@[<v>%a@]" (print_error pp r) (f ());
         Format.fprintf fmt "@]"
       end;
       Format.fprintf fmt "@]@,"
  |{result = Failure (f) ; request = PackageList rl } when failure -> 
       Format.fprintf fmt "@[<v 1>-@,";
       Format.fprintf fmt "status: broken@,";
       Format.fprintf fmt "@]@,"
;;

let printf ?(pp=default_pp) ?(failure=false) ?(success=false) ?(explain=false) d =
  fprintf ~pp ~failure ~success ~explain Format.std_formatter d

let is_solution = function
  |{result = Success _ } -> true
  |{result = Failure _ } -> false

let add h k v =
  try let l = ResultHash.find h k in l := v :: !l
  with Not_found -> ResultHash.add h k (ref [v])

let collect results = function
  |{result = Failure (f) ; request = Package r } -> 
      List.iter (fun reason ->
        match reason with
        |Conflict (i,j,_) ->
            add results.summary reason r;
            results.conflict <- results.conflict + 1
        |Missing (i,vpkgs) ->
            add results.summary reason r;
            results.missing <- results.missing + 1
        |_ -> ()
      ) (f ())
  |_  -> ()
;;

let pp_summary_row pp fmt = function
  |(Conflict (i,j,_),pl) ->
      Format.fprintf fmt "@[<v 1>conflict:@,";
      Format.fprintf fmt "@[<v 1>pkg1:@,%a@]@," (pp_package pp) i;
      Format.fprintf fmt "@[<v 1>pkg2:@,%a@]@," (pp_package pp) j;
      Format.fprintf fmt "@[<v 1>packages:@," ;
      pp_list (pp_package ~source:true pp) fmt pl;
      Format.fprintf fmt "@]@]"
  |(Missing (i,vpkgs) ,pl) -> 
      Format.fprintf fmt "@[<v 1>missing:@,";
      Format.fprintf fmt "@[<v 1>unsat-dependency: %a@]@," (pp_vpkglist pp) vpkgs;
      Format.fprintf fmt "@[<v 1>packages:@," ;
      pp_list (pp_package ~source:true pp) fmt pl;
      Format.fprintf fmt "@]@]"
  |_ -> ()
;;

let pp_summary ?(pp=default_pp) () fmt result = 
  let l =
    ResultHash.fold (fun k v acc -> 
      let l1 = Util.list_unique !v in
      begin match k with
        |Conflict(_,_,_) -> result.unique_conflict <- result.unique_conflict + 1;
        |Missing(_,_) -> result.unique_missing <- result.unique_missing +1;
        |_ -> ()
      end;
      if List.length l1 > 1 then (k,l1)::acc else acc 
    ) result.summary [] 
  in
  let l = List.sort ~cmp:(fun (_,l1) (_,l2) -> (List.length l1) - (List.length l2)) l in

  Format.fprintf fmt "@[";
  Format.fprintf fmt "missing-packages: %d@." result.missing;
  Format.fprintf fmt "conflict-packages: %d@." result.conflict;
  Format.fprintf fmt "unique-missing-packages: %d@." result.unique_missing;
  Format.fprintf fmt "unique-conflict-packages: %d@." result.unique_conflict;
  Format.fprintf fmt "@]";

  Format.fprintf fmt "@[<v 1>summary:@," ;
  pp_list (pp_summary_row pp) fmt l;
  Format.fprintf fmt "@]"
;;
