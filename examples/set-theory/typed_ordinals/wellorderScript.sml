open HolKernel Parse boolLib bossLib
open lcsymtacs
open boolSimps

open set_relationTheory pred_setTheory

val _ = new_theory "wellorder"

val wellfounded_def = Define`
  wellfounded R <=>
   !s. (?w. w IN s) ==> ?min. min IN s /\ !w. (w,min) IN R ==> w NOTIN s
`;

val wellfounded_WF = store_thm(
  "wellfounded_WF",
  ``wellfounded R <=> WF (CURRY R)``,
  rw[wellfounded_def, relationTheory.WF_DEF, SPECIFICATION]);

val wellorder_def = Define`
  wellorder R <=>
    wellfounded R /\ strict_linear_order R (domain R UNION range R)
`;

(* well order examples *)
val wellorder_EMPTY = store_thm(
  "wellorder_EMPTY",
  ``wellorder {}``,
  rw[wellorder_def, wellfounded_def, strict_linear_order_def, transitive_def,
     antisym_def, domain_def, range_def]);

val wellorder_SING = store_thm(
  "wellorder_SING",
  ``wellorder {(x,y)} <=> x <> y``,
  rw[wellorder_def, wellfounded_def] >> eq_tac >| [
    rpt strip_tac >> rw[] >>
    first_x_assum (qspec_then `{x}` mp_tac) >> simp[],

    strip_tac >> conj_tac >| [
      rw[] >> Cases_on `x IN s` >- (qexists_tac `x` >> rw[]) >>
      rw[] >> metis_tac [],
      rw[strict_linear_order_def, domain_def, range_def] >>
      rw[transitive_def]
    ]
  ]);

val rrestrict_SUBSET = store_thm(
  "rrestrict_SUBSET",
  ``rrestrict r s SUBSET r``,
  rw[SUBSET_DEF,rrestrict_def] >> rw[]);



val wellfounded_subset = store_thm(
  "wellfounded_subset",
  ``!r0 r. wellfounded r /\ r0 SUBSET r ==> wellfounded r0``,
  rw[wellfounded_def] >>
  `?min. min IN s /\ !w. (w,min) IN r ==> w NOTIN s` by metis_tac [] >>
  metis_tac [SUBSET_DEF])

val wellorder_results = newtypeTools.rich_new_type(
  "wellorder",
  prove(``?x. wellorder x``, qexists_tac `{}` >> simp[wellorder_EMPTY]))

val termP_term_REP = #termP_term_REP wellorder_results

val elsOf_def = Define`
  elsOf w = domain (wellorder_REP w) UNION range (wellorder_REP w)
`;

val _ = overload_on("WIN", ``λp w. p IN wellorder_REP w``)
val _ = set_fixity "WIN" (Infix(NONASSOC, 425))
val _ = overload_on ("wrange", ``\w. range (wellorder_REP w)``)


val WIN_elsOf = store_thm(
  "WIN_elsOf",
  ``(x,y) WIN w ==> x IN elsOf w /\ y IN elsOf w``,
  rw[elsOf_def, range_def, domain_def] >> metis_tac[]);

val WIN_trichotomy = store_thm(
  "WIN_trichotomy",
  ``!x y. x IN elsOf w /\ y IN elsOf w ==>
          (x,y) WIN w \/ (x = y) \/ (y,x) WIN w``,
  rpt strip_tac >>
  `wellorder (wellorder_REP w)` by metis_tac [termP_term_REP] >>
  fs[elsOf_def, wellorder_def, strict_linear_order_def] >> metis_tac[]);

val WIN_REFL = store_thm(
  "WIN_REFL",
  ``(x,x) WIN w = F``,
  `wellorder (wellorder_REP w)` by metis_tac [termP_term_REP] >>
  fs[wellorder_def, strict_linear_order_def]);
val _ = export_rewrites ["WIN_REFL"]

val WIN_TRANS = store_thm(
  "WIN_TRANS",
  ``(x,y) WIN w /\ (y,z) WIN w ==> (x,z) WIN w``,
  `transitive (wellorder_REP w)`
     by metis_tac [termP_term_REP, wellorder_def, strict_linear_order_def] >>
  metis_tac [transitive_def]);

val WIN_WF = store_thm(
  "WIN_WF",
  ``wellfounded (\p. p WIN w)``,
  `wellorder (wellorder_REP w)` by metis_tac [termP_term_REP] >>
  fs[wellorder_def] >>
  qsuff_tac `(\p. p WIN w) = wellorder_REP w` >- simp[] >>
  simp[FUN_EQ_THM, SPECIFICATION]);

val CURRY_def = pairTheory.CURRY_DEF |> SPEC_ALL |> ABS ``y:'b``
                                     |> ABS ``x:'a``
                                     |> SIMP_RULE (bool_ss ++ ETA_ss) []

val WIN_WF2 = save_thm(
  "WIN_WF2",
  WIN_WF |> SIMP_RULE (srw_ss()) [wellfounded_WF, CURRY_def])

val iseg_def = Define`iseg w x = { y | (y,x) WIN w }`

val wellorder_rrestrict = store_thm(
  "wellorder_rrestrict",
  ``wellorder (rrestrict (wellorder_REP w) (iseg w x))``,
  rw[wellorder_def, iseg_def]
    >- (match_mp_tac wellfounded_subset >> qexists_tac `wellorder_REP w` >>
        rw[rrestrict_SUBSET] >>
        metis_tac [termP_term_REP, wellorder_def])
    >- (qabbrev_tac `WO = wellorder_REP w` >>
        qabbrev_tac `els = {y | (y,x) IN WO}` >>
        simp[strict_linear_order_def] >> rpt conj_tac >| [
          simp[transitive_def, rrestrict_def] >> metis_tac [WIN_TRANS],
          simp[rrestrict_def, Abbr`WO`],
          map_every qx_gen_tac [`a`, `b`] >>
          simp[rrestrict_def, in_domain, in_range] >>
          `!e. e IN els ==> e IN elsOf w`
             by (rw[elsOf_def, Abbr`els`, domain_def, range_def] >>
                 metis_tac[]) >>
          metis_tac [WIN_trichotomy]
        ]))

val wobound_def = Define`
  wobound x w = wellorder_ABS (rrestrict (wellorder_REP w) (iseg w x))
`;

