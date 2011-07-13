(* casting or separate op types for float/(u)int? *)

(* make different levels of IR subtype off increasingly restrictive, partially
 * compatible interface types? *)

(* bits per element *)
type val_type = 
    | Int of int 
    | UInt of int 
    | Float of int 
    (* TODO: this technically allows Vector(Vector(...)) which the pattern
     * matching checks don't like, among other things. *)
    (* TODO: switch to explicit IntVector, UIntVector, FloatVector? *)
    (* TODO: separate BoolVector or mask type? *)
    | IntVector of int * int
    | UIntVector of int * int
    | FloatVector of int * int

let bool1 = UInt(1)
let u8 = UInt(8)
let u16 = UInt(16)
let u32 = UInt(32)
let u64 = UInt(64)
let i8 = Int(8)
let i16 = Int(16)
let i32 = Int(32)
let i64 = Int(64)
let f16 = Float(16)
let f32 = Float(32)
let f64 = Float(64)

(* how to enforce valid arithmetic subtypes for different subexpressions? 
 * e.g. only logical values expressions for Logical? Declare interfaces for 
 * each subtype? *)
type expr =
    (* constants *)
    (* TODO: add val_type to immediates? *)
    | IntImm of int
    | UIntImm of int
    | FloatImm of float

    (* TODO: separate "cast" from "convert"?
     * Cast changes operational interpretation of variables, but doesn't touch
     * stored bits.
     * Convert changes data to bits with equivalent interpretation in new type. *)
    (* TODO: validate operand type matches with Caml type parameters *)
    | Cast of val_type * expr

    (* arithmetic *)
    | Add of expr * expr
    | Sub of expr * expr
    | Mul of expr * expr
    | Div of expr * expr

    (* only for domain variables? *)
    | Var of string

    (* comparison *)
    | EQ of expr * expr
    | NE of expr * expr
    | LT of expr * expr
    | LE of expr * expr
    | GT of expr * expr
    | GE of expr * expr

    (* logical *)
    | And of expr * expr
    | Or  of expr * expr
    | Not of expr

    (* Select of [condition], [true val], [false val] *)
    (* Type is type of [true val] & [false val], which must match *)
    | Select of expr * expr * expr

    (* memory *)
    | Load of val_type * memref
          
    (* Two different ways to make vectors *)
    | MakeVector of (expr list)
    (* | Broadcast of val_type * expr *)

    (* TODO: Unpack/swizzle vectors *)

    (* TODO: function calls? *)

and memref = {
    (* how do we represent memory references? computed references? *)
    buf : buffer;
    idx : expr;
}

and buffer = int (* TODO: just an ID for now *)

(* TODO: assert that l,r subexpressions match. Do as separate checking pass? *)
let rec val_type_of_expr = function
  | IntImm _ -> i64
  | UIntImm _ -> u64
  | FloatImm _ -> f32
  | Cast(t,_) -> t
  | Add(l,r) | Sub(l,r) | Mul(l,r) | Div(l,r) | Select(_,l,r) ->
      assert (val_type_of_expr l = val_type_of_expr r);
      val_type_of_expr l
  | Var _ -> i64 (* Vars are only defined as integer programs so must be ints *)
  (* boolean expressions on vector types return bool vectors of equal length*)
  (* boolean expressions on scalars return scalar bools *)
  | EQ(l,r) | NE(l,r) | LT(l,r) | LE(l,r) | GT(l,r) | GE(l,r) ->
      assert (val_type_of_expr l = val_type_of_expr r);
      begin
        match val_type_of_expr l with
          | IntVector(_, len) | UIntVector(_, len) | FloatVector(_, len) ->
              IntVector(1, len)
          | _ -> bool1
      end
  (* And/Or/Not only allow boolean operands, and return the same type *)
  | And(e,_) | Or(e,_) | Not e ->
      (* TODO: add checks *)
      val_type_of_expr e
  | Load(t,_) -> t
  | MakeVector(l) ->
      let len = List.length l in
      match val_type_of_expr (List.hd l) with 
        | Int(b)   -> IntVector(b,len)
        | UInt(b)  -> UIntVector(b,len)
        | Float(b) -> FloatVector(b,len)
  (* | Broadcast(t,_) -> t *)

(* does this really become a list of domain bindings? *)
type domain = {
    name : string; (* name binding *)
    range : program; (* TODO: rename - polygon, region, polyhedron, ... *)
}

and program = int * int (* just intervals for initial testing *)

type stmt =
    (* TODO: | Blit of -- how to express sub-ranges? -- split and merge
     * sub-ranges *)
    | If of expr * stmt
    | IfElse of expr * stmt * stmt
    | Map of domain * stmt
    | For of domain * stmt
    (* TODO: For might need landing pad: always executes before, only if *any* iteration
    * fired. Same for Map - useful for loop invariant code motion. Easier for
    * Map if multiple dimensions are fused into 1. *)
    | Block of stmt list
    | Reduce of reduce_op * expr * memref (* TODO: initializer expression? *)
    | Store of expr * memref

(* TODO:  *)
and reduce_op =
    | AddEq
    | SubEq
    | MulEq
    | DivEq