val IN_wobound = store_thm(
  "IN_wobound",
  ``(x,y) WIN wobound z w <=> (x,z) WIN w /\ (y,z) WIN w /\ (x,y) WIN w``,
  rw[wobound_def, wellorder_rrestrict, #repabs_pseudo_id wellorder_results] >>
  rw[rrestrict_def, iseg_def] >> metis_tac []);

val localDefine = with_flag (computeLib.auto_import_definitions, false) Define

val wrange_wobound = store_thm(
  "wrange_wobound",
  ``wrange (wobound x w) = iseg w x INTER wrange w``,
  rw[EXTENSION, range_def, iseg_def, IN_wobound, EQ_IMP_THM] >>
  metis_tac[WIN_TRANS]);

val wellorder_cases = store_thm(
  "wellorder_cases",
  ``!w. ?s. wellorder s /\ (w = wellorder_ABS s)``,
  rw[Once (#termP_exists wellorder_results)] >>
  simp_tac (srw_ss() ++ DNF_ss)[#absrep_id wellorder_results]);
val WEXTENSION = store_thm(
  "WEXTENSION",
  ``(w1 = w2) <=> !a b. (a,b) WIN w1 <=> (a,b) WIN w2``,
  qspec_then `w1` (Q.X_CHOOSE_THEN `s1` STRIP_ASSUME_TAC) wellorder_cases >>
  qspec_then `w2` (Q.X_CHOOSE_THEN `s2` STRIP_ASSUME_TAC) wellorder_cases >>
  simp[#repabs_pseudo_id wellorder_results,
       #term_ABS_pseudo11 wellorder_results,
       EXTENSION, pairTheory.FORALL_PROD]);

val wobound2 = store_thm(
  "wobound2",
  ``(a,b) WIN w ==> (wobound a (wobound b w) = wobound a w)``,
  rw[WEXTENSION, IN_wobound, EQ_IMP_THM] >> metis_tac [WIN_TRANS]);

val wellorder_fromNat = store_thm(
  "wellorder_fromNat",
  ``wellorder { (i,j) | i < j /\ j <= n }``,
  rw[wellorder_def, wellfounded_def, strict_linear_order_def] >| [
    qexists_tac `LEAST m. m IN s` >> numLib.LEAST_ELIM_TAC >> rw[] >>
    metis_tac [],
    srw_tac[ARITH_ss][transitive_def],
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def],
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def],
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def],
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def]
  ]);

val wellorder_fromNat_SUM = store_thm(
  "wellorder_fromNat_SUM",
  ``wellorder { (INL i, INL j) | i < j /\ j <= n }``,
  rw[wellorder_def, wellfounded_def, strict_linear_order_def] >| [
    Cases_on `w` >| [
      qexists_tac `INL (LEAST m. INL m IN s)` >> numLib.LEAST_ELIM_TAC >>
      rw[] >> metis_tac[],
      qexists_tac `INR y` >> rw[]
    ],
    srw_tac[ARITH_ss][transitive_def],
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def] >> rw[] >>
    DECIDE_TAC,
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def] >> rw[] >>
    DECIDE_TAC,
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def] >> rw[] >>
    DECIDE_TAC,
    full_simp_tac (srw_ss() ++ ARITH_ss) [domain_def, range_def] >> rw[] >>
    DECIDE_TAC
  ]);

val fromNat0_def = Define`
  fromNat0 n = wellorder_ABS { (INL i, INL j) | i < j /\ j <= n }
`

val fromNat0_11 = store_thm(
  "fromNat0_11",
  ``(fromNat0 i = fromNat0 j) <=> (i = j)``,
  rw[fromNat0_def, WEXTENSION, wellorder_fromNat_SUM,
     #repabs_pseudo_id wellorder_results] >>
  simp[EQ_IMP_THM] >> strip_tac >>
  spose_not_then assume_tac >>
  `i < j \/ j < i` by DECIDE_TAC >| [
     first_x_assum (qspecl_then [`INL i`, `INL j`] mp_tac),
     first_x_assum (qspecl_then [`INL j`, `INL i`] mp_tac)
  ] >> srw_tac[ARITH_ss][]);

val elsOf_fromNat0 = store_thm(
  "elsOf_fromNat0",
  ``elsOf (fromNat0 n) = if n = 0 then {} else { INL i | i <= n }``,
  simp[fromNat0_def, EXTENSION, elsOf_def, #repabs_pseudo_id wellorder_results,
       wellorder_fromNat_SUM, in_domain, in_range, EQ_IMP_THM] >>
  simp_tac (srw_ss() ++ DNF_ss) [] >> rw[] >> TRY DECIDE_TAC >>
  Cases_on `i = n` >- (DISJ2_TAC >> qexists_tac `n - 1` >> DECIDE_TAC) >>
  DISJ1_TAC >> qexists_tac `n` >> DECIDE_TAC);

val elsOf_wobound = store_thm(
  "elsOf_wobound",
  ``elsOf (wobound x w) =
      let s = { y | (y,x) WIN w }
      in
        if FINITE s /\ (CARD s = 1) then {}
        else s``,
  simp[wobound_def, EXTENSION] >> qx_gen_tac `a` >>
  simp[elsOf_def, wellorder_rrestrict, #repabs_pseudo_id wellorder_results] >>
  simp[rrestrict_def, iseg_def, domain_def, range_def] >> eq_tac >|[
    disch_then (DISJ_CASES_THEN (Q.X_CHOOSE_THEN `b` STRIP_ASSUME_TAC)) >>
    rw[] >>
    `a <> b` by (strip_tac >> fs[WIN_REFL]) >>
    `a IN { y | (y,x) WIN w} /\ b IN { y | (y,x) WIN w}` by rw[] >>
    `SING { y | (y,x) WIN w }` by metis_tac [SING_IFF_CARD1] >>
    `?z. { y | (y,x) WIN w } = {z}` by fs[SING_DEF] >>
    pop_assum SUBST_ALL_TAC >> fs[],

    rw [] >>
    qabbrev_tac `s = { y | (y,x) WIN w }` >> Cases_on `FINITE s` >> fs[] >| [
      `CARD s <> 0`
        by (strip_tac >> `s = {}` by metis_tac [CARD_EQ_0] >>
            `a IN s` by rw[Abbr`s`] >> rw[] >> fs[]) >>
      `?b. a <> b /\ (b,x) WIN w`
         by (SPOSE_NOT_THEN strip_assume_tac >>
             qsuff_tac `s = {a}` >- (strip_tac >> fs[]) >>
             rw[EXTENSION, Abbr`s`, EQ_IMP_THM] >> metis_tac []) >>
      metis_tac [WIN_trichotomy, WIN_elsOf],

      `?b. a <> b /\ b IN s`
         by (qspecl_then [`s`, `{a}`] MP_TAC IN_INFINITE_NOT_FINITE >>
             simp[] >> metis_tac []) >>
      fs[Abbr`s`] >> metis_tac [WIN_trichotomy, WIN_elsOf]
    ]
  ]);

val orderiso_def = Define`
  orderiso w1 w2 <=>
    ?f. (!x. x IN elsOf w1 ==> f x IN elsOf w2) /\
        (!x1 x2. x1 IN elsOf w1 /\ x2 IN elsOf w1 ==>
                 ((f x1 = f x2) = (x1 = x2))) /\
        (!y. y IN elsOf w2 ==> ?x. x IN elsOf w1 /\ (f x = y)) /\
        (!x y. (x,y) WIN w1 ==> (f x, f y) WIN w2)
`;

val orderiso_thm = store_thm(
  "orderiso_thm",
  ``orderiso w1 w2 <=>
     ?f. BIJ f (elsOf w1) (elsOf w2) /\
         !x y. (x,y) WIN w1 ==> (f x, f y) WIN w2``,
  rw[orderiso_def, BIJ_DEF, INJ_DEF, SURJ_DEF] >> eq_tac >> rpt strip_tac >>
  qexists_tac `f` >> metis_tac []);

val orderiso_REFL = store_thm(
  "orderiso_REFL",
  ``!w. orderiso w w``,
  rw[orderiso_def] >> qexists_tac `\x.x` >> rw[]);

val orderiso_SYM = store_thm(
  "orderiso_SYM",
  ``!w1 w2. orderiso w1 w2 ==> orderiso w2 w1``,
  rw[orderiso_thm] >>
  qabbrev_tac `g = LINV f (elsOf w1)` >>
  `BIJ g (elsOf w2) (elsOf w1)` by metis_tac [BIJ_LINV_BIJ] >>
  qexists_tac `g` >> simp[] >>
  rpt strip_tac >>
  `x IN elsOf w2 /\ y IN elsOf w2` by metis_tac [WIN_elsOf] >>
  `g x IN elsOf w1 /\ g y IN elsOf w1` by metis_tac [BIJ_DEF, INJ_DEF] >>
  `(g x, g y) WIN w1 \/ (g x = g y) \/ (g y, g x) WIN w1`
    by metis_tac [WIN_trichotomy]
    >- (`x = y` by metis_tac [BIJ_DEF, INJ_DEF] >> fs[WIN_REFL]) >>
  `(f (g y), f (g x)) WIN w2` by metis_tac [WIN_TRANS] >>
  `(y,x) WIN w2` by metis_tac [BIJ_LINV_INV] >>
  metis_tac [WIN_TRANS, WIN_REFL]);

val orderiso_TRANS = store_thm(
  "orderiso_TRANS",
  ``!w1 w2 w3. orderiso w1 w2 /\ orderiso w2 w3 ==> orderiso w1 w3``,
  rw[orderiso_def] >> qexists_tac `f' o f` >>
  rw[] >> metis_tac []);

val orderlt_def = Define`
  orderlt w1 w2 = ?x. x IN elsOf w2 /\ orderiso w1 (wobound x w2)
`;

val elsOf_NEVER_SING = store_thm(
  "elsOf_NEVER_SING",
  ``!e. elsOf w <> {e}``,
  rw[elsOf_def] >> disch_then (assume_tac o SIMP_RULE (srw_ss()) [EXTENSION]) >>
  `e IN domain (wellorder_REP w) \/ e IN wrange w` by metis_tac[] >>
   fs[in_domain, in_range] >> metis_tac [WIN_REFL]);

val orderlt_REFL = store_thm(
  "orderlt_REFL",
  ``orderlt w w = F``,
  simp[orderlt_def] >> qx_gen_tac `x` >> Cases_on `x IN elsOf w` >> simp[] >>
  simp[orderiso_thm] >> qx_gen_tac `f` >>
  Cases_on `BIJ f (elsOf w) (elsOf (wobound x w))` >> simp[] >>
  spose_not_then strip_assume_tac >>
  `f x IN elsOf (wobound x w)` by metis_tac [BIJ_IFF_INV] >>
  `elsOf (wobound x w) = {y | (y,x) WIN w}`
       by (full_simp_tac (srw_ss() ++ COND_elim_ss)
                                 [elsOf_wobound, LET_THM] >>
                   fs[]) >>
  `!n. (FUNPOW f (SUC n) x, FUNPOW f n x) WIN w`
     by (Induct >> simp[] >- fs[] >>
         `(FUNPOW f (SUC (SUC n)) x, FUNPOW f (SUC n) x) WIN wobound x w`
            by metis_tac [arithmeticTheory.FUNPOW_SUC] >>
         fs [IN_wobound]) >>
  mp_tac WIN_WF >> simp[wellfounded_def] >>
  qexists_tac `{ FUNPOW f n x | n | T }` >> simp[] >>
  simp_tac (srw_ss() ++ DNF_ss)[] >> qx_gen_tac `min` >>
  Cases_on `!n. min <> FUNPOW f n x` >- simp[] >>
  fs[] >> DISJ2_TAC >> rw[] >> qexists_tac `SUC n` >>
  rw[Once SPECIFICATION]);

val FINITE_IMAGE_INJfn = prove(
  ``!s. (!x y. x IN s /\ y IN s ==> ((f x = f y) = (x = y))) ==>
        (FINITE (IMAGE f s) = FINITE s)``,
  rpt strip_tac >> simp[EQ_IMP_THM, IMAGE_FINITE] >>
  qsuff_tac `!t. FINITE t ==>
                 !s'. s' SUBSET s /\ (t = IMAGE f s') ==> FINITE s'`
    >- metis_tac[SUBSET_REFL] >>
  Induct_on `FINITE t` >> conj_tac >- metis_tac[IMAGE_EQ_EMPTY, FINITE_EMPTY] >>
  qx_gen_tac `t` >> strip_tac >> qx_gen_tac `e` >> strip_tac >>
  qx_gen_tac `s'` >> strip_tac >>
  `?d. (e = f d) /\ d IN s'`
     by (pop_assum mp_tac >> simp[EXTENSION] >> metis_tac[]) >>
  qsuff_tac `t = IMAGE f (s' DELETE d)`
    >- metis_tac [FINITE_DELETE, DELETE_SUBSET, SUBSET_TRANS] >>
  Q.UNDISCH_THEN `e INSERT t = IMAGE f s'` mp_tac >> simp[EXTENSION] >>
  strip_tac >> qx_gen_tac `x` >>
  `!x. x IN s' ==> x IN s` by fs[SUBSET_DEF] >>
  Cases_on `x = f d` >> asm_simp_tac(srw_ss() ++ CONJ_ss)[] >- rw[] >>
  first_x_assum (qspec_then `x` mp_tac) >> simp[] >> metis_tac []);

val IMAGE_CARD_INJfn = prove(
  ``!s. FINITE s /\ (!x y. x IN s /\ y IN s ==> ((f x = f y) = (x = y))) ==>
        (CARD (IMAGE f s) = CARD s)``,
  rpt strip_tac >>
  qsuff_tac `!t. FINITE t ==> t SUBSET s ==> (CARD (IMAGE f t) = CARD t)`
    >- metis_tac [SUBSET_REFL] >>
  Induct_on `FINITE t` >> simp[] >> rpt strip_tac >>
  `!x. x IN t ==> x IN s` by fs[SUBSET_DEF] >>
  asm_simp_tac (srw_ss() ++ CONJ_ss) []);

val wobounds_preserve_bijections = store_thm(
  "wobounds_preserve_bijections",
  ``BIJ f (elsOf w1) (elsOf w2) /\ x IN elsOf w1 /\
    (!x y. (x,y) WIN w1 ==> (f x, f y) WIN w2) ==>
    BIJ f (elsOf (wobound x w1)) (elsOf (wobound (f x) w2))``,
  simp[BIJ_IFF_INV,elsOf_wobound] >> strip_tac >>
  `{ y | (y, f x) WIN w2 } = IMAGE f {y | (y,x) WIN w1 }`
     by (simp[EXTENSION] >> qx_gen_tac `e` >> eq_tac >| [
           strip_tac >>
           `e IN elsOf w2 /\ f x IN elsOf w2`
              by (rw[elsOf_def, in_domain, in_range] >> metis_tac[]) >>
            `?d. d IN elsOf w1 /\ (e = f d)` by metis_tac[] >>
            rw[] >>
            `d <> x` by metis_tac [WIN_REFL] >>
            `~((x,d) WIN w1)` by metis_tac [WIN_TRANS, WIN_REFL] >>
            metis_tac [WIN_trichotomy],
            disch_then (Q.X_CHOOSE_THEN `d` STRIP_ASSUME_TAC) >> rw[]
         ]) >>
  qabbrev_tac `ltx = {y | (y,x) WIN w1}` >> simp[] >>
  `!x y. x IN ltx /\ y IN ltx ==> ((f x = f y) <=> (x = y))`
     by (simp[Abbr`ltx`] >> metis_tac [IN_UNION, in_domain, elsOf_def]) >>
  asm_simp_tac (srw_ss() ++ CONJ_ss) [FINITE_IMAGE_INJfn, IMAGE_CARD_INJfn] >>
  Cases_on `FINITE ltx /\ (CARD ltx = 1)` >> simp[] >| [
    `!x. x IN ltx ==> x IN elsOf w1`
       by (rw[Abbr`ltx`, elsOf_def, in_domain] >> metis_tac []) >>
    asm_simp_tac (srw_ss() ++ DNF_ss) [] >>
    `!x y. x IN elsOf w1 /\ y IN elsOf w1 ==> ((f x = f y) = (x = y))`
       by metis_tac [] >>
    asm_simp_tac (srw_ss() ++ CONJ_ss)[] >> metis_tac []
  ]);

val orderlt_TRANS = store_thm(
  "orderlt_TRANS",
  ``!w1 w2 w3. orderlt w1 w2 /\ orderlt w2 w3 ==> orderlt w1 w3``,
  simp[orderlt_def] >> rpt gen_tac >>
  disch_then (CONJUNCTS_THEN2
                  (Q.X_CHOOSE_THEN `a` strip_assume_tac)
                  (Q.X_CHOOSE_THEN `b` strip_assume_tac)) >>
  `(?f. BIJ f (elsOf w1) (elsOf (wobound a w2)) /\
        !x y. (x,y) WIN w1 ==> (f x, f y) WIN wobound a w2) /\
   (?g. BIJ g (elsOf w2) (elsOf (wobound b w3)) /\
        !x y. (x,y) WIN w2 ==> (g x, g y) WIN wobound b w3)`
     by metis_tac[orderiso_thm] >>
  `g a IN elsOf (wobound b w3)` by metis_tac [BIJ_IFF_INV] >>
  `(g a, b) WIN w3`
    by (pop_assum mp_tac >> simp[elsOf_wobound, in_domain, in_range] >>
        asm_simp_tac (srw_ss() ++ COND_elim_ss) [LET_THM] >>
        metis_tac[]) >>
  qexists_tac `g a` >> conj_tac >- metis_tac[IN_UNION, elsOf_def, in_domain] >>
  match_mp_tac orderiso_TRANS >> qexists_tac `wobound a w2` >>
  rw[] >> rw[orderiso_thm] >> qexists_tac `g` >> conj_tac >| [
    `wobound (g a) w3 = wobound (g a) (wobound b w3)`
      by rw[wobound2] >>
    pop_assum SUBST1_TAC >>
    match_mp_tac wobounds_preserve_bijections >> rw[],
    fs[IN_wobound]
  ]);

val wleast_def = Define`
  wleast w s =
    some x. x IN elsOf w /\ x NOTIN s /\
            !y. y IN elsOf w /\ y NOTIN s /\ x <> y ==> (x,y) WIN w
`;

val wo2wo_def = Define`
  wo2wo w1 w2 =
    WFREC (\x y. (x,y) WIN w1)
          (\f x. let s0 = IMAGE f (iseg w1 x) in
                 let s1 = IMAGE THE (s0 DELETE NONE)
                 in
                   if s1 = elsOf w2 then NONE
                   else wleast w2 s1)
`;

val restrict_away = prove(
  ``IMAGE (RESTRICT f (\x y. (x,y) WIN w) x) (iseg w x) = IMAGE f (iseg w x)``,
  rw[EXTENSION, relationTheory.RESTRICT_DEF, iseg_def] >> srw_tac[CONJ_ss][]);

val wo2wo_thm = save_thm(
  "wo2wo_thm",
  wo2wo_def |> concl |> strip_forall |> #2 |> rhs |> strip_comb |> #2
            |> C ISPECL relationTheory.WFREC_THM
            |> C MATCH_MP WIN_WF2
            |> SIMP_RULE (srw_ss()) []
            |> REWRITE_RULE [GSYM wo2wo_def, restrict_away])


val WO_INDUCTION =
    relationTheory.WF_INDUCTION_THM |> C MATCH_MP WIN_WF2 |> Q.GEN `w`
                                    |> BETA_RULE

val wleast_IN_wo = store_thm(
  "wleast_IN_wo",
  ``(wleast w s = SOME x) ==>
       x IN elsOf w /\ x NOTIN s /\
       !y. y IN elsOf w /\ y NOTIN s /\ x <> y ==> (x,y) WIN w``,
  simp[wleast_def] >> DEEP_INTRO_TAC optionTheory.some_intro >>
  simp[]);

val wleast_EQ_NONE = store_thm(
  "wleast_EQ_NONE",
  ``(wleast w s = NONE) ==> elsOf w SUBSET s``,
  simp[wleast_def] >> DEEP_INTRO_TAC optionTheory.some_intro >> rw[] >>
  simp[SUBSET_DEF] >>
  qspec_then `w` ho_match_mp_tac WO_INDUCTION >>
  qx_gen_tac `x` >> rpt strip_tac >>
  first_x_assum (fn th => qspec_then `x` mp_tac th >> simp[] >>
                          disch_then strip_assume_tac) >>
  `(y,x) WIN w` by metis_tac [WIN_trichotomy] >> metis_tac[]);

val wo2wo_IN_w2 = store_thm(
  "wo2wo_IN_w2",
  ``!x y. (wo2wo w1 w2 x = SOME y) ==> y IN elsOf w2``,
  rw[Once wo2wo_thm, LET_THM] >> metis_tac [wleast_IN_wo]);

val IMAGE_wo2wo_SUBSET = store_thm(
  "IMAGE_wo2wo_SUBSET",
  ``IMAGE THE (IMAGE (wo2wo w1 w2) (iseg w1 x) DELETE NONE) SUBSET elsOf w2``,
  simp_tac (srw_ss() ++ DNF_ss) [SUBSET_DEF] >> qx_gen_tac `a` >>
  Cases_on `wo2wo w1 w2 a` >> rw[] >> metis_tac [wo2wo_IN_w2]);

val wo2wo_EQ_NONE = store_thm(
  "wo2wo_EQ_NONE",
  ``!x. (wo2wo w1 w2 x = NONE) ==>
        !y. (x,y) WIN w1 ==> (wo2wo w1 w2 y = NONE)``,
  ONCE_REWRITE_TAC [wo2wo_thm] >> rw[LET_THM] >| [
    qsuff_tac
        `IMAGE THE (IMAGE (wo2wo w1 w2) (iseg w1 y) DELETE NONE) = elsOf w2` >-
        rw[] >>
    match_mp_tac SUBSET_ANTISYM >> rw[IMAGE_wo2wo_SUBSET] >>
    match_mp_tac SUBSET_TRANS >>
    qexists_tac `IMAGE THE (IMAGE (wo2wo w1 w2) (iseg w1 x) DELETE NONE)` >>
    conj_tac >- rw[] >>
    simp_tac (srw_ss() ++ DNF_ss) [SUBSET_DEF] >>
    qsuff_tac `!a. a IN iseg w1 x ==> a IN iseg w1 y` >- metis_tac[] >>
    rw[iseg_def] >> metis_tac [WIN_TRANS],
    imp_res_tac wleast_EQ_NONE >>
    qsuff_tac `IMAGE THE (IMAGE (wo2wo w1 w2) (iseg w1 x) DELETE NONE) SUBSET
               elsOf w2` >- metis_tac [SUBSET_ANTISYM] >>
    rw[IMAGE_wo2wo_SUBSET]
  ]);

val wo2wo_EQ_SOME_downwards = store_thm(
  "wo2wo_EQ_SOME_downwards",
  ``!x y. (wo2wo w1 w2 x = SOME y) ==>
          !x0. (x0,x) WIN w1 ==> ?y0. wo2wo w1 w2 x0 = SOME y0``,
  metis_tac [wo2wo_EQ_NONE, optionTheory.option_CASES]);

val _ = overload_on (
  "woseg",
  ``\w1 w2 x. IMAGE THE (IMAGE (wo2wo w1 w2) (iseg w1 x) DELETE NONE)``)

val mono_woseg = store_thm(
  "mono_woseg",
  ``(x1,x2) WIN w1 ==> woseg w1 w2 x1 SUBSET woseg w1 w2 x2``,
  simp_tac(srw_ss() ++ DNF_ss) [SUBSET_DEF, iseg_def]>> metis_tac [WIN_TRANS]);

val wo2wo_injlemma = prove(
  ``(x,y) WIN w1 /\ (wo2wo w1 w2 y = SOME z) ==> (wo2wo w1 w2 x <> SOME z)``,
  rw[Once wo2wo_thm, LET_THM, SimpL ``$==>``] >> strip_tac >>
  `z IN woseg w1 w2 y`
     by (asm_simp_tac (srw_ss() ++ DNF_ss) [] >> qexists_tac `x` >>
         simp[iseg_def]) >>
  metis_tac [wleast_IN_wo]);

val wo2wo_11 = store_thm(
  "wo2wo_11",
  ``x1 IN elsOf w1 /\ x2 IN elsOf w1 /\ (wo2wo w1 w2 x1 = SOME y) /\
    (wo2wo w1 w2 x2 = SOME y) ==> (x1 = x2)``,
  rpt strip_tac >>
  `(x1 = x2) \/ (x1,x2) WIN w1 \/ (x2,x1) WIN w1`
     by metis_tac [WIN_trichotomy] >>
  metis_tac [wo2wo_injlemma]);

val wleast_SUBSET = store_thm(
  "wleast_SUBSET",
  ``(wleast w s1 = SOME x) /\ (wleast w s2 = SOME y) /\ s1 SUBSET s2 ==>
    (x = y) \/ (x,y) WIN w``,
  simp[wleast_def] >> DEEP_INTRO_TAC optionTheory.some_intro >> simp[] >>
  DEEP_INTRO_TAC optionTheory.some_intro >> simp[] >> metis_tac[SUBSET_DEF]);

val wo2wo_mono = store_thm(
  "wo2wo_mono",
  ``(wo2wo w1 w2 x0 = SOME y0) /\ (wo2wo w1 w2 x = SOME y) /\ (x0,x) WIN w1 ==>
    (y0,y) WIN w2``,
  rpt strip_tac >>
  `x0 IN elsOf w1 /\ x IN elsOf w1`
      by metis_tac [elsOf_def, in_domain, in_range, IN_UNION] >>
  `y0 <> y` by metis_tac [WIN_REFL, wo2wo_11] >>
  rpt (qpat_assum `wo2wo X Y Z = WW` mp_tac) >>
  ONCE_REWRITE_TAC [wo2wo_thm] >> rw[LET_THM] >>
  metis_tac [mono_woseg, wleast_SUBSET]);

val wo2wo_ONTO = store_thm(
  "wo2wo_ONTO",
  ``x IN elsOf w1 /\ (wo2wo w1 w2 x = SOME y) /\ (y0,y) WIN w2 ==>
    ?x0. x0 IN elsOf w1 /\ (wo2wo w1 w2 x0 = SOME y0)``,
  simp[SimpL ``$==>``, Once wo2wo_thm] >> rw[] >>
  spose_not_then strip_assume_tac >>
  `y0 NOTIN woseg w1 w2 x`
     by (asm_simp_tac (srw_ss() ++ DNF_ss) [] >> qx_gen_tac `a` >>
         `(wo2wo w1 w2 a = NONE) \/ ?y'. wo2wo w1 w2 a = SOME y'`
            by metis_tac [optionTheory.option_CASES] >> simp[iseg_def] >>
         metis_tac[WIN_elsOf]) >>
  `y0 <> y` by metis_tac [WIN_REFL] >>
  `y0 IN elsOf w2 /\ y IN elsOf w2` by metis_tac [WIN_elsOf] >>
  metis_tac [WIN_TRANS, WIN_REFL, wleast_IN_wo]);

val wo2wo_EQ_NONE_woseg = store_thm(
  "wo2wo_EQ_NONE_woseg",
  ``(wo2wo w1 w2 x = NONE) ==> (elsOf w2 = woseg w1 w2 x)``,
  rw[Once wo2wo_thm, LET_THM] >>
  `?y. y IN elsOf w2 /\ y NOTIN woseg w1 w2 x`
     by metis_tac [IMAGE_wo2wo_SUBSET, SUBSET_DEF, EXTENSION] >>
  strip_tac >> imp_res_tac wleast_EQ_NONE >> metis_tac [SUBSET_DEF]);

val orderlt_trichotomy = store_thm(
  "orderlt_trichotomy",
  ``orderlt w1 w2 \/ orderiso w1 w2 \/ orderlt w2 w1``,
  Cases_on `?x. x IN elsOf w1 /\ (wo2wo w1 w2 x = NONE)` >| [
    `?x0. wleast w1 { x | ?y. wo2wo w1 w2 x = SOME y } = SOME x0`
       by (Cases_on `wleast w1 { x | ?y. wo2wo w1 w2 x = SOME y }` >>
           rw[] >> imp_res_tac wleast_EQ_NONE >>
           pop_assum mp_tac >> simp[SUBSET_DEF] >> qexists_tac `x` >>
           rw[]) >>
    pop_assum (mp_tac o MATCH_MP (GEN_ALL wleast_IN_wo)) >>
    rw[] >>
    `!x. (x,x0) WIN w1 ==> ?y. wo2wo w1 w2 x = SOME y`
       by metis_tac [WIN_TRANS, WIN_REFL, WIN_elsOf] >>
    qsuff_tac `orderlt w2 w1` >- rw[] >>
    simp[orderlt_def] >> qexists_tac `x0` >> rw[] >>
    MATCH_MP_TAC orderiso_SYM >>
    rw[orderiso_def] >>
    qexists_tac `THE o wo2wo w1 w2` >>
    `elsOf (wobound x0 w1) = { x | (x,x0) WIN w1 }`
       by (rw[elsOf_wobound] >> rw[] >>
           `?z. s = {z}` by metis_tac [SING_IFF_CARD1, SING_DEF] >>
           `(z,x0) WIN w1` by fs[Abbr`s`, EXTENSION] >>
           `elsOf w2 = woseg w1 w2 x0`
              by metis_tac [wo2wo_EQ_NONE_woseg, optionTheory.option_CASES] >>
           ` _ = {THE (wo2wo w1 w2 z)}`
              by (asm_simp_tac(srw_ss() ++ DNF_ss)[EXTENSION] >>
                  `?y. wo2wo w1 w2 z = SOME y` by metis_tac[] >>
                  simp[EQ_IMP_THM, FORALL_AND_THM] >>
                  Tactical.REVERSE conj_tac
                    >- (qexists_tac `z` >> rw[iseg_def]) >>
                  asm_simp_tac (srw_ss() ++ DNF_ss) [iseg_def]) >>
           fs[elsOf_NEVER_SING]) >>
    simp[] >> rpt conj_tac >| [
      metis_tac [wo2wo_IN_w2, optionTheory.THE_DEF],
      metis_tac [wo2wo_11, optionTheory.THE_DEF, WIN_elsOf],
      `elsOf w2 = woseg w1 w2 x0`
        by metis_tac [wo2wo_EQ_NONE_woseg, optionTheory.option_CASES] >>
      asm_simp_tac (srw_ss() ++ DNF_ss) [iseg_def] >>
      metis_tac [optionTheory.option_CASES],
      simp[IN_wobound] >> metis_tac [optionTheory.THE_DEF, wo2wo_mono]
    ],
    ALL_TAC
  ] >>
  fs[METIS_PROVE []``(!x. ~P x \/ Q x) = (!x. P x ==> Q x)``,
     METIS_PROVE [optionTheory.option_CASES, optionTheory.NOT_SOME_NONE]
                  ``(x <> NONE) <=> ?y. x = SOME y``] >>
  Cases_on `elsOf w2 = { y | ?x. x IN elsOf w1 /\ (wo2wo w1 w2 x = SOME y) }`
  >| [
    qsuff_tac `orderiso w1 w2` >- rw[] >>
    rw[orderiso_def] >> qexists_tac `THE o wo2wo w1 w2` >>
    pop_assum (strip_assume_tac o SIMP_RULE (srw_ss()) [EXTENSION]) >>
    simp[] >> rpt conj_tac >| [
      metis_tac [optionTheory.THE_DEF],
      metis_tac [wo2wo_11, optionTheory.THE_DEF],
      metis_tac [optionTheory.THE_DEF],
      metis_tac [optionTheory.THE_DEF, wo2wo_mono, WIN_elsOf]
    ],
    ALL_TAC
  ] >>
  `?y. y IN elsOf w2 /\ !x. x IN elsOf w1 ==> (wo2wo w1 w2 x <> SOME y)`
    by (pop_assum mp_tac >> simp[EXTENSION] >> metis_tac [wo2wo_IN_w2]) >>
  qabbrev_tac `
    y0_opt = wleast w2 { y | ?x. x IN elsOf w1 /\ (wo2wo w1 w2 x = SOME y) }
  ` >>
  `y0_opt <> NONE`
     by (qunabbrev_tac `y0_opt` >> strip_tac >>
         imp_res_tac wleast_EQ_NONE >> fs[SUBSET_DEF] >> metis_tac[]) >>
  `?y0. y0_opt = SOME y0` by metis_tac [optionTheory.option_CASES] >>
  qunabbrev_tac `y0_opt` >>
  pop_assum (strip_assume_tac o MATCH_MP wleast_IN_wo) >> fs[] >>
  qsuff_tac `orderlt w1 w2` >- rw[] >> simp[orderlt_def] >>
  qexists_tac `y0` >> simp[orderiso_def] >>
  qexists_tac `THE o wo2wo w1 w2` >>
  `!a b. a IN elsOf w1 /\ (wo2wo w1 w2 a = SOME b) ==> (b,y0) WIN w2`
    by (rpt strip_tac >>
        `b <> y0` by metis_tac [] >>
        `~((y0,b) WIN w2)`
           by metis_tac [wo2wo_ONTO, optionTheory.NOT_SOME_NONE] >>
        metis_tac [WIN_trichotomy, wo2wo_IN_w2]) >>
  `elsOf (wobound y0 w2) = { y | (y,y0) WIN w2}`
     by (rw[elsOf_wobound] >> rw[] >>
         `?z. s = {z}` by metis_tac [SING_IFF_CARD1, SING_DEF] >>
         `(z,y0) WIN w2` by fs[Abbr`s`, EXTENSION] >>
         `~((y0,z) WIN w2)` by metis_tac [WIN_TRANS, WIN_REFL] >>
         `z <> y0` by metis_tac [WIN_REFL] >>
         `z IN elsOf w2` by metis_tac [WIN_elsOf] >>
         `?x. x IN elsOf w1 /\ (wo2wo w1 w2 x = SOME z)` by metis_tac[] >>
         qsuff_tac `elsOf w1 = {x}` >- metis_tac [elsOf_NEVER_SING] >>
         simp[EXTENSION, EQ_IMP_THM] >> qx_gen_tac `x'` >>
         spose_not_then strip_assume_tac >>
         `?z'. (wo2wo w1 w2 x' = SOME z') /\ z' IN elsOf w2 /\ (z',y0) WIN w2`
            by metis_tac [wo2wo_IN_w2] >>
         `z' <> z` by metis_tac [wo2wo_11] >>
         `z' IN s` by rw[Abbr`s`] >> rw[] >> fs[]) >>
  simp[] >> rpt conj_tac >| [
    metis_tac [optionTheory.THE_DEF],
    metis_tac [optionTheory.THE_DEF, wo2wo_11],
    metis_tac [WIN_REFL, WIN_TRANS, WIN_elsOf, optionTheory.THE_DEF],
    simp[IN_wobound] >> metis_tac [wo2wo_mono, optionTheory.THE_DEF, WIN_elsOf]
  ]);

val wZERO_def = Define`wZERO = wellorder_ABS {}`

val elsOf_wZERO = store_thm(
  "elsOf_wZERO",
  ``elsOf wZERO = {}``,
  simp[wZERO_def, elsOf_def, #repabs_pseudo_id wellorder_results,
       wellorder_EMPTY, EXTENSION, in_domain, in_range]);
val _ = export_rewrites ["elsOf_wZERO"]

val WIN_wZERO = store_thm(
  "WIN_wZERO",
  ``(x,y) WIN wZERO <=> F``,
  simp[wZERO_def, #repabs_pseudo_id wellorder_results, wellorder_EMPTY]);
val _ = export_rewrites ["WIN_wZERO"]

val orderiso_wZERO = store_thm(
  "orderiso_wZERO",
  ``orderiso wZERO w <=> (w = wZERO)``,
  simp[orderiso_thm, BIJ_EMPTY, EQ_IMP_THM] >>
  Q.ISPEC_THEN `w` strip_assume_tac wellorder_cases >>
  simp[elsOf_def, EXTENSION, in_range, in_domain, wZERO_def,
       #term_ABS_pseudo11 wellorder_results, wellorder_EMPTY,
       #repabs_pseudo_id wellorder_results,
       pairTheory.FORALL_PROD]);

val elsOf_EQ_EMPTY = store_thm(
  "elsOf_EQ_EMPTY",
  ``(elsOf w = {}) <=> (w = wZERO)``,
  simp[EQ_IMP_THM] >> strip_tac >>
  qsuff_tac `orderiso w wZERO` >- metis_tac [orderiso_wZERO, orderiso_SYM] >>
  simp[orderiso_thm, BIJ_EMPTY] >> metis_tac [WIN_elsOf, NOT_IN_EMPTY]);
val _ = export_rewrites ["elsOf_EQ_EMPTY"]

val LT_wZERO = store_thm(
  "LT_wZERO",
  ``orderlt w wZERO = F``,
  simp[orderlt_def]);

val orderlt_WF = store_thm(
  "orderlt_WF",
  ``WF (orderlt : 'a wellorder -> 'a wellorder -> bool)``,
  rw[prim_recTheory.WF_IFF_WELLFOUNDED, prim_recTheory.wellfounded_def] >>
  spose_not_then strip_assume_tac >>
  qabbrev_tac `w0 = f 0` >>
  qsuff_tac `~ WF (\x y. (x,y) WIN w0)` >- rw[WIN_WF2] >>
  simp[relationTheory.WF_DEF] >>
  `!n. orderlt (f (SUC n)) w0`
     by (Induct >- metis_tac [arithmeticTheory.ONE] >>
         metis_tac [orderlt_TRANS]) >>
  `!n. ?x. x IN elsOf w0 /\ orderiso (wobound x w0) (f (SUC n))`
     by metis_tac [orderlt_def, orderiso_SYM] >>
  qexists_tac `
     \e. ?n. e IN elsOf w0 /\ orderiso (wobound e w0) (f (SUC n))
  ` >> simp[] >> conj_tac >- metis_tac[] >>
  qx_gen_tac `y` >>
  Cases_on `y IN elsOf w0` >> simp[] >>
  Cases_on `!n. ~ orderiso (wobound y w0) (f (SUC n))` >> simp[] >>
  pop_assum (Q.X_CHOOSE_THEN `m` strip_assume_tac o SIMP_RULE (srw_ss()) []) >>
  `orderlt (f (SUC (SUC m))) (f (SUC m))` by metis_tac[] >>
  pop_assum (Q.X_CHOOSE_THEN `p` strip_assume_tac o
             SIMP_RULE (srw_ss()) [orderlt_def]) >>
  `?h. BIJ h (elsOf (f (SUC m))) (elsOf (wobound y w0)) /\
       !a b. (a,b) WIN f (SUC m) ==> (h a, h b) WIN wobound y w0`
    by metis_tac [orderiso_thm, orderiso_SYM] >>
  qexists_tac `h p` >>
  `h p IN elsOf (wobound y w0)` by metis_tac [BIJ_IFF_INV] >>
  pop_assum mp_tac >> simp[elsOf_wobound] >> rw[] >>
  qexists_tac `SUC m` >> conj_tac >- metis_tac [WIN_elsOf] >>
  match_mp_tac (INST_TYPE [beta |-> alpha] orderiso_TRANS) >>
  qexists_tac `wobound p (f (SUC m))` >>
  Tactical.REVERSE conj_tac >- metis_tac [orderiso_SYM] >>
  match_mp_tac orderiso_SYM >> simp[orderiso_thm] >> qexists_tac `h` >>
  conj_tac
    >- (`wobound (h p) w0 = wobound (h p) (wobound y w0)` by rw [wobound2] >>
        pop_assum SUBST1_TAC >>
        match_mp_tac wobounds_preserve_bijections >> rw[]) >>
  fs[IN_wobound])

val orderlt_orderiso = store_thm(
  "orderlt_orderiso",
  ``orderiso x0 y0 /\ orderiso a0 b0 ==> (orderlt x0 a0 <=> orderlt y0 b0)``,
  rw[orderlt_def, EQ_IMP_THM] >| [
    `orderiso y0 (wobound x a0)` by metis_tac [orderiso_SYM, orderiso_TRANS] >>
    `?f. BIJ f (elsOf a0) (elsOf b0) /\
         (!x y. (x,y) WIN a0 ==> (f x, f y) WIN b0)`
       by metis_tac [orderiso_thm] >>
    qexists_tac `f x` >> conj_tac
      >- metis_tac [BIJ_DEF, INJ_DEF] >>
    qsuff_tac `orderiso (wobound x a0) (wobound (f x) b0)`
      >- metis_tac [orderiso_TRANS] >>
    rw[orderiso_thm] >> qexists_tac `f` >> rw[IN_wobound] >>
    match_mp_tac wobounds_preserve_bijections >>
    fs[orderiso_thm],
    `orderiso x0 (wobound x b0)` by metis_tac [orderiso_TRANS] >>
    `?f. BIJ f (elsOf b0) (elsOf a0) /\
         (!x y. (x,y) WIN b0 ==> (f x, f y) WIN a0)`
       by metis_tac [orderiso_thm, orderiso_SYM] >>
    qexists_tac `f x` >> conj_tac >- metis_tac [BIJ_IFF_INV] >>
    qsuff_tac `orderiso (wobound x b0) (wobound (f x) a0)`
      >- metis_tac [orderiso_TRANS] >>
    rw[orderiso_thm] >> qexists_tac `f` >> rw[IN_wobound] >>
    match_mp_tac wobounds_preserve_bijections >>
    metis_tac [orderiso_thm, orderiso_SYM]
  ]);

val islimit_def = Define`
  islimit w = !e. e IN elsOf w ==>
                  ?e'. e' IN elsOf w /\ (e,e') WIN w
`;

val islimit_maximals = store_thm(
  "islimit_maximals",
  ``islimit w <=> (maximal_elements (elsOf w) (wellorder_REP w) = {})``,
  rw[islimit_def, maximal_elements_def, EXTENSION] >>
  rw[METIS_PROVE [] ``(!x. ~P x \/ Q x) = (!x. P x ==> Q x)``] >>
  metis_tac [WIN_REFL]);

val islimit_wZERO = store_thm(
  "islimit_wZERO",
  ``islimit wZERO``,
  rw[islimit_def, wZERO_def]);

val islimit_iso = store_thm(
  "islimit_iso",
  ``orderiso w1 w2 ==> (islimit w1 <=> islimit w2)``,
  rw[orderiso_thm, islimit_def, EQ_IMP_THM] >| [
    `?a. a IN elsOf w1 /\ (f a = e)` by metis_tac [BIJ_IFF_INV] >>
    `?b. b IN elsOf w1 /\ (a,b) WIN w1` by metis_tac [] >>
    `f b IN elsOf w2` by metis_tac [BIJ_IFF_INV] >>
    metis_tac[],
    `f e IN elsOf w2` by metis_tac [BIJ_IFF_INV] >>
    `?u. u IN elsOf w2 /\ (f e,u) WIN w2` by metis_tac [] >>
    `?e'. e' IN elsOf w1 /\ (u = f e')` by metis_tac [BIJ_IFF_INV] >>
    metis_tac [WIN_trichotomy, WIN_REFL, WIN_TRANS]
  ]);

val finite_def = Define`
  finite w = FINITE (elsOf w)
`;

val finite_iso = store_thm(
  "finite_iso",
  ``orderiso w1 w2 ==> (finite w1 <=> finite w2)``,
  rw[orderiso_thm, finite_def] >> metis_tac [BIJ_FINITE, BIJ_LINV_BIJ]);

val finite_wZERO = store_thm(
  "finite_wZERO",
  ``finite wZERO``,
  rw[finite_def]);

(* perform quotient, creating a type of "pre-ordinals".

   These should all that's necessary, but I can't see how to define the limit
   operation on these.  Instead, the "real" type of ordinals will be the
   downward-closed sets of pre-ordinals.
*)
fun mk_def(s,t) =
    {def_name = s ^ "_def", fixity = NONE, fname = s, func = t};

val orderiso_equiv = prove(
  ``!s1 s2. orderiso (s1:'a wellorder) (s2:'a wellorder) <=>
            (orderiso s1 : 'a wellorder set = orderiso s2)``,
  rw[FUN_EQ_THM, EQ_IMP_THM] >>
  metis_tac [orderiso_SYM, orderiso_TRANS, orderiso_REFL])

val alphaise =
    INST_TYPE  [beta |-> alpha, delta |-> alpha, gamma |-> alpha]

val [preolt_REFL, preolt_TRANS, preolt_WF0, preolt_trichotomy,
     preolt_ZERO, preo_islimit_ZERO, preo_finite_ZERO] =
    quotient.define_quotient_types_full
    {
     types = [{name = "preord", equiv = orderiso_equiv}],
     defs = map mk_def
       [("preolt", ``orderlt : 'a wellorder -> 'a wellorder -> bool``),
        ("preo_islimit", ``islimit : 'a wellorder -> bool``),
        ("preo_ZERO", ``wZERO : 'a wellorder``),
        ("preo_finite", ``finite : 'a wellorder -> bool``)],
     tyop_equivs = [],
     tyop_quotients = [],
     tyop_simps = [],
     respects = [alphaise islimit_iso, alphaise orderlt_orderiso,
                 alphaise finite_iso],
     poly_preserves = [],
     poly_respects = [],
     old_thms = [orderlt_REFL, alphaise orderlt_TRANS,
                 REWRITE_RULE [relationTheory.WF_DEF] orderlt_WF,
                 alphaise orderlt_trichotomy, alphaise LT_wZERO,
                 islimit_wZERO, finite_wZERO]}

val _ = save_thm ("preolt_REFL", preolt_REFL)
val _ = save_thm ("preolt_TRANS", preolt_TRANS)
val _ = save_thm ("preolt_WF",
                  REWRITE_RULE [GSYM relationTheory.WF_DEF] preolt_WF0)
val _ = save_thm ("preo_ZERO", preolt_ZERO)
val _ = save_thm ("preo_islimit_ZERO", preo_islimit_ZERO)
val _ = save_thm ("preo_finite_ZERO", preo_finite_ZERO)

val _ = type_abbrev ("inf", ``:num + 'a``)

val fromNat_def = Define`
  fromNat n : 'a inf preord =
    preord_ABS_CLASS (orderiso (fromNat0 n : 'a inf wellorder))
`;

val preord_repabs = prove(
  ``preord_REP_CLASS (preord_ABS_CLASS (orderiso (c : 'a wellorder))) =
    (orderiso c : 'a wellorder set)``,
  REWRITE_TAC [GSYM (theorem "preord_ABS_REP_CLASS")] >>
  metis_tac [orderiso_REFL]);

val finite_inl = prove(
  ``FINITE {INL i | i <= n}``,
 `{INL i | i <= n } = IMAGE INL {i | i <= n}`
    by rw[EXTENSION] >>
 rw[] >>
 qsuff_tac `{i | i <= n} = n INSERT count n` >- rw[] >>
 srw_tac[ARITH_ss][EXTENSION]);

val card_inl = prove(
  ``CARD {INL i | i <= n} = n + 1``,
 `{INL i | i <= n } = IMAGE INL {i | i <= n}`
    by rw[EXTENSION] >>
 `{i | i <= n} = n INSERT count n` by srw_tac[ARITH_ss][EXTENSION] >>
 rw[CARD_INJ_IMAGE, finite_inl, arithmeticTheory.ADD1]);

val fromNat_11 = store_thm(
  "fromNat_11",
  ``(fromNat n = fromNat m) = (n = m)``,
  rw[fromNat_def, EQ_IMP_THM] >>
  pop_assum (mp_tac o Q.AP_TERM `preord_REP_CLASS`) >>
  rw[preord_repabs] >>
  pop_assum (mp_tac o C Q.AP_THM `fromNat0 n : 'a inf wellorder`) >>
  simp[orderiso_REFL] >> simp[orderiso_thm] >>
  disch_then (Q.X_CHOOSE_THEN `f` strip_assume_tac) >>
  Cases_on `m = 0` >> Cases_on `n = 0` >> fs[BIJ_EMPTY, elsOf_fromNat0] >| [
    fs[EXTENSION] >> first_x_assum (qspec_then `n` mp_tac) >> rw[],
    fs[EXTENSION] >> first_x_assum (qspec_then `n` mp_tac) >> rw[],
    `m + 1 = n + 1` by metis_tac [FINITE_BIJ_CARD_EQ, finite_inl, card_inl] >>
    fs[]
  ]);

val preo_finite_fromNat = store_thm(
  "preo_finite_fromNat",
  ``preo_finite (fromNat n)``,
  rw[definition "preo_finite_def", fromNat_def, definition "preord_REP_def"] >>
  DEEP_INTRO_TAC SELECT_ELIM_THM >> rw[preord_repabs]
     >- metis_tac [orderiso_REFL] >>
  fs[orderiso_thm, finite_def] >>
  qsuff_tac `FINITE (elsOf (fromNat0 n))` >- metis_tac[BIJ_FINITE] >>
  rw[elsOf_fromNat0, finite_inl]);

val _ = export_theory()